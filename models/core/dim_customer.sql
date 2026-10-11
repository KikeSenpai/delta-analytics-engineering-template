-- Grain: one row per customer, group attributes flattened in (flat star).
-- Keeps "no group" (NULL reference) apart from "invalid group reference"
-- (points to a group that does not exist) instead of collapsing both to NULL.
SELECT
    c.customer_id,
    c.customer_name,
    c.customer_group_id AS referenced_customer_group_id,
    g.customer_group_id,
    g.customer_group_type,
    g.customer_group_name,
    CASE
        WHEN c.customer_group_id IS NULL THEN 'no_group'
        WHEN g.customer_group_id IS NULL THEN 'invalid_group_reference'
        ELSE 'group_member'
    END AS group_membership_status,
    c.email IS NOT NULL AS has_email,
    c.phone_number IS NOT NULL AS has_phone_number
FROM {{ ref('stg_customer') }} AS c
LEFT JOIN {{ ref('dim_customer_group') }} AS g
    ON c.customer_group_id = g.customer_group_id
