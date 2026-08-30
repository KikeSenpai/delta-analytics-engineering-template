WITH source_totals AS (
    SELECT COUNT(*) AS source_count
    FROM {{ ref('stg_pipedrive__activities') }} AS activities
    INNER JOIN {{ ref('stg_pipedrive__activity_types') }} AS types
        ON activities.activity_type = types.activity_type
    WHERE
        activities.is_done
        AND types.is_active
        AND types.activity_type_name IN ('Sales Call 1', 'Sales Call 2')
),

mapped_totals AS (
    SELECT COUNT(*) AS mapped_count
    FROM {{ ref('int_pipedrive__funnel_step_events') }} AS events
    WHERE events.event_source = 'completed_activity'
)

SELECT
    source_totals.source_count,
    mapped_totals.mapped_count
FROM source_totals
CROSS JOIN mapped_totals
WHERE source_totals.source_count != mapped_totals.mapped_count
