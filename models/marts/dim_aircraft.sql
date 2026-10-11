-- One row per physical aeroplane, enriched with its model specification from the JSON catalogue.
-- LEFT JOIN keeps aeroplanes whose model is missing from the catalogue (specification columns NULL).
SELECT
    aeroplane.airplane_id,
    aeroplane.manufacturer,
    aeroplane.aircraft_model,
    spec.max_seats,
    spec.max_weight,
    spec.max_distance,
    spec.engine_type,
    spec.aircraft_model IS NOT NULL AS has_model_spec
FROM {{ ref('stg_aeroplane') }} AS aeroplane
LEFT JOIN {{ ref('stg_aeroplane_model') }} AS spec
    ON
        aeroplane.manufacturer = spec.manufacturer
        AND aeroplane.aircraft_model = spec.aircraft_model
