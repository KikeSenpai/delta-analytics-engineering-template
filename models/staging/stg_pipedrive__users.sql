SELECT
    CAST(id AS BIGINT) AS user_id,
    name AS user_name,
    CAST(modified AS TIMESTAMP) AS modified_at,
    LOWER(email) AS email
FROM {{ source('raw', 'users') }}
