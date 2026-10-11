-- Active (Booked + Finished) seats on a trip must not exceed the aircraft model's seat capacity.
SELECT trip_id, active_seats, seat_capacity
FROM {{ ref('fct_trip') }}
WHERE active_seats > seat_capacity
