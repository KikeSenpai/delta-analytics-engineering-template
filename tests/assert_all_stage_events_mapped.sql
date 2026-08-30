WITH source_totals AS (
    SELECT COUNT(*) AS source_count
    FROM {{ ref('stg_pipedrive__deal_changes') }} AS source_changes
    WHERE source_changes.changed_field_key = 'stage_id'
),

mapped_totals AS (
    SELECT COUNT(*) AS mapped_count
    FROM {{ ref('int_pipedrive__funnel_step_events') }} AS events
    WHERE events.event_source = 'deal_stage'
)

SELECT
    source_totals.source_count,
    mapped_totals.mapped_count
FROM source_totals
CROSS JOIN mapped_totals
WHERE source_totals.source_count != mapped_totals.mapped_count
