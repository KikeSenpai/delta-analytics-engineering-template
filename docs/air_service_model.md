# Uber Air analytical data model

Analytical model for the Uber Air marketplace (aircraft operators selling seats on trips to
individuals and customer groups). Built on the template stack: CSV → `prod.raw` Delta tables
in MinIO → dbt-spark models in `prod.analytics` (Unity Catalog metadata, MinIO storage).

Contents: [provenance](#1-source-provenance) · [source profile](#2-source-profile) ·
[conceptual model](#3-conceptual-model) · [implemented model](#4-implemented-model) ·
[semantics](#5-metric-and-business-semantics) · [reporting use](#6-using-the-reporting-tables) ·
[quality controls](#7-quality-controls) · [question coverage](#8-business-question-coverage-and-data-gaps) ·
[limitations](#9-limitations-and-future-work) · [CI/CD](#10-cicd-proposal) ·
[verification](#11-verification-evidence)

## 1. Source provenance

The six inputs were taken unchanged from branch `take-home/air-service` of this repository
(commit `17e413455cad8f08babf2e3f6db5a4a7fe6f72d1`), exact paths only, and committed to `data/`.
The assignment describes the aircraft model catalog as JSON; it was supplied already converted
to `aeroplane_model.csv`. The other files are workbook sheet exports.

| File | Rows | SHA-256 |
|---|---:|---|
| `data/aeroplane.csv` | 10 | `5fd67ad4b9bc3f087666a6df8e0b729a374f16c3c1f5403a6a9035a85102883f` |
| `data/aeroplane_model.csv` | 19 | `82f6176e0ed785ff6c5b59ecf08a6f6368f35a06e064702f60c76f58d2e073cb` |
| `data/customer.csv` | 20 | `50b82b662d141cf8c8c0d20503256ea7bb7b61f2580665889026397402fde36d` |
| `data/customer_group.csv` | 5 | `ac81a3e4e860bf0a5d83222165dec95eeebf3857d0111e213a850b81aa8f48b7` |
| `data/order.csv` | 20 | `288d01fbfe1a6293bd62936c05c96370768c543979e0da579405b684403eb237` |
| `data/trip.csv` | 20 | `0ac9c2c302fc5e9fe74b1d81dc5d8d9dfbc373e6fec47a72748a8bd40ba557af` |

Check with `sha256sum data/*.csv`.

## 2. Source profile

Profiled in Spark SQL on `prod.raw` and cross-checked in Python directly from the CSV files.

| Table | Key | Findings |
|---|---|---|
| `trip` | `Trip ID` 1–20, unique, no NULLs | 20 directional city pairs, all distinct (Los Angeles→Sydney and Sydney→Los Angeles both exist). Each of the 10 aircraft flies 2 trips. Starts 2024-08-01 14:30 to 2024-08-28 09:00. Timestamps have **no timezone**. Trips 3 (Sydney→Los Angeles) and 9 (Beijing→San Francisco) end before they start: consistent with local departure/arrival times across the date line, so timestamps are local wall-clock values and their difference is not a flight time. No trip status, distance, country or region columns. |
| `order` | `Order ID` 1–20, unique | Status: Finished 13 (18 900 EUR), Booked 5 (9 900 EUR), Cancelled 2 (1 400 EUR); total 30 200 EUR. Price integer EUR 500–2 500. Every order references a valid customer and trip. Orders cover 8 trips; **12 of 20 trips have zero orders**. 20 distinct customers, **each with exactly one order** (no repeat customers in this extract). One seat per order; no seat is held twice on a trip. No order/booking/cancellation timestamp. Booked orders sit on trips that also have Finished orders, so "Booked" cannot be read as "trip not yet flown". |
| `customer` | `Customer ID` 1–20, unique | 6 customers have no group (NULL). **7 customers (6, 7, 9, 10, 16, 18, 20) reference groups 6–10, which do not exist.** 7 reference valid groups 1–5. Emails right-padded with spaces (17), 2 missing; phones in mixed formats, 3 missing. PII: name, email, phone. |
| `customer_group` | `ID` 1–5, unique | Types: Company (3), Private Group (1), Organisation (1). Registry number missing for the private group, mixed formats otherwise. |
| `aeroplane` | `Airplane ID` 1–10, unique | 6 models: 737-800 ×3, CRJ900 ×3, A320neo, E190-E2, G650, 787-9. All resolve to the catalog on manufacturer + model. |
| `aeroplane_model` | manufacturer + model, unique | 19 models. Units: seats, kg, nautical miles (max range). Engine type. No cabin configuration, no cost or premium/low-cost attribute. |

Anomalies kept visible rather than fixed: seat labels such as `17C` on a 19-seat G650 suggest
seat labels are not a cabin map, so seat labels are carried but not interpreted.

## 3. Conceptual model

```
 Customer Group 1 ──< 0..n Customer 1 ──< 0..n Order >── 1 Trip >── 1 Aircraft >── 1 Aircraft Model
                         (group optional;            (one seat)    │
                          reference may be invalid)                └── origin City, destination City (Route)
```

- A **trip** is one flight of one aircraft between two cities at a scheduled time. It exists
  whether or not seats are sold.
- An **order** is one customer buying one seat on one trip, with a price and a lifecycle status.
- A **customer** optionally belongs to a **customer group** (company, private group,
  organisation).
- An **aircraft** is an instance of an **aircraft model** with certified limits.
- A **route** is a directional origin → destination city pair.
- Missing business concepts (needed for the full brief): city → country/region geography,
  route distance, fare class / product tier, order and cancellation timestamps, app or
  search activity, operator (aeroplane owner) and Uber Air commission.

## 4. Implemented model

All objects are UC-managed Delta tables in `prod.analytics`, physically in MinIO.

```
 prod.raw.*  ──>  stg_* (6)  ──>  dim_* (5) + fct_trip, fct_order  ──>  agg_* (7)
                                         flat star schema              reporting tables
```

### Staging (rename, cast, trim; no joins, no logic)

| Model | Grain |
|---|---|
| `stg_trip` | one row per trip (timestamps cast to `TIMESTAMP_NTZ`) |
| `stg_order` | one row per order (status lower-cased, price `DECIMAL(18,2)`) |
| `stg_customer` | one row per customer (last layer containing email/phone) |
| `stg_customer_group` | one row per customer group |
| `stg_aeroplane` | one row per aircraft |
| `stg_aeroplane_model` | one row per manufacturer + model |

### Core flat star

| Model | Grain | Contents |
|---|---|---|
| `fct_trip` | one row per trip, including zero-order trips | `trip_id`; FKs `route_key`, `aircraft_id`, `service_date`; recorded `trip_start_at`/`trip_end_at`; atomic `recorded_duration_minutes`, `is_end_before_start`. No order rollups, no descriptors. |
| `fct_order` | one row per order (= one seat) | `order_id`; FKs `trip_id`, `customer_id`, `route_key`, `aircraft_id`, `service_date`; degenerate `seat_no`; `order_status`; atomic additive `gross_order_value_eur`, `realized_revenue_proxy_eur`, `open_booking_value_eur`, `cancelled_value_eur`, `net_order_value_eur`, `seats_sold`. No trip/customer/aircraft descriptors. |
| `dim_customer` | one row per customer | name, `group_membership_status`, `referenced_customer_group_id` (as supplied), `customer_group_id` (resolved, NULL unless valid), group type/name flattened in, `has_email`, `has_phone_number`. |
| `dim_customer_group` | one row per group in the group master | type, name, `has_registry_number`. |
| `dim_aircraft` | one row per aircraft | manufacturer, model, `has_model_spec`, max seats/weight/range, engine type (flattened from the catalog). |
| `dim_route` | one row per directional city pair | `route_key` (MD5 of origin\|destination), origin, destination, `route_name`. |
| `dim_date` | one row per day, first to last trip service date | `week_start` (ISO Monday), `month_start`, year, day name, weekend flag. |

The route, aircraft and date keys on `fct_order` are conformed foreign keys taken from its
trip, so order analysis joins straight to every dimension without passing through
`fct_trip`. They are keys, not copies of descriptive attributes.

### Reporting aggregates (one explicit grain each)

| Model | Grain | Question it answers |
|---|---|---|
| `agg_service_daily` | one row per service date on the full date spine (zero-filled) | Service performance over time: trips, zero-order trips, capacity, orders by status, seats, EUR by status, utilisation, cancellation rate. |
| `agg_route` | one row per directional route | Origin/destination performance. |
| `agg_aircraft_model` | one row per fleet aircraft model (manufacturer + model) | Aircraft type performance, fleet size, utilisation of maximum seats. |
| `agg_customer` | one row per customer | Customer value, status mix, distinct trips/routes, first/last active date, active/repeat flags. |
| `agg_customer_group` | one row per (`group_membership_status`, `customer_group_ref`) | Which groups are served well: every real group, one "No group" row, one row per missing referenced group id. |
| `agg_active_customers_daily` | one row per day | DAU, rolling 7-day WAU, rolling 30-day MAU, DAU/MAU, full-window flags. |
| `agg_active_customers_calendar` | one row per (`period_type` ∈ {week, month}, `period_start`) | Calendar-week and calendar-month active customers, complete-period flag. |

Route and aircraft aggregates are deliberately separate: a route × aircraft table would mix
grains and invite double counting when users sum across one dimension. Cross-cuts are
answered from the star (see section 6).

## 5. Metric and business semantics

**Order status.** `finished` = fulfilled seat; `booked` = open (paid or committed, not yet
finished); `cancelled` = no service. Statuses are taken as supplied; the extract date is
unknown, so stale `booked` statuses on past trips are not reclassified.

**Value measures (EUR, additive).** All are customer prices, not Uber Air revenue: the
commission/take rate is not in the source.

| Measure | Definition |
|---|---|
| `gross_order_value_eur` | price of every order, any status |
| `net_order_value_eur` | price of non-cancelled orders (finished + booked) = booked value |
| `realized_revenue_proxy_eur` | price of finished orders |
| `open_booking_value_eur` | price of booked orders |
| `cancelled_value_eur` | price of cancelled orders |

Identities: gross = net + cancelled; net = realized + open.

**Seats and capacity.** `seats_sold` = non-cancelled orders (one order holds one seat).
`max_seat_capacity` = model `max_seats` summed over departed trips, an upper bound because the
configured cabin is unknown. `max_seat_utilisation` = seats_sold / max_seat_capacity is
therefore a lower bound of the real load factor.

**Time attribution.** Every trip and order is attributed to `service_date` = local departure
date of the trip. There is no order, payment or cancellation timestamp, so booking-date
metrics (booking lead time, bookings made today) cannot be produced. Timestamps are kept as
`TIMESTAMP_NTZ` so a late-evening departure stays on its local date (unit-tested).

**Active customer.** A customer with at least one non-cancelled order (status booked or
finished) on a trip departing within the window. Cancelled-only customers are not active.
There is no app/login data, so "DAU" means daily *travelling* customers, not app users.

**Rolling vs calendar windows.**

| Window | Definition | Use |
|---|---|---|
| DAU | `[d, d]` | daily monitoring |
| WAU (rolling) | `[d − 6, d]`, 7 days including d | daily monitoring; a value every day, no week-start artefacts |
| MAU (rolling) | `[d − 29, d]`, 30 days including d | stickiness (DAU/MAU) and trend lines |
| Calendar week | ISO week Monday–Sunday | business reporting, week-over-week |
| Calendar month | 1st – last day of month | finance-aligned monthly reporting |

Rolling windows are comparable day to day and avoid the 28–31-day month-length bias;
calendar windows match how the business closes periods. Both are provided; neither is
additive. `is_full_7d_window` / `is_full_30d_window` / `is_complete_period` flag windows that
reach outside the observed date range (August 2024 data: MAU is never a full 30-day window).

**Customer group membership.** `group_member` (valid group), `no_group` (NULL reference:
individual customer), `invalid_group_reference` (references a group missing from the master).
Invalid references keep their referenced id and are reported as "Unknown group N", never
merged into "No group".

**Routes.** Directional city pairs. No region, country, distance, or short/long-haul class is
derived: none exists in the source and inventing a mapping or threshold would be unverifiable.
The model range (`max_range_nm`) is a capability of the aircraft, not the distance flown.

**Not classified on purpose:** premium vs low-cost, short vs long haul, customer segments
beyond the supplied group type, seat class from seat labels, aircraft size classes. Raw
attributes (price, max seats, engine type, group type) are exposed so analysts can slice by
them explicitly.

**Additivity.** Counts and EUR columns are additive across rows of their table. Ratios
(`max_seat_utilisation`, `order_cancellation_rate`, `avg_net_price_per_seat_eur`,
`net_order_value_per_active_customer_eur`, `dau_mau_ratio`) and distinct counts
(`active_customers`, DAU/WAU/MAU, `active_routes`) are not: recompute them from the additive
columns or from `fct_order`. Exception: in `agg_customer_group` the customer counts are additive
across segments because each customer belongs to exactly one segment.

## 6. Using the reporting tables

Monthly service performance (ratios recomputed from additive columns):

```sql
SELECT
    month_start,
    SUM(trips_departed) AS trips,
    SUM(zero_order_trips) AS zero_order_trips,
    SUM(seats_sold) AS seats_sold,
    SUM(net_order_value_eur) AS net_eur,
    SUM(realized_revenue_proxy_eur) AS realized_eur,
    SUM(seats_sold) / SUM(max_seat_capacity) AS max_seat_utilisation,
    SUM(orders_cancelled) / SUM(orders_total) AS cancellation_rate
FROM prod.analytics.agg_service_daily
GROUP BY month_start;
-- 2024-08-01 | 20 | 12 | 18 | 28800.00 | 18900.00 | 0.0062 | 0.1
```

Customer groups served best:

```sql
SELECT segment_name, group_membership_status, active_customers, net_order_value_eur,
       net_order_value_per_active_customer_eur, order_cancellation_rate
FROM prod.analytics.agg_customer_group
ORDER BY net_order_value_eur DESC;
```

Top routes and aircraft types: `ORDER BY net_order_value_eur DESC` on `agg_route` /
`agg_aircraft_model`.

Activity monitoring:

```sql
SELECT activity_date, dau, wau_rolling_7d, mau_rolling_30d, is_full_30d_window
FROM prod.analytics.agg_active_customers_daily
ORDER BY activity_date;
```

Self-service cross-cut on the star (no aggregate needed), e.g. individual customers' seats by
origin city and engine type:

```sql
SELECT r.origin_city, a.engine_type, SUM(f.seats_sold) AS seats_sold,
       SUM(f.net_order_value_eur) AS net_eur
FROM prod.analytics.fct_order AS f
JOIN prod.analytics.dim_route AS r ON f.route_key = r.route_key
JOIN prod.analytics.dim_aircraft AS a ON f.aircraft_id = a.aircraft_id
JOIN prod.analytics.dim_customer AS c ON f.customer_id = c.customer_id
WHERE c.group_membership_status = 'no_group'
GROUP BY r.origin_city, a.engine_type;
```

Zero-order trips: `SELECT * FROM fct_trip LEFT ANTI JOIN fct_order USING (trip_id)`.

Platform caveat: on this Spark/Delta build a bare scalar `SELECT MIN(<date column>) FROM
<delta table>` fails with a `LocalDate` `ClassCastException` (Delta metadata-only aggregate).
Use a `GROUP BY`, a filter, or `MIN(...) OVER ()`; the models do the latter.

## 7. Quality controls

`dbt test` runs 99 checks (`just test`):

- **Generic:** `unique` + `not_null` on every key and composite key (`CONCAT_WS` expression);
  `relationships` for every FK on both facts and for `stg_order`/`stg_trip`;
  `accepted_values` for order status, membership status and period type.
- **Known-defect register (identity-aware):** `seeds/known_source_defects.csv` lists each
  known defective record (7 invalid group references, 2 end-before-start trips).
  `assert_source_defects_match_register` fails on any *new* defect and on any registered
  defect that is no longer detected, so defects are tracked record by record, not tolerated
  wholesale. Missing aircraft model specs are detected the same way (none today).
- **Independent reconciliations** (expected values computed from `prod.raw` with raw column
  names and raw status strings, not from `fct_order`):
  - `assert_order_status_reconciliation`: order count and EUR per bucket (finished, booked,
    cancelled, all, non-cancelled) for `fct_order` and all five order-carrying aggregates.
  - `assert_trip_reconciliation`: trip and zero-order-trip counts for `fct_trip`,
    `agg_service_daily`, `agg_route`, `agg_aircraft_model`.
  - `assert_customer_group_membership`: per-customer membership class vs raw, resolved-id
    consistency, and segment customer totals in `agg_customer_group`.
  - `assert_active_customers_match_source`: DAU per day and calendar week/month actives
    recomputed from raw orders + trips, plus DAU ≤ WAU ≤ MAU.
- **Invariants:** `assert_order_invariants`: positive prices, no seat double-booked on a
  trip, seats sold ≤ model max seats.
- **Unit tests (exact boundaries, synthetic inputs):**
  - `active_customers_rolling_window_boundaries`: active on d counts in WAU on d+6 but not
    d+7, in MAU on d+29 but not d+30; cancelled-only customer never active; repeat customer
    (two orders a day, booked + cancelled same day) counted once.
  - `active_customers_calendar_boundaries`: Sunday belongs to the previous ISO week, Monday
    starts a new one; customer active in two weeks/months counted in each; two orders in a
    week counted once; cancelled excluded.
  - `dim_date_calendar_boundaries`: 23:30 departure stays on its local date; ISO week and
    month boundaries.

The tests were mutation-checked during development: widening the WAU/MAU windows by one day,
counting booked orders as realized, and deregistering one known defect each made the
corresponding test fail.

## 8. Business question coverage and data gaps

| Question | Status | Where / what is missing |
|---|---|---|
| Revenue and comparable metrics | Supported as customer value | `agg_*` EUR by status, per seat, per active customer. Platform revenue needs commission/take rate per order. |
| DAU / WAU / MAU | Supported (travel-based) | `agg_active_customers_*`. App engagement needs event/session data. |
| Customers / customer groups served well | Supported | `agg_customer`, `agg_customer_group`. Satisfaction needs ratings/NPS, complaints, delay data. |
| Origin / destination | Supported at city level | `agg_route`. |
| Regional growth drivers | **Not supported** | Needs city → country/region reference (ideally IATA airport codes) and more than one month of data for growth. |
| Short vs long haul | **Not supported** | Needs route distance or airport coordinates (great-circle), or timezone-aware timestamps for true block time. Thresholds then need a business definition. |
| Low-cost vs premium | **Not supported** | Needs fare class/product tier or an agreed price-band definition. Raw price is available for explicit slicing. |
| Group vs individual / seat size | Partially | Group type and membership; seats per order are always 1. Party size per booking needs a booking/party id grouping orders. |
| Aircraft type | Supported | `agg_aircraft_model`, `dim_aircraft`. Real load factor needs configured seat count per aircraft. |
| Booking behaviour, lead time, cancellation timing | **Not supported** | Needs order created/cancelled timestamps. |
| Operator performance | **Not supported** | Needs aircraft → operator ownership. |

## 9. Limitations and future work

- One month (August 2024) and 20 orders: no growth trends; all customers order once, so
  repeat behaviour is only exercised by unit tests.
- Statuses are a single snapshot with no history; add status-change events or a snapshot
  (`dbt snapshot`) per extract to analyse cancellations and booked→finished conversion.
- Timestamps lack timezones; durations are flagged as unreliable. Add airport timezone
  reference to compute UTC times and true flight duration.
- Models are full-rebuild tables (fine at this size). At scale: incremental `merge` on
  `order_id` / `trip_id` keyed by an `updated_at` the source does not yet provide; partition
  facts by `service_date`; replace the rolling-window range join with per-customer-day
  pre-aggregation or HLL sketches.
- Invalid group references are reported, not repaired; fix at source (customer master) and
  remove rows from the defect register.
- PII: email/phone stop in staging; customer name is kept in `dim_customer` for usability.
  In production mask or tag it with UC column-level permissions.
- Add a semantic layer (dbt metrics / MetricFlow) so ratios are defined once for BI tools.

## 10. CI/CD proposal

**Ideal environment** (cloud warehouse e.g. Databricks + UC, GitHub Actions or similar):

1. On every pull request: `just ci` (dbt parse + sqlfluff), `dbt build --select state:modified+
   --defer --state <prod manifest>` in an isolated per-PR schema (Slim CI), unit tests, data
   tests, `dbt docs generate`; post row-count / metric diffs vs production (e.g. `audit_helper`
   or data-diff) on the PR. Required review + green checks to merge.
2. Nightly or on merge: full `just verify`-equivalent integration run on the container stack
   to catch infra/dependency drift (Spark, Delta, UC connector versions are pinned).
3. Deploy on merge to `main`: build into a staging schema, run all tests, then swap/promote
   to `prod.analytics` (blue/green), so consumers never read a half-built model. Source
   freshness checks and `dbt build` in the orchestrator (Airflow/Databricks Workflows) after
   each landing; alert on failure; store `run_results.json` for observability.
4. Governance: the defect register and reconciliations run in prod; new source defects page
   the data owner instead of silently flowing to dashboards.

**Resource-constrained environment** (no cloud warehouse, single runner, small budget):

1. Pre-commit hooks: `sqlfluff lint`, `dbt parse` (seconds, no Docker).
2. CI on every push: `just ci` only (no Docker).
3. `just verify` (full Docker stack: MinIO, UC, Spark, load, seed, run, test, storage and
   restart checks) on merge to `main` and nightly, or manually before release, on one runner
   with ~8 GB RAM; cache the Spark image layer.
4. Deploy = run `just load-raw && dbt build` on the single host after landing, with
   `dbt build` stopping on test failure so bad data never replaces good tables (keep the
   previous Delta version for rollback via time travel).

## 11. Verification evidence

Canonical run: `just verify` from a clean stack (fresh volumes) passes: static checks,
compose check, stack start, UC smoke test, raw load of 6 tables, seed, 20 models, 99 tests,
storage check (6 raw + 21 analytics tables with `_delta_log` and Parquet in
`s3://delta-warehouse/prod/...`), restart with volumes kept, unchanged raw row counts,
99 tests again and storage check again.

Reconciled outputs (all equal to the CSV totals computed independently in Python):

| Metric | Value |
|---|---:|
| Trips / zero-order trips | 20 / 12 |
| Orders finished / booked / cancelled | 13 / 5 / 2 |
| Realized revenue proxy / open booking / cancelled EUR | 18 900 / 9 900 / 1 400 |
| Gross / net order value EUR | 30 200 / 28 800 |
| Seats sold | 18 |
| Active customers Aug 2024 (calendar month) | 18 of 20 (customers 13 and 15 only cancelled) |
| Customer segments | 5 groups (7 customers), no group (6), invalid refs 6–10 (7 customers) |
| DAU / WAU / MAU on 2024-08-15 | 2 / 12 / 18 |
