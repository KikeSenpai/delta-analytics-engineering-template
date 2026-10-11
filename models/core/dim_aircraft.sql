-- Grain: one row per physical aircraft, model specification flattened in.
-- has_model_spec = FALSE exposes aircraft missing from the model catalog.
SELECT
    a.aircraft_id,
    a.manufacturer,
    a.aircraft_model,
    m.max_seats,
    m.max_weight_kg,
    m.max_range_nm,
    m.engine_type,
    m.aircraft_model IS NOT NULL AS has_model_spec
FROM {{ ref('stg_aeroplane') }} AS a
LEFT JOIN {{ ref('stg_aeroplane_model') }} AS m
    ON
        a.manufacturer = m.manufacturer
        AND a.aircraft_model = m.aircraft_model
