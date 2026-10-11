WITH order_periods AS (

    SELECT
        'day' AS period_type,
        trip.service_date AS period_start,
        orders.customer_id,
        orders.order_id,
        orders.is_active_order,
        orders.realized_revenue_eur,
        orders.booked_gmv_eur,
        orders.total_revenue_eur
    FROM {{ ref('fct_orders') }} AS orders
    INNER JOIN {{ ref('fct_trips') }} AS trip
        ON orders.trip_id = trip.trip_id

    UNION ALL

    SELECT
        'week' AS period_type,
        CAST(DATE_TRUNC('WEEK', trip.service_date) AS DATE) AS period_start,
        orders.customer_id,
        orders.order_id,
        orders.is_active_order,
        orders.realized_revenue_eur,
        orders.booked_gmv_eur,
        orders.total_revenue_eur
    FROM {{ ref('fct_orders') }} AS orders
    INNER JOIN {{ ref('fct_trips') }} AS trip
        ON orders.trip_id = trip.trip_id

    UNION ALL

    SELECT
        'month' AS period_type,
        CAST(DATE_TRUNC('MONTH', trip.service_date) AS DATE) AS period_start,
        orders.customer_id,
        orders.order_id,
        orders.is_active_order,
        orders.realized_revenue_eur,
        orders.booked_gmv_eur,
        orders.total_revenue_eur
    FROM {{ ref('fct_orders') }} AS orders
    INNER JOIN {{ ref('fct_trips') }} AS trip
        ON orders.trip_id = trip.trip_id

)

SELECT
    period_type,
    period_start,
    COUNT(DISTINCT CASE WHEN is_active_order THEN customer_id END)
        AS active_users,
    SUM(CASE WHEN is_active_order THEN 1 ELSE 0 END) AS active_orders,
    COUNT(DISTINCT order_id) AS all_orders,
    SUM(realized_revenue_eur) AS realized_revenue_eur,
    SUM(booked_gmv_eur) AS booked_gmv_eur,
    SUM(total_revenue_eur) AS total_revenue_eur
FROM order_periods
GROUP BY period_type, period_start
