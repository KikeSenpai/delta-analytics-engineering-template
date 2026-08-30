SELECT *
FROM {{ ref('fct_trips') }}
WHERE
    active_order_count > max_seats
    OR active_seat_utilization < 0
    OR active_seat_utilization > 1
