WITH stage_events AS (
    SELECT
        CONCAT(
            'stage||',
            SHA2(
                CONCAT_WS(
                    '||',
                    CAST(source_changes.deal_id AS STRING),
                    CAST(source_changes.changed_at AS STRING),
                    source_changes.new_value
                ),
                256
            )
        ) AS event_key,
        CONCAT('deal_episode||', episodes.deal_episode_key)
            AS funnel_entity_key,
        source_changes.changed_at AS event_at,
        CASE CAST(source_changes.new_value AS INT)
            WHEN 1 THEN 'Lead Generation'
            WHEN 2 THEN 'Qualified Lead'
            WHEN 3 THEN 'Needs Assessment'
            WHEN 4 THEN 'Proposal/Quote Preparation'
            WHEN 5 THEN 'Negotiation'
            WHEN 6 THEN 'Closing'
            WHEN 7 THEN 'Implementation/Onboarding'
            WHEN 8 THEN 'Follow-up/Customer Success'
            WHEN 9 THEN 'Renewal/Expansion'
        END AS kpi_name,
        CONCAT('Step ', CAST(source_changes.new_value AS INT)) AS funnel_step,
        'deal_stage' AS event_source
    FROM {{ ref('stg_pipedrive__deal_changes') }} AS source_changes
    INNER JOIN {{ ref('int_pipedrive__deal_episodes') }} AS episodes
        ON
            source_changes.deal_id = episodes.deal_id
            AND DATE_FORMAT(source_changes.changed_at, 'HH:mm:ss')
            = episodes.lifecycle_time_signature
    INNER JOIN {{ ref('stg_pipedrive__stages') }} AS stage_lookup
        ON CAST(source_changes.new_value AS INT) = stage_lookup.stage_id
    WHERE source_changes.changed_field_key = 'stage_id'
),

sales_call_events AS (
    SELECT
        CONCAT('activity||', activities.activity_record_key) AS event_key,
        CONCAT('activity_deal||', CAST(activities.deal_id AS STRING))
            AS funnel_entity_key,
        activities.due_at AS event_at,
        types.activity_type_name AS kpi_name,
        CASE types.activity_type_name
            WHEN 'Sales Call 1' THEN 'Step 2.1'
            WHEN 'Sales Call 2' THEN 'Step 3.1'
        END AS funnel_step,
        'completed_activity' AS event_source
    FROM {{ ref('stg_pipedrive__activities') }} AS activities
    INNER JOIN {{ ref('stg_pipedrive__activity_types') }} AS types
        ON activities.activity_type = types.activity_type
    WHERE
        activities.is_done
        AND types.is_active
        AND types.activity_type_name IN ('Sales Call 1', 'Sales Call 2')
),

all_events AS (
    SELECT * FROM stage_events
    UNION ALL
    SELECT * FROM sales_call_events
),

first_step_event AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY funnel_entity_key, funnel_step
            ORDER BY event_at, event_key
        ) AS event_order
    FROM all_events
)

SELECT
    event_key,
    funnel_entity_key,
    event_at,
    kpi_name,
    funnel_step,
    event_source
FROM first_step_event
WHERE event_order = 1
