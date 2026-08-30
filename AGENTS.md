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
└── .agents/                         # Amp orb lifecycle scripts
```

## Testing workflow

### SQL/dbt-only changes (models, seeds, macros, profiles.yml)

Run `just ci` — executes `dbt parse` + `sqlfluff lint`. No Docker needed.

### Orb-native end-to-end (no Docker required)

Run `just verify-orb` — the Orb-native equivalent of `just verify`. It:

1. Runs static checks (`dbt parse` + `sqlfluff lint`)
2. Stops any existing Orb-native services and removes `.orb-runtime/`
3. Starts UC server + Spark Thrift Server as native processes with readiness checks
4. Verifies UC API is responding + dbt can connect (`orb-smoke`)
5. Loads CSV files from `data/` into `prod.raw` (`orb-load-raw`)
6. Runs `dbt seed` (load seed data into prod.analytics)
7. Runs `dbt run` (build models)
8. Runs `dbt test` (data tests)
9. Tears down services on exit (trap)

**Use this inside Amp Orbs** where Docker is unavailable. Requires `.agents/setup` to have installed Java, Spark, UC, and Maven jars (done automatically on orb setup).

### Infrastructure changes (infra/, docker-compose, service wiring, dependency versions)

Run `just verify` — the canonical end-to-end check (requires Docker). It:

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
| `just verify` | Full end-to-end with Docker — infra changes, dependency bumps, service wiring |
| `just verify-orb` | Full end-to-end without Docker — Orb-native, no Docker daemon needed |
| `just infra-up` | Start Docker stack and wait for health |
| `just infra-status` | Check Docker container health |
| `just infra-logs` | Tail Docker service logs |
| `just smoke` | UC API + dbt connection check (Docker) |
| `just load-raw` | Load CSV files from `data/` into `prod.raw` (Docker, non-dbt) |
| `just query "SELECT ..."` | Run ad-hoc Spark SQL against the Docker stack |
| `just orb-setup` | Install Orb-native dependencies (Java, Spark, UC, Maven jars) |
| `just orb-up` | Start Orb-native services (UC + Spark Thrift) |
| `just orb-down` | Stop Orb-native services |
| `just orb-status` | Health check for Orb-native services |
| `just orb-smoke` | UC API + dbt connection check (Orb-native) |
| `just orb-load-raw` | Load CSV files from `data/` into `prod.raw` (Orb-native) |
| `just orb-query "SELECT ..."` | Run ad-hoc Spark SQL against the Orb-native stack |
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
- Raw data is loaded separately from dbt via `just load-raw` (Docker) or `just orb-load-raw` (Orb-native) — CSV files in `data/` → Delta tables in `prod.raw`. See `data/README.md`.
- UC bootstrap creates `prod.default`, `prod.analytics`, `prod.raw` schemas.
- Spark entrypoint resolves Maven jars into `$SPARK_HOME/jars/` (workaround for Spark 4.x ArtifactManager classloader isolation).

### Orb-native runtime

The Orb-native runtime launches the same Spark + Delta + Unity Catalog + dbt-spark stack as native processes (no Docker). It is used inside Amp Orbs where Docker is unavailable.

**Architecture:** Same components, same versions, same configuration semantics as the Docker Compose stack. UC server runs on port 8090 (8080/8081 are occupied in the orb environment). Spark Thrift Server runs on port 10000 (same as Docker, so `profiles.yml` works unchanged).

**Dependencies** (installed by `infra/orb/setup.sh` via `.agents/setup`):
- Java 17 (Temurin) → `~/.local/share/java-17/`
- Spark 4.1.1 → `~/.local/share/spark-4.1.1/`
- Unity Catalog 0.5.0 (built from source) → `~/.local/share/unitycatalog-0.5.0/`
- Delta 4.3.0 + UC connector 0.5.0 Maven jars → `$SPARK_HOME/jars/`

**Runtime state** (all in `.orb-runtime/`, gitignored):
- `pids/` — PID files for UC and Spark Thrift
- `logs/` — UC and Spark log files
- `uc-storage/` — UC storage root (table metadata)
- `spark-warehouse/` — Spark SQL warehouse directory
- `raw-data/` — Staged CSV copies for Spark to read

**Troubleshooting:**
- `just orb-status` — check service health
- `just orb-down` — force stop all services
- If ports are stuck: `ss -tlnp | grep -E '8090|10000'` to find stale processes, `kill` them
- UC logs: `.orb-runtime/logs/uc.log`
- Spark logs: `.orb-runtime/logs/spark-start.log`

**Limitations:**
- UC uses embedded H2 database (same as Docker image). Database is wiped on each `start.sh` invocation for clean state.
- No MinIO support — raw data is loaded from local filesystem.
- `metastore_db/` (Derby) is created at repo root by Spark Thrift Server; gitignored.
