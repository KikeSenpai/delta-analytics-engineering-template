WITH creation_events AS (
    SELECT
        deal_id,
        CAST(new_value AS TIMESTAMP) AS created_at
    FROM {{ ref('stg_pipedrive__deal_changes') }}
    WHERE changed_field_key = 'add_time'
)

SELECT
    deal_id,
    created_at,
    SHA2(
        CONCAT_WS('||', CAST(deal_id AS STRING), CAST(created_at AS STRING)),
        256
    ) AS deal_episode_key,
    DATE_FORMAT(created_at, 'HH:mm:ss') AS lifecycle_time_signature
FROM creation_events
