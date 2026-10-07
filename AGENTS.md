# AGENTS.md

Guidance for AI agents working in this repository.

## Project overview

Delta Lake analytics engineering template for take-home tests.
Stack: MinIO (table storage) + Unity Catalog OSS (metadata) + Spark 4.1 + Delta 4.3 + dbt-spark + UV + sqlfluff + just.
MinIO is required: every `prod.*` Delta table is physically stored in `s3://delta-warehouse`.

## Layout

```
├── dbt_project.yml, profiles.yml   # dbt project root
├── models/                          # dbt models (empty — template user adds)
├── seeds/                           # dbt seed files (empty — optional)
├── macros/                          # dbt macros (empty — template user adds)
├── data/                            # Raw CSV landing zone (load-raw reads from here)
├── infra/                           # Docker stack (compose, Spark Dockerfile + conf, UC conf)
├── justfile                         # CLI commands
├── pyproject.toml                   # Python deps + sqlfluff config
├── .agents/                         # Amp orb lifecycle scripts (setup, resume)
└── .amp/services.yaml               # Amp orb supervised services (dockerd)
```

## Testing workflow

### SQL/dbt-only changes (models, seeds, macros, profiles.yml)

Run `just ci` — executes `dbt parse` + `sqlfluff lint`. No Docker needed.

### Infrastructure changes (infra/, docker-compose, service wiring, dependency versions)

Run `just verify` — the canonical end-to-end check, locally and in Amp orbs (requires Docker). It:

1. Runs static checks (`dbt parse` + `sqlfluff lint`)
2. Validates `docker-compose.yml` syntax
3. Starts the stack with `just infra-up` (MinIO → bucket init → UC → UC bootstrap → Spark, `--wait` on healthchecks)
4. Verifies UC API is responding
5. Loads CSV files from `data/` into `prod.raw` (`load-raw`)
6. Runs `dbt seed` (load seed data into prod.analytics)
7. Runs `dbt run` (build models)
8. Runs `dbt test` (data tests)
9. Runs `just storage-check` (every prod.raw / prod.analytics table has its Delta log in MinIO)
10. Restarts the stack (volumes kept), then re-checks raw row counts, `dbt test` and storage
11. Tears down the stack and volumes on exit (trap)

**Never claim infrastructure works if only static checks ran.**

`just verify` requires user-provided CSV files in `data/` and fails at `load-raw` without them. This is intended: do not commit sample data or make `verify` generate data.

When testing template changes (as a maintainer/agent), create a small temporary fixture such as `data/fixture_orders.csv` (plus a temporary model under `models/` so `prod.analytics` is exercised), run `just verify`, then delete the fixtures and confirm `git status` shows no CSV files or fixture models before committing.

### Querying raw data

After loading raw data with `just load-raw`, explore it with:

```bash
just query "SELECT * FROM prod.raw.orders LIMIT 10"
just query "SHOW TABLES IN prod.raw"
just query "DESCRIBE TABLE prod.raw.orders"
```

This runs Spark SQL via Beeline against the Thrift Server — no dbt needed.

### In Amp orbs

Docker runs in orbs too: `.agents/setup` installs Docker Engine + the Compose plugin, and `.amp/services.yaml` declares `dockerd` as the supervised `docker-daemon` service. `.agents/resume` starts it and waits until `docker info` succeeds (default 8 s, fits Amp's 10 s resume window; override with `DOCKER_WAIT_TIMEOUT`). On timeout it exits non-zero and prints the service status (see `~/.cache/amp/logs/resume.log`); rerun `.agents/resume` and check `amp orb service logs docker-daemon`. Host port 8081 is taken in orbs, so the UC REST API is published on `localhost:8090` everywhere.

### On failure

- `just infra-status` — show container health
- `just infra-logs` — tail service logs
- `docker logs infra-spark-1` — Spark Thrift Server log (runs in the foreground)
- `docker logs infra-unity-catalog-1` — UC server log
- `docker logs infra-uc-init-1` / `docker logs infra-minio-init-1` — bootstrap output
- `just minio-ls` — objects in `s3://delta-warehouse`

## Prerequisites

- **Docker** must be installed and running for any infra/dbt runtime command.
- `just setup` (or `uv sync`) installs Python dependencies.
- `.agents/setup` installs `uv`, `just`, Docker Engine, and the Compose plugin if missing, then syncs dependencies.

## Commands

| Command | When to run |
|---------|-------------|
| `just ci` | SQL/dbt-only changes — fast, no Docker |
| `just compose-check` | Validate compose syntax — no Docker daemon needed |
| `just verify` | Full end-to-end with Docker — infra changes, dependency bumps, service wiring |
| `just infra-up` | Start Docker stack (the only startup command) and wait for health |
| `just infra-status` | Check Docker container health |
| `just infra-logs` | Tail Docker service logs |
| `just smoke` | UC API + dbt connection check (Docker) |
| `just load-raw` | Load CSV files from `data/` into `prod.raw` (Docker, non-dbt) |
| `just query "SELECT ..."` | Run ad-hoc Spark SQL against the Docker stack |
| `just storage-check` | Assert every prod.raw / prod.analytics table is stored in MinIO |
| `just minio-ls` | List objects in the MinIO warehouse bucket |
| `just seed` | Load dbt seed files into `prod.analytics` |
| `just run` | Build dbt models |
| `just test` | Run dbt data tests |
| `just debug` | dbt connection test |
| `just parse` | Parse dbt project (syntax check) |
| `just lint` | SQLFluff lint |
| `just fix` | SQLFluff auto-fix |
| `just clean` | Stop Docker stack + delete volumes |
| `just down` | Stop Docker stack (preserve volumes) |

## Conventions

- SQL keywords: UPPERCASE. Identifiers: lowercase. (sqlfluff enforces.)
- Models use `file_format='delta'` and `incremental_strategy='merge'`.
- Seeds land in the default target schema (`prod.analytics`). Use for small reference/lookup data, not raw source data.
- Raw data is loaded separately from dbt via `just load-raw` — CSV files in `data/` → Delta tables in `prod.raw`. See `data/README.md`.
- UC bootstrap (`uc-init`) creates `prod.default`, `prod.analytics`, `prod.raw` with storage roots `s3://delta-warehouse/prod/<schema>`; all tables are UC-managed and land there.
- UC vends the MinIO keys (`MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from `.env`) to Spark; Spark has no storage keys of its own. See README "Storage credentials".
- `minio-data` (table files) and `uc-db` (metadata) volumes must be kept or deleted together (`just clean`).
- `infra/spark/Dockerfile` bakes pinned jars (Delta, UC connector, hadoop-aws 3.4.2) into `$SPARK_HOME/jars/` at build time (workaround for Spark 4.x ArtifactManager classloader isolation).
