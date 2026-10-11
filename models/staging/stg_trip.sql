-- Source timestamps carry no time zone. They behave like local wall-clock times at origin and
-- destination (e.g. Sydney 22:00 -> Los Angeles 15:00 the same day), so they are kept as TIMESTAMP_NTZ.
SELECT
    CAST(`Trip ID` AS INT) AS trip_id,
    CAST(`Airplane ID` AS INT) AS airplane_id,
    CAST(`Start Timestamp` AS TIMESTAMP_NTZ) AS start_local_at,
    CAST(`End Timestamp` AS TIMESTAMP_NTZ) AS end_local_at,
    TRIM(`Origin City`) AS origin_city,
    TRIM(`Destination City`) AS destination_city
FROM {{ source('raw', 'trip') }}
