SELECT
    CAST(id AS INT) AS customer_group_id,
    CAST(`Registry number` AS STRING) AS registry_number,
    TRIM(type) AS customer_group_type,
    TRIM(name) AS customer_group_name
FROM {{ source('raw', 'customer_group') }}
