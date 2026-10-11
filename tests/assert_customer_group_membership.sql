-- Identity-level check of group membership classification against the raw source, plus
-- segment totals in agg_customer_group. Expected values are derived from raw tables only.
WITH expected AS (
    SELECT
        c.`Customer ID` AS customer_id,
        CASE
            WHEN c.`Customer Group ID` IS NULL THEN 'no_group'
            WHEN g.`ID` IS NULL THEN 'invalid_group_reference'
            ELSE 'group_member'
        END AS group_membership_status
    FROM {{ source('raw', 'customer') }} AS c
    LEFT JOIN {{ source('raw', 'customer_group') }} AS g ON c.`Customer Group ID` = g.`ID`
),

customer_mismatches AS (
    SELECT
        'dim_customer' AS check_name,
        CAST(COALESCE(e.customer_id, d.customer_id) AS STRING) AS item,
        e.group_membership_status AS expected,
        d.group_membership_status AS actual
    FROM expected AS e
    FULL OUTER JOIN {{ ref('dim_customer') }} AS d ON e.customer_id = d.customer_id
    WHERE
        e.group_membership_status IS DISTINCT FROM d.group_membership_status
        -- a resolved group id is only allowed for members
        OR (d.customer_group_id IS NOT NULL) != (d.group_membership_status = 'group_member')
),

segment_mismatches AS (
    SELECT
        'agg_customer_group' AS check_name,
        COALESCE(e.group_membership_status, s.group_membership_status) AS item,
        CAST(e.customers AS STRING) AS expected,
        CAST(s.customers AS STRING) AS actual
    FROM (
        SELECT
            group_membership_status,
            COUNT(*) AS customers
        FROM expected
        GROUP BY group_membership_status
    ) AS e
    FULL OUTER JOIN (
        SELECT
            group_membership_status,
            SUM(customers) AS customers
        FROM {{ ref('agg_customer_group') }}
        GROUP BY group_membership_status
        HAVING SUM(customers) > 0
    ) AS s ON e.group_membership_status = s.group_membership_status
    WHERE e.customers IS DISTINCT FROM s.customers
)

SELECT * FROM customer_mismatches
UNION ALL
SELECT * FROM segment_mismatches
