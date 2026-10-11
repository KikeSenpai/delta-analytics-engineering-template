SELECT
    customer.customer_id,
    customer.customer_name,
    customer.customer_group_id,
    customer.email,
    customer.phone_number,
    COALESCE(
        customer_group.customer_group_name,
        CASE
            WHEN customer.customer_group_id IS NULL THEN 'no group recorded'
            ELSE 'unknown group'
        END
    ) AS customer_group_name,
    COALESCE(
        customer_group.customer_group_type,
        CASE
            WHEN customer.customer_group_id IS NULL THEN 'no group recorded'
            ELSE 'unknown group'
        END
    ) AS customer_group_type
FROM {{ ref('stg_air_service__customers') }} AS customer
LEFT JOIN {{ ref('stg_air_service__customer_groups') }} AS customer_group
    ON customer.customer_group_id = customer_group.customer_group_id
