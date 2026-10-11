-- One row per aircraft model specification.
-- Natural key: manufacturer + aircraft_model.
SELECT
    max_seats,
    max_weight_kg,
    max_distance_nautical_miles AS max_range_nm,
    TRIM(manufacturer) AS manufacturer,
    TRIM(airplane_model) AS aircraft_model,
    TRIM(engine_type) AS engine_type
FROM {{ source('raw', 'aeroplane_model') }}
