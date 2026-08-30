SELECT
    customer.customer_id,
    customer.customer_name,
    customer.customer_group_id,
    customer_group.customer_group_name,
    customer_group.customer_group_type,
    customer_group.known_customer_count AS known_group_size,
    customer.email,
    customer.phone_number,
    CASE
        WHEN customer.customer_group_id IS NULL THEN 'individual'
        WHEN
            customer_group.customer_group_id IS NULL
            THEN 'unmatched group reference'
        ELSE 'known group member'
    END AS group_membership_status,
    CASE
        WHEN customer.customer_group_id IS NULL THEN 'Individual'
        WHEN customer_group.customer_group_id IS NULL THEN 'Unknown group'
        ELSE customer_group.customer_group_type
    END AS customer_segment
FROM {{ ref('stg_air_service__customers') }} AS customer
LEFT JOIN {{ ref('dim_customer_groups') }} AS customer_group
    ON customer.customer_group_id = customer_group.customer_group_id
