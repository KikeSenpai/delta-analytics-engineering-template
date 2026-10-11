SELECT
    CAST(`Airplane ID` AS INT) AS airplane_id,
    TRIM(manufacturer) AS manufacturer,
    TRIM(`Airplane Model`) AS aircraft_model
FROM {{ source('raw', 'aeroplane') }}
