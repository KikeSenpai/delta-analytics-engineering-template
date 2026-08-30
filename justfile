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

# Start the full Docker stack and wait for healthchecks
infra-up:
    {{COMPOSE}} up -d --wait

# Start with optional MinIO storage for raw data
up-minio:
    {{COMPOSE}} --profile minio up -d --wait

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

# Bootstrap Unity Catalog catalog + schemas (run once after up)
uc-bootstrap:
    {{COMPOSE}} run --rm uc-init

# ── dbt ─────────────────────────────────────────────────────────────────

# Check dbt can connect to Spark Thrift Server
debug:
    {{DBT_ENV}} uv run dbt debug

# Load seed files into the default target schema (prod.analytics)
seed:
    {{DBT_ENV}} uv run dbt seed

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
            -e "DROP TABLE IF EXISTS prod.raw.${table_name}; CREATE TABLE prod.raw.${table_name} USING DELTA AS SELECT * FROM csv.\`/tmp/raw-data/${table_name}.csv\` OPTIONS (header=true, inferSchema=true)"
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
    curl -sf http://localhost:8081/api/2.1/unity-catalog/catalogs | head -c 200
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
    echo "── Starting Docker stack ──"
    {{COMPOSE}} up -d --wait
    trap '{{COMPOSE}} down -v' EXIT
    echo "── Smoke test ──"
    just smoke
    echo "── dbt seed ──"
    {{DBT_ENV}} uv run dbt seed
    echo "── dbt run ──"
    {{DBT_ENV}} uv run dbt run
    echo "── dbt test ──"
    {{DBT_ENV}} uv run dbt test
    echo "── All verification checks passed ──"
