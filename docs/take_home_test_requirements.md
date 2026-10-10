# Pipedrive Sales Funnel — Take-Home Test

## Business context

Vattenfall runs its sales operation in Pipedrive CRM. Sales leadership wants to understand how prospects flow through
the sales process over time: where deals are entering the funnel, how many reach each stage, and where volume concentrates
across the year.

You have been given an extract of the CRM data. Your task is to build a reliable, monthly sales-funnel report on top of it.

## Inputs

Six CSV datasets, supplied by the requester. Together they are the complete source data — there is no separate `deals`
table, and you must not invent one.

| File | Columns | Role |
|---|---|---|
| `data/users.csv` | `id, name, email, modified` | CRM users (deal owners, activity assignees) |
| `data/stages.csv` | `stage_id, stage_name` | Pipeline stage definitions |
| `data/fields.csv` | `ID, FIELD_KEY, NAME, FIELD_VALUE_OPTIONS` | Custom-field metadata |
| `data/deal_changes.csv` | `deal_id, change_time, changed_field_key, new_value` | Change-event log per deal (stage moves, creation, and more) |
| `data/activity.csv` | `activity_id, type, assigned_to_user, deal_id, done, due_to` | Scheduled activities (calls, meetings) linked to deals |
| `data/activity_types.csv` | `id, name, active, type` | Activity type definitions |

A reference PostgreSQL loader script, `load_data.sh`, was also supplied to show how the raw extract was originally
ingested. Treat it as reference for source semantics only; in this repository, load the CSVs through the template's native
non-dbt raw loader (`just load-raw`).

## Required output

Build a dbt model named **`rep_sales_funnel_monthly`** that reports funnel volume at monthly intervals with exactly these
columns, in this order:

| Column | Meaning |
|---|---|
| `month` | Calendar month |
| `kpi_name` | KPI / funnel-step name |
| `funnel_step` | Funnel step label |
| `deals_count` | Count for that month and step |

The report must cover these funnel steps, in order:

| Step | KPI |
|---|---|
| Step 1 | Lead Generation |
| Step 2 | Qualified Lead |
| Step 2.1 | Sales Call 1 |
| Step 3 | Needs Assessment |
| Step 3.1 | Sales Call 2 |
| Step 4 | Proposal/Quote Preparation |
| Step 5 | Negotiation |
| Step 6 | Closing |
| Step 7 | Implementation/Onboarding |
| Step 8 | Follow-up/Customer Success |
| Step 9 | Renewal/Expansion |

The supplied data does not label these steps directly: you must profile the sources and reverse-engineer how deals,
lifecycles, stage history, and call activities map onto the required steps. Document the evidence for every mapping.

## Deliverables

1. dbt sources and a clean model architecture: staging → intermediate → reporting, with `rep_sales_funnel_monthly` as the
   final reporting model.
2. A short analysis document explaining source understanding, deal-identity reconstruction, funnel mappings, KPI
   semantics, assumptions, and limitations.
3. Data tests covering grain, uniqueness, referential integrity, accepted values, chronology, nulls, and funnel-mapping
   coverage — including diagnostics that expose unmapped records.
4. Reproducible run and validation instructions.

## Constraints

- Work in the Delta Lake template: dbt on Spark with Delta tables in MinIO, Unity Catalog as the metastore. Use the
  template's patterns and workflow; do not replace its architecture.
- Load the six CSVs into the raw schema through the template workflow (`just load-raw`).
- Base all semantics on the supplied data; where a requested KPI cannot be derived faithfully, do not fabricate it —
  choose the most defensible evidence-based mapping and clearly flag the limitation.
- Avoid double counting across repeated change events or activities; deduplication must be deterministic.
- Every required funnel step must appear in the report, including months or steps with zero deals if that is the chosen
  reporting contract.

## Validation

- Run the full template workflow: start the stack, load raw data, build and test models, and query
  `rep_sales_funnel_monthly` to verify exact columns, grain, counts, and representative months.
- Reconcile report totals against source-level checks.
- `just ci` runs the Docker-free static checks (`dbt parse` + sqlfluff lint).

## Acceptance criteria

- `rep_sales_funnel_monthly` exists with exactly the columns `month, kpi_name, funnel_step, deals_count` and returns all
  11 required funnel steps.
- The funnel mapping for every step is traceable to evidence in the supplied data and documented in the analysis
  document.
- Counting semantics are explicitly documented and free of double counting.
- All dbt tests pass, including mapping-coverage diagnostics that surface unmapped records.
- Raw data is loaded via the template workflow, all models are Delta tables in the UC-managed warehouse, and the solution
  runs end to end with `just verify`.
