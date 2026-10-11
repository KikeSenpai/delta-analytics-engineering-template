-- Email and phone number are profiled in docs/ but not carried forward: no analytical consumer needs PII.
SELECT
    CAST(`Customer ID` AS INT) AS customer_id,
    CAST(`Customer Group ID` AS INT) AS customer_group_id,
    TRIM(name) AS customer_name
FROM {{ source('raw', 'customer') }}
