SELECT
    order_id,
    customer_id,
    trip_id,
    seat_number,
    order_status,
    price_eur,
    order_status IN ('booked', 'finished') AS is_active_order,
    order_status = 'finished' AS is_finished_order,
    CASE
        WHEN order_status = 'finished' THEN price_eur
        ELSE 0
    END AS realized_revenue_eur,
    CASE
        WHEN order_status = 'booked' THEN price_eur
        ELSE 0
    END AS booked_gmv_eur,
    CASE
        WHEN order_status IN ('booked', 'finished') THEN price_eur
        ELSE 0
    END AS total_revenue_eur,
    CASE
        WHEN order_status = 'cancelled' THEN price_eur
        ELSE 0
    END AS cancelled_value_eur
FROM {{ ref('stg_air_service__orders') }}
