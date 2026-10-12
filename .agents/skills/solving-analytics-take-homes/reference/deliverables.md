# Deliverables

Put the solution write-up where the brief asks; otherwise one Markdown document (for example, `docs/solution.md`) linked from the README. Column and grain definitions live in dbt YAML; the write-up links to them instead of restating.

## Write-up skeleton

1. **Summary:** what was built and how it answers each requirement (from the ledger).
2. **Source and provenance:** files, checksums, row counts, load method, type coercions corrected.
3. **Profiling findings:** grain, keys, defects (with identities and counts), the can / cannot support lists.
4. **ERD:** Mermaid `erDiagram` of dims, facts, and reporting models with keys and cardinalities.
5. **Models:** one line each — name, grain, purpose, materialization.
6. **KPI definitions:** formula, numerator/denominator, status and time-attribution rules, window (rolling or calendar, bounds), additivity, null semantics.
7. **Assumptions:** each labelled, with the evidence or its absence (units, timezone, status meaning) and the impact if wrong.
8. **Limitations:** what the data cannot answer and what extra data would fix it.
9. **Consumer queries:** runnable SQL against `prod.analytics` that answers each brief question, plus sample output from the actual run.
10. **Testing and reconciliation:** what each test guards and which mutation it caught.
11. **CI/CD:** see below.
12. **How to run:** the template commands, nothing bespoke unless needed.

## CI/CD answer: ideal vs constrained

Give both, and say which one the repo implements.

- **Ideal:** PR checks (`just ci`: parse + lint), slim CI building only modified models and their children against an ephemeral schema/catalog with deferred state, data tests gating merge, write-audit-publish or blue/green promotion so failed tests never reach consumers, scheduled production runs with freshness checks and alerting, code owners and docs deployment.
- **Constrained (this template, local stack):** `just ci` on every change; `just verify` (stack up, load, seed, run, test, storage-check, restart, re-test) as the integration gate; table materializations replace in place, so a failed test leaves the new table in place — be explicit about this trade-off.

## Stack proof to include

Paste the decisive lines, not full logs:

- `just test` summary (`PASS=… WARN=0 ERROR=0`).
- `just storage-check` output showing every `prod.raw` and `prod.analytics` table `ok` with `_delta_log=True` and a MinIO `s3://delta-warehouse/...` location.
- The same storage-check and test summary after `just down && just infra-up`.

## Sync check before hand-off

Re-read the write-up against the final code and latest run: model names, grains, KPI formulas, test counts, and every number quoted. Stale statements are worse than missing ones.
