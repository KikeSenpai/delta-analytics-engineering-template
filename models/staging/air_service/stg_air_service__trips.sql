SELECT
    CAST(`Trip ID` AS BIGINT) AS trip_id,
    CAST(`Airplane ID` AS BIGINT) AS aeroplane_id,
    CAST(`Start Timestamp` AS TIMESTAMP) AS start_timestamp_local,
    CAST(`End Timestamp` AS TIMESTAMP) AS end_timestamp_local,
    TRIM(`Origin City`) AS origin_city,
    TRIM(`Destination City`) AS destination_city,
    TO_DATE(CAST(`Start Timestamp` AS TIMESTAMP)) AS service_date,
    CAST(`End Timestamp` AS TIMESTAMP)
    < CAST(`Start Timestamp` AS TIMESTAMP) AS end_precedes_start_local
FROM {{ source('air_service_raw', 'trip') }}
