-- Active-customer outputs recomputed independently from the raw tables (raw status strings,
-- raw trip timestamps). Exact rolling/calendar boundaries are covered by unit tests in
-- models/reporting/_reporting.yml; this test checks the real data end to end.
WITH raw_activity AS (
    SELECT DISTINCT
        o.`Customer ID` AS customer_id,
        CAST(CAST(t.`Start Timestamp` AS TIMESTAMP_NTZ) AS DATE) AS activity_date
    FROM {{ source('raw', 'order') }} AS o
    INNER JOIN {{ source('raw', 'trip') }} AS t ON o.`Trip ID` = t.`Trip ID`
    WHERE LOWER(TRIM(o.`Status`)) IN ('booked', 'finished')
),

expected AS (
    SELECT
        'day' AS period_type,
        activity_date AS period_start,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM raw_activity
    GROUP BY activity_date
    UNION ALL
    SELECT
        'week',
        DATE_TRUNC('WEEK', activity_date),
        COUNT(DISTINCT customer_id)
    FROM raw_activity
    GROUP BY DATE_TRUNC('WEEK', activity_date)
    UNION ALL
    SELECT
        'month',
        DATE_TRUNC('MONTH', activity_date),
        COUNT(DISTINCT customer_id)
    FROM raw_activity
    GROUP BY DATE_TRUNC('MONTH', activity_date)
),

actual AS (
    SELECT
        'day' AS period_type,
        activity_date AS period_start,
        dau AS active_customers
    FROM {{ ref('agg_active_customers_daily') }}
    WHERE dau > 0
    UNION ALL
    SELECT
        period_type,
        period_start,
        active_customers
    FROM {{ ref('agg_active_customers_calendar') }}
    WHERE active_customers > 0
),

ordering_violations AS (
    SELECT
        'dau_le_wau_le_mau' AS period_type,
        activity_date AS period_start,
        NULL AS expected,
        NULL AS actual
    FROM {{ ref('agg_active_customers_daily') }}
    WHERE NOT (dau <= wau_rolling_7d AND wau_rolling_7d <= mau_rolling_30d)
)

SELECT
    COALESCE(e.period_type, a.period_type) AS period_type,
    COALESCE(CAST(e.period_start AS DATE), a.period_start) AS period_start,
    e.active_customers AS expected,
    a.active_customers AS actual
FROM expected AS e
FULL OUTER JOIN actual AS a
    ON e.period_type = a.period_type AND CAST(e.period_start AS DATE) = a.period_start
WHERE e.active_customers IS DISTINCT FROM a.active_customers
UNION ALL
SELECT * FROM ordering_violations
