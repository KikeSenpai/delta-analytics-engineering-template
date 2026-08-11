# AGENTS.md

Guidance for AI agents working in this repository.

## Project overview

Delta Lake analytics engineering template for take-home tests.
Stack: Spark 4.1 + Delta 4.3 + Unity Catalog OSS + dbt-spark + UV + sqlfluff + just.

## Layout

```
├── dbt_project.yml, profiles.yml   # dbt project root
├── models/                          # dbt models
├── seeds/                           # dbt seed files (fixture source data)
├── macros/                          # dbt macros
├── infra/                           # Docker stack (compose, spark, uc configs)
├── justfile                         # CLI commands
├── pyproject.toml                   # Python deps + sqlfluff config
└── .agents/                         # Amp orb lifecycle scripts
```

## Testing workflow

### SQL/dbt-only changes (models, seeds, macros, profiles.yml)

Run `just ci` — executes `dbt parse` + `sqlfluff lint`. No Docker needed.

### Infrastructure changes (infra/, docker-compose, service wiring, dependency versions)

Run `just verify` — the canonical end-to-end check. It:

1. Runs static checks (`dbt parse` + `sqlfluff lint`)
2. Validates `docker-compose.yml` syntax
3. Starts the full Docker stack with `--wait` (healthchecks)
4. Verifies UC API is responding
5. Runs `dbt debug` (connection test)
6. Runs `dbt seed` (load fixture data)
7. Runs `dbt run` (build models)
8. Runs `dbt test` (data tests)
9. Tears down the stack and volumes on exit (trap)

**Never claim infrastructure works if only static checks ran.**

### On failure

- `just infra-status` — show container health
- `just infra-logs` — tail service logs
- `docker exec infra-spark-1 sh -c 'tail -100 /tmp/spark-logs/*.out'` — Spark daemon log
- `docker logs infra-unity-catalog-1` — UC server log

## Prerequisites

- **Docker** must be installed and running for any infra/dbt runtime command.
- `just setup` (or `uv sync`) installs Python dependencies.
- `.agents/setup` installs `uv` + `just` if missing and syncs dependencies.

## Commands

| Command | When to run |
|---------|-------------|
| `just ci` | SQL/dbt-only changes — fast, no Docker |
| `just compose-check` | Validate compose syntax — no Docker daemon needed |
| `just verify` | Full end-to-end — infra changes, dependency bumps, service wiring |
| `just infra-up` | Start stack and wait for health |
| `just infra-status` | Check container health |
| `just infra-logs` | Tail service logs |
| `just smoke` | UC API + dbt connection check |
| `just seed` | Load fixture data into `main.raw` |
| `just run` | Build dbt models |
| `just test` | Run dbt data tests |
| `just debug` | dbt connection test |
| `just parse` | Parse dbt project (syntax check) |
| `just lint` | SQLFluff lint |
| `just fix` | SQLFluff auto-fix |
| `just clean` | Stop stack + delete volumes |
| `just down` | Stop stack (preserve volumes) |

## Conventions

- SQL keywords: UPPERCASE. Identifiers: lowercase. (sqlfluff enforces.)
- Models use `file_format='delta'` and `incremental_strategy='merge'`.
- Seeds are fixture data — load with `dbt seed` before `dbt run`.
- `generate_schema_name` macro uses custom schema names directly (no concatenation).
- UC bootstrap creates `main.default`, `main.analytics`, `main.raw` schemas.
- Spark entrypoint resolves Maven jars into `$SPARK_HOME/jars/` (workaround for Spark 4.x ArtifactManager classloader isolation).
