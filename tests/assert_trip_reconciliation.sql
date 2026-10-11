-- Every raw trip, including trips with zero orders, must survive into fct_trip and into each
-- trip-level aggregate. Expected values come from the raw source, not from fct_trip.
{% set aggregates = ['agg_service_daily', 'agg_route', 'agg_aircraft_model'] %}

WITH raw_ordered_trips AS (
    SELECT DISTINCT `Trip ID` AS trip_id
    FROM {{ source('raw', 'order') }}
),

expected AS (
    SELECT
        COUNT(*) AS trips,
        COUNT_IF(o.trip_id IS NULL) AS zero_order_trips
    FROM {{ source('raw', 'trip') }} AS t
    LEFT JOIN raw_ordered_trips AS o ON t.`Trip ID` = o.trip_id
),

actual AS (
    SELECT
        'fct_trip' AS model,
        COUNT(*) AS trips,
        COUNT_IF(o.trip_id IS NULL) AS zero_order_trips
    FROM {{ ref('fct_trip') }} AS t
    LEFT JOIN (SELECT DISTINCT trip_id FROM {{ ref('fct_order') }}) AS o ON t.trip_id = o.trip_id
    {% for model in aggregates %}
        UNION ALL
        SELECT
            '{{ model }}',
            SUM(trips_departed),
            SUM(zero_order_trips)
        FROM {{ ref(model) }}
    {% endfor %}
)

SELECT
    a.model,
    e.trips AS expected_trips,
    a.trips AS actual_trips,
    e.zero_order_trips AS expected_zero_order_trips,
    a.zero_order_trips AS actual_zero_order_trips
FROM actual AS a
CROSS JOIN expected AS e
WHERE a.trips != e.trips OR a.zero_order_trips != e.zero_order_trips
