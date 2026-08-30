SELECT
    trip_id,
    seat_number,
    COUNT(*) AS duplicate_count
FROM {{ ref('fct_orders') }}
WHERE is_active_order
GROUP BY trip_id, seat_number
HAVING COUNT(*) > 1
