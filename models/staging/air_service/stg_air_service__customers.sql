SELECT
    CAST(`Customer ID` AS BIGINT) AS customer_id,
    CAST(`Customer Group ID` AS BIGINT) AS customer_group_id,
    TRIM(name) AS customer_name,
    NULLIF(LOWER(TRIM(email)), '') AS email,
    NULLIF(TRIM(`Phone Number`), '') AS phone_number
FROM {{ source('air_service_raw', 'customer') }}
