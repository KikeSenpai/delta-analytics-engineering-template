# Default: show available recipes
default:
    @just --list

# Install Python dependencies via uv
setup:
    uv sync

# Start the full Docker stack (Spark + MinIO)
up:
    docker compose up -d

# Start with Unity Catalog
up-uc:
    docker compose --profile uc up -d

# Stop the Docker stack
down:
    docker compose down

# Check dbt can connect to Spark Thrift Server
debug:
    DBT_PROFILES_DIR={{justfile_directory()}} uv run dbt debug

# Run dbt models
run *args:
    DBT_PROFILES_DIR={{justfile_directory()}} uv run dbt run {{args}}

# Run dbt tests
test:
    DBT_PROFILES_DIR={{justfile_directory()}} uv run dbt test

# Run dbt docs generate + serve
docs:
    DBT_PROFILES_DIR={{justfile_directory()}} uv run dbt docs generate && DBT_PROFILES_DIR={{justfile_directory()}} uv run dbt docs serve

# Lint SQL files with sqlfluff
lint:
    uv run sqlfluff lint models/

# Auto-fix SQL lint violations
fix:
    uv run sqlfluff fix models/

# Parse dbt project without connecting to anything (fast syntax check)
parse:
    DBT_PROFILES_DIR={{justfile_directory()}} uv run dbt parse

# Full CI check: parse + lint
ci: parse lint
    @echo "CI checks passed"
