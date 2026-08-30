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
    echo "── Load raw data ──"
    just load-raw
    echo "── dbt seed ──"
    {{DBT_ENV}} uv run dbt seed
    echo "── dbt run ──"
    {{DBT_ENV}} uv run dbt run
    echo "── dbt test ──"
    {{DBT_ENV}} uv run dbt test
    echo "── All verification checks passed ──"

# ── Orb-native runtime ──────────────────────────────────────────────────
# Run the full stack as native processes in the Orb (no Docker needed).
# Requires .agents/setup to have installed Java, Spark, UC, and Maven jars.

ORB_DIR := justfile_directory() + "/infra/orb"
ORB_ENV := "SPARK_THRIFT_HOST=127.0.0.1 SPARK_THRIFT_PORT=10000 DBT_PROFILES_DIR=" + justfile_directory()

# Install Orb-native dependencies (Java, Spark, UC, Maven jars)
orb-setup:
    bash {{ORB_DIR}}/setup.sh

# Start Orb-native services (UC + Spark Thrift) with readiness checks
orb-up:
    bash {{ORB_DIR}}/start.sh

# Stop Orb-native services (kills by PID, no orphans)
orb-down:
    bash {{ORB_DIR}}/stop.sh

# Health check for Orb-native services
orb-status:
    bash {{ORB_DIR}}/status.sh

# Run ad-hoc Spark SQL against the Orb-native stack (e.g. just orb-query "SELECT 1")
# Backticks in SQL (e.g. \`order\`) are safe — single-quoted in the recipe.
orb-query sql:
    #!/usr/bin/env bash
    set -euo pipefail
    export JAVA_HOME="$HOME/.local/share/java-17"
    export PATH="$JAVA_HOME/bin:$PATH"
    "$HOME/.local/share/spark-4.1.1/bin/beeline" -u "jdbc:hive2://127.0.0.1:10000" -e '{{sql}}'

# Load CSV files from data/ into prod.raw (Orb-native, no Docker)
orb-load-raw:
    bash {{ORB_DIR}}/load-raw.sh

# Smoke test: UC API + dbt connection (Orb-native)
orb-smoke:
    #!/usr/bin/env bash
    set -e
    echo "── UC API ──"
    curl -sf http://localhost:8090/api/2.1/unity-catalog/catalogs | head -c 200
    echo
    echo "── dbt debug ──"
    {{ORB_ENV}} uv run dbt debug

# Full Orb-native verification: clean state → start → load-raw → dbt → stop
# No Docker required. Tests the complete stack end-to-end.
verify-orb: ci
    #!/usr/bin/env bash
    set -euo pipefail
    echo "── Stopping any existing services ──"
    bash {{ORB_DIR}}/stop.sh || true
    echo "── Cleaning runtime state ──"
    rm -rf .orb-runtime
    echo "── Starting Orb-native services ──"
    bash {{ORB_DIR}}/start.sh
    trap 'bash {{ORB_DIR}}/stop.sh' EXIT
    echo "── Smoke test ──"
    just orb-smoke
    echo "── Load raw data ──"
    bash {{ORB_DIR}}/load-raw.sh
    echo "── dbt seed ──"
    {{ORB_ENV}} uv run dbt seed
    echo "── dbt run ──"
    {{ORB_ENV}} uv run dbt run
    echo "── dbt test ──"
    {{ORB_ENV}} uv run dbt test
    echo "── All Orb-native verification checks passed ──"
