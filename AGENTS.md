# AGENTS.md

Guidance for AI agents working in this repository.

## Project overview

Delta Lake analytics engineering template for take-home tests.
Stack: Spark 4.1 + Delta 4.3 + Unity Catalog OSS + dbt-spark + UV + sqlfluff + just.

## Layout

```
├── dbt_project.yml, profiles.yml   # dbt project root
├── models/                          # dbt models (empty — template user adds)
├── seeds/                           # dbt seed files (empty — optional)
├── macros/                          # dbt macros (empty — template user adds)
├── data/                            # Raw CSV landing zone (load-raw reads from here)
├── infra/                           # Docker stack (compose, spark, uc configs)
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
3. Starts the full Docker stack with `--wait` (healthchecks)
4. Verifies UC API is responding
5. Loads CSV files from `data/` into `prod.raw` (`load-raw`)
6. Runs `dbt seed` (load seed data into prod.analytics)
7. Runs `dbt run` (build models)
8. Runs `dbt test` (data tests)
9. Tears down the stack and volumes on exit (trap)

**Never claim infrastructure works if only static checks ran.**

### Querying raw data

After loading raw data with `just load-raw`, explore it with:

```bash
just query "SELECT * FROM prod.raw.orders LIMIT 10"
just query "SHOW TABLES IN prod.raw"
just query "DESCRIBE TABLE prod.raw.orders"
```

This runs Spark SQL via Beeline against the Thrift Server — no dbt needed.

### In Amp orbs

Docker runs in orbs too: `.agents/setup` installs Docker Engine + the Compose plugin, and `.amp/services.yaml` declares `dockerd` as the supervised `docker-daemon` service. `.agents/resume` starts it; if `docker info` fails, run `amp orb services ensure` and check `amp orb service logs docker-daemon`. Host port 8081 is taken in orbs, so the UC REST API is published on `localhost:8090` everywhere.

### On failure

- `just infra-status` — show container health
- `just infra-logs` — tail service logs
- `docker exec infra-spark-1 sh -c 'tail -100 /tmp/spark-logs/*.out'` — Spark daemon log
- `docker logs infra-unity-catalog-1` — UC server log

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
| `just infra-up` | Start Docker stack and wait for health |
| `just infra-status` | Check Docker container health |
| `just infra-logs` | Tail Docker service logs |
| `just smoke` | UC API + dbt connection check (Docker) |
| `just load-raw` | Load CSV files from `data/` into `prod.raw` (Docker, non-dbt) |
| `just query "SELECT ..."` | Run ad-hoc Spark SQL against the Docker stack |
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
- UC bootstrap creates `prod.default`, `prod.analytics`, `prod.raw` schemas.
- Spark entrypoint resolves Maven jars into `$SPARK_HOME/jars/` (workaround for Spark 4.x ArtifactManager classloader isolation).
