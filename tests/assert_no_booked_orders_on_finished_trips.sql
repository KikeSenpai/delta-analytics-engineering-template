-- If any order on a trip is Finished, the trip has flown, so remaining Booked orders are stale.
-- Known source defect: 5 Booked orders (7, 9, 13, 16, 19) sit on trips 6, 8, 9 and 10 that have Finished orders.
-- Warn on the known 5; fail if more appear.
{{ config(severity='error', warn_if='>0', error_if='>5') }}

SELECT booked.order_id, booked.trip_id
FROM {{ ref('stg_order') }} AS booked
WHERE
    booked.order_status = 'Booked'
    AND EXISTS (
        SELECT 1
        FROM {{ ref('stg_order') }} AS finished
        WHERE finished.trip_id = booked.trip_id AND finished.order_status = 'Finished'
    )
