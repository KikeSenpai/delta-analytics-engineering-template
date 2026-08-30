SELECT
    customer_segment,
    group_membership_status,
    price_band,
    COUNT(DISTINCT customer_id) AS customers,
    COUNT(*) AS orders,
    SUM(CASE WHEN is_active_order THEN 1 ELSE 0 END) AS active_orders,
    SUM(CASE WHEN is_finished_order THEN 1 ELSE 0 END) AS finished_orders,
    SUM(CASE WHEN order_status = 'cancelled' THEN 1 ELSE 0 END)
        AS cancelled_orders,
    SUM(realized_revenue_eur) AS realized_revenue_eur,
    SUM(booked_gmv_eur) AS booked_gmv_eur,
    AVG(price_eur) AS average_order_price_eur
FROM {{ ref('fct_orders') }}
GROUP BY customer_segment, group_membership_status, price_band
