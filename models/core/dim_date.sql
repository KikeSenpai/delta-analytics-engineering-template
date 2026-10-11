-- Grain: one row per day from the first to the last trip service date.
-- Spine for daily reporting: days without trips appear with zero activity.
WITH bounds AS (
    SELECT
        MIN(CAST(trip_start_at AS DATE)) AS first_day,
        MAX(CAST(trip_start_at AS DATE)) AS last_day
    FROM {{ ref('stg_trip') }}
),

days AS (
    SELECT EXPLODE(SEQUENCE(first_day, last_day, INTERVAL 1 DAY)) AS date_day
    FROM bounds
)

SELECT
    date_day,
    TRUNC(date_day, 'WEEK') AS week_start,  -- ISO week, Monday start
    TRUNC(date_day, 'MM') AS month_start,
    YEAR(date_day) AS year_number,
    DATE_FORMAT(date_day, 'EEEE') AS day_name,
    DAYOFWEEK(date_day) IN (1, 7) AS is_weekend
FROM days
