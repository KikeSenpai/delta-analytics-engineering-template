# Delta Analytics Engineering Template

Delta Lake analytics stack with Spark, MinIO (S3), and dbt. Mirrors Databricks architecture: same engine (Spark SQL), same format (Delta), same catalog product (Unity Catalog optional).

## Stack

| Component | Purpose |
|-----------|---------|
| Spark 4.1 + Delta 4.1 | SQL engine + table format |
| MinIO | S3-compatible object storage |
| Spark Thrift Server | JDBC endpoint for dbt-spark |
| dbt-spark | Transformations (Delta format, merge strategy) |
| Unity Catalog (optional) | Governance + credential vending |

## Quickstart

### 1. Start the stack

```bash
cp .env.example .env.local
docker compose up -d
```

Spark Thrift Server is ready when the `spark` container healthcheck passes (~60s on first run — Maven downloads Delta jars).

With Unity Catalog:

```bash
docker compose --profile uc up -d
```

### 2. Install dbt

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 3. Run dbt

```bash
export DBT_PROFILES_DIR="$(pwd)"
dbt debug          # verify Thrift connection
dbt run            # build models
dbt test           # run tests
```

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

Install: `pip install dbt-databricks`

## Version compatibility

| Component | Version |
|-----------|---------|
| Spark | 4.1.0 |
| Delta | 4.1.0 |
| dbt-core | 1.11.x |
| dbt-spark | 1.11.x |

Delta ↔ Spark pinning is strict. Check https://docs.delta.io/releases before upgrading.

## Notes

- Spark Thrift Server downloads Delta jars from Maven on first start (~60s). Cached after.
- MinIO credentials are static (`admin`/`password`) for local dev only.
- Unity Catalog integration requires the UC Spark connector. See https://docs.unitycatalog.io/.
