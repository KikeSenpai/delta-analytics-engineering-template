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

## Air Boltic take-home data

The six Air Boltic raw tables are loaded from the supplied exercise files:

| Raw table | Landing file | Source format |
|---|---|---|
| `prod.raw.trip` | `trip.csv` | CSV, unchanged |
| `prod.raw.order` | `order.csv` | CSV, unchanged |
| `prod.raw.customer_group` | `customer_group.csv` | CSV, unchanged |
| `prod.raw.customer` | `customer.csv` | CSV, unchanged |
| `prod.raw.aeroplane` | `aeroplane.csv` | CSV, unchanged |
| `prod.raw.aeroplane_model` | `aeroplane_model.csv` | Converted from supplied JSON |

### Aeroplane model conversion provenance

Source attachment: `8da3df3e5617671a01cedccaca68c03d2424119fa9aba40cabffbc89b182d902-aeroplane_model.json`.
Its SHA-256 is `b91a1b319b31aa00e27de8f93aef382db11c8843b9eae865098ea5c8b4d499c8`.

The JSON has a two-level `manufacturer -> model -> attributes` structure. It was flattened to one row per
manufacturer/model pair. `max_weight` was renamed `max_weight_kg`; `max_distance` was renamed
`max_distance_nautical_miles`, reflecting standard aircraft-specification units. No values were transformed.
Manufacturer and model insertion order from the source was retained.

Conversion validation parsed both files and compared every flattened key/value pair. Result: 9 manufacturers,
19 unique models, 76 JSON attributes and all 114 output CSV fields matched exactly. Output CSV SHA-256:
`82f6176e0ed785ff6c5b59ecf08a6f6368f35a06e064702f60c76f58d2e073cb`.
