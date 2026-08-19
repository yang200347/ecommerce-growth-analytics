-- 06_funnel_dropoff_analysis.sql
-- Measure session drop-off between ordered funnel stages.

/*
Purpose:
Count a session at each funnel stage only when the event happened after the
previous stage, then calculate the number and percentage of sessions lost
between stages.

Required order:
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
    event_name,
    event_timestamp
  FROM
    relevant_events
  WHERE
    user_pseudo_id IS NOT NULL
    AND ga_session_id IS NOT NULL
),

-- Stage 1: Find the first product view in each session.
view_stage AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    MIN(event_timestamp) AS view_item_timestamp
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
    view_stage.view_item_timestamp
),

-- Stage 3: Find the first checkout event after the add-to-cart event.
checkout_stage AS (
  SELECT
    cart_stage.user_pseudo_id,
    cart_stage.ga_session_id,
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
    cart_stage.view_item_timestamp,
    cart_stage.add_to_cart_timestamp
),

-- Stage 4: Find the first purchase event after the checkout event.
purchase_stage AS (
  SELECT
    checkout_stage.user_pseudo_id,
    checkout_stage.ga_session_id,
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
    checkout_stage.view_item_timestamp,
    checkout_stage.add_to_cart_timestamp,
    checkout_stage.begin_checkout_timestamp
),

funnel_counts AS (
  SELECT
    COUNT(*) AS view_item_sessions,
    COUNTIF(add_to_cart_timestamp IS NOT NULL) AS add_to_cart_sessions,
    COUNTIF(begin_checkout_timestamp IS NOT NULL) AS begin_checkout_sessions,
    COUNTIF(purchase_timestamp IS NOT NULL) AS purchase_sessions
  FROM
    purchase_stage
),

dropoff_results AS (
  SELECT
    1 AS transition_number,
    'View Item -> Add to Cart' AS funnel_transition,
    view_item_sessions AS starting_sessions,
    add_to_cart_sessions AS continuing_sessions,
    view_item_sessions - add_to_cart_sessions AS dropped_sessions,
    ROUND(
      100 * SAFE_DIVIDE(
        view_item_sessions - add_to_cart_sessions,
        view_item_sessions
      ),
      2
    ) AS dropoff_rate_pct
  FROM
    funnel_counts

  UNION ALL

  SELECT
    2,
    'Add to Cart -> Begin Checkout',
    add_to_cart_sessions,
    begin_checkout_sessions,
    add_to_cart_sessions - begin_checkout_sessions,
    ROUND(
      100 * SAFE_DIVIDE(
        add_to_cart_sessions - begin_checkout_sessions,
        add_to_cart_sessions
      ),
      2
    )
  FROM
    funnel_counts

  UNION ALL

  SELECT
    3,
    'Begin Checkout -> Purchase',
    begin_checkout_sessions,
    purchase_sessions,
    begin_checkout_sessions - purchase_sessions,
    ROUND(
      100 * SAFE_DIVIDE(
        begin_checkout_sessions - purchase_sessions,
        begin_checkout_sessions
      ),
      2
    )
  FROM
    funnel_counts
)

SELECT
  *
FROM
  dropoff_results
ORDER BY
  transition_number;
