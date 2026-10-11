-- Grain: one row per directional route (origin city -> destination city).
-- Route-only: aircraft performance lives in agg_aircraft_model (no mixed
-- grain).
WITH trip_has_order AS (
    SELECT DISTINCT trip_id
    FROM {{ ref('fct_order') }}
),

trips AS (
    SELECT
        t.route_key,
        COUNT(*) AS trips_departed,
        COUNT_IF(o.trip_id IS NULL) AS zero_order_trips,
        SUM(a.max_seats) AS max_seat_capacity,
        MIN(t.service_date) AS first_service_date,
        MAX(t.service_date) AS last_service_date
    FROM {{ ref('fct_trip') }} AS t
    LEFT JOIN trip_has_order AS o ON t.trip_id = o.trip_id
    LEFT JOIN {{ ref('dim_aircraft') }} AS a ON t.aircraft_id = a.aircraft_id
    GROUP BY t.route_key
),

orders AS (
    SELECT
        route_key,
        COUNT(*) AS orders_total,
        COUNT_IF(order_status = 'finished') AS orders_finished,
        COUNT_IF(order_status = 'booked') AS orders_booked,
        COUNT_IF(order_status = 'cancelled') AS orders_cancelled,
        SUM(seats_sold) AS seats_sold,
        SUM(gross_order_value_eur) AS gross_order_value_eur,
        SUM(net_order_value_eur) AS net_order_value_eur,
        SUM(realized_revenue_proxy_eur) AS realized_revenue_proxy_eur,
        SUM(open_booking_value_eur) AS open_booking_value_eur,
        SUM(cancelled_value_eur) AS cancelled_value_eur,
        COUNT(DISTINCT CASE WHEN seats_sold = 1 THEN customer_id END)
            AS active_customers
    FROM {{ ref('fct_order') }}
    GROUP BY route_key
)

SELECT
    r.route_key,
    r.route_name,
    r.origin_city,
    r.destination_city,
    t.first_service_date,
    t.last_service_date,
    t.trips_departed,
    t.zero_order_trips,
    t.max_seat_capacity,
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
FROM {{ ref('dim_route') }} AS r
LEFT JOIN trips AS t ON r.route_key = t.route_key
LEFT JOIN orders AS o ON r.route_key = o.route_key
