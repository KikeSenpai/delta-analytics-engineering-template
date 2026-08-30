SELECT
    origin_city,
    origin_country,
    origin_region,
    destination_city,
    destination_country,
    destination_region,
    COUNT(*) AS scheduled_trips,
    SUM(active_order_count) AS active_orders,
    SUM(finished_order_count) AS finished_orders,
    SUM(cancelled_order_count) AS cancelled_orders,
    SUM(realized_revenue_eur) AS realized_revenue_eur,
    SUM(booked_gmv_eur) AS booked_gmv_eur,
    SUM(available_seats) AS available_seats,
    CAST(SUM(active_order_count) AS DECIMAL(18, 4))
    / SUM(available_seats) AS active_seat_utilization
FROM (
    SELECT
        origin_city,
        origin_country,
        origin_region,
        destination_city,
        destination_country,
        destination_region,
        active_order_count,
        finished_order_count,
        cancelled_order_count,
        realized_revenue_eur,
        booked_gmv_eur,
        max_seats AS available_seats
    FROM {{ ref('fct_trips') }}
) AS trip
GROUP BY
    origin_city,
    origin_country,
    origin_region,
    destination_city,
    destination_country,
    destination_region
