-- Grain: one row per directional route (origin -> destination) in trips.
-- A -> B and B -> A are different routes. No region, country or distance:
-- the source has none.
SELECT DISTINCT
    origin_city,
    destination_city,
    MD5(CONCAT_WS('|', origin_city, destination_city)) AS route_key,
    CONCAT(origin_city, ' -> ', destination_city) AS route_name
FROM {{ ref('stg_trip') }}
