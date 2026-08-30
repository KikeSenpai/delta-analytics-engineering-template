SELECT
    source_changes.deal_id,
    source_changes.changed_at,
    source_changes.new_value AS owner_user_id
FROM {{ ref('stg_pipedrive__deal_changes') }} AS source_changes
LEFT JOIN {{ ref('stg_pipedrive__users') }} AS user_lookup
    ON CAST(source_changes.new_value AS BIGINT) = user_lookup.user_id
WHERE
    source_changes.changed_field_key = 'user_id'
    AND user_lookup.user_id IS NULL
