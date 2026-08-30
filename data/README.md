# Raw Data Landing

This folder is the landing zone for raw source data files.

## Purpose

In a real analytics engineering workflow, raw data is landed by the data
engineering team — not by dbt. dbt handles transformations only. This template
simulates that boundary: place raw data files here, then load them into the
`prod.raw` schema with the provided script.

## How raw data is loaded

The `just load-raw` command uses **Beeline**, a command-line JDBC client that
ships with Spark. Beeline connects to the Spark Thrift Server (port 10000) —
the same JDBC endpoint dbt uses — and runs Spark SQL to create Delta tables
from CSV files. No dbt, no Python scripts — just SQL against the running
Spark stack.

Learn more: [Spark Distributed SQL Engine — Thrift Server & Beeline](https://spark.apache.org/docs/latest/sql-distributed-sql-engine)

## Usage

1. Place CSV files in this directory (e.g. `orders.csv`, `customers.csv`)
2. Start the Docker stack: `just infra-up`
3. Load raw data: `just load-raw`

Each CSV file becomes a Delta table in `prod.raw`:

| File             | Table             |
|------------------|-------------------|
| `orders.csv`     | `prod.raw.orders` |
| `customers.csv`  | `prod.raw.customers` |

Table name = filename without extension. CSV must have a header row; column
types are inferred automatically.

## After loading

Create a dbt source definition in `models/` to reference the loaded tables:

```yaml
version: 2

sources:
  - name: raw
    schema: raw
    description: "Raw source tables landed in the Delta warehouse"
    tables:
      - name: orders
        description: "Raw order records"
```

Then build staging models that read from `source('raw', 'orders')`.
