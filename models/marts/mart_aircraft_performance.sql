SELECT
    manufacturer,
    airplane_model,
    seat_capacity_band,
    engine_type,
    max_seats,
    max_distance_nautical_miles,
    COUNT(*) AS scheduled_trips,
    SUM(active_order_count) AS active_orders,
    SUM(finished_order_count) AS finished_orders,
    SUM(cancelled_order_count) AS cancelled_orders,
    SUM(realized_revenue_eur) AS realized_revenue_eur,
    SUM(booked_gmv_eur) AS booked_gmv_eur,
    SUM(max_seats) AS available_seats,
    CAST(SUM(active_order_count) AS DECIMAL(18, 4))
    / SUM(max_seats) AS active_seat_utilization
FROM {{ ref('fct_trips') }}
GROUP BY
    manufacturer,
    airplane_model,
    seat_capacity_band,
    engine_type,
    max_seats,
    max_distance_nautical_miles
