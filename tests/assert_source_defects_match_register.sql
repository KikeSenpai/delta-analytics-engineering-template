-- Identity-aware defect check: every detected source defect must be registered in the
-- known_source_defects seed, and every registered defect must still be detected.
-- Fails on a new defect (triage it, then register or fix) and on a fixed defect (deregister it).
WITH detected AS (
    SELECT
        'customer' AS source_table,
        c.customer_id AS record_id,
        'invalid_customer_group_reference' AS defect_type
    FROM {{ ref('stg_customer') }} AS c
    LEFT ANTI JOIN {{ ref('stg_customer_group') }} AS g ON c.customer_group_id = g.customer_group_id
    WHERE c.customer_group_id IS NOT NULL
    UNION ALL
    SELECT
        'trip',
        trip_id,
        'end_before_start'
    FROM {{ ref('stg_trip') }}
    WHERE trip_end_at < trip_start_at
    UNION ALL
    SELECT
        'aeroplane',
        a.aircraft_id,
        'missing_model_spec'
    FROM {{ ref('stg_aeroplane') }} AS a
    LEFT ANTI JOIN {{ ref('stg_aeroplane_model') }} AS m
        ON a.manufacturer = m.manufacturer AND a.aircraft_model = m.aircraft_model
),

registered AS (
    SELECT
        source_table,
        record_id,
        defect_type
    FROM {{ ref('known_source_defects') }}
)

SELECT
    COALESCE(d.source_table, r.source_table) AS source_table,
    COALESCE(d.record_id, r.record_id) AS record_id,
    COALESCE(d.defect_type, r.defect_type) AS defect_type,
    CASE WHEN r.record_id IS NULL THEN 'unregistered_new_defect' ELSE 'registered_defect_not_detected' END AS problem
FROM detected AS d
FULL OUTER JOIN registered AS r
    ON
        d.source_table = r.source_table
        AND d.record_id = r.record_id
        AND d.defect_type = r.defect_type
WHERE d.record_id IS NULL OR r.record_id IS NULL
