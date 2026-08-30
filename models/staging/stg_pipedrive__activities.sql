SELECT
    CAST(activity_id AS BIGINT) AS activity_id,
    CAST(assigned_to_user AS BIGINT) AS assigned_user_id,
    CAST(deal_id AS BIGINT) AS deal_id,
    CAST(due_to AS TIMESTAMP) AS due_at,
    CAST(done AS BOOLEAN) AS is_done,
    SHA2(
        CONCAT_WS(
            '||',
            CAST(activity_id AS STRING),
            type,
            CAST(assigned_to_user AS STRING),
            CAST(deal_id AS STRING),
            CAST(done AS STRING),
            CAST(due_to AS STRING)
        ),
        256
    ) AS activity_record_key,
    LOWER(type) AS activity_type
FROM {{ source('raw', 'activity') }}
