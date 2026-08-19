-- 08_funnel_by_traffic_source.sql
-- Compare ordered funnel performance by first-user acquisition source.

/*
Purpose:
Measure whether users originally acquired from different sources and mediums
move through the purchase funnel at different rates.

Important:
The GA4 traffic_source fields used here describe the user's original
acquisition source. They do not necessarily describe the source of the current
session.

Required funnel order:
view_item -> add_to_cart -> begin_checkout -> purchase
*/

WITH relevant_events AS (
  SELECT
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,
    COALESCE(traffic_source.source, '(direct)') AS first_user_source,
    COALESCE(traffic_source.medium, '(none)') AS first_user_medium,
    event_name,
    event_timestamp
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

valid_events AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    first_user_source,
    first_user_medium,
    event_name,
    event_timestamp
  FROM
    relevant_events
  WHERE
    user_pseudo_id IS NOT NULL
    AND ga_session_id IS NOT NULL
),

-- Stage 1: Find the first product view and acquisition source per session.
view_stage AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    MIN(event_timestamp) AS view_item_timestamp,
    ARRAY_AGG(
      first_user_source
      ORDER BY event_timestamp
      LIMIT 1
    )[OFFSET(0)] AS first_user_source,
    ARRAY_AGG(
      first_user_medium
      ORDER BY event_timestamp
      LIMIT 1
    )[OFFSET(0)] AS first_user_medium
  FROM
    valid_events
  WHERE
    event_name = 'view_item'
  GROUP BY
    user_pseudo_id,
    ga_session_id
),

-- Stage 2: Find the first add-to-cart event after the product view.
cart_stage AS (
  SELECT
    view_stage.user_pseudo_id,
    view_stage.ga_session_id,
    view_stage.first_user_source,
    view_stage.first_user_medium,
    view_stage.view_item_timestamp,
    MIN(valid_events.event_timestamp) AS add_to_cart_timestamp
  FROM
    view_stage
  LEFT JOIN
    valid_events
    ON view_stage.user_pseudo_id = valid_events.user_pseudo_id
    AND view_stage.ga_session_id = valid_events.ga_session_id
    AND valid_events.event_name = 'add_to_cart'
    AND valid_events.event_timestamp > view_stage.view_item_timestamp
  GROUP BY
    view_stage.user_pseudo_id,
    view_stage.ga_session_id,
    view_stage.first_user_source,
    view_stage.first_user_medium,
    view_stage.view_item_timestamp
),

-- Stage 3: Find the first checkout event after the add-to-cart event.
checkout_stage AS (
  SELECT
    cart_stage.user_pseudo_id,
    cart_stage.ga_session_id,
    cart_stage.first_user_source,
    cart_stage.first_user_medium,
    cart_stage.view_item_timestamp,
    cart_stage.add_to_cart_timestamp,
    MIN(valid_events.event_timestamp) AS begin_checkout_timestamp
  FROM
    cart_stage
  LEFT JOIN
    valid_events
    ON cart_stage.user_pseudo_id = valid_events.user_pseudo_id
    AND cart_stage.ga_session_id = valid_events.ga_session_id
    AND valid_events.event_name = 'begin_checkout'
    AND valid_events.event_timestamp > cart_stage.add_to_cart_timestamp
  GROUP BY
    cart_stage.user_pseudo_id,
    cart_stage.ga_session_id,
    cart_stage.first_user_source,
    cart_stage.first_user_medium,
    cart_stage.view_item_timestamp,
    cart_stage.add_to_cart_timestamp
),

-- Stage 4: Find the first purchase event after the checkout event.
purchase_stage AS (
  SELECT
    checkout_stage.user_pseudo_id,
    checkout_stage.ga_session_id,
    checkout_stage.first_user_source,
    checkout_stage.first_user_medium,
    checkout_stage.view_item_timestamp,
    checkout_stage.add_to_cart_timestamp,
    checkout_stage.begin_checkout_timestamp,
    MIN(valid_events.event_timestamp) AS purchase_timestamp
  FROM
    checkout_stage
  LEFT JOIN
    valid_events
    ON checkout_stage.user_pseudo_id = valid_events.user_pseudo_id
    AND checkout_stage.ga_session_id = valid_events.ga_session_id
    AND valid_events.event_name = 'purchase'
    AND valid_events.event_timestamp > checkout_stage.begin_checkout_timestamp
  GROUP BY
    checkout_stage.user_pseudo_id,
    checkout_stage.ga_session_id,
    checkout_stage.first_user_source,
    checkout_stage.first_user_medium,
    checkout_stage.view_item_timestamp,
    checkout_stage.add_to_cart_timestamp,
    checkout_stage.begin_checkout_timestamp
),

source_funnel AS (
  SELECT
    first_user_source,
    first_user_medium,
    COUNT(*) AS view_item_sessions,
    COUNTIF(add_to_cart_timestamp IS NOT NULL) AS add_to_cart_sessions,
    COUNTIF(begin_checkout_timestamp IS NOT NULL) AS begin_checkout_sessions,
    COUNTIF(purchase_timestamp IS NOT NULL) AS purchase_sessions
  FROM
    purchase_stage
  GROUP BY
    first_user_source,
    first_user_medium
)

SELECT
  first_user_source,
  first_user_medium,
  view_item_sessions,
  add_to_cart_sessions,
  begin_checkout_sessions,
  purchase_sessions,
  ROUND(
    100 * SAFE_DIVIDE(add_to_cart_sessions, view_item_sessions),
    2
  ) AS view_to_cart_rate_pct,
  ROUND(
    100 * SAFE_DIVIDE(begin_checkout_sessions, add_to_cart_sessions),
    2
  ) AS cart_to_checkout_rate_pct,
  ROUND(
    100 * SAFE_DIVIDE(purchase_sessions, begin_checkout_sessions),
    2
  ) AS checkout_to_purchase_rate_pct,
  ROUND(
    100 * SAFE_DIVIDE(purchase_sessions, view_item_sessions),
    2
  ) AS overall_purchase_rate_pct
FROM
  source_funnel
-- Exclude very small source groups whose rates may be unreliable.
WHERE
  view_item_sessions >= 100
ORDER BY
  view_item_sessions DESC
LIMIT 15;
