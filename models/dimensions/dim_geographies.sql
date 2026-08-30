SELECT
    city,
    country,
    region
FROM {{ ref('city_geography') }}
