/*
Purpose:
Explore the event types available in the GA4 e-commerce dataset
and calculate the number of occurrences for each event.

Data source:
Google Merchandise Store GA4 public sample dataset.

Grain:
One row per event type.
*/

SELECT
  event_name,
  COUNT(*) AS event_count
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY
  event_name
ORDER BY
  event_count DESC;
