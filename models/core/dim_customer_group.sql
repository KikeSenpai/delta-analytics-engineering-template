-- Grain: one row per customer group in the group master.
SELECT
    customer_group_id,
    customer_group_type,
    customer_group_name,
    registry_number IS NOT NULL AS has_registry_number
FROM {{ ref('stg_customer_group') }}
