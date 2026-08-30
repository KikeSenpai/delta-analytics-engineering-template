SELECT
    CAST(id AS INT) AS activity_type_id,
    name AS activity_type_name,
    LOWER(active) = 'yes' AS is_active,
    LOWER(type) AS activity_type
FROM {{ source('raw', 'activity_types') }}
