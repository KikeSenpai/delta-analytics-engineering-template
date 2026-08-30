SELECT
    funnel_entity_key,
    funnel_step
FROM {{ ref('int_pipedrive__funnel_step_events') }}
GROUP BY 1, 2
HAVING COUNT(*) != 1
