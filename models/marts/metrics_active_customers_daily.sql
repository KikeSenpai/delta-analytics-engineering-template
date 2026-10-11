-- One row per calendar day between the first and last trip departure, including days without demand.
-- Active customer = customer with at least one active (Booked or Finished) order on a trip departing
-- in the window. DAU = that day, WAU = trailing 7 days, MAU = trailing 30 days (both ending on the day).
WITH calendar AS (
    SELECT EXPLODE(SEQUENCE(MIN(departure_date), MAX(departure_date), INTERVAL 1 DAY)) AS activity_date
    FROM {{ ref('fct_trip') }}
),

active_customer_days AS (
    SELECT DISTINCT
        departure_date,
        customer_id
    FROM {{ ref('fct_order') }}
    WHERE is_active
)

SELECT
    calendar.activity_date,
    COUNT(DISTINCT CASE WHEN active.departure_date = calendar.activity_date THEN active.customer_id END) AS dau,
    COUNT(
        DISTINCT CASE WHEN active.departure_date > DATE_SUB(calendar.activity_date, 7) THEN active.customer_id END
    ) AS wau,
    COUNT(DISTINCT active.customer_id) AS mau,
    calendar.activity_date >= DATE_ADD(MIN(calendar.activity_date) OVER (), 6) AS is_complete_7d_window,
    calendar.activity_date >= DATE_ADD(MIN(calendar.activity_date) OVER (), 29) AS is_complete_30d_window
FROM calendar
LEFT JOIN active_customer_days AS active
    ON active.departure_date BETWEEN DATE_SUB(calendar.activity_date, 29) AND calendar.activity_date
GROUP BY calendar.activity_date
