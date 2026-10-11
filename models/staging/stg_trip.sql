-- One row per trip. Source timestamps are local wall-clock values with no
-- timezone: keep them as TIMESTAMP_NTZ so no session timezone is applied.
SELECT
    `Trip ID` AS trip_id,
    `Airplane ID` AS aircraft_id,
    CAST(`Start Timestamp` AS TIMESTAMP_NTZ) AS trip_start_at,
    CAST(`End Timestamp` AS TIMESTAMP_NTZ) AS trip_end_at,
    TRIM(`Origin City`) AS origin_city,
    TRIM(`Destination City`) AS destination_city
FROM {{ source('raw', 'trip') }}
