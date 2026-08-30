SELECT *
FROM {{ ref('fct_orders') }}
WHERE
    realized_revenue_eur
    != CASE WHEN order_status = 'finished' THEN price_eur ELSE 0 END
    OR booked_gmv_eur
    != CASE WHEN order_status = 'booked' THEN price_eur ELSE 0 END
    OR cancelled_value_eur
    != CASE WHEN order_status = 'cancelled' THEN price_eur ELSE 0 END
