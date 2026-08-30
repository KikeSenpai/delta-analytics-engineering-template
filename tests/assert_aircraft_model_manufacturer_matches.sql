SELECT aeroplane.*
FROM {{ ref('stg_air_service__aeroplanes') }} AS aeroplane
LEFT JOIN {{ ref('stg_air_service__aeroplane_models') }} AS model_spec
    ON
        aeroplane.airplane_model = model_spec.airplane_model
        AND aeroplane.manufacturer = model_spec.manufacturer
WHERE model_spec.airplane_model IS NULL
