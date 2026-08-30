SELECT
    trip_id,
    COUNT(*) AS total_order_count,
    COUNT(DISTINCT customer_id) AS total_customer_count,
    SUM(CASE WHEN is_active_order THEN 1 ELSE 0 END) AS active_order_count,
    COUNT(DISTINCT CASE WHEN is_active_order THEN customer_id END)
        AS active_customer_count,
    SUM(CASE WHEN is_finished_order THEN 1 ELSE 0 END) AS finished_order_count,
    SUM(CASE WHEN order_status = 'booked' THEN 1 ELSE 0 END)
        AS booked_order_count,
    SUM(CASE WHEN order_status = 'cancelled' THEN 1 ELSE 0 END)
        AS cancelled_order_count,
    SUM(realized_revenue_eur) AS realized_revenue_eur,
    SUM(booked_gmv_eur) AS booked_gmv_eur,
    SUM(cancelled_value_eur) AS cancelled_value_eur
FROM {{ ref('int_air_service__orders_enriched') }}
GROUP BY trip_id
