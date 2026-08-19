-- 08_funnel_by_traffic_source.sql
-- Compare funnel performance across GA4 acquisition sources

WITH relevant_events AS (
  SELECT
    user_pseudo_id,

    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,

    COALESCE(
      traffic_source.source,
      '(direct)'
    ) AS acquisition_source,

    COALESCE(
      traffic_source.medium,
      '(none)'
    ) AS acquisition_medium,

    event_name

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
),

session_actions AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    acquisition_source,
    acquisition_medium,

    COUNTIF(event_name = 'view_item') > 0 AS viewed_item,
    COUNTIF(event_name = 'add_to_cart') > 0 AS added_to_cart,
    COUNTIF(event_name = 'begin_checkout') > 0 AS began_checkout,
    COUNTIF(event_name = 'purchase') > 0 AS purchased

  FROM relevant_events

  WHERE ga_session_id IS NOT NULL

  GROUP BY
    user_pseudo_id,
    ga_session_id,
    acquisition_source,
    acquisition_medium
),

source_funnel AS (
  SELECT
    acquisition_source,
    acquisition_medium,

    COUNTIF(viewed_item) AS view_item_sessions,

    COUNTIF(
      viewed_item
      AND added_to_cart
    ) AS add_to_cart_sessions,

    COUNTIF(
      viewed_item
      AND added_to_cart
      AND began_checkout
    ) AS begin_checkout_sessions,

    COUNTIF(
      viewed_item
      AND added_to_cart
      AND began_checkout
      AND purchased
    ) AS purchase_sessions

  FROM session_actions

  GROUP BY
    acquisition_source,
    acquisition_medium
)

SELECT
  acquisition_source,
  acquisition_medium,
  view_item_sessions,
  add_to_cart_sessions,
  begin_checkout_sessions,
  purchase_sessions,

  ROUND(
    100 * SAFE_DIVIDE(
      add_to_cart_sessions,
      view_item_sessions
    ),
    2
  ) AS view_to_cart_rate_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      begin_checkout_sessions,
      add_to_cart_sessions
    ),
    2
  ) AS cart_to_checkout_rate_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      purchase_sessions,
      begin_checkout_sessions
    ),
    2
  ) AS checkout_to_purchase_rate_pct,

  ROUND(
    100 * SAFE_DIVIDE(
      purchase_sessions,
      view_item_sessions
    ),
    2
  ) AS overall_purchase_rate_pct

FROM source_funnel

-- Remove very small sources whose rates may be unreliable
WHERE view_item_sessions >= 100

ORDER BY view_item_sessions DESC

LIMIT 15;
