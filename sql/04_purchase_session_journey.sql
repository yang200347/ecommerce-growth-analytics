WITH event_data AS (
  SELECT
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
    ecommerce.purchase_revenue AS purchase_revenue,
    items

  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`

  WHERE
    _TABLE_SUFFIX = '20210131'
),

selected_session AS (
  SELECT
    user_pseudo_id,
    ga_session_id
  FROM
    event_data
  WHERE
    ga_session_id IS NOT NULL
  GROUP BY
    user_pseudo_id,
    ga_session_id
  HAVING
    COUNTIF(event_name = 'purchase') > 0
  ORDER BY
    COUNT(*) DESC
  LIMIT 1
)

SELECT
  event_name,
  COUNT(*) AS event_count,
  MIN(event_time) AS first_event_time,
  MAX(event_time) AS last_event_time,
  MAX(purchase_revenue) AS purchase_revenue
FROM
  event_data
INNER JOIN
  selected_session
USING
  (user_pseudo_id, ga_session_id)
WHERE
  event_name IN (
    'session_start',
    'view_item',
    'add_to_cart',
    'begin_checkout',
    'add_shipping_info',
    'add_payment_info',
    'purchase'
  )
GROUP BY
  event_name
ORDER BY
  first_event_time;
