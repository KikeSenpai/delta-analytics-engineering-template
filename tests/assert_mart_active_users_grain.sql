SELECT
    period_type,
    period_start,
    COUNT(*) AS duplicate_count
FROM {{ ref('mart_active_users') }}
GROUP BY period_type, period_start
HAVING COUNT(*) > 1
