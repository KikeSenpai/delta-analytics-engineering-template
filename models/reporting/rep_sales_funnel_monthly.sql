WITH funnel_definition AS (
    SELECT *
    FROM
        VALUES
        ('Lead Generation', 'Step 1'),
        ('Qualified Lead', 'Step 2'),
        ('Sales Call 1', 'Step 2.1'),
        ('Needs Assessment', 'Step 3'),
        ('Sales Call 2', 'Step 3.1'),
        ('Proposal/Quote Preparation', 'Step 4'),
        ('Negotiation', 'Step 5'),
        ('Closing', 'Step 6'),
        ('Implementation/Onboarding', 'Step 7'),
        ('Follow-up/Customer Success', 'Step 8'),
        ('Renewal/Expansion', 'Step 9')
            AS funnel_definition (kpi_name, funnel_step)
),

event_bounds AS (
    SELECT
        CAST(DATE_TRUNC('MONTH', MIN(event_at)) AS DATE) AS first_month,
        CAST(DATE_TRUNC('MONTH', MAX(event_at)) AS DATE) AS last_month
    FROM {{ ref('int_pipedrive__funnel_step_events') }}
),

months AS (
    SELECT
        EXPLODE(SEQUENCE(first_month, last_month, INTERVAL 1 MONTH))
            AS month  -- noqa: RF04
    FROM event_bounds
),

monthly_counts AS (
    SELECT
        CAST(DATE_TRUNC('MONTH', event_at) AS DATE) AS month,  -- noqa: RF04
        kpi_name,
        funnel_step,
        COUNT(DISTINCT funnel_entity_key) AS deals_count
    FROM {{ ref('int_pipedrive__funnel_step_events') }}
    GROUP BY 1, 2, 3
)

SELECT
    months.month,
    funnel_definition.kpi_name,
    funnel_definition.funnel_step,
    COALESCE(monthly_counts.deals_count, 0) AS deals_count
FROM months
CROSS JOIN funnel_definition
LEFT JOIN monthly_counts
    ON
        months.month = monthly_counts.month
        AND funnel_definition.kpi_name = monthly_counts.kpi_name
        AND funnel_definition.funnel_step = monthly_counts.funnel_step
