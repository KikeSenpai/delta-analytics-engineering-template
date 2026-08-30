SELECT
    month,
    COUNT(*) AS step_count
FROM {{ ref('rep_sales_funnel_monthly') }}
GROUP BY 1
HAVING COUNT(*) != 11
