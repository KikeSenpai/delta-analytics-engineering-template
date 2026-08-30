SELECT
    CAST(deal_id AS BIGINT) AS deal_id,
    CAST(change_time AS TIMESTAMP) AS changed_at,
    LOWER(changed_field_key) AS changed_field_key,
    TRIM(new_value) AS new_value
FROM {{ source('raw', 'deal_changes') }}
