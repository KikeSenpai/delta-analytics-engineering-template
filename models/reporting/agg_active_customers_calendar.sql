-- Grain: one row per (period_type, period_start), period_type week or month.
-- Calendar periods: ISO week Monday..Sunday, calendar month 1st..last day.
-- Same active-customer definition as agg_active_customers_daily.
-- Distinct counts: NOT additive (weekly actives do not sum to the month).
WITH activity AS (
    SELECT DISTINCT
        customer_id,
        service_date AS activity_date
    FROM {{ ref('fct_order') }}
    WHERE order_status != 'cancelled'
),

days AS (
    -- Window MIN/MAX: see agg_active_customers_daily (Delta metadata MIN bug).
    SELECT
        week_start,
        month_start,
        MIN(date_day) OVER () AS first_day,
        MAX(date_day) OVER () AS last_day
    FROM {{ ref('dim_date') }}
),

periods AS (
    SELECT DISTINCT
        'week' AS period_type,
        week_start AS period_start,
        DATE_ADD(week_start, 6) AS period_end,
        first_day,
        last_day
    FROM days
    UNION ALL
    SELECT DISTINCT
        'month' AS period_type,
        month_start AS period_start,
        LAST_DAY(month_start) AS period_end,
        first_day,
        last_day
    FROM days
)

SELECT
    p.period_type,
    p.period_start,
    p.period_end,
    COUNT(DISTINCT a.customer_id) AS active_customers,
    -- FALSE when the period extends beyond the observed date range.
    p.period_start >= p.first_day
    AND p.period_end <= p.last_day AS is_complete_period
FROM periods AS p
LEFT JOIN activity AS a
    ON a.activity_date BETWEEN p.period_start AND p.period_end
GROUP BY
    p.period_type, p.period_start, p.period_end, p.first_day, p.last_day
