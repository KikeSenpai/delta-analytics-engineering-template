-- One row per customer. Emails are right-padded with spaces in the source;
-- blanks become NULL. PII (email, phone) stops here: marts only carry
-- completeness flags.
SELECT
    `Customer ID` AS customer_id,
    `Customer Group ID` AS customer_group_id,
    TRIM(name) AS customer_name,
    NULLIF(TRIM(email), '') AS email,
    NULLIF(TRIM(`Phone Number`), '') AS phone_number
FROM {{ source('raw', 'customer') }}
