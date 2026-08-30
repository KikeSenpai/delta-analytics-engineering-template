SELECT
    manufacturer,
    airplane_model,
    max_seats,
    max_weight_kg,
    max_distance_nautical_miles,
    engine_type,
    CASE
        WHEN max_seats <= 19 THEN 'up to 19 seats'
        WHEN max_seats <= 100 THEN '20-100 seats'
        WHEN max_seats <= 250 THEN '101-250 seats'
        ELSE 'more than 250 seats'
    END AS seat_capacity_band
FROM {{ ref('stg_air_service__aeroplane_models') }}
