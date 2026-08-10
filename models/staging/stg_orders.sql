{{
  config(
    materialized='incremental',
    file_format='delta',
    incremental_strategy='merge',
    unique_key='order_id'
  )
}}

select
    order_id,
    customer_id,
    order_date,
    amount,
    status
from {{ source('raw', 'orders') }}

{% if is_incremental() %}
where order_date > (select coalesce(max(order_date), date '1970-01-01') from {{ this }})
{% endif %}
