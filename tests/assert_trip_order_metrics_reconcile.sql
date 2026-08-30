SELECT *
FROM {{ ref('fct_trips') }}
WHERE
    total_order_count
    != finished_order_count + booked_order_count + cancelled_order_count
    OR active_order_count != finished_order_count + booked_order_count
