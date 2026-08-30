WITH group_sizes AS (

    SELECT
        customer_group_id,
        COUNT(*) AS known_customer_count
    FROM {{ ref('stg_air_service__customers') }}
    WHERE customer_group_id IS NOT NULL
    GROUP BY customer_group_id

)

SELECT
    customer_group.customer_group_id,
    customer_group.customer_group_type,
    customer_group.customer_group_name,
    customer_group.registry_number,
    COALESCE(group_sizes.known_customer_count, 0) AS known_customer_count
FROM {{ ref('stg_air_service__customer_groups') }} AS customer_group
LEFT JOIN group_sizes
    ON customer_group.customer_group_id = group_sizes.customer_group_id
