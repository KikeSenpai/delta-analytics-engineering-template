-- Business invariants on orders. Returns one row per violation.
--   non_positive_price     every order price must be > 0 EUR
--   double_booked_seat     a seat can be held by at most one non-cancelled order per trip
--   over_max_seats         non-cancelled orders on a trip cannot exceed the model's max seats
SELECT
    'non_positive_price' AS violation,
    CAST(order_id AS STRING) AS item
FROM {{ ref('fct_order') }}
WHERE gross_order_value_eur <= 0

UNION ALL

SELECT
    'double_booked_seat',
    CONCAT(trip_id, ':', seat_no)
FROM {{ ref('fct_order') }}
WHERE order_status != 'cancelled'
GROUP BY trip_id, seat_no
HAVING COUNT(*) > 1

UNION ALL

SELECT
    'over_max_seats',
    CAST(o.trip_id AS STRING)
FROM {{ ref('fct_order') }} AS o
INNER JOIN {{ ref('dim_aircraft') }} AS a ON o.aircraft_id = a.aircraft_id
GROUP BY o.trip_id, a.max_seats
HAVING SUM(o.seats_sold) > a.max_seats
