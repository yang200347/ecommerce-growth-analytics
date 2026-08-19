-- 09_data_quality_checks.sql
-- Check whether the GA4 data is reliable enough for funnel analysis.

/*
Check 1: Daily core funnel event counts

Purpose:
Compare the number of core funnel events recorded on each day.
This helps identify dates where an event is missing or tracking is incomplete.
*/

SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  COUNTIF(event_name = 'view_item') AS view_item_events,
  COUNTIF(event_name = 'add_to_cart') AS add_to_cart_events,
  COUNTIF(event_name = 'begin_checkout') AS begin_checkout_events,
  COUNTIF(event_name = 'purchase') AS purchase_events
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  AND event_name IN (
    'view_item',
    'add_to_cart',
    'begin_checkout',
    'purchase'
  )
GROUP BY
  event_date
ORDER BY
  event_date;


/*
Check 2: Identify the reliable add-to-cart tracking period

Purpose:
Find the last date with zero add-to-cart events and use the following date as
the candidate start of the reliable tracking period. A few isolated events do
not prove that tracking was complete.
*/

WITH daily_event_counts AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    COUNTIF(event_name = 'view_item') AS view_item_events,
    COUNTIF(event_name = 'add_to_cart') AS add_to_cart_events
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
  GROUP BY
    event_date
)

SELECT
  MAX(
    IF(add_to_cart_events = 0, event_date, NULL)
  ) AS last_zero_add_to_cart_date,
  DATE_ADD(
    MAX(IF(add_to_cart_events = 0, event_date, NULL)),
    INTERVAL 1 DAY
  ) AS candidate_reliable_start_date,
  COUNTIF(add_to_cart_events = 0) AS days_with_zero_add_to_cart,
  ROUND(
    100 * MIN(SAFE_DIVIDE(add_to_cart_events, view_item_events)),
    2
  ) AS minimum_daily_cart_to_view_pct,
  ROUND(
    100 * MAX(SAFE_DIVIDE(add_to_cart_events, view_item_events)),
    2
  ) AS maximum_daily_cart_to_view_pct
FROM
  daily_event_counts;


/*
Check 3: Missing user IDs in the official analysis period

Purpose:
Measure how many core funnel events cannot be linked to a user.
*/

SELECT
  COUNT(*) AS total_core_events,
  COUNTIF(user_pseudo_id IS NULL) AS events_missing_user_id,
  ROUND(
    100 * SAFE_DIVIDE(
      COUNTIF(user_pseudo_id IS NULL),
      COUNT(*)
    ),
    2
  ) AS missing_user_id_pct
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  _TABLE_SUFFIX BETWEEN '20201125' AND '20210131'
  AND event_name IN (
    'view_item',
    'add_to_cart',
    'begin_checkout',
    'purchase'
  );


/*
Check 4: Missing session IDs in the official analysis period

Purpose:
Measure how many core funnel events cannot be assigned to a session.
The session ID is stored inside the nested event_params field.
*/

WITH core_events AS (
  SELECT
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20201125' AND '20210131'
    AND event_name IN (
      'view_item',
      'add_to_cart',
      'begin_checkout',
      'purchase'
    )
)

SELECT
  COUNT(*) AS total_core_events,
  COUNTIF(ga_session_id IS NULL) AS events_missing_session_id,
  ROUND(
    100 * SAFE_DIVIDE(
      COUNTIF(ga_session_id IS NULL),
      COUNT(*)
    ),
    2
  ) AS missing_session_id_pct
FROM
  core_events;
