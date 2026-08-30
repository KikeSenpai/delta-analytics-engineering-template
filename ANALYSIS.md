# Pipedrive sales funnel

## Reporting contract

`rep_sales_funnel_monthly` counts distinct reconstructed entities when they are first observed reaching each funnel step.
It is an entry-event report, not a month-end snapshot. Each calendar month from the earliest through latest mapped event
contains all 11 required rows; absent activity is reported as zero. Output grain is `(month, kpi_name, funnel_step)`.

For deal stages, event time is `deal_changes.change_time`. For Sales Call 1 and 2, only completed activities (`done=True`)
count. Their `due_to` timestamp is the event-time proxy because no completion timestamp is supplied. Repeated events for
one reconstructed entity and step retain the earliest timestamp deterministically.

## Source evidence and identity

The six supplied CSVs are loaded unchanged into `prod.raw` with `just load-raw`; dbt begins at typed staging views/tables.
The supplied PostgreSQL `load_data.sh` confirms one CSV maps directly to one same-named raw table, but is not needed by
this Delta/Spark template.

Profiled source facts:

- `deal_changes`: 15,406 rows, 1,995 literal `deal_id` values, and 2,000 `add_time` creation records.
- Five `deal_id` values are reused for two independent lifecycles. All 15,406 changes match exactly one lifecycle by the
  time-of-day signature preserved between `add_time` and `change_time`. Therefore deal identity is the deterministic hash
  of `(deal_id, add_time)`, yielding 2,000 episodes without discarding valid records.
- 8,906 `stage_id` events all map to one reconstructed episode and one of nine supplied stages. Stage chronology has no
  event before its episode creation.
- `activity`: 4,579 rows and 4,568 distinct `activity_id` values. The 11 reused IDs describe different records, so staging
  uses a hash of the full supplied row as record identity. Activity `deal_id` overlaps reconstructed stage entities only
  eight times, so calls are independently namespaced rather than falsely joined to stage lifecycles.
- All activity owners and changed deal owners resolve to `users`. All activity type and stage references resolve.

## Funnel mapping

| Funnel step | KPI | Supplied evidence |
|---|---|---|
| Step 1 | Lead Generation | `stage_id=1` |
| Step 2 | Qualified Lead | `stage_id=2` (`stages` uses minor lowercase variation) |
| Step 2.1 | Sales Call 1 | completed activity type `meeting`, named by `activity_types` |
| Step 3 | Needs Assessment | `stage_id=3` |
| Step 3.1 | Sales Call 2 | completed activity type `sc_2`, named by `activity_types` |
| Step 4 | Proposal/Quote Preparation | `stage_id=4` |
| Step 5 | Negotiation | `stage_id=5` |
| Step 6 | Closing | `stage_id=6` |
| Step 7 | Implementation/Onboarding | `stage_id=7` |
| Step 8 | Follow-up/Customer Success | `stage_id=8` |
| Step 9 | Renewal/Expansion | `stage_id=9` |

`Follow Up Call` is inactive and does not replace stage 8. `After Close Call` is active but has no requested KPI and is
excluded rather than fabricated into one. `lost_reason`, owner changes, user details, and field metadata provide integrity
and interpretation but do not represent funnel entry.

## Architecture and validation

Raw CSVs feed six `stg_pipedrive__*` models. `int_pipedrive__deal_episodes` reconstructs lifecycle identity;
`int_pipedrive__funnel_step_events` unifies stage and call evidence and deduplicates first entries; the report aggregates
those events onto a complete month-step spine.

Run:

```bash
just infra-up
just load-raw
just run
just test
just query "SELECT * FROM prod.analytics.rep_sales_funnel_monthly ORDER BY month, funnel_step"
```

`just ci` runs parsing and linting without Docker. Singular and generic dbt tests enforce source/model nulls, keys,
relationships, accepted domains, chronology, full mapping coverage, report grain, nonnegative counts, and reconciliation.
`just verify` includes `just load-raw`, so its clean-stack run is end-to-end for this supplied dataset.

## Limitations

- No deals snapshot or explicit won/lost status exists. Current-state, conversion, revenue, and close-rate KPIs cannot be
  derived faithfully and are not invented.
- Activity `due_to` is scheduled time, not proven completion time. Counts are completed-as-of-extract activities grouped
  by scheduled month.
- Cross-source deal continuity between activities and stage histories is mostly absent, so this report supports per-step
  entry volume, not individual end-to-end journey or conversion analysis.
