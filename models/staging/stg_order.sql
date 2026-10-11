-- One row per order (one seat on one trip for one customer).
SELECT
    `Order ID` AS order_id,
    `Customer ID` AS customer_id,
    `Trip ID` AS trip_id,
    CAST(`Price (EUR)` AS DECIMAL(18, 2)) AS price_eur,
    TRIM(`Seat No`) AS seat_no,
    LOWER(TRIM(status)) AS order_status
FROM {{ source('raw', 'order') }}
