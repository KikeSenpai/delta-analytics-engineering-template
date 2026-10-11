SELECT
    orders.trip_id,
    model.max_seats,
    COUNT(*) AS active_orders
FROM {{ ref('fct_orders') }} AS orders
INNER JOIN {{ ref('fct_trips') }} AS trip
    ON orders.trip_id = trip.trip_id
INNER JOIN {{ ref('dim_aeroplanes') }} AS model
    ON trip.aeroplane_id = model.aeroplane_id
WHERE orders.is_active_order
GROUP BY orders.trip_id, model.max_seats
HAVING COUNT(*) > model.max_seats
