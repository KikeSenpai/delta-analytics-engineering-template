-- One row per physical aircraft.
SELECT
    `Airplane ID` AS aircraft_id,
    TRIM(manufacturer) AS manufacturer,
    TRIM(`Airplane Model`) AS aircraft_model
FROM {{ source('raw', 'aeroplane') }}
