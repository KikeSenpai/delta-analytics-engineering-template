# Load .env (copied from .env.example) so Compose and dbt see the same settings
set dotenv-load

# Default: show available recipes
default:
    @just --list

# ── Python ──────────────────────────────────────────────────────────────

# Install Python dependencies via uv
setup:
    uv sync

# ── Docker stack ────────────────────────────────────────────────────────

COMPOSE := "docker compose -f infra/docker-compose.yml"
DBT_ENV := "DBT_PROFILES_DIR=" + justfile_directory()

# Start the stack and wait for healthchecks: MinIO → bucket init → Unity Catalog → UC bootstrap → Spark
infra-up:
    {{COMPOSE}} up -d --build --wait

# Stop the Docker stack (preserve volumes)
down:
    {{COMPOSE}} down

# Stop the Docker stack and delete all data volumes
clean:
    {{COMPOSE}} down -v

# Show service health status
infra-status:
    {{COMPOSE}} ps

# Tail logs from all services
infra-logs:
    {{COMPOSE}} logs -f --tail=50

# Validate docker-compose syntax (no Docker daemon needed)
compose-check:
    {{COMPOSE}} config --quiet

# List all objects in the MinIO warehouse bucket
minio-ls:
    docker exec infra-minio-1 mc ls -r local/delta-warehouse

# Prove every prod.raw / prod.analytics table is physically stored in MinIO (Delta log + data files)
storage-check:
    #!/usr/bin/env -S uv run python
    import json, subprocess, sys, urllib.request
    failed = False
    for schema in ("raw", "analytics"):
        url = f"http://localhost:8090/api/2.1/unity-catalog/tables?catalog_name=prod&schema_name={schema}"
        tables = json.load(urllib.request.urlopen(url)).get("tables", [])
        print(f"prod.{schema}: {len(tables)} table(s)")
        for table in tables:
            location = table["storage_location"]
            listing = subprocess.run(
                ["docker", "exec", "infra-minio-1", "mc", "ls", "-r", "local/" + location.removeprefix("s3://")],
                capture_output=True, text=True,
            ).stdout
            has_log = "_delta_log/00000000000000000000.json" in listing
            parquet = listing.count(".parquet")
            ok = location.startswith("s3://delta-warehouse/") and has_log
            failed |= not ok
            print(f"  {'ok  ' if ok else 'FAIL'} {table['name']}: _delta_log={has_log} parquet_files={parquet} {location}")
    sys.exit("Tables missing from MinIO" if failed else 0)

# ── dbt ─────────────────────────────────────────────────────────────────

# Check dbt can connect to Spark Thrift Server
debug:
    {{DBT_ENV}} uv run dbt debug

# Load seed files into the default target schema (prod.analytics)
seed:
    {{DBT_ENV}} uv run dbt seed

# Run ad-hoc Spark SQL queries against the running stack (e.g. just query "SELECT * FROM prod.raw.orders LIMIT 10")
query sql:
    docker exec infra-spark-1 beeline -u "jdbc:hive2://localhost:10000" -e "{{sql}}"

# Load CSV files from data/ into prod.raw as Delta tables (non-dbt, simulates raw data landing)
load-raw:
    #!/usr/bin/env bash
    set -euo pipefail
    csv_files=$(ls data/*.csv 2>/dev/null || true)
    if [ -z "$csv_files" ]; then
        echo "No CSV files found in data/"
        echo "Place raw CSV files in the data/ directory first. See data/README.md"
        exit 1
    fi
    docker exec infra-spark-1 mkdir -p /tmp/raw-data
    docker cp data/. infra-spark-1:/tmp/raw-data/
    for csv_file in $csv_files; do
        table_name=$(basename "$csv_file" .csv)
        echo "Loading $csv_file → prod.raw.$table_name"
        docker exec infra-spark-1 beeline -u "jdbc:hive2://localhost:10000" \
            -e "CREATE OR REPLACE TEMPORARY VIEW raw_csv_input USING CSV OPTIONS (path '/tmp/raw-data/${table_name}.csv', header 'true', inferSchema 'true'); DROP TABLE IF EXISTS prod.raw.\`${table_name}\`; CREATE TABLE prod.raw.\`${table_name}\` USING DELTA AS SELECT * FROM raw_csv_input; DROP VIEW raw_csv_input"
    done
    echo "Raw data loaded into prod.raw"

# Run dbt models
run *args:
    {{DBT_ENV}} uv run dbt run {{args}}

# Run dbt tests
test:
    {{DBT_ENV}} uv run dbt test

# Run dbt docs generate + serve
docs:
    {{DBT_ENV}} uv run dbt docs generate && {{DBT_ENV}} uv run dbt docs serve

# Parse dbt project without connecting to anything (fast syntax check)
parse:
    {{DBT_ENV}} uv run dbt parse

# ── SQL linting ─────────────────────────────────────────────────────────

# Lint SQL files with sqlfluff
lint:
    uv run sqlfluff lint models/

# Auto-fix SQL lint violations
fix:
    uv run sqlfluff fix models/

# ── Composite workflows ─────────────────────────────────────────────────

# Smoke test: verify UC API is up + dbt can connect
smoke:
    #!/usr/bin/env bash
    set -e
    echo "── UC API ──"
    curl -sf http://localhost:8090/api/2.1/unity-catalog/catalogs | head -c 200
    echo
    echo "── dbt debug ──"
    {{DBT_ENV}} uv run dbt debug

# Static CI check: parse + lint (no Docker needed)
ci: parse lint
    @echo "CI checks passed"

# Full verification: static checks + Compose validation + runtime integration
# Run this when changes touch infra/, profiles.yml, dependency versions, or service wiring
verify: ci compose-check
    #!/usr/bin/env bash
    set -euo pipefail
    trap '{{COMPOSE}} down -v' EXIT
    echo "── Starting Docker stack ──"
    just infra-up
    echo "── Smoke test ──"
    just smoke
    echo "── Load raw data ──"
    just load-raw
    echo "── dbt seed ──"
    {{DBT_ENV}} uv run dbt seed
    echo "── dbt run ──"
    {{DBT_ENV}} uv run dbt run
    echo "── dbt test ──"
    {{DBT_ENV}} uv run dbt test
    echo "── MinIO storage check ──"
    just storage-check
    echo "── Restart persistence check ──"
    row_counts() {
        for csv_file in data/*.csv; do
            table_name=$(basename "$csv_file" .csv)
            count=$(docker exec infra-spark-1 beeline -u "jdbc:hive2://localhost:10000" --silent=true \
                --showHeader=false --outputformat=csv2 -e "SELECT COUNT(*) FROM prod.raw.\`${table_name}\`" \
                2>/dev/null | awk 'END { print $NF }')
            [[ "$count" =~ ^[0-9]+$ ]] || { echo "Cannot count prod.raw.$table_name" >&2; return 1; }
            echo "prod.raw.$table_name: $count rows"
        done
    }
    before=$(row_counts)
    echo "$before"
    {{COMPOSE}} down
    just infra-up
    after=$(row_counts)
    [ "$before" = "$after" ] || { echo "Row counts changed across restart:"; echo "$after"; exit 1; }
    echo "Row counts unchanged after restart"
    {{DBT_ENV}} uv run dbt test
    just storage-check
    echo "── All verification checks passed ──"
