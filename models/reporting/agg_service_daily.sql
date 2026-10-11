-- Grain: one row per service date (trip departure date) on the dim_date
-- spine, zero-filled. Trip-grain and order-grain metrics are aggregated
-- separately and joined on date (no fan-out).
WITH trip_has_order AS (
    SELECT DISTINCT trip_id
    FROM {{ ref('fct_order') }}
),

trips AS (
    SELECT
        t.service_date,
        COUNT(*) AS trips_departed,
        COUNT_IF(o.trip_id IS NULL) AS zero_order_trips,
        SUM(a.max_seats) AS max_seat_capacity
    FROM {{ ref('fct_trip') }} AS t
    LEFT JOIN trip_has_order AS o ON t.trip_id = o.trip_id
    LEFT JOIN {{ ref('dim_aircraft') }} AS a ON t.aircraft_id = a.aircraft_id
    GROUP BY t.service_date
),

orders AS (
    SELECT
        service_date,
        COUNT(*) AS orders_total,
        COUNT_IF(order_status = 'finished') AS orders_finished,
        COUNT_IF(order_status = 'booked') AS orders_booked,
        COUNT_IF(order_status = 'cancelled') AS orders_cancelled,
        SUM(seats_sold) AS seats_sold,
        SUM(gross_order_value_eur) AS gross_order_value_eur,
        SUM(net_order_value_eur) AS net_order_value_eur,
        SUM(realized_revenue_proxy_eur) AS realized_revenue_proxy_eur,
        SUM(open_booking_value_eur) AS open_booking_value_eur,
        SUM(cancelled_value_eur) AS cancelled_value_eur
    FROM {{ ref('fct_order') }}
    GROUP BY service_date
)

SELECT
    d.date_day AS service_date,
    d.week_start,
    d.month_start,
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
    -- Non-additive ratios: recompute from the additive columns on rollup.
    TRY_DIVIDE(o.seats_sold, t.max_seat_capacity) AS max_seat_utilisation,
    TRY_DIVIDE(o.orders_cancelled, o.orders_total) AS order_cancellation_rate,
    TRY_DIVIDE(o.net_order_value_eur, o.seats_sold)
        AS avg_net_price_per_seat_eur
FROM {{ ref('dim_date') }} AS d
LEFT JOIN trips AS t ON d.date_day = t.service_date
LEFT JOIN orders AS o ON d.date_day = o.service_date
