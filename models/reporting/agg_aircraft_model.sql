-- Grain: one row per aircraft model flown by the fleet
-- (manufacturer + aircraft_model). Catalog models without aircraft in the
-- fleet have no activity and are not listed.
-- Aircraft-only: route performance lives in agg_route (no mixed grain).
WITH models AS (
    SELECT
        manufacturer,
        aircraft_model,
        has_model_spec,
        max_seats,
        max_weight_kg,
        max_range_nm,
        engine_type,
        COUNT(*) AS fleet_aircraft
    FROM {{ ref('dim_aircraft') }}
    GROUP BY
        manufacturer,
        aircraft_model,
        has_model_spec,
        max_seats,
        max_weight_kg,
        max_range_nm,
        engine_type
),

trip_has_order AS (
    SELECT DISTINCT trip_id
    FROM {{ ref('fct_order') }}
),

trips AS (
    SELECT
        a.manufacturer,
        a.aircraft_model,
        COUNT(*) AS trips_departed,
        COUNT_IF(o.trip_id IS NULL) AS zero_order_trips,
        SUM(a.max_seats) AS max_seat_capacity
    FROM {{ ref('fct_trip') }} AS t
    INNER JOIN {{ ref('dim_aircraft') }} AS a ON t.aircraft_id = a.aircraft_id
    LEFT JOIN trip_has_order AS o ON t.trip_id = o.trip_id
    GROUP BY a.manufacturer, a.aircraft_model
),

orders AS (
    SELECT
        a.manufacturer,
        a.aircraft_model,
        COUNT(*) AS orders_total,
        COUNT_IF(f.order_status = 'finished') AS orders_finished,
        COUNT_IF(f.order_status = 'booked') AS orders_booked,
        COUNT_IF(f.order_status = 'cancelled') AS orders_cancelled,
        SUM(f.seats_sold) AS seats_sold,
        SUM(f.gross_order_value_eur) AS gross_order_value_eur,
        SUM(f.net_order_value_eur) AS net_order_value_eur,
        SUM(f.realized_revenue_proxy_eur) AS realized_revenue_proxy_eur,
        SUM(f.open_booking_value_eur) AS open_booking_value_eur,
        SUM(f.cancelled_value_eur) AS cancelled_value_eur,
        COUNT(DISTINCT CASE WHEN f.seats_sold = 1 THEN f.customer_id END)
            AS active_customers
    FROM {{ ref('fct_order') }} AS f
    INNER JOIN {{ ref('dim_aircraft') }} AS a ON f.aircraft_id = a.aircraft_id
    GROUP BY a.manufacturer, a.aircraft_model
)

SELECT
    m.manufacturer,
    m.aircraft_model,
    m.has_model_spec,
    m.max_seats,
    m.max_weight_kg,
    m.max_range_nm,
    m.engine_type,
    m.fleet_aircraft,
    COALESCE(t.trips_departed, 0) AS trips_departed,
    COALESCE(t.zero_order_trips, 0) AS zero_order_trips,
    COALESCE(t.max_seat_capacity, 0) AS max_seat_capacity,
    COALESCE(o.orders_total, 0) AS orders_total,
    COALESCE(o.orders_finished, 0) AS orders_finished,
    COALESCE(o.orders_booked, 0) AS orders_booked,
    COALESCE(o.orders_cancelled, 0) AS orders_cancelled,
    COALESCE(o.seats_sold, 0) AS seats_sold,
    COALESCE(o.gross_order_value_eur, 0) AS gross_order_value_eur,
    COALESCE(o.net_order_value_eur, 0) AS net_order_value_eur,
    COALESCE(o.realized_revenue_proxy_eur, 0) AS realized_revenue_proxy_eur,
    COALESCE(o.open_booking_value_eur, 0) AS open_booking_value_eur,
    COALESCE(o.cancelled_value_eur, 0) AS cancelled_value_eur,
    COALESCE(o.active_customers, 0) AS active_customers,
    TRY_DIVIDE(o.seats_sold, t.max_seat_capacity) AS max_seat_utilisation,
    TRY_DIVIDE(o.orders_cancelled, o.orders_total) AS order_cancellation_rate,
    TRY_DIVIDE(o.net_order_value_eur, o.seats_sold)
        AS avg_net_price_per_seat_eur
FROM models AS m
LEFT JOIN trips AS t
    ON m.manufacturer = t.manufacturer AND m.aircraft_model = t.aircraft_model
LEFT JOIN orders AS o
    ON m.manufacturer = o.manufacturer AND m.aircraft_model = o.aircraft_model
