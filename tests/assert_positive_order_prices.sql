SELECT *
FROM {{ ref('stg_air_service__orders') }}
WHERE price_eur <= 0
