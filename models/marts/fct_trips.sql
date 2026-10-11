SELECT
    trip_id,
    aeroplane_id,
    service_date,
    start_timestamp_local,
    end_timestamp_local,
    origin_city,
    destination_city
FROM {{ ref('stg_air_service__trips') }}
