SELECT
    CAST(`Airplane ID` AS BIGINT) AS aeroplane_id,
    TRIM(`Airplane Model`) AS airplane_model,
    TRIM(manufacturer) AS manufacturer
FROM {{ source('air_service_raw', 'aeroplane') }}
