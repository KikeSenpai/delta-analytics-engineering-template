---
name: solving-analytics-take-homes
description: "Solves and reviews analytics-engineering take-homes in this Delta/dbt template: profiling source CSVs, designing source-to-model dimensional cores, defining KPIs, writing reconciliations and tests, documenting, and proving the MinIO/Unity Catalog/Spark/dbt run. Use for take-home problems, source-to-model design, or review/validation of such a solution."
---

# Solving analytics take-homes

An evidence-led workflow: every model, KPI, and claim traces back to a profiled fact in the source or to a labelled assumption. Smallest defensible model that answers the brief, proven on the real stack.

## Guardrails

- **Inputs:** work from the employer's brief and the source files the user supplied. When either is missing, ask for it. Read other branches (saved solutions, `eval/*`, reference answers) only when the user explicitly permits it.
- **Branch:** build the solution on a feature branch. Commit or push to `main` only when the user explicitly asks.
- **Honesty:** report only checks you ran. A claim about storage, persistence, or test behaviour needs the command output behind it.

## Steps

### 1. Ledger the requirements

Split the prompt into two lists in your working notes:

- **Employer requirements:** what the reviewer will grade (questions, deliverables, KPIs, CI/CD question, format).
- **Execution instructions:** how the operator wants you to work (branch, push, report-back, tooling).

Turn each employer requirement into a ledger row: requirement, where it will be satisfied, evidence. Done when every sentence of the brief maps to a row or is explicitly out of scope.

### 2. Land the source with provenance

Copy files byte-for-byte into `data/` (table name = file stem). Record filename, size, checksum (`sha256sum`), row count, and header for each. Then `just infra-up` and `just load-raw`.

`load-raw` uses `inferSchema`, so Spark may coerce types (leading-zero IDs become ints, timestamps parse as strings or shift). Compare `DESCRIBE TABLE prod.raw.<t>` to the raw file and cast explicitly in staging. Done when raw row counts equal the file line counts minus header and every coercion is noted.

### 3. Profile until the data has no surprises

Follow [reference/profiling.md](reference/profiling.md). For every table establish grain, keys, cardinality, nulls, duplicates, status domains, timestamp ranges and formats, units, and anomalies; for every relationship, orphan counts split into *known absence* versus *invalid reference*. Done when every column used downstream has a profiled fact behind it and the "can / cannot support" list is written.

### 4. Design the minimal dimensional core

Follow [reference/modeling.md](reference/modeling.md): thin atomic facts, dimensions owning descriptors, zero-activity and supply preserved, separate reporting aggregates with explicit grain and additivity, and written semantics for activity, status, time attribution, windows, and revenue proxies. Each model earns its place by serving a ledger row; model count is not quality. Done when every ledger row has a model, column, or query that answers it, and every rule in it is sourced from the brief, the data, or a labelled assumption.

### 5. Build, test, reconcile

Implement staging, core, and reporting models in `models/`, then write tests per [reference/testing.md](reference/testing.md): keys and relationships, domains, independent source-to-model reconciliations for every slice that matters, boundary cases, and identity-aware known-defect handling. Prove each important test can go red by mutating a filter or input, then revert. Done when `just ci` passes, `just run` and `just test` pass on the stack, and every test has failed once on purpose.

### 6. Prove the stack

Run the canonical workflow and keep the decisive output:

```bash
just ci && just infra-up && just load-raw && just seed && just run && just test
just storage-check          # every prod.raw and prod.analytics table has _delta_log + parquet in MinIO
just down && just infra-up  # restart with volumes kept
just test && just storage-check
```

`just verify` runs the same sequence end to end but deletes the volumes on exit; run it last or on data you can reload. Done when storage-check lists every raw and transformed table as `ok` both before and after the restart.

### 7. Document and answer the brief

Write the deliverable per [reference/deliverables.md](reference/deliverables.md): ERD, model grains, KPI definitions, assumptions, limitations, consumer queries, and the ideal-versus-constrained CI/CD answer. Grain and column meaning live once, in dbt YAML descriptions; prose docs link to them. Done when every ledger row shows evidence and each doc statement matches the code and the latest run.

### 8. Clean up and hand off

Delete scratch queries, mutation edits, fixture CSVs not part of the deliverable, and stray files; leave `target/` and `.env` ignored. Done when `git status` shows only intended deliverables, docs match the final code, and the hand-off states branch, commit, checks run, and open questions.

## Reviewing a solution

Use the same references as a rubric. Check in order: ledger coverage of the brief, profiled evidence behind each rule, grain and additivity of each model, independence of reconciliations, red-ability of tests, stack proof output, and doc/code agreement. Report findings with file and line, and the source fact that contradicts the claim.
