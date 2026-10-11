-- DAU <= WAU <= MAU <= customers ever active, on every day.
SELECT activity_date, dau, wau, mau
FROM {{ ref('metrics_active_customers_daily') }}
WHERE
    dau > wau
    OR wau > mau
    OR mau > (SELECT COUNT(DISTINCT customer_id) FROM {{ ref('fct_order') }} WHERE is_active)
