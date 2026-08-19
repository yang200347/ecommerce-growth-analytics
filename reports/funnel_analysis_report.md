# Funnel Analysis Report

## Executive Summary

This analysis evaluates how product-view sessions progress through the Google Merchandise Store purchase funnel during the reliable analysis period of **2020-11-25 to 2021-01-31**.

The ordered session-level funnel contained:

- **56,696** product-view sessions
- **13,890** add-to-cart sessions
- **4,991** checkout sessions
- **2,694** purchase sessions
- **4.75%** overall view-to-purchase conversion

The largest loss occurred between product view and add-to-cart. This transition lost **42,806 sessions**, representing a **75.50% drop-off rate**. Mobile sessions slightly outperformed desktop sessions, while Google Organic generated the highest traffic and purchase volume among identifiable first-user acquisition sources.

## Scope and Method

The analysis uses the GA4 public e-commerce sample dataset and the data-quality-approved period of **2020-11-25 to 2021-01-31**.

A session is identified by the combination of:

- `user_pseudo_id`
- `ga_session_id`

The final funnel requires events to occur in this order:

> `view_item` -> `add_to_cart` -> `begin_checkout` -> `purchase`

Each stage must occur after the previous stage according to `event_timestamp`. This prevents a session from being counted as a complete funnel merely because all four event names appeared somewhere in the session.

Supporting SQL:

- [`sql/10_ordered_conversion_funnel.sql`](../sql/10_ordered_conversion_funnel.sql)
- [`sql/06_funnel_dropoff_analysis.sql`](../sql/06_funnel_dropoff_analysis.sql)
- [`sql/07_funnel_by_device.sql`](../sql/07_funnel_by_device.sql)
- [`sql/08_funnel_by_traffic_source.sql`](../sql/08_funnel_by_traffic_source.sql)

## Ordered Conversion Funnel

| Funnel step | Sessions | Conversion from previous step | Conversion from product view |
|---|---:|---:|---:|
| View Item | 56,696 | 100.00% | 100.00% |
| Add to Cart | 13,890 | 24.50% | 24.50% |
| Begin Checkout | 4,991 | 35.93% | 8.80% |
| Purchase | 2,694 | 53.98% | 4.75% |

Approximately one in four product-view sessions reached add-to-cart, and fewer than one in twenty-one completed a purchase.

## Funnel Drop-Off

| Funnel transition | Starting sessions | Continuing sessions | Dropped sessions | Drop-off rate |
|---|---:|---:|---:|---:|
| View Item -> Add to Cart | 56,696 | 13,890 | 42,806 | 75.50% |
| Add to Cart -> Begin Checkout | 13,890 | 4,991 | 8,899 | 64.07% |
| Begin Checkout -> Purchase | 4,991 | 2,694 | 2,297 | 46.02% |

The product-view-to-cart transition is the largest opportunity by both lost-session volume and drop-off rate. The data identifies where the loss occurs, but it does not establish whether the cause is product relevance, price, page design, shipping expectations, technical friction, or another factor.

## Why Event Order Matters

The initial funnel counted sessions when the required events appeared anywhere in the same session. The ordered funnel applies event-time rules to remove sessions that did not follow the intended journey.

| Funnel step | Presence-based sessions | Ordered sessions | Sessions excluded by ordering |
|---|---:|---:|---:|
| View Item | 56,696 | 56,696 | 0 |
| Add to Cart | 14,645 | 13,890 | 755 |
| Begin Checkout | 5,703 | 4,991 | 712 |
| Purchase | 2,762 | 2,694 | 68 |

The overall purchase rate decreased from **4.87%** in the presence-based funnel to **4.75%** in the ordered funnel. The ordered method is used as the official result because it better represents progression through the customer journey.

## Device Performance

| Device | View-item sessions | Add-to-cart sessions | Checkout sessions | Purchase sessions | Overall purchase rate |
|---|---:|---:|---:|---:|---:|
| Desktop | 33,083 | 8,026 | 2,863 | 1,520 | 4.59% |
| Mobile | 22,358 | 5,566 | 2,018 | 1,113 | 4.98% |
| Tablet | 1,255 | 298 | 110 | 61 | 4.86% |

Mobile sessions slightly outperformed desktop sessions across all funnel transitions and achieved the highest overall purchase rate. The difference is modest, so the results do not indicate a major mobile conversion problem.

Desktop generated the most traffic and purchases but had the lowest overall purchase rate. Its large traffic volume makes it a useful area for further investigation. Tablet results should be interpreted cautiously because the sample is much smaller.

## First-User Acquisition Performance

The source analysis uses `traffic_source.source` and `traffic_source.medium`. These fields describe the user's original acquisition source and do not necessarily represent the source of the current session.

Selected results:

| First-user source / medium | View-item sessions | Purchase sessions | Overall purchase rate |
|---|---:|---:|---:|
| google / organic | 17,442 | 711 | 4.08% |
| (direct) / (none) | 13,006 | 610 | 4.69% |
| Store-domain referral | 4,836 | 325 | 6.72% |
| (data deleted) / (data deleted) | 4,085 | 365 | 8.94% |
| google / cpc | 2,320 | 85 | 3.66% |

Google Organic generated the highest identifiable traffic and purchase volume. Direct traffic had a higher purchase rate than Google Organic, while Google CPC had a lower purchase rate during the selected period.

The deleted-source group cannot support a channel recommendation because its source is unknown. The store-domain referral appears to originate from the store's own domain and should be investigated as a potential self-referral or attribution issue rather than treated as a high-performing external channel.

Advertising cost is not available, so this analysis cannot determine return on ad spend or whether Google CPC is financially efficient.

## Recommendations

### 1. Investigate the product-view-to-cart experience

This transition accounts for the largest loss: 42,806 sessions and a 75.50% drop-off rate. Further analysis should examine product-level performance, pricing, stock availability, product-page engagement, and add-to-cart functionality before recommending a specific intervention.

### 2. Examine desktop conversion opportunities

Desktop represents the largest traffic segment but converts slightly below mobile. Product-page and checkout behavior should be compared across device categories to identify whether specific desktop journeys or product mixes explain the difference.

### 3. Protect and understand organic traffic

Google Organic produces the largest identifiable purchase volume. Product and landing-page analysis can help identify which organic journeys contribute most to conversion.

### 4. Validate acquisition tracking

The store-domain referral and deleted-source categories reduce channel interpretability. Referral exclusion, cross-domain measurement, and campaign tagging should be reviewed before making channel-budget decisions.

### 5. Add revenue and cost context

Conversion rate alone does not measure business value. The next phase should compare revenue, average order value, and revenue per session. Paid-channel decisions also require advertising cost data.

## Limitations

- The dataset is anonymized and covers a limited time period.
- The analysis is observational and does not establish causal relationships.
- The acquisition fields describe first-user source rather than current-session source.
- Advertising cost is unavailable, so paid-channel profitability cannot be measured.
- Some acquisition values are obfuscated, grouped, or deleted.
- Tablet results are based on a relatively small sample.
- Events with identical timestamps cannot be reliably ordered and are not treated as valid progression to the next stage.

## Conclusion

The ordered funnel provides a more conservative and behaviorally consistent estimate than the presence-based funnel. Overall view-to-purchase conversion was **4.75%**, with the largest loss occurring before add-to-cart. Device performance was broadly similar, with mobile slightly ahead of desktop, while Google Organic delivered the largest identifiable purchase volume.

The next analytical phase should connect funnel behavior to revenue, product performance, and order value before final growth recommendations are made.
