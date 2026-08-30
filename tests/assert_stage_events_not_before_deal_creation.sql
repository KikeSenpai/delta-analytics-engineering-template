SELECT
    events.*,
    episodes.created_at
FROM {{ ref('int_pipedrive__funnel_step_events') }} AS events
INNER JOIN {{ ref('int_pipedrive__deal_episodes') }} AS episodes
    ON
        events.funnel_entity_key
        = CONCAT('deal_episode||', episodes.deal_episode_key)
WHERE
    events.event_source = 'deal_stage'
    AND events.event_at < episodes.created_at
