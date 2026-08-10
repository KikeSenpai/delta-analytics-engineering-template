{{
  config(
    materialized='incremental',
    file_format='delta',
    incremental_strategy='merge',
    unique_key='order_id'
  )
}}

select
    src.order_id,
    src.customer_id,
    src.order_date,
    src.amount,
    src.status
from {{ source('raw', 'orders') }} as src

{% if is_incremental() %}
    where src.order_date > (
        select coalesce(prev.order_date, date '1970-01-01')
        from {{ this }} as prev
    )
{% endif %}
