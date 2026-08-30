SELECT
    month,
    kpi_name,
    funnel_step
FROM {{ ref('rep_sales_funnel_monthly') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) != 1 OR MIN(deals_count) < 0
