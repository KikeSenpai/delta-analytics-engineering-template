# Air Boltic take-home — original requirements and provenance

This document preserves the **original take-home requirements** for the `take-home/air-service` branch
so a reader can compare the assignment as given against the implemented solution, which is documented
separately in [air_service_analytics.md](air_service_analytics.md).

## Provenance

- The assignment was recovered verbatim from the originating solver thread:
  [T-01a05270-0222-74b0-908e-9b8ecf100831](https://ampcode.com/threads/T-01a05270-0222-74b0-908e-9b8ecf100831).
- The assignment text was delivered as a message in that thread from executor thread
  `T-019f9b6f-87cc-740a-a752-1cd97bc2685e`. **No separate requirements document, PDF, or URL existed**;
  the prompt itself is the authoritative requirement source.
- The six input datasets were supplied as Amp attachment downloads (listed below). The attachment URLs are
  quoted in the solver thread and are not stable long-term; the converted/landed copies live in `data/`.
- One follow-up operational clarification was issued later in the same thread (quoted in its own section
  below). Everything else is reproduced verbatim from the initial assignment message.
- Sections of this document that are **not** part of the source text are marked as inferred; see
  [Inferred clarifications](#inferred-clarifications-not-in-the-source-text).

## Original assignment (verbatim)

> Solve this take-home exercise completely end-to-end in the Delta Analytics Engineering Template repository.
> Do the work yourself and do not create another thread. Start from the latest `origin/main`, preserve `main`,
> create branch `take-home/air-service`, commit the completed solution, and push that branch automatically.
> Never merge into or push changes to `main`.
>
> Download and use these input files:
>
> - `https://ampcode.com/user-content/attachments/93b6835c450eb27afdcc1b35cf8d5d1064e6453381d8ef1329ac96fa07604113-trip.csv`
> - `https://ampcode.com/user-content/attachments/a166f72a0c09cab54f2c46d3dddbb032ed988ecc570f51696d73c9da502ad978-order.csv`
> - `https://ampcode.com/user-content/attachments/3827ac6d5e48a5bc21256deb7663ecd7c698a9249d44045cf62c68b81c918e5b-customer_group.csv`
> - `https://ampcode.com/user-content/attachments/109ef23aab13472000247b2495e43a9d18af77cb569b7bc9d907ef666d9112bb-customer.csv`
> - `https://ampcode.com/user-content/attachments/8da3df3e5617671a01cedccaca68c03d2424119fa9aba40cabffbc89b182d902-aeroplane_model.json`
> - `https://ampcode.com/user-content/attachments/a2979359b8a162f4aef4faec47a367a5e814f8f401d2b4d3041f487698a3ffde-aeroplane.csv`
>
> Convert `aeroplane_model.json` into a clean CSV suitable for the template raw loader. Do not add the JSON file to
> `data/`; add only the converted CSV and supplied CSV datasets. Preserve provenance/document the conversion and
> validate row/field fidelity.
>
> Business brief:
>
> Bolt hypothetically launched Air Boltic, a marketplace matching aeroplane operators with individuals/groups needing
> transport. The service wants to understand regional growth drivers, customer segments served well, use cases
> (distance, geography, price tier, group/seat size, aircraft type), and portfolio-comparable metrics including
> DAU/WAU/MAU and revenue. It aims to facilitate 20% of global aeroplane rides by 2030.
>
> Task:
>
> Design and implement a reliable, scalable, maintainable, user-friendly analytical data model for monitoring and
> self-service analysis. Deliver both the implemented model and documentation explaining its design. At minimum:
>
> - Inspect and profile every dataset deeply; infer grain, keys, relationships, timestamps, statuses, units, null
>   behavior, and anomalies from evidence rather than assumptions.
> - Load all raw CSVs through the template's non-dbt raw-loading workflow into the raw schema.
> - Define dbt sources with freshness/tests where supported and useful.
> - Build sensible staging, intermediate, fact, dimension, and reporting/mart layers. Choose grains and history
>   handling appropriate to supplied data and anticipated scale.
> - Support regional growth analysis, customer/customer-group segmentation, route/use-case analysis, aircraft/model
>   analysis, order/seat economics, trips, revenue, and daily/weekly/monthly active users. Define active-user and
>   revenue semantics explicitly.
> - Add robust generic and singular data tests for keys, relationships, accepted values, logical consistency, and
>   important business rules without encoding false assumptions.
> - Provide an ERD (Mermaid is acceptable), model dictionary, grain/key documentation, KPI definitions, assumptions,
>   limitations, and rationale.
> - Keep the solution appropriately scoped to the actual data; clearly identify metrics that cannot be computed
>   reliably.
> - Use Delta/Spark/dbt patterns native to this template; do not replace its architecture.
>
> Validation:
>
> Run the full template workflow and all available checks. If Docker is available, start the stack, load raw data,
> execute dbt build/tests, and query representative outputs/KPIs. Resolve failures. If Docker is unavailable, run
> every static/unit check possible and clearly document runtime gaps. Remove temporary test artifacts. Verify `main`
> remains untouched, branch is pushed, and report the branch name, commit SHA, validation results, key model outputs,
> assumptions, and any blockers.
>
> When finished, reply to the originating Puck thread with a concise completion report and pushed branch URL.

## Operational follow-up (verbatim, solver-thread message 93)

> Rebase `take-home/air-service` onto current `origin/main`, specifically including Orb-native runtime commit
> `abd0982`; run `just verify-orb`; query and reconcile actual KPI/model outputs; fix issues; remove temporary
> artifacts; safely force-push with `--force-with-lease`; leave `main` unmodified; verify local/remote SHA equality;
> report final SHA, evidence, reconciliation, fixes, and limitations.

## Inferred clarifications (not in the source text)

These statements were **not** in the assignment. They record decisions the solver made or readings the solver
applied, listed here so the verbatim requirements above stay clean.

- "The template's non-dbt raw-loading workflow" was read as the repository's `just load-raw` Beeline workflow
  (`data/` landing zone → `prod.raw` Delta tables), per `data/README.md`.
- The template's overall AGENTS.md verification contract (in particular `just verify` being the canonical
  end-to-end check) supplied the concrete interpretation of "run the full template workflow and all available
  checks"; on the Amp orb runtime this was executed as `just verify-orb`.
- "Portfolio-comparable metrics" was interpreted as metrics comparable across the aircraft portfolio
  (utilization, revenue per aircraft/model) rather than financial-portfolio metrics.
- Conversion tooling for `aeroplane_model.json`, the exact column naming (including the `max_weight_kg` /
  `max_distance_nautical_miles` renames), KPI definitions, segment/price-band buckets, the city-geography seed,
  and the warning-severity choice for unresolved customer-group references were all solver decisions, documented
  with their rationale in [air_service_analytics.md](air_service_analytics.md) and [data/README.md](../data/README.md).
- The assignment named no location or filename for the documentation deliverable; `docs/` was the solver's choice.

## Requirement-to-implementation traceability

Mapping from each original requirement to where the solution satisfies it. (This table is documentation added on
top of the assignment; the solution artifacts are the authoritative implementation.)

| Requirement (source section) | Implementation |
|---|---|
| Input files downloaded and used; JSON converted to CSV, no JSON in `data/`, conversion validated with row/field fidelity | `data/*.csv` (six files incl. `aeroplane_model.csv`); conversion provenance, SHA-256 checksums and field-fidelity evidence in `data/README.md` |
| Load raw CSVs via non-dbt workflow into raw schema | `just load-raw` → `prod.raw.{trip,order,customer,customer_group,aeroplane,aeroplane_model}` |
| dbt sources with freshness/tests where supported and useful | `models/staging/air_service/_air_service__sources.yml`; freshness deliberately not configured (no source ingestion timestamps — see analytics doc) |
| Staging / intermediate / fact / dimension / mart layers with appropriate grains and history handling | `models/staging/air_service/`, `models/intermediate/`, `models/facts/`, `models/dimensions/`, `models/marts/`; current-snapshot decision and production-scale path in the analytics doc |
| Regional growth, segmentation, route/use-case, aircraft/model, order/seat economics, trips, revenue, DAU/WAU/MAU with explicit active-user and revenue semantics | `mart_service_daily`, `mart_customer_segments`, `mart_route_performance`, `mart_aircraft_performance`, `fct_orders`, `fct_trips`, `mart_active_users`; KPI definitions in the analytics doc |
| Generic and singular data tests without false assumptions | `models/**/_*.yml` generic tests; `tests/assert_*.sql` singular tests; warning-severity handling of known-bad group references |
| ERD, model dictionary, grain/key docs, KPI definitions, assumptions, limitations, rationale | `docs/air_service_analytics.md` |
| Identify metrics that cannot be computed reliably | "Assumptions and limitations" section of the analytics doc (duration, distance/passenger-km, share of global rides, status history, retention) |
| Native Delta/Spark/dbt template patterns | Delta tables via dbt-spark under Unity Catalog; MinIO warehouse; no architecture replacement |
| Full validation workflow, remove temp artifacts, `main` untouched, branch pushed and reported | `just verify` / `just verify-orb` runs recorded in the solver thread; completion report posted to the originating Puck thread |
| Operational follow-up: rebase incl. `abd0982`, `just verify-orb`, reconcile KPI outputs, `--force-with-lease` push | `aec1a88` ("fix: support Air Service on Orb runtime") sits on `origin/main`; final branch SHA reported in the solver thread |
