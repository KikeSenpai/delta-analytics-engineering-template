SELECT
    customer.customer_group_type,
    customer.customer_group_name,
    COUNT(DISTINCT orders.customer_id) AS customers,
    COUNT(*) AS orders,
    SUM(CASE WHEN orders.is_active_order THEN 1 ELSE 0 END) AS active_orders,
    SUM(CASE WHEN orders.is_finished_order THEN 1 ELSE 0 END)
        AS finished_orders,
    SUM(CASE WHEN orders.order_status = 'cancelled' THEN 1 ELSE 0 END)
        AS cancelled_orders,
    SUM(orders.realized_revenue_eur) AS realized_revenue_eur,
    SUM(orders.booked_gmv_eur) AS booked_gmv_eur,
    SUM(orders.total_revenue_eur) AS total_revenue_eur,
    AVG(orders.price_eur) AS average_order_price_eur
FROM {{ ref('fct_orders') }} AS orders
INNER JOIN {{ ref('dim_customers') }} AS customer
    ON orders.customer_id = customer.customer_id
GROUP BY
    customer.customer_group_type,
    customer.customer_group_name
