WITH report_counts AS (
    SELECT
        kpi_name,
        funnel_step,
        SUM(deals_count) AS deals_count
    FROM {{ ref('rep_sales_funnel_monthly') }}
    GROUP BY 1, 2
),

event_counts AS (
    SELECT
        kpi_name,
        funnel_step,
        COUNT(*) AS deals_count
    FROM {{ ref('int_pipedrive__funnel_step_events') }}
    GROUP BY 1, 2
)

SELECT
    report_counts.kpi_name,
    report_counts.funnel_step,
    report_counts.deals_count AS report_deals_count,
    event_counts.deals_count AS event_deals_count
FROM report_counts
INNER JOIN event_counts
    ON
        report_counts.kpi_name = event_counts.kpi_name
        AND report_counts.funnel_step = event_counts.funnel_step
WHERE report_counts.deals_count != event_counts.deals_count
