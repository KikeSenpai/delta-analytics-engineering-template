-- Status-level order count and value reconciliation: the raw source (read directly, not via
-- staging or fct_order) must equal fct_order and every reporting aggregate, per status bucket.
-- Buckets: finished, booked, cancelled, all (gross), non_cancelled (net / seats sold).
{% set aggregates = ['agg_service_daily', 'agg_route', 'agg_aircraft_model', 'agg_customer', 'agg_customer_group'] %}

WITH raw_orders AS (
    SELECT
        LOWER(TRIM(`Status`)) AS status,
        `Price (EUR)` AS price
    FROM {{ source('raw', 'order') }}
),

expected AS (
    SELECT
        status AS bucket,
        COUNT(*) AS orders,
        SUM(price) AS value_eur
    FROM raw_orders
    GROUP BY status
    UNION ALL
    SELECT
        'all',
        COUNT(*),
        SUM(price)
    FROM raw_orders
    UNION ALL
    SELECT
        'non_cancelled',
        COUNT(*),
        SUM(price)
    FROM raw_orders
    WHERE status != 'cancelled'
),

totals AS (
    SELECT
        'fct_order' AS model,
        COUNT_IF(order_status = 'finished') AS finished_orders,
        SUM(realized_revenue_proxy_eur) AS finished_value,
        COUNT_IF(order_status = 'booked') AS booked_orders,
        SUM(open_booking_value_eur) AS booked_value,
        COUNT_IF(order_status = 'cancelled') AS cancelled_orders,
        SUM(cancelled_value_eur) AS cancelled_value,
        COUNT(*) AS all_orders,
        SUM(gross_order_value_eur) AS all_value,
        SUM(seats_sold) AS non_cancelled_orders,
        SUM(net_order_value_eur) AS non_cancelled_value
    FROM {{ ref('fct_order') }}
    {% for model in aggregates %}
        UNION ALL
        SELECT
            '{{ model }}',
            SUM(orders_finished),
            SUM(realized_revenue_proxy_eur),
            SUM(orders_booked),
            SUM(open_booking_value_eur),
            SUM(orders_cancelled),
            SUM(cancelled_value_eur),
            SUM(orders_total),
            SUM(gross_order_value_eur),
            SUM(seats_sold),
            SUM(net_order_value_eur)
        FROM {{ ref(model) }}
    {% endfor %}
),

actual AS (
    SELECT
        model,
        STACK(
            5,
            'finished', finished_orders, finished_value,
            'booked', booked_orders, booked_value,
            'cancelled', cancelled_orders, cancelled_value,
            'all', all_orders, all_value,
            'non_cancelled', non_cancelled_orders, non_cancelled_value
        ) AS (bucket, orders, value_eur)
    FROM totals
)

SELECT
    a.model,
    e.bucket,
    e.orders AS expected_orders,
    a.orders AS actual_orders,
    e.value_eur AS expected_value_eur,
    a.value_eur AS actual_value_eur
FROM expected AS e
LEFT JOIN actual AS a ON e.bucket = a.bucket
WHERE
    a.model IS NULL
    OR a.orders IS DISTINCT FROM e.orders
    OR a.value_eur IS DISTINCT FROM e.value_eur
