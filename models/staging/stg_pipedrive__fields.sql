SELECT
    CAST(id AS INT) AS field_id,
    name AS field_name,
    field_value_options,
    LOWER(field_key) AS field_key
FROM {{ source('raw', 'fields') }}
