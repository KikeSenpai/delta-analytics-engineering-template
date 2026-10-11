-- Known source limitation: trips 3 (Sydney -> Los Angeles) and 9 (Beijing -> San Francisco) arrive
-- "before" they depart because timestamps are local wall-clock times without a time zone.
-- Warn on the known 2; fail if more appear.
{{ config(severity='error', warn_if='>0', error_if='>2') }}

SELECT trip_id, origin_city, destination_city, start_local_at, end_local_at
FROM {{ ref('stg_trip') }}
WHERE end_local_at < start_local_at
