SELECT
    order_detail.order_id,
    order_detail.customer_id,
    order_detail.trip_id,
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
    aeroplane.max_distance_nautical_miles,
    aeroplane.engine_type,
    aeroplane.seat_capacity_band,
    customer.customer_group_id,
    customer.customer_group_name,
    customer.customer_group_type,
    customer.known_group_size,
    customer.group_membership_status,
    customer.customer_segment,
    order_detail.seat_number,
    order_detail.order_status,
    order_detail.price_eur,
    order_detail.order_status IN ('booked', 'finished') AS is_active_order,
    order_detail.order_status = 'finished' AS is_finished_order,
    CASE
        WHEN
            order_detail.order_status = 'finished'
            THEN order_detail.price_eur
        ELSE 0
    END AS realized_revenue_eur,
    CASE
        WHEN
            order_detail.order_status = 'booked'
            THEN order_detail.price_eur
        ELSE 0
    END AS booked_gmv_eur,
    CASE
        WHEN
            order_detail.order_status = 'cancelled'
            THEN order_detail.price_eur
        ELSE 0
    END AS cancelled_value_eur,
    CASE
        WHEN order_detail.price_eur < 1000 THEN 'under 1,000 EUR'
        WHEN order_detail.price_eur < 2000 THEN '1,000-1,999 EUR'
        ELSE '2,000 EUR or more'
    END AS price_band
FROM {{ ref('stg_air_service__orders') }} AS order_detail
INNER JOIN {{ ref('stg_air_service__trips') }} AS trip
    ON order_detail.trip_id = trip.trip_id
INNER JOIN {{ ref('dim_aeroplanes') }} AS aeroplane
    ON trip.aeroplane_id = aeroplane.aeroplane_id
INNER JOIN {{ ref('dim_customers') }} AS customer
    ON order_detail.customer_id = customer.customer_id
LEFT JOIN {{ ref('dim_geographies') }} AS origin
    ON trip.origin_city = origin.city
LEFT JOIN {{ ref('dim_geographies') }} AS destination
    ON trip.destination_city = destination.city
