-- The source JSON is one document keyed manufacturer -> model -> specification.
-- prod.raw.aeroplane_model holds it verbatim (one row); here it is flattened to one row per model.
WITH manufacturers AS (
    SELECT
        EXPLODE(
            FROM_JSON(
                value,
                'MAP<STRING, MAP<STRING, STRUCT<'
                || 'max_seats: INT, max_weight: INT, max_distance: INT, engine_type: STRING>>>'
            )
        ) AS (manufacturer, models)
    FROM {{ source('raw', 'aeroplane_model') }}
)

SELECT
    manufacturers.manufacturer,
    models.aircraft_model,
    models.spec.max_seats,
    models.spec.max_weight,
    models.spec.max_distance,
    models.spec.engine_type
FROM manufacturers
    LATERAL VIEW EXPLODE(manufacturers.models) models AS aircraft_model, spec
