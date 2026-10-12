# Modeling

## Layers

| Layer | Purpose | Rules |
|-------|---------|-------|
| `stg_*` | One model per source table | Rename, cast explicitly, trim, normalise domains. No joins, no filtering of defects (flag them). Keep a source-row identifier for traceability. |
| `dim_*` | Entities and their descriptors | One row per entity at stated grain. Descriptors live here, not copied onto facts. Include explicit unknown members where known absence exists. |
| `fct_*` | Atomic events | Thin: keys, event timestamps, degenerate IDs, additive measures, status. Grain = one source event unless the brief demands otherwise. |
| reporting (`rpt_*`, `agg_*`, or brief-named) | Consumer-ready answers | Pre-aggregated at an explicit grain, with additivity documented per measure. Built from facts and dims, never back into them. |

A layer exists only if it does work. Fewer, well-tested models beat a broad DAG.

## Grain and additivity

State every model's grain in one sentence in its YAML description ("one row per X per day"). For each measure in a reporting model, label it:

- **Additive:** sums across all dimensions (counts, amounts).
- **Semi-additive:** sums across some dimensions, not time (balances, capacity snapshots).
- **Non-additive:** ratios, distinct counts, percentiles. Store numerator and denominator alongside, so consumers re-aggregate correctly.

## Zero activity and supply

Reports that answer "per entity per period" start from a spine (dimension × date spine) and left join activity, so entities with no events appear with zero.

- Counts and sums with no activity are `0` (`COALESCE`), not null.
- Ratios: when the denominator exists but the numerator is zero, the value is `0`. Null is reserved for a genuinely undefined ratio (zero or missing denominator), and the YAML says so. An empty group whose correct answer is zero must not surface as null utilisation.

## Semantics to write down

Each item is sourced from the brief, the data, or a labelled assumption. Put the final wording in the deliverable's KPI section.

- **Activity:** which events count as activity (all records? completed only? excluding cancelled?).
- **Status:** how each status value affects each KPI (demand, fulfilment, revenue).
- **Time attribution:** which timestamp places an event in a period, and in which timezone.
- **Windows:** rolling (last N days relative to an as-of date) or calendar (month, week) — choose explicitly per KPI. Use a deterministic as-of date (for example, the max event date in source, or a dbt `var`) rather than `current_date()`, so results reproduce. State inclusive/exclusive bounds.
- **Revenue proxy:** when no revenue field exists, any price × quantity style metric is a *proxy*: name it as such, state its formula and exclusions, and list what true revenue would need.
- **Classifications and thresholds:** use only those defined by the brief or source. Otherwise leave them out or make them a named `var` with the assumption stated.

## Defects in models

Keep defective rows; add boolean flags (`is_orphan_<parent>`, `is_duplicate`) in staging and carry them where consumers need them. Reporting models document whether flagged rows are included.

## Materialization notes for this template

- Every model materializes as a Delta table (`dbt_project.yml`); UC OSS cannot create views.
- Incremental models use `incremental_strategy='merge'` with a tested `unique_key`; full-rebuild tables are fine for take-home scale.
- `dbt run` replaces each table before `dbt test` runs, and `dbt build` tests after the model is already written. A failing test therefore does **not** preserve the previous good table unless you add a deployment pattern that does (write-audit-publish, blue/green schema swap). Describe it as such.
- Only dbt's built-in generic tests are available (no `packages.yml`). Prefer singular SQL tests in `tests/` over adding packages.
