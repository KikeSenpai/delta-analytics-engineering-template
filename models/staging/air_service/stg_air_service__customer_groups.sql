SELECT
    CAST(ID AS BIGINT) AS CUSTOMER_GROUP_ID,
    TRIM(TYPE) AS CUSTOMER_GROUP_TYPE,
    TRIM(NAME) AS CUSTOMER_GROUP_NAME,
    NULLIF(TRIM(`Registry number`), '') AS REGISTRY_NUMBER
FROM {{ source('air_service_raw', 'customer_group') }}
