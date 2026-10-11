SELECT trip_id, origin_city, destination_city
FROM {{ ref('stg_trip') }}
WHERE origin_city = destination_city
