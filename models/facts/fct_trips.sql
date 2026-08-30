SELECT
    trip.trip_id,
    trip.service_date,
    trip.start_timestamp_local,
    trip.end_timestamp_local,
    trip.end_precedes_start_local,
    trip.origin_city,
    origin.country AS origin_country,
    origin.region AS origin_region,
    trip.destination_city,
    destination.country AS destination_country,
    destination.region AS destination_region,
    trip.aeroplane_id,
    aeroplane.airplane_model,
    aeroplane.manufacturer,
    aeroplane.max_seats,
    aeroplane.max_weight_kg,
    aeroplane.max_distance_nautical_miles,
    aeroplane.engine_type,
    aeroplane.seat_capacity_band,
    COALESCE(metrics.total_order_count, 0) AS total_order_count,
    COALESCE(metrics.total_customer_count, 0) AS total_customer_count,
    COALESCE(metrics.active_order_count, 0) AS active_order_count,
    COALESCE(metrics.active_customer_count, 0) AS active_customer_count,
    COALESCE(metrics.finished_order_count, 0) AS finished_order_count,
    COALESCE(metrics.booked_order_count, 0) AS booked_order_count,
    COALESCE(metrics.cancelled_order_count, 0) AS cancelled_order_count,
    COALESCE(metrics.realized_revenue_eur, 0) AS realized_revenue_eur,
    COALESCE(metrics.booked_gmv_eur, 0) AS booked_gmv_eur,
    COALESCE(metrics.cancelled_value_eur, 0) AS cancelled_value_eur,
    CAST(COALESCE(metrics.active_order_count, 0) AS DECIMAL(18, 4))
    / aeroplane.max_seats AS active_seat_utilization
FROM {{ ref('stg_air_service__trips') }} AS trip
INNER JOIN {{ ref('dim_aeroplanes') }} AS aeroplane
    ON trip.aeroplane_id = aeroplane.aeroplane_id
LEFT JOIN {{ ref('int_air_service__trip_order_metrics') }} AS metrics
    ON trip.trip_id = metrics.trip_id
LEFT JOIN {{ ref('dim_geographies') }} AS origin
    ON trip.origin_city = origin.city
LEFT JOIN {{ ref('dim_geographies') }} AS destination
    ON trip.destination_city = destination.city
