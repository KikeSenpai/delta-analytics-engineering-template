SELECT *
FROM {{ ref('int_pipedrive__funnel_step_events') }}
WHERE NOT (
    (kpi_name = 'Lead Generation' AND funnel_step = 'Step 1')
    OR (kpi_name = 'Qualified Lead' AND funnel_step = 'Step 2')
    OR (kpi_name = 'Sales Call 1' AND funnel_step = 'Step 2.1')
    OR (kpi_name = 'Needs Assessment' AND funnel_step = 'Step 3')
    OR (kpi_name = 'Sales Call 2' AND funnel_step = 'Step 3.1')
    OR (kpi_name = 'Proposal/Quote Preparation' AND funnel_step = 'Step 4')
    OR (kpi_name = 'Negotiation' AND funnel_step = 'Step 5')
    OR (kpi_name = 'Closing' AND funnel_step = 'Step 6')
    OR (kpi_name = 'Implementation/Onboarding' AND funnel_step = 'Step 7')
    OR (kpi_name = 'Follow-up/Customer Success' AND funnel_step = 'Step 8')
    OR (kpi_name = 'Renewal/Expansion' AND funnel_step = 'Step 9')
)
