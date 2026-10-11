-- One row per order (= one seat on one trip). Orders carry no timestamp of their own, so every
-- order is attributed to its trip's local departure date.
SELECT
    orders.order_id,
    orders.customer_id,
    orders.trip_id,
    trip.airplane_id,
    trip.origin_city,
    trip.destination_city,
    CAST(trip.start_local_at AS DATE) AS departure_date,
    orders.seat_no,
    orders.order_status,
    orders.price_eur,
    orders.order_status IN ('Booked', 'Finished') AS is_active,
    CASE WHEN orders.order_status IN ('Booked', 'Finished') THEN orders.price_eur ELSE 0 END
        AS gross_booking_value_eur,
    CASE WHEN orders.order_status = 'Finished' THEN orders.price_eur ELSE 0 END AS realized_revenue_proxy_eur,
    CASE WHEN orders.order_status = 'Cancelled' THEN orders.price_eur ELSE 0 END AS cancelled_value_eur
FROM {{ ref('stg_order') }} AS orders
LEFT JOIN {{ ref('stg_trip') }} AS trip
    ON orders.trip_id = trip.trip_id
