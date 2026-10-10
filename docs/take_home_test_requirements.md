# Take-Home Test: Air Boltic Analytics Engineering

## Business context

Bolt has hypothetically launched **Air Boltic**, a marketplace matching aeroplane operators with individuals
and groups needing transport. The service wants to understand regional growth drivers, the customer segments
it serves well, and its use cases (distance, geography, price tier, group/seat size, aircraft type), plus
portfolio-comparable metrics including DAU/WAU/MAU and revenue. The business aims to facilitate 20% of global
aeroplane rides by 2030.

Your task is to design and implement a reliable, scalable, maintainable, user-friendly analytical data model
for monitoring and self-service analysis, on the Delta Analytics Engineering Template in this repository.

## Inputs

Six supplied datasets:

- `trip.csv` — scheduled trips
- `order.csv` — seat orders
- `customer.csv` — customers
- `customer_group.csv` — customer groups
- `aeroplane.csv` — aircraft inventory
- `aeroplane_model.json` — aircraft model specifications (nested JSON)

All CSV files are added unchanged to `data/`. The JSON file is **not** added to `data/`: convert it into a
clean CSV suitable for the template raw loader, add only the converted CSV, and validate row/field fidelity
while preserving provenance of the conversion.

## Deliverables

1. **Raw load.** Load all raw CSVs through the template's non-dbt raw-loading workflow into the raw schema.
2. **Sources.** Define dbt sources with freshness/tests where supported and useful.
3. **Data model.** Build sensible staging, intermediate, fact, dimension, and reporting/mart layers. Choose
   grains and history handling appropriate to the supplied data and anticipated scale.
4. **Analysis coverage.** Support regional growth analysis, customer/customer-group segmentation,
   route/use-case analysis, aircraft/model analysis, order/seat economics, trips, revenue, and
   daily/weekly/monthly active users. Define active-user and revenue semantics explicitly.
5. **Data tests.** Add robust generic and singular data tests for keys, relationships, accepted values,
   logical consistency, and important business rules, without encoding false assumptions.
6. **Documentation.** Provide an ERD (Mermaid is acceptable), model dictionary, grain/key documentation, KPI
   definitions, assumptions, limitations, and rationale — delivered as the solution/design document under
   `docs/`.

## Constraints

- Inspect and profile every dataset deeply; infer grain, keys, relationships, timestamps, statuses, units,
  null behavior, and anomalies from evidence rather than assumptions.
- Keep the solution appropriately scoped to the actual data; clearly identify metrics that cannot be computed
  reliably.
- Use the Delta/Spark/dbt patterns native to this template; do not replace its architecture.
- Do all work on the branch `take-home/air-service`, created from the latest `origin/main`. Never merge into
  or push changes to `main`.

## Validation

Run the full template workflow and all available checks. If Docker is available, start the stack, load raw
data, execute dbt build/tests, and query representative outputs/KPIs; resolve any failures. If Docker is
unavailable, run every static/unit check possible and clearly document runtime gaps. Remove temporary test
artifacts before delivering.

## Acceptance criteria

- All six datasets are loaded through the template's raw-loading workflow; the JSON-to-CSV conversion is
  validated and its provenance documented.
- The dbt project builds and all generic and singular tests pass on the running stack.
- The model answers the analysis coverage in Deliverables 4, with active-user and revenue semantics stated
  explicitly and unreliably computable metrics identified.
- Documentation under `docs/` covers the ERD, model dictionary, grains/keys, KPI definitions, assumptions,
  limitations, and rationale.
- `main` is untouched and the completed solution is committed and pushed on `take-home/air-service`.
