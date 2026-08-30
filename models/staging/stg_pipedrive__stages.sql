SELECT
    CAST(stage_id AS INT) AS stage_id,
    stage_name
FROM {{ source('raw', 'stages') }}
