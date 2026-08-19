-- 06_funnel_dropoff_analysis.sql
-- Measure session drop-off between funnel stages

WITH relevant_events AS (
  SELECT
    user_pseudo_id,
    (
      SELECT value.int_value
      FROM UNNEST(event_params)
      WHERE key = 'ga_session_id'
    ) AS ga_session_id,
    event_name
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
),

session_actions AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    COUNTIF(event_name = 'view_item') > 0 AS viewed_item,
    COUNTIF(event_name = 'add_to_cart') > 0 AS added_to_cart,
    COUNTIF(event_name = 'begin_checkout') > 0 AS began_checkout,
    COUNTIF(event_name = 'purchase') > 0 AS purchased
  FROM relevant_events
  WHERE ga_session_id IS NOT NULL
  GROUP BY
    user_pseudo_id,
    ga_session_id
),

funnel_counts AS (
  SELECT
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
),

dropoff_results AS (
  SELECT
    1 AS transition_number,
    'View Item → Add to Cart' AS funnel_transition,
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
  FROM funnel_counts

  UNION ALL

  SELECT
    2,
    'Add to Cart → Begin Checkout',
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
  FROM funnel_counts

  UNION ALL

  SELECT
    3,
    'Begin Checkout → Purchase',
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
  FROM funnel_counts
)

SELECT *
FROM dropoff_results
ORDER BY transition_number;
