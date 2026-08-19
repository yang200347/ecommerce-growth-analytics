-- 11_ecommerce_kpi_overview.sql
-- Validate purchase data and calculate core e-commerce KPIs.

/*
Official analysis period:
2020-11-25 to 2021-01-31

This file contains five queries:
1. Purchase data quality summary
2. Revenue anomaly details
3. Anomalous purchase event details
4. Overall e-commerce KPIs
5. Daily KPI trend
*/


/*
Query 1: Purchase data quality summary

Purpose:
Check whether transaction IDs and purchase revenue can be used to calculate
orders and revenue without double counting.
*/

WITH purchase_events AS (
  SELECT
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,
    NULLIF(ecommerce.transaction_id, '(not set)') AS transaction_id,
    ecommerce.purchase_revenue AS purchase_revenue
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201125' AND '20210131'
    AND event_name = 'purchase'
),

event_quality AS (
  SELECT
    COUNT(*) AS purchase_events,
    COUNTIF(transaction_id IS NULL) AS events_missing_transaction_id,
    COUNTIF(purchase_revenue IS NULL) AS events_missing_revenue
  FROM
    purchase_events
),

order_summary AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    transaction_id,
    COUNT(*) AS events_per_order,
    MAX(purchase_revenue) AS order_revenue,
    COUNT(DISTINCT purchase_revenue) AS distinct_revenue_values
  FROM
    purchase_events
  WHERE
    transaction_id IS NOT NULL
  GROUP BY
    user_pseudo_id,
    ga_session_id,
    transaction_id
),

order_quality AS (
  SELECT
    COUNT(*) AS unique_orders,
    COUNTIF(events_per_order > 1)
      AS orders_with_duplicate_events,
    SUM(events_per_order - 1) AS extra_duplicate_purchase_events,
    COUNTIF(order_revenue IS NULL) AS orders_missing_revenue,
    COUNTIF(COALESCE(order_revenue, 0) <= 0)
      AS orders_with_non_positive_revenue,
    COUNTIF(distinct_revenue_values > 1)
      AS orders_with_conflicting_revenue
  FROM
    order_summary
),

transaction_contexts AS (
  SELECT
    transaction_id,
    COUNT(
      DISTINCT CONCAT(
        user_pseudo_id,
        '-',
        CAST(ga_session_id AS STRING)
      )
    ) AS order_contexts
  FROM
    purchase_events
  WHERE
    transaction_id IS NOT NULL
  GROUP BY
    transaction_id
),

transaction_reuse_quality AS (
  SELECT
    COUNT(*) AS unique_transaction_ids,
    COUNTIF(order_contexts > 1) AS reused_transaction_ids
  FROM
    transaction_contexts
)

SELECT
  purchase_events,
  events_missing_transaction_id,
  events_missing_revenue,
  unique_transaction_ids,
  reused_transaction_ids,
  unique_orders,
  orders_with_duplicate_events,
  extra_duplicate_purchase_events,
  orders_missing_revenue,
  orders_with_non_positive_revenue,
  orders_with_conflicting_revenue
FROM
  event_quality
CROSS JOIN
  order_quality
CROSS JOIN
  transaction_reuse_quality;


/*
Query 2: Revenue anomaly details

Purpose:
Inspect transactions that have no revenue or more than one recorded revenue
value. These records should be reviewed before choosing a revenue deduplication
rule.
*/

WITH purchase_events AS (
  SELECT
    NULLIF(ecommerce.transaction_id, '(not set)') AS transaction_id,
    ecommerce.purchase_revenue AS purchase_revenue
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201125' AND '20210131'
    AND event_name = 'purchase'
)

SELECT
  transaction_id,
  COUNT(*) AS purchase_events,
  COUNTIF(purchase_revenue IS NULL) AS events_missing_revenue,
  COUNT(DISTINCT purchase_revenue) AS distinct_revenue_values,
  ARRAY_AGG(
    DISTINCT purchase_revenue IGNORE NULLS
    ORDER BY purchase_revenue
  ) AS recorded_revenue_values,
  MIN(purchase_revenue) AS minimum_recorded_revenue,
  MAX(purchase_revenue) AS maximum_recorded_revenue
FROM
  purchase_events
WHERE
  transaction_id IS NOT NULL
GROUP BY
  transaction_id
HAVING
  MAX(purchase_revenue) IS NULL
  OR COUNT(DISTINCT purchase_revenue) > 1
ORDER BY
  distinct_revenue_values DESC,
  transaction_id;


/*
Query 3: Anomalous purchase event details

Purpose:
Determine whether conflicting revenue values for the same transaction ID came
from the same user and session or from different customer journeys.
*/

WITH purchase_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    TIMESTAMP_MICROS(event_timestamp) AS event_time,
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,
    NULLIF(ecommerce.transaction_id, '(not set)') AS transaction_id,
    ecommerce.purchase_revenue AS purchase_revenue
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201125' AND '20210131'
    AND event_name = 'purchase'
),

