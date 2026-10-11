-- Grain: one row per trip, including trips with zero orders.
-- Thin fact: foreign keys, recorded timestamps, atomic duration measure.
-- No order rollups.
SELECT
    trip_id,
    aircraft_id,
    CAST(trip_start_at AS DATE) AS service_date,
    trip_start_at,
    trip_end_at,
    MD5(CONCAT_WS('|', origin_city, destination_city)) AS route_key,
    -- Difference of two local wall-clock times in (unknown) different
    -- timezones: NOT a flight time.
    TIMESTAMPDIFF(MINUTE, trip_start_at, trip_end_at)
        AS recorded_duration_minutes,
    trip_end_at < trip_start_at AS is_end_before_start
FROM {{ ref('stg_trip') }}
