SELECT
    CAST(`Order ID` AS BIGINT) AS order_id,
    CAST(`Customer ID` AS BIGINT) AS customer_id,
    CAST(`Trip ID` AS BIGINT) AS trip_id,
    CAST(`Price (EUR)` AS DECIMAL(18, 2)) AS price_eur,
    UPPER(TRIM(`Seat No`)) AS seat_number,
    LOWER(TRIM(status)) AS order_status
FROM {{ source('air_service_raw', 'order') }}
