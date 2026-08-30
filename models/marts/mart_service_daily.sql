WITH trip_metrics AS (

    SELECT
        service_date,
        origin_region,
        destination_region,
        COUNT(*) AS scheduled_trips,
        SUM(max_seats) AS available_seats,
        SUM(active_order_count) AS active_orders,
        SUM(finished_order_count) AS finished_orders,
        SUM(booked_order_count) AS booked_orders,
        SUM(cancelled_order_count) AS cancelled_orders,
        SUM(realized_revenue_eur) AS realized_revenue_eur,
        SUM(booked_gmv_eur) AS booked_gmv_eur
    FROM {{ ref('fct_trips') }}
    GROUP BY service_date, origin_region, destination_region

),

active_users AS (

    SELECT
        service_date,
        origin_region,
        destination_region,
        COUNT(DISTINCT customer_id) AS active_users
    FROM {{ ref('fct_orders') }}
    WHERE is_active_order
    GROUP BY service_date, origin_region, destination_region

)

SELECT
    trip_metrics.service_date,
    trip_metrics.origin_region,
    trip_metrics.destination_region,
    trip_metrics.scheduled_trips,
    trip_metrics.available_seats,
    trip_metrics.active_orders,
    trip_metrics.finished_orders,
    trip_metrics.booked_orders,
    trip_metrics.cancelled_orders,
    trip_metrics.realized_revenue_eur,
    trip_metrics.booked_gmv_eur,
    COALESCE(active_users.active_users, 0) AS active_users,
    CAST(trip_metrics.active_orders AS DECIMAL(18, 4))
    / trip_metrics.available_seats AS active_seat_utilization
FROM trip_metrics
LEFT JOIN active_users
    ON
        trip_metrics.service_date = active_users.service_date
        AND trip_metrics.origin_region = active_users.origin_region
        AND trip_metrics.destination_region = active_users.destination_region
