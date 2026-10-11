-- One row per customer with the current (snapshot) customer group attributes.
-- Group references that do not resolve are kept and signalled, not nulled out or dropped.
SELECT
    customer.customer_id,
    customer.customer_name,
    customer.customer_group_id,
    customer_group.customer_group_name,
    customer_group.customer_group_type,
    CASE
        WHEN customer.customer_group_id IS NULL THEN 'no_group'
        WHEN customer_group.customer_group_id IS NULL THEN 'unknown_group_reference'
        ELSE 'valid_group'
    END AS customer_group_reference_status
FROM {{ ref('stg_customer') }} AS customer
LEFT JOIN {{ ref('stg_customer_group') }} AS customer_group
    ON customer.customer_group_id = customer_group.customer_group_id