anomalous_transactions AS (
  SELECT
    transaction_id
  FROM
    purchase_events
  WHERE
    transaction_id IS NOT NULL
  GROUP BY
    transaction_id
  HAVING
    MAX(purchase_revenue) IS NULL
    OR COUNT(DISTINCT purchase_revenue) > 1
)

SELECT
  purchase_events.transaction_id,
  purchase_events.event_date,
  purchase_events.event_time,
  purchase_events.user_pseudo_id,
  purchase_events.ga_session_id,
  purchase_events.purchase_revenue
FROM
  purchase_events
INNER JOIN
  anomalous_transactions
  USING (transaction_id)
ORDER BY
  transaction_id,
  event_time;


/*
Query 4: Overall e-commerce KPIs

Definitions:
- Users: unique user_pseudo_id values
- Sessions: unique user_pseudo_id and ga_session_id combinations
- Orders: unique user, session, and valid transaction ID combinations
- Revenue: revenue summed once per deduplicated order
- Purchase conversion rate: orders divided by sessions
- Average order value: revenue divided by orders
- Revenue per session: revenue divided by sessions
- Revenue per user: revenue divided by users
*/

WITH base_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,
    event_name,
    NULLIF(ecommerce.transaction_id, '(not set)') AS transaction_id,
    ecommerce.purchase_revenue AS purchase_revenue
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201125' AND '20210131'
),

traffic_summary AS (
  SELECT
    MIN(event_date) AS analysis_start_date,
    MAX(event_date) AS analysis_end_date,
    COUNT(DISTINCT user_pseudo_id) AS users,
    COUNT(
      DISTINCT IF(
        user_pseudo_id IS NOT NULL AND ga_session_id IS NOT NULL,
        CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)),
        NULL
      )
    ) AS sessions
  FROM
    base_events
),

orders AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    transaction_id,
    MAX(purchase_revenue) AS order_revenue
  FROM
    base_events
  WHERE
    event_name = 'purchase'
    AND transaction_id IS NOT NULL
  GROUP BY
    user_pseudo_id,
    ga_session_id,
    transaction_id
),

order_summary AS (
  SELECT
    COUNT(*) AS orders,
    SUM(order_revenue) AS revenue
  FROM
    orders
)

SELECT
  analysis_start_date,
  analysis_end_date,
  users,
  sessions,
  orders,
  ROUND(revenue, 2) AS revenue,
  ROUND(
    100 * SAFE_DIVIDE(orders, sessions),
    2
  ) AS purchase_conversion_rate_pct,
  ROUND(
    SAFE_DIVIDE(revenue, orders),
    2
  ) AS average_order_value,
  ROUND(
    SAFE_DIVIDE(revenue, sessions),
    2
  ) AS revenue_per_session,
  ROUND(
    SAFE_DIVIDE(revenue, users),
    2
  ) AS revenue_per_user
FROM
  traffic_summary
CROSS JOIN
  order_summary;


/*
Query 5: Daily KPI trend

Purpose:
Create a daily table that can later be used for revenue and conversion charts.
*/

WITH base_events AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,
    event_name,
    NULLIF(ecommerce.transaction_id, '(not set)') AS transaction_id,
    ecommerce.purchase_revenue AS purchase_revenue
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201125' AND '20210131'
),

daily_traffic AS (
  SELECT
    event_date,
    COUNT(DISTINCT user_pseudo_id) AS users,
    COUNT(
      DISTINCT IF(
        user_pseudo_id IS NOT NULL AND ga_session_id IS NOT NULL,
        CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)),
        NULL
      )
    ) AS sessions
  FROM
    base_events
  GROUP BY
    event_date
),

daily_orders AS (
  SELECT
    event_date,
    user_pseudo_id,
    ga_session_id,
    transaction_id,
    MAX(purchase_revenue) AS order_revenue
  FROM
    base_events
  WHERE
    event_name = 'purchase'
    AND transaction_id IS NOT NULL
  GROUP BY
    event_date,
    user_pseudo_id,
    ga_session_id,
    transaction_id
),

daily_order_summary AS (
  SELECT
    event_date,
    COUNT(*) AS orders,
    SUM(order_revenue) AS revenue
  FROM
    daily_orders
  GROUP BY
    event_date
)

SELECT
  daily_traffic.event_date,
  daily_traffic.users,
  daily_traffic.sessions,
  COALESCE(daily_order_summary.orders, 0) AS orders,
  ROUND(COALESCE(daily_order_summary.revenue, 0), 2) AS revenue,
  ROUND(
    100 * SAFE_DIVIDE(
      COALESCE(daily_order_summary.orders, 0),
      daily_traffic.sessions
    ),
    2
  ) AS purchase_conversion_rate_pct,
  ROUND(
    SAFE_DIVIDE(
      COALESCE(daily_order_summary.revenue, 0),
      COALESCE(daily_order_summary.orders, 0)
    ),
    2
  ) AS average_order_value,
  ROUND(
    SAFE_DIVIDE(
      COALESCE(daily_order_summary.revenue, 0),
      daily_traffic.sessions
    ),
    2
  ) AS revenue_per_session
FROM
  daily_traffic
LEFT JOIN
  daily_order_summary
  USING (event_date)
ORDER BY
  event_date;
