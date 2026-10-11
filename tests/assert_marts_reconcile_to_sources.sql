-- No fan-out and no dropped rows: mart row counts equal source row counts, and
-- trip-level order measures in fct_trip add up to fct_order and to the raw source prices.
WITH checks AS (
    SELECT 'fct_order rows = raw order rows' AS check_name,
        (SELECT COUNT(*) FROM {{ ref('fct_order') }}) AS actual,
        (SELECT COUNT(*) FROM {{ source('raw', 'order') }}) AS expected
    UNION ALL
    SELECT 'fct_trip rows = raw trip rows',
        (SELECT COUNT(*) FROM {{ ref('fct_trip') }}),
        (SELECT COUNT(*) FROM {{ source('raw', 'trip') }})
    UNION ALL
    SELECT 'dim_customer rows = raw customer rows',
        (SELECT COUNT(*) FROM {{ ref('dim_customer') }}),
        (SELECT COUNT(*) FROM {{ source('raw', 'customer') }})
    UNION ALL
    SELECT 'dim_aircraft rows = raw aeroplane rows',
        (SELECT COUNT(*) FROM {{ ref('dim_aircraft') }}),
        (SELECT COUNT(*) FROM {{ source('raw', 'aeroplane') }})
    UNION ALL
    SELECT 'fct_trip orders = fct_order rows',
        (SELECT SUM(orders) FROM {{ ref('fct_trip') }}),
        (SELECT COUNT(*) FROM {{ ref('fct_order') }})
    UNION ALL
    SELECT 'fct_trip status seats = orders',
        (SELECT SUM(booked_seats + finished_seats + cancelled_seats) FROM {{ ref('fct_trip') }}),
        (SELECT SUM(orders) FROM {{ ref('fct_trip') }})
    UNION ALL
    SELECT 'fct_trip GBV + cancelled = raw order price total',
        (SELECT SUM(gross_booking_value_eur + cancelled_value_eur) FROM {{ ref('fct_trip') }}),
        (SELECT SUM(`Price (EUR)`) FROM {{ source('raw', 'order') }})
    UNION ALL
    SELECT 'fct_trip realized revenue proxy = fct_order',
        (SELECT SUM(realized_revenue_proxy_eur) FROM {{ ref('fct_trip') }}),
        (SELECT SUM(realized_revenue_proxy_eur) FROM {{ ref('fct_order') }})
)

SELECT * FROM checks WHERE NOT (actual <=> expected)
