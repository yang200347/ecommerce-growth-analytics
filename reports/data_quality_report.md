# Data Quality Report

## Purpose

This report evaluates whether the Google Analytics 4 e-commerce sample data is reliable enough for session-level conversion funnel analysis.

The checks focus on:

- Daily availability of the four core funnel events
- Stability of `add_to_cart` tracking
- Missing user identifiers
- Missing session identifiers

The supporting SQL is available in [`sql/09_data_quality_checks.sql`](../sql/09_data_quality_checks.sql).

## Data Reviewed

The initial data quality review covered **2020-11-01 to 2021-01-31**.

The four core funnel events were:

1. `view_item`
2. `add_to_cart`
3. `begin_checkout`
4. `purchase`

## Finding 1: Incomplete Add-to-Cart Tracking

Daily event counts showed that `view_item`, `begin_checkout`, and `purchase` events continued to be recorded while `add_to_cart` events were missing or unusually low on multiple days before 2020-11-25.

Examples of the tracking instability included:

| Date | View-item events | Add-to-cart events | Observation |
|---|---:|---:|---|
| 2020-11-15 | 3,212 | 0 | No add-to-cart events recorded |
| 2020-11-16 | 4,836 | 85 | Add-to-cart events reappeared at a low level |
| 2020-11-17 | 6,077 | 535 | Large increase from the previous day |
| 2020-11-20 | 6,082 | 15 | Add-to-cart events fell sharply |
| 2020-11-21 | 4,214 | 0 | Tracking returned to zero |
| 2020-11-24 | 6,624 | 0 | Last day with zero add-to-cart events |
| 2020-11-25 | 6,700 | 297 | Start of continuous non-zero recording |

Across the full review period:

- **18 days** had zero recorded `add_to_cart` events.
- The last zero-event date was **2020-11-24**.
- The candidate reliable start date was therefore **2020-11-25**.
- The daily view-to-cart rate ranged from **0.00% to 30.31%**.

The presence of checkout and purchase events on days with no add-to-cart events suggests a tracking limitation rather than genuine customer behavior. This is an analytical inference from the event-count pattern; the public dataset does not provide a confirmed technical cause.

## Finding 2: User ID Completeness

User ID completeness was checked for the selected analysis period of **2020-11-25 to 2021-01-31**.

| Metric | Result |
|---|---:|
| Core funnel events | 363,050 |
| Events missing `user_pseudo_id` | 0 |
| Missing user ID rate | 0.00% |

All core funnel events can be linked to an anonymous user identifier.

## Finding 3: Session ID Completeness

Session ID completeness was checked over the same selected analysis period.

| Metric | Result |
|---|---:|
| Core funnel events | 363,050 |
| Events missing `ga_session_id` | 0 |
| Missing session ID rate | 0.00% |

All core funnel events can be assigned to a session using the combination of `user_pseudo_id` and `ga_session_id`.

## Analysis Decision

The official funnel analysis period is restricted to:

> **2020-11-25 to 2021-01-31**

This start date excludes the period where add-to-cart tracking was missing or unstable. Using the earlier dates could undercount add-to-cart sessions and distort both conversion and drop-off rates.

The date filter is applied consistently in:

- `sql/05_conversion_funnel.sql`
- `sql/06_funnel_dropoff_analysis.sql`
- `sql/07_funnel_by_device.sql`
- `sql/08_funnel_by_traffic_source.sql`

## Conclusion

After excluding the unreliable add-to-cart tracking period, the selected data contains complete user and session identifiers for all 363,050 core funnel events. The selected period is suitable for session-level funnel analysis, subject to the limitations of an anonymized public sample dataset.

This quality review supports descriptive and diagnostic analysis. It does not identify the technical cause of the early tracking issue and should not be interpreted as evidence of a real change in customer behavior.
