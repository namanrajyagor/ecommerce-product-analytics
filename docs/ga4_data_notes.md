# GA4 Data Notes — Structure, Traps and Decisions

## Dataset
- `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*` — Google Merchandise Store
- 4,295,584 events · 270,154 users · 360,129 sessions · 1 Nov 2020 – 31 Jan 2021
- One table per day (`events_YYYYMMDD`); `events_*` reads all of them; `_TABLE_SUFFIX` filters dates to reduce cost

## How the data is structured
| Field | Type | What it holds |
|---|---|---|
| `event_name` | string | 17 event types (page_view, view_item, add_to_cart, begin_checkout, add_shipping_info, add_payment_info, purchase …) |
| `user_pseudo_id` | string | Anonymous user (browser/device) ID |
| `event_params` | array of {key, value} | 33 keys, e.g. ga_session_id, ga_session_number, page_location, page_title, session_engaged, engagement_time_msec |
| `items` | array | Products attached to e-commerce events (item_name, item_category, quantity, item_revenue …) |
| `device`, `geo` | struct | Device category, OS, country … |
| `traffic_source` | struct | The user's **first-touch** acquisition source / medium |
| `ecommerce` | struct | Order-level values such as purchase_revenue and transaction_id |

**Key SQL pattern** to read one parameter:
```sql
(SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id')
```
Values sit in different type columns (string_value, int_value, float_value, double_value), so each key must be read from the right one.

## Traps found and decisions made
| Trap | Evidence | Decision |
|---|---|---|
| `ga_session_id` is not unique across users | 349,545 distinct IDs vs 360,129 true sessions (−3%) | Session = `user_pseudo_id` + `ga_session_id` |
| Not every session has a `session_start` event | 354,970 session_start events vs 360,129 sessions | Count sessions by the ID pair, not by session_start |
| Users appear under more than one first-touch medium | Medium totals = 328,574 users vs 270,154 actual | Assign each user the medium from their first event |
| Product categories are inconsistent | e.g. "Google Crewneck Sweatshirt Navy" = Uncategorized Items, Grey version = Apparel | Prefer product-level analysis; treat category results with care |
| Obfuscated values | `<Other>`, `(data deleted)`, `<obfuscated>` | Report them, but do not draw conclusions from them |
| `begin_checkout` ≈ `add_shipping_info` users | 9,715 vs 9,714 | Likely a quirk of the sample; interpret those two steps together |

## Early observations (to be confirmed in Phase 4)
- About 1.6% of users purchase (4,419 of 270,154); 5,692 purchase events → some repeat buyers
- Largest user-level leak: view_item (61,252) → add_to_cart (12,545)
- Paid search (cpc) users convert lowest (0.98%); referral highest among readable channels (1.85%)
- Mobile (1.70%) converts slightly better than desktop (1.60%) at user level — unusual, to be checked at session level
- Top product by revenue: Google Zip Hoodie F/C ($13,692); apparel dominates the top 15