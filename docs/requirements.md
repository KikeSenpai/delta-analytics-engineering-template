# Original take-home requirements

This document records the original Pipedrive sales-funnel take-home assignment as supplied, so a reader can compare the
requirements against the implemented solution on this branch (`take-home/pipedrive-sales-funnel`). The implemented side is
described in [ANALYSIS.md](../ANALYSIS.md) and [README.md](../README.md).

## Provenance

- The assignment text below was recovered from the first message of the original solver Amp thread
  [`T-01a05270-07eb-746c-987d-ed7d128fc652`](https://ampcode.com/threads/T-01a05270-07eb-746c-987d-ed7d128fc652). That
  thread is the authoritative record of the requirements; no separate assignment document, evaluation rubric, or
  human-authored clarification exists in the thread.
- Provenance caveat: the solver thread's first message was itself an agent-generated instruction (a Puck executor
  prompt), not a directly observed human-authored assignment. Its requirements text is reproduced faithfully below; the
  phrasing of items is the prompt's, and its numbering is preserved.
- The only original requirement artifacts referenced by that thread are the seven linked input files (six CSV datasets
  plus a reference loader script), reproduced in [Requirement artifacts](#requirement-artifacts) below.
- Labels used throughout:
  - **[Verbatim]** — quoted directly from the assignment text.
  - **[Source-derived]** — derived directly from the supplied artifact files (CSV contents, `load_data.sh`), not stated
    in prose.
  - **[Inferred]** — a clarification or interpretation added during recovery or implementation that is **not** part of
    the original assignment. These are the only non-original statements in this document and are always labelled.
  - Unlabelled prose under "Reproduced assignment" is a faithful re-transcription of the thread message.

## Reproduced assignment

> Solve this take-home exercise completely end-to-end in the Delta Analytics Engineering Template repository. Do the work
> yourself and do not create another thread. Start from the latest `origin/main`, preserve `main`, create branch
> `take-home/pipedrive-sales-funnel`, commit the completed solution, and push that branch automatically. Never merge into
> or push changes to `main`.
>
> Download and inspect these inputs:
>
> - users.csv, stages.csv, fields.csv, deal_changes.csv, activity.csv, activity_types.csv (six CSV attachments)
> - load_data.sh (one attachment)
>
> The six CSV datasets—users, stages, fields, deal_changes, activity, and activity_types—are the complete supplied source
> data. There is no separate deals table. Treat `load_data.sh` as reference input: inspect it for source semantics, but
> use the Delta template's native non-dbt raw loader unless a carefully justified adaptation is required.
>
> Requirements:
>
> 1. Remove any test/demo model after confirming the environment works.
> 2. Profile and deeply understand all Pipedrive CRM source data. Research Pipedrive terminology only where useful, but
>    let supplied data determine semantics.
> 3. Define dbt sources and build appropriate staging/intermediate/reporting layers for relevance and maintainability.
> 4. Build `rep_sales_funnel_monthly` at monthly intervals with these funnel steps/KPIs:
>    - Step 1: Lead Generation
>    - Step 2: Qualified Lead
>    - Step 2.1: Sales Call 1
>    - Step 3: Needs Assessment
>    - Step 3.1: Sales Call 2
>    - Step 4: Proposal/Quote Preparation
>    - Step 5: Negotiation
>    - Step 6: Closing
>    - Step 7: Implementation/Onboarding
>    - Step 8: Follow-up/Customer Success
>    - Step 9: Renewal/Expansion
> 5. Exact reporting columns: `month`, `kpi_name`, `funnel_step`, `deals_count`.
>
> Implementation expectations:
>
> - Load the six CSVs into the raw schema through the template workflow; do not invent a missing deals dataset.
> - Reverse-engineer deal identity and lifecycle events from `deal_changes`, stages, fields, activities, and activity
>   types. Document evidence for mappings, especially how each required funnel step is represented.
> - Decide and explicitly document whether monthly counts represent entry events, distinct deals reaching a step, current
>   snapshots, or another defensible semantic. Avoid double counting repeated changes/activities.
> - If any requested KPI cannot be derived faithfully, do not fabricate it: implement the most defensible evidence-based
>   mapping, clearly flag limitations, and include tests/diagnostics that expose unmapped records.
> - Build maintainable staging and intermediate models before the report; use deterministic deduplication and appropriate
>   date handling.
> - Add source/model descriptions and tests for grain, uniqueness, relationships, accepted values, chronology, nulls, and
>   funnel mapping coverage.
> - Ensure all required funnel rows/order labels are represented consistently when justified by the data, including
>   months/steps with zero deals if that is the chosen reporting contract.
> - Add a concise README or analysis document explaining source understanding, architecture, mappings, KPI semantics,
>   assumptions, limitations, and how to run/validate the solution.
> - Use Delta/Spark/dbt patterns native to this template; do not replace its architecture.
>
> Validation:
>
> Run the full template workflow and all available checks. If Docker is available, start the stack, load raw data, execute
> dbt build/tests, and query `rep_sales_funnel_monthly` to verify exact columns, grain, counts, and representative months.
> Reconcile outputs against source-level checks. If Docker is unavailable, run every static/unit check possible and clearly
> document runtime gaps. Remove temporary artifacts. Verify `main` remains untouched, branch is pushed, and report branch
> name, commit SHA, validation results, row/count checks, assumptions, and blockers.
>
> When finished, reply to the originating Puck thread with a concise completion report and pushed branch URL.

## Requirement artifacts

The seven files linked in the assignment are the original requirement artifacts. They were supplied as Amp user-content
attachments; the same data files are now committed in `data/` on this branch.

| Artifact | Observed schema **[Source-derived]** | Original link |
|---|---|---|
| `users.csv` | `id, name, email, modified` | [attachment](https://ampcode.com/user-content/attachments/dcff7328a68742b042c9b58f482154b5b615f51986caff8b41c7a423f6271355-users.csv) |
| `stages.csv` | `stage_id, stage_name` | [attachment](https://ampcode.com/user-content/attachments/83ab40aee3a6b234cb5b06a33292691b0c09d1c247adb137794c26e97cdc5fa4-stages.csv) |
| `fields.csv` | `ID, FIELD_KEY, NAME, FIELD_VALUE_OPTIONS` | [attachment](https://ampcode.com/user-content/attachments/377b6716ffe2af8487c9eb37f4b6f00dc3709da044cc33dbde84791d7a611bfd-fields.csv) |
| `deal_changes.csv` | `deal_id, change_time, changed_field_key, new_value` | [attachment](https://ampcode.com/user-content/attachments/871cf58f96f13add982a285bfe654766e437019432816f52baa02258eb8bcd00-deal_changes.csv) |
| `activity.csv` | `activity_id, type, assigned_to_user, deal_id, done, due_to` | [attachment](https://ampcode.com/user-content/attachments/828b60021d3af15f52d8941e5e29f8225f43c234866deb7e85c2fbcb51221816-activity.csv) |
| `activity_types.csv` | `id, name, active, type` | [attachment](https://ampcode.com/user-content/attachments/13214204a5caa3f7d4d202fc7ac81ca7ab6e4c3b5c12e1d61077f4e695fc334d-activity_types.csv) |
| `load_data.sh` | PostgreSQL `\COPY` loop: one CSV → one same-named table (operational reference only) | [attachment](https://ampcode.com/user-content/attachments/58fd6a1967cfd12f38353776f37dd40258708646d57ff6665d0bc63424d63895-load_data.sh) |

The observed schemas are **[Source-derived]**: they come from inspecting the supplied files and from the recovered solver
thread, not from an assignment document.

**[Inferred]** No evaluation criteria, acceptance thresholds, or target KPI numbers were part of the original
requirements. The only requirements beyond the seven artifacts are those quoted above, plus a later executor-side
(Puck) message in the same thread that reiterated validation and delivery steps (run `just verify-orb`, reconcile the
11-step monthly spine and counts, rebase and force-push with `--force-with-lease`, do not modify `main`). That message
added no new business semantics.

## Requirements → implemented solution

The mapping below is **[Inferred]** context for readers: it links each original requirement to where this branch
implements it. See [ANALYSIS.md](../ANALYSIS.md) for the full evidence trail and [README.md](../README.md) for how to
run and validate.

| Original requirement | Where implemented |
|---|---|
| Load six CSVs via template raw loader | `data/*.csv` → `just load-raw` → `prod.raw` tables |
| Source + staging/intermediate/reporting layers | `models/sources.yml`, `models/staging/`, `models/intermediate/`, `models/reporting/` |
| `rep_sales_funnel_monthly`, 11 steps, exact columns | `models/reporting/rep_sales_funnel_monthly.sql` |
| Deal identity / lifecycle reconstruction, mapping evidence | `models/intermediate/int_pipedrive__deal_episodes.sql`; evidence in `ANALYSIS.md` |
| KPI semantics, no double counting, no fabrication | Entry-event semantics (first observation per entity/step); documented in `ANALYSIS.md` |
| Tests for grain, uniqueness, relationships, chronology, mapping coverage | `models/*/…yml` schema tests and `tests/assert_*.sql` diagnostics |
| Analysis document | `ANALYSIS.md` (reporting contract, source evidence, funnel mapping, limitations) |
| Remove demo model | `models/` contains only take-home models |
| Preserve `main`; work on branch `take-home/pipedrive-sales-funnel` | Branch history; `main` untouched |

**[Inferred]** The reporting contract in `ANALYSIS.md` (entry-event counts, complete month×step spine with zeros,
`due_to` as the call event-time proxy) is the implementation's documented interpretation of requirement 4 and the
"KPI semantics" expectation, not wording from the original assignment.
