# Delta Analytics Engineering Template

Delta Lake analytics stack for analytics engineer take-home tests. Spark + Delta + MinIO + dbt, with UV for Python dependency management and sqlfluff for SQL linting.

## Stack

| Component | Purpose |
|-----------|---------|
| Spark 4.1 + Delta 4.1 | SQL engine + table format |
| MinIO | S3-compatible object storage |
| Spark Thrift Server | JDBC endpoint for dbt-spark |
| dbt-spark | Transformations (Delta format, merge strategy) |
| UV | Python dependency management |
| sqlfluff | SQL linter (sparksql dialect, dbt-aware) |
| just | CLI command runner |

## Quickstart

### 1. Install UV + just

```bash
# UV — Python package manager
curl -LsSf https://astral.sh/uv/install.sh | sh

# just — command runner
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
```

### 2. Install Python dependencies

```bash
just setup
# or: uv sync
```

### 3. Start the Docker stack

```bash
cp .env.example .env.local
just up
# or with Unity Catalog: just up-uc
```

Spark Thrift Server is ready when the `spark` container healthcheck passes (~60s on first run — Maven downloads Delta jars).

### 4. Run dbt

```bash
just debug     # verify Thrift connection
just run       # build models
just test      # run tests
just docs      # generate + serve docs
```

### 5. Lint SQL

```bash
just lint      # check SQL style
just fix       # auto-fix violations
```

### 6. CI check (no Docker needed)

```bash
just ci        # dbt parse + sqlfluff lint
```

## Available commands

Run `just` to see all recipes:

| Command | Description |
|---------|-------------|
| `just setup` | Install Python deps via UV |
| `just up` | Start Docker stack (Spark + MinIO) |
| `just up-uc` | Start with Unity Catalog |
| `just down` | Stop Docker stack |
| `just debug` | Check dbt Thrift connection |
| `just run` | Run dbt models |
| `just test` | Run dbt tests |
| `just docs` | Generate + serve dbt docs |
| `just lint` | Lint SQL with sqlfluff |
| `just fix` | Auto-fix SQL lint violations |
| `just parse` | Parse dbt project (fast syntax check) |
| `just ci` | Full CI check (parse + lint) |

## Architecture

```
dbt-spark  --thrift-->  Spark Thrift Server  --S3A-->  MinIO
                              |
                        Delta Lake format
                              |
                     Unity Catalog (optional)
```

### Delta session catalog

Three configs in `spark/conf/spark-defaults.conf` make Delta the session catalog — unqualified table names use Delta format, same as Databricks:

```properties
spark.sql.extensions             io.delta.sql.DeltaSparkSessionExtension
spark.sql.catalog.spark_catalog  org.apache.spark.sql.delta.catalog.DeltaCatalog
```

### dbt incremental models

Models use `file_format='delta'` and `incremental_strategy='merge'` — these carry over verbatim when switching to `dbt-databricks` for production.

```sql
{{ config(materialized='incremental', file_format='delta',
          incremental_strategy='merge', unique_key='order_id') }}
```

### SQL linting

sqlfluff is configured with:
- Dialect: `sparksql`
- Templater: `jinja` with dbt builtins (`ref`, `source`, `config`, `var`, `is_incremental`)
- Max line length: 120
- Keywords/functions: uppercase, identifiers: lowercase

Config: `.sqlfluff`

### Prod migration

Swap `dbt-spark` for `dbt-databricks` in `profiles.yml`:

```yaml
prod:
  type: databricks
  host: <workspace>.cloud.databricks.com
  http_path: /sql/1.0/warehouses/<id>
  catalog: main
  schema: analytics
```

Install: `uv add dbt-databricks`

## Version compatibility

| Component | Version |
|-----------|---------|
| Python | 3.11 |
| Spark | 4.1.0 |
| Delta | 4.1.0 |
| dbt-core | 1.11.x |
| dbt-spark | 1.11.x |
| sqlfluff | 4.x |

Delta ↔ Spark pinning is strict. Check https://docs.delta.io/releases before upgrading.

## Project structure

```
.
├── justfile              # CLI commands (just <recipe>)
├── pyproject.toml        # Python deps (uv sync)
├── uv.lock               # Locked dependency versions
├── .python-version       # Python 3.11
├── .sqlfluff             # SQL linter config
├── .sqlfluffignore       # Lint exclusions
├── dbt_project.yml       # dbt project config
├── profiles.yml          # dbt connection profiles
├── docker-compose.yml    # Spark + MinIO + UC (optional)
├── spark/
│   ├── conf/spark-defaults.conf  # Delta + S3A config
│   └── entrypoint.sh             # Thrift Server startup
├── models/
│   └── staging/
│       ├── _sources.yml          # Source definitions
│       └── stg_orders.sql        # Sample Delta incremental model
├── .agents/
│   ├── setup            # Orb setup (uv sync + tools)
│   └── resume           # Orb resume (fast check)
└── .env.example         # Environment variables template
```
