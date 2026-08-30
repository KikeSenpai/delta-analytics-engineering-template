WITH activity_periods AS (

    SELECT
        'day' AS period_type,
        service_date AS period_start,
        customer_id,
        order_id,
        is_active_order,
        realized_revenue_eur,
        booked_gmv_eur
    FROM {{ ref('fct_orders') }}

    UNION ALL

    SELECT
        'week' AS period_type,
        CAST(DATE_TRUNC('WEEK', service_date) AS DATE) AS period_start,
        customer_id,
        order_id,
        is_active_order,
        realized_revenue_eur,
        booked_gmv_eur
    FROM {{ ref('fct_orders') }}

    UNION ALL

    SELECT
        'month' AS period_type,
        CAST(DATE_TRUNC('MONTH', service_date) AS DATE) AS period_start,
        customer_id,
        order_id,
        is_active_order,
        realized_revenue_eur,
        booked_gmv_eur
    FROM {{ ref('fct_orders') }}

)

SELECT
    period_type,
    period_start,
    COUNT(DISTINCT CASE WHEN is_active_order THEN customer_id END)
        AS active_users,
    SUM(CASE WHEN is_active_order THEN 1 ELSE 0 END) AS active_orders,
    COUNT(DISTINCT order_id) AS all_orders,
    SUM(realized_revenue_eur) AS realized_revenue_eur,
    SUM(booked_gmv_eur) AS booked_gmv_eur
FROM activity_periods
GROUP BY period_type, period_start
