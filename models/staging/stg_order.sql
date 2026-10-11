SELECT
    CAST(`Order ID` AS INT) AS order_id,
    CAST(`Customer ID` AS INT) AS customer_id,
    CAST(`Trip ID` AS INT) AS trip_id,
    CAST(`Price (EUR)` AS DECIMAL(12, 2)) AS price_eur,
    TRIM(`Seat No`) AS seat_no,
    TRIM(status) AS order_status
FROM {{ source('raw', 'order') }}
