-- One row per trip (supply event), including trips with zero orders.
-- Order measures are pre-aggregated to trip grain so they can be summed without fan-out.
WITH trip_orders AS (
    SELECT
        trip_id,
        COUNT(*) AS orders,
        COUNT_IF(is_active) AS active_seats,
        COUNT_IF(order_status = 'Booked') AS booked_seats,
        COUNT_IF(order_status = 'Finished') AS finished_seats,
        COUNT_IF(order_status = 'Cancelled') AS cancelled_seats,
        SUM(gross_booking_value_eur) AS gross_booking_value_eur,
        SUM(realized_revenue_proxy_eur) AS realized_revenue_proxy_eur,
        SUM(cancelled_value_eur) AS cancelled_value_eur
    FROM {{ ref('fct_order') }}
    GROUP BY trip_id
)

SELECT
    trip.trip_id,
    trip.airplane_id,
    trip.origin_city,
    trip.destination_city,
    trip.start_local_at,
    trip.end_local_at,
    CAST(trip.start_local_at AS DATE) AS departure_date,
    aircraft.max_seats AS seat_capacity,
    trip.end_local_at < trip.start_local_at AS is_end_before_start,
    COALESCE(trip_orders.orders, 0) AS orders,
    COALESCE(trip_orders.active_seats, 0) AS active_seats,
    COALESCE(trip_orders.booked_seats, 0) AS booked_seats,
    COALESCE(trip_orders.finished_seats, 0) AS finished_seats,
    COALESCE(trip_orders.cancelled_seats, 0) AS cancelled_seats,
    COALESCE(trip_orders.gross_booking_value_eur, 0) AS gross_booking_value_eur,
    COALESCE(trip_orders.realized_revenue_proxy_eur, 0) AS realized_revenue_proxy_eur,
    COALESCE(trip_orders.cancelled_value_eur, 0) AS cancelled_value_eur,
    COALESCE(trip_orders.active_seats, 0) / aircraft.max_seats AS load_factor
FROM {{ ref('stg_trip') }} AS trip
LEFT JOIN {{ ref('dim_aircraft') }} AS aircraft
    ON trip.airplane_id = aircraft.airplane_id
LEFT JOIN trip_orders
    ON trip.trip_id = trip_orders.trip_id
