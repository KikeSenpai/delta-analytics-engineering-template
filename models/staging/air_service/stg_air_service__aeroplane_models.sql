SELECT
    CAST(max_seats AS INT) AS max_seats,
    CAST(max_weight_kg AS BIGINT) AS max_weight_kg,
    CAST(max_distance_nautical_miles AS INT) AS max_distance_nautical_miles,
    TRIM(manufacturer) AS manufacturer,
    TRIM(airplane_model) AS airplane_model,
    TRIM(engine_type) AS engine_type
FROM {{ source('air_service_raw', 'aeroplane_model') }}
