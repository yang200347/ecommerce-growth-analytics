SELECT
  PARSE_DATE('%Y%m%d', event_date) AS event_date,
  TIMESTAMP_MICROS(event_timestamp) AS event_time,
  event_name,
  user_pseudo_id,

  (
    SELECT value.int_value
    FROM UNNEST(event_params)
    WHERE key = 'ga_session_id'
  ) AS ga_session_id,

  device.category AS device_category,
  geo.country AS country,
  traffic_source.source AS traffic_source,
  traffic_source.medium AS traffic_medium,
  ecommerce.purchase_revenue AS purchase_revenue,
  ARRAY_LENGTH(items) AS item_count

FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

WHERE
  _TABLE_SUFFIX = '20210131'

ORDER BY
  event_timestamp

LIMIT 20;
