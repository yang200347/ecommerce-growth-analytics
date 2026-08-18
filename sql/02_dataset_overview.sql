/*
Purpose:
Summarize the date range and overall scale of the GA4 dataset.

Metrics:
- Total events
- Unique users
- Unique sessions
- Dataset start and end dates
*/

WITH event_data AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
)

SELECT
  MIN(event_date) AS start_date,
  MAX(event_date) AS end_date,
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_pseudo_id) AS total_users,
  COUNT(
    DISTINCT CONCAT(
      user_pseudo_id,
      '-',
      CAST(ga_session_id AS STRING)
    )
  ) AS total_sessions
FROM
  event_data;
