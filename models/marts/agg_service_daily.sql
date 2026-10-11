WITH trip_orders AS (

    SELECT
        trip_id,
        SUM(CASE WHEN is_active_order THEN 1 ELSE 0 END) AS active_order_count,
        SUM(CASE WHEN is_finished_order THEN 1 ELSE 0 END)
            AS finished_order_count,
        SUM(CASE WHEN order_status = 'booked' THEN 1 ELSE 0 END)
            AS booked_order_count,
        SUM(CASE WHEN order_status = 'cancelled' THEN 1 ELSE 0 END)
            AS cancelled_order_count,
        SUM(realized_revenue_eur) AS realized_revenue_eur,
        SUM(booked_gmv_eur) AS booked_gmv_eur,
        SUM(total_revenue_eur) AS total_revenue_eur
    FROM {{ ref('fct_orders') }}
    GROUP BY trip_id

),

trip_metrics AS (

    SELECT
        trip.service_date,
        origin.region AS origin_region,
        destination.region AS destination_region,
        COUNT(*) AS scheduled_trips,
        SUM(plane_model.max_seats) AS available_seats,
        SUM(COALESCE(trip_orders.active_order_count, 0)) AS active_orders,
        SUM(COALESCE(trip_orders.finished_order_count, 0)) AS finished_orders,
        SUM(COALESCE(trip_orders.booked_order_count, 0)) AS booked_orders,
        SUM(COALESCE(trip_orders.cancelled_order_count, 0)) AS cancelled_orders,
        SUM(COALESCE(trip_orders.realized_revenue_eur, 0))
            AS realized_revenue_eur,
        SUM(COALESCE(trip_orders.booked_gmv_eur, 0)) AS booked_gmv_eur,
        SUM(COALESCE(trip_orders.total_revenue_eur, 0)) AS total_revenue_eur
    FROM {{ ref('fct_trips') }} AS trip
    INNER JOIN {{ ref('dim_aeroplanes') }} AS plane_model
        ON trip.aeroplane_id = plane_model.aeroplane_id
    LEFT JOIN {{ ref('dim_geographies') }} AS origin
        ON trip.origin_city = origin.city
    LEFT JOIN {{ ref('dim_geographies') }} AS destination
        ON trip.destination_city = destination.city
    LEFT JOIN trip_orders
        ON trip.trip_id = trip_orders.trip_id
    GROUP BY
        trip.service_date,
        origin.region,
        destination.region

),

active_users AS (

    SELECT
        trip.service_date,
        origin.region AS origin_region,
        destination.region AS destination_region,
        COUNT(DISTINCT orders.customer_id) AS active_users
    FROM {{ ref('fct_orders') }} AS orders
    INNER JOIN {{ ref('fct_trips') }} AS trip
        ON orders.trip_id = trip.trip_id
    LEFT JOIN {{ ref('dim_geographies') }} AS origin
        ON trip.origin_city = origin.city
    LEFT JOIN {{ ref('dim_geographies') }} AS destination
        ON trip.destination_city = destination.city
    WHERE orders.is_active_order
    GROUP BY
        trip.service_date,
        origin.region,
        destination.region

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
    trip_metrics.total_revenue_eur,
    COALESCE(active_users.active_users, 0) AS active_users,
    CAST(trip_metrics.active_orders AS DECIMAL(18, 4))
    / trip_metrics.available_seats AS active_seat_utilization
FROM trip_metrics
LEFT JOIN active_users
    ON
        trip_metrics.service_date = active_users.service_date
        AND trip_metrics.origin_region = active_users.origin_region
        AND trip_metrics.destination_region = active_users.destination_region
