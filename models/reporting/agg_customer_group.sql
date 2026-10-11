-- Grain: one row per customer-group segment
-- (group_membership_status, customer_group_ref):
--   group_member: one row per group in the group master, even without customers
--   no_group: one row, customer_group_ref NULL (customer has no group)
--   invalid_group_reference: one row per referenced group id that is missing
--   from the group master
-- Rolled up from agg_customer, so every metric here is additive over customers.
WITH segments AS (
    SELECT
        group_membership_status,
        referenced_customer_group_id AS customer_group_ref,
        COUNT(*) AS customers,
        COUNT_IF(orders_total > 0) AS ordering_customers,
        COUNT_IF(is_active_customer) AS active_customers,
        COUNT_IF(is_repeat_customer) AS repeat_customers,
        SUM(orders_total) AS orders_total,
        SUM(orders_finished) AS orders_finished,
        SUM(orders_booked) AS orders_booked,
        SUM(orders_cancelled) AS orders_cancelled,
        SUM(seats_sold) AS seats_sold,
        SUM(gross_order_value_eur) AS gross_order_value_eur,
        SUM(net_order_value_eur) AS net_order_value_eur,
        SUM(realized_revenue_proxy_eur) AS realized_revenue_proxy_eur,
        SUM(open_booking_value_eur) AS open_booking_value_eur,
        SUM(cancelled_value_eur) AS cancelled_value_eur
    FROM {{ ref('agg_customer') }}
    GROUP BY group_membership_status, referenced_customer_group_id
)

SELECT
    g.customer_group_type,
    COALESCE(s.group_membership_status, 'group_member')
        AS group_membership_status,
    COALESCE(s.customer_group_ref, g.customer_group_id) AS customer_group_ref,
    CASE
        WHEN g.customer_group_id IS NOT NULL THEN g.customer_group_name
        WHEN s.group_membership_status = 'no_group' THEN 'No group'
        ELSE CONCAT('Unknown group ', s.customer_group_ref)
    END AS segment_name,
    COALESCE(s.customers, 0) AS customers,
    COALESCE(s.ordering_customers, 0) AS ordering_customers,
    COALESCE(s.active_customers, 0) AS active_customers,
    COALESCE(s.repeat_customers, 0) AS repeat_customers,
    COALESCE(s.orders_total, 0) AS orders_total,
    COALESCE(s.orders_finished, 0) AS orders_finished,
    COALESCE(s.orders_booked, 0) AS orders_booked,
    COALESCE(s.orders_cancelled, 0) AS orders_cancelled,
    COALESCE(s.seats_sold, 0) AS seats_sold,
    COALESCE(s.gross_order_value_eur, 0) AS gross_order_value_eur,
    COALESCE(s.net_order_value_eur, 0) AS net_order_value_eur,
    COALESCE(s.realized_revenue_proxy_eur, 0) AS realized_revenue_proxy_eur,
    COALESCE(s.open_booking_value_eur, 0) AS open_booking_value_eur,
    COALESCE(s.cancelled_value_eur, 0) AS cancelled_value_eur,
    TRY_DIVIDE(s.net_order_value_eur, s.active_customers)
        AS net_order_value_per_active_customer_eur,
    TRY_DIVIDE(s.orders_cancelled, s.orders_total) AS order_cancellation_rate
FROM segments AS s
FULL OUTER JOIN {{ ref('dim_customer_group') }} AS g
    ON
        s.group_membership_status = 'group_member'
        AND s.customer_group_ref = g.customer_group_id
