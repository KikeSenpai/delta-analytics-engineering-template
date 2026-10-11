-- Grain: one row per order (= one seat on one trip for one customer).
-- Thin fact: conformed foreign keys, degenerate seat_no, status and atomic
-- additive measures. service_date is the trip departure date: the source has
-- no order or booking timestamp.
SELECT
    o.order_id,
    o.trip_id,
    o.customer_id,
    t.route_key,
    t.aircraft_id,
    t.service_date,
    o.seat_no,
    o.order_status,
    o.price_eur AS gross_order_value_eur,
    CASE WHEN o.order_status = 'finished' THEN o.price_eur ELSE 0 END
        AS realized_revenue_proxy_eur,
    CASE WHEN o.order_status = 'booked' THEN o.price_eur ELSE 0 END
        AS open_booking_value_eur,
    CASE WHEN o.order_status = 'cancelled' THEN o.price_eur ELSE 0 END
        AS cancelled_value_eur,
    CASE WHEN o.order_status != 'cancelled' THEN o.price_eur ELSE 0 END
        AS net_order_value_eur,
    CASE WHEN o.order_status != 'cancelled' THEN 1 ELSE 0 END AS seats_sold
FROM {{ ref('stg_order') }} AS o
LEFT JOIN {{ ref('fct_trip') }} AS t
    ON o.trip_id = t.trip_id
