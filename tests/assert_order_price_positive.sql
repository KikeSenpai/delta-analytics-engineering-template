SELECT order_id, price_eur
FROM {{ ref('stg_order') }}
WHERE price_eur <= 0
