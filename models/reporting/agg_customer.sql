-- Grain: one row per customer (all customers, including those without orders).
WITH orders AS (
    SELECT
        customer_id,
        COUNT(*) AS orders_total,
        COUNT_IF(order_status = 'finished') AS orders_finished,
        COUNT_IF(order_status = 'booked') AS orders_booked,
        COUNT_IF(order_status = 'cancelled') AS orders_cancelled,
        SUM(seats_sold) AS seats_sold,
        SUM(gross_order_value_eur) AS gross_order_value_eur,
        SUM(net_order_value_eur) AS net_order_value_eur,
        SUM(realized_revenue_proxy_eur) AS realized_revenue_proxy_eur,
        SUM(open_booking_value_eur) AS open_booking_value_eur,
        SUM(cancelled_value_eur) AS cancelled_value_eur,
        COUNT(DISTINCT CASE WHEN seats_sold = 1 THEN trip_id END)
            AS active_trips,
        COUNT(DISTINCT CASE WHEN seats_sold = 1 THEN route_key END)
            AS active_routes,
        MIN(CASE WHEN seats_sold = 1 THEN service_date END)
            AS first_active_date,
        MAX(CASE WHEN seats_sold = 1 THEN service_date END) AS last_active_date
    FROM {{ ref('fct_order') }}
    GROUP BY customer_id
)

SELECT
    c.customer_id,
    c.customer_name,
    c.group_membership_status,
    c.referenced_customer_group_id,
    c.customer_group_id,
    c.customer_group_type,
    c.customer_group_name,
    o.first_active_date,
    o.last_active_date,
    COALESCE(o.orders_total, 0) AS orders_total,
    COALESCE(o.orders_finished, 0) AS orders_finished,
    COALESCE(o.orders_booked, 0) AS orders_booked,
    COALESCE(o.orders_cancelled, 0) AS orders_cancelled,
    COALESCE(o.seats_sold, 0) AS seats_sold,
    COALESCE(o.gross_order_value_eur, 0) AS gross_order_value_eur,
    COALESCE(o.net_order_value_eur, 0) AS net_order_value_eur,
    COALESCE(o.realized_revenue_proxy_eur, 0) AS realized_revenue_proxy_eur,
    COALESCE(o.open_booking_value_eur, 0) AS open_booking_value_eur,
    COALESCE(o.cancelled_value_eur, 0) AS cancelled_value_eur,
    COALESCE(o.active_trips, 0) AS active_trips,
    COALESCE(o.active_routes, 0) AS active_routes,
    COALESCE(o.seats_sold, 0) > 0 AS is_active_customer,
    COALESCE(o.active_trips, 0) > 1 AS is_repeat_customer
FROM {{ ref('dim_customer') }} AS c
LEFT JOIN orders AS o ON c.customer_id = o.customer_id
