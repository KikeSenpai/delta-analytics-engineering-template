WITH trip_orders AS (

    SELECT
        trip_id,
        SUM(CASE WHEN is_active_order THEN 1 ELSE 0 END) AS active_order_count,
        SUM(CASE WHEN is_finished_order THEN 1 ELSE 0 END)
            AS finished_order_count,
        SUM(CASE WHEN order_status = 'cancelled' THEN 1 ELSE 0 END)
            AS cancelled_order_count,
        SUM(realized_revenue_eur) AS realized_revenue_eur,
        SUM(booked_gmv_eur) AS booked_gmv_eur,
        SUM(total_revenue_eur) AS total_revenue_eur
    FROM {{ ref('fct_orders') }}
    GROUP BY trip_id

)

SELECT
    origin.city AS origin_city,
    origin.country AS origin_country,
    origin.region AS origin_region,
    destination.city AS destination_city,
    destination.country AS destination_country,
    destination.region AS destination_region,
    COUNT(*) AS scheduled_trips,
    SUM(COALESCE(trip_orders.active_order_count, 0)) AS active_orders,
    SUM(COALESCE(trip_orders.finished_order_count, 0)) AS finished_orders,
    SUM(COALESCE(trip_orders.cancelled_order_count, 0)) AS cancelled_orders,
    SUM(COALESCE(trip_orders.realized_revenue_eur, 0)) AS realized_revenue_eur,
    SUM(COALESCE(trip_orders.booked_gmv_eur, 0)) AS booked_gmv_eur,
    SUM(COALESCE(trip_orders.total_revenue_eur, 0)) AS total_revenue_eur
FROM {{ ref('fct_trips') }} AS trip
LEFT JOIN {{ ref('dim_geographies') }} AS origin
    ON trip.origin_city = origin.city
LEFT JOIN {{ ref('dim_geographies') }} AS destination
    ON trip.destination_city = destination.city
LEFT JOIN trip_orders
    ON trip.trip_id = trip_orders.trip_id
GROUP BY
    origin.city,
    origin.country,
    origin.region,
    destination.city,
    destination.country,
    destination.region
