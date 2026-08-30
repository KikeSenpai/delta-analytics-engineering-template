SELECT
    aeroplane.aeroplane_id,
    aeroplane.airplane_model,
    aeroplane.manufacturer,
    model_spec.max_seats,
    model_spec.max_weight_kg,
    model_spec.max_distance_nautical_miles,
    model_spec.engine_type,
    model_spec.seat_capacity_band
FROM {{ ref('stg_air_service__aeroplanes') }} AS aeroplane
INNER JOIN {{ ref('dim_aeroplane_models') }} AS model_spec
    ON
        aeroplane.airplane_model = model_spec.airplane_model
        AND aeroplane.manufacturer = model_spec.manufacturer
