# Data Dictionary

## Dataset Overview

This project uses the Google Analytics 4 public e-commerce sample dataset from the Google Merchandise Store.

The raw dataset is event-level data, meaning that each row represents one user event rather than one customer, session, or transaction.

## Analysis Levels

| Level | Definition |
|---|---|
| User | An anonymous website visitor identified by `user_pseudo_id` |
| Session | A website visit identified by the combination of `user_pseudo_id` and `ga_session_id` |
| Event | A recorded user action, such as viewing a product or completing a purchase |
| Item | A product associated with an e-commerce event |

## Core Fields

| Field | Level | Description | Analytical Use |
|---|---|---|---|
| `event_date` | Event | Date on which the event occurred | Daily and monthly trend analysis |
| `event_timestamp` | Event | Exact event time stored in microseconds | Event sequencing and user journey analysis |
| `event_name` | Event | Name of the recorded user action | Funnel and behavioral analysis |
| `user_pseudo_id` | User | Anonymous identifier assigned to a user | Unique user counts and user-level analysis |
| `ga_session_id` | Session | Session identifier stored inside `event_params` | Session counts and session-level analysis |
| `event_params` | Event | Nested parameters containing additional event information | Extracting session and engagement attributes |
| `device.category` | Event | Device category such as desktop, mobile, or tablet | Device performance comparison |
| `geo.country` | Event | Country associated with the event | Geographic analysis |
| `traffic_source.source` | User | Original acquisition source associated with the user | Acquisition source analysis |
| `traffic_source.medium` | User | Original acquisition medium associated with the user | Marketing channel analysis |
| `ecommerce.purchase_revenue` | Event | Revenue recorded for a purchase event | Revenue and order value analysis |
| `items` | Item | Repeated product records associated with an event | Product performance analysis |
| `items.item_id` | Item | Product identifier | Product-level grouping |
| `items.item_name` | Item | Product name | Product reporting |
| `_TABLE_SUFFIX` | Table | Date suffix of the daily GA4 event table | Limiting queries to selected dates |

## Key Event Names

| Event Name | Funnel Stage | Description |
|---|---|---|
| `session_start` | Visit | A new website session begins |
| `page_view` | Visit | A webpage is viewed |
| `view_item` | Product consideration | A product detail page is viewed |
| `add_to_cart` | Purchase intent | A product is added to the shopping cart |
| `begin_checkout` | Checkout | The checkout process begins |
| `add_shipping_info` | Checkout | Shipping information is submitted |
| `add_payment_info` | Checkout | Payment information is submitted |
| `purchase` | Conversion | A transaction is completed |

## Important Measurement Rules

1. Event counts are not equivalent to unique user counts.
2. One user can have multiple sessions.
3. One session can contain multiple events of the same type.
4. A unique session should be identified using both `user_pseudo_id` and `ga_session_id`.
5. Funnel conversion rates should be calculated using unique users or unique sessions, not raw event counts.
6. Null revenue values are expected for non-purchase events.
7. Events with identical timestamps do not always have a reliable internal order.

## Dataset Limitations

- The dataset is anonymized and obfuscated.
- It covers a limited three-month period.
- Some fields contain null or placeholder values.
- The dataset should not be used to make causal claims.
- Long-term customer lifetime value cannot be reliably estimated from the available period.
