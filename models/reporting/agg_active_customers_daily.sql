-- Grain: one row per day on the dim_date spine.
-- Active customer: >= 1 non-cancelled order (booked or finished) on a trip
-- departing in the window. Rolling windows end on and include the day d:
--   DAU = [d, d], WAU = [d - 6, d] (7 days), MAU = [d - 29, d] (30 days).
-- Distinct counts: NOT additive across days or windows.
WITH activity AS (
    SELECT DISTINCT
        customer_id,
        service_date AS activity_date
    FROM {{ ref('fct_order') }}
    WHERE order_status != 'cancelled'
),

days AS (
    -- Window MIN, not a scalar MIN(): Delta's metadata-only MIN on a DATE
    -- column fails on this Spark build (LocalDate ClassCastException).
    SELECT
        date_day,
        MIN(date_day) OVER () AS first_day
    FROM {{ ref('dim_date') }}
),

windows AS (
    SELECT
        d.date_day,
        COUNT(
            DISTINCT CASE
                WHEN a.activity_date = d.date_day THEN a.customer_id
            END
        ) AS dau,
        COUNT(
            DISTINCT CASE
                WHEN
                    a.activity_date >= DATE_SUB(d.date_day, 6)
                    THEN a.customer_id
            END
        ) AS wau_rolling_7d,
        COUNT(DISTINCT a.customer_id) AS mau_rolling_30d,
        DATE_SUB(d.date_day, 6) >= d.first_day AS is_full_7d_window,
        DATE_SUB(d.date_day, 29) >= d.first_day AS is_full_30d_window
    FROM days AS d
    -- ponytail: range join is O(days x activity rows); fine here. At scale,
    -- pre-aggregate per customer-day or use HLL sketches.
    LEFT JOIN activity AS a
        ON a.activity_date BETWEEN DATE_SUB(d.date_day, 29) AND d.date_day
    GROUP BY d.date_day, d.first_day
)

SELECT
    date_day AS activity_date,
    dau,
    wau_rolling_7d,
    mau_rolling_30d,
    is_full_7d_window,
    is_full_30d_window,
    TRY_DIVIDE(dau, mau_rolling_30d) AS dau_mau_ratio
FROM windows
