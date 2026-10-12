# Testing and reconciliation

A test is worth keeping only if a plausible wrong model fails it. Write the test, then make it go red on purpose.

## Structural tests (YAML generic tests)

- `unique` + `not_null` on every model's grain key (composite keys: a singular test on the column combination).
- `relationships` from facts to dims, scoped with `where` to exclude flagged known-absence rows when those map to an explicit unknown member.
- `accepted_values` on every normalised status/category column.

## Independent reconciliations (singular tests in `tests/`)

Recompute each important number straight from `source('raw', ...)` with separate SQL, then compare with the model. Reusing a staging or intermediate model in the check reproduces its bugs.

Reconcile every slice the brief reports on, not just the grand total:

- Row counts: source vs staging vs fact (minus documented exclusions).
- Totals per slice: per entity, per date/period, per group/category, per route or pairing — each independently. A correct total can hide misattribution between slices.
- Zero-activity coverage: spine row count = dimension count × periods.

Return offending rows (dbt convention: a test passes when it returns zero rows), so a failure shows which slice drifted.

## Boundary cases

Pick inputs where right and wrong answers differ:

- Window edges: events exactly on the as-of date, exactly N days before it, and one day either side; month-end and month-start for calendar windows.
- Repeat entities (same customer/asset twice in a window), cancellation-only entities, entities with only flagged rows.
- Ratios with zero numerator (expect 0) and zero denominator (expect documented null).
- Timezone or date-cast edges if timestamps carry times near midnight.

If the real data lacks a boundary case, assert the rule with a small seed or an inline `VALUES` CTE in a singular test.

## Known defects: identity, not thresholds

When the source has accepted defects (orphans, duplicates), list their keys in a seed (for example, `seeds/known_<defect>.csv`) and test that the flagged set equals that list. A `count <= N` threshold passes when one defect is fixed and a new one appears; an identity comparison fails.

## Mutation check

For each important test, temporarily break the thing it guards (drop a status filter, shift a window bound by one day, swap a join to inner, edit one raw value in a scratch copy), run `just test`, confirm it goes red, and revert. Record which mutation each test caught. Delete every mutation before committing.

## Claims about test behaviour

State only what the run shows. `dbt test` failing does not roll back tables `dbt run` already replaced (see [modeling.md](modeling.md)).
