# Data Model — BigQuery (`ecommerce-analytics-513805.ga4_analytics`)

A layered model built from Google's public GA4 sample, so analysis queries are short, fast and consistent.
All tables are rebuilt by running `sql/02_build_tables.sql` top to bottom.

```
bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*   (raw, nested, 4.3M rows)
        │  UNNEST event_params, read structs, build session_key
        ▼
events_clean   (1 row per event — 4,295,584 rows, clustered by event_name)
        │  purchase events, de-duplicated by transaction_id
        ▼
orders         (1 row per order — 5,357 rows)
        │  GROUP BY session_key  (+ orders and revenue joined from orders)
        ▼
sessions       (1 row per visit — 360,129 rows)
        │  GROUP BY user_pseudo_id
        ▼
users          (1 row per user — 270,154 rows)
```

## Tables

### events_clean — one row per event
| Column | Description |
|---|---|
| event_date, event_ts | Date and timestamp of the event |
| event_name | page_view, view_item, add_to_cart, begin_checkout, add_shipping_info, add_payment_info, purchase … |
| user_pseudo_id | Anonymous user ID |
| ga_session_id, ga_session_number | Session ID (unique only within a user) and visit number |
| session_key | **user_pseudo_id + ga_session_id** — the true session ID |
| page_location, page_title | Page viewed |
| session_engaged, engagement_time_msec | Engagement signals |
| device_category, operating_system, country | Device and location |
| first_touch_medium, first_touch_source | User's acquisition channel (GA4 `traffic_source`) |
| transaction_id, purchase_revenue_usd, items_in_order | Order fields (purchase events) |

### orders — one row per order (duplicates removed)
| Column | Description |
|---|---|
| order_id | transaction_id, or a generated `no_id_…` key when the ID is missing |
| order_ts, order_date | When the order was placed (first purchase event) |
| session_key, user_pseudo_id | Visit and user who placed it |
| revenue_usd, items_in_order | Order value and quantity |
| has_transaction_id | 1 = had a real transaction ID; 0 = missing ID (kept, but flagged) |
| purchase_events | How many purchase events were recorded for this order (>1 = duplicates) |

### sessions — one row per visit
| Column | Description |
|---|---|
| session_key, user_pseudo_id | Keys |
| session_start_ts, session_date | Start of the visit |
| session_number, is_first_session | Visit number; 1 = user's first visit |
| device_category, country | From the visit's first event |
| landing_page_title | First page viewed in the visit |
| is_engaged, page_views, engagement_time_sec | Engagement |
| viewed_item, added_to_cart, began_checkout, added_shipping, added_payment | **Funnel flags (0/1)** from events |
| purchased, orders, revenue_usd | From the **de-duplicated orders** table |

### users — one row per user
| Column | Description |
|---|---|
| user_pseudo_id | Key |
| first_seen_date, first_seen_week | First visit (week starts Monday) — used for cohorts |
| last_seen_date | Last visit |
| first_touch_medium, first_touch_source | Channel from the user's **first event** (one per user) |
| first_device, first_country | From the first session |
| sessions, active_days | Activity |
| is_purchaser, orders, purchase_sessions, revenue_usd, first_purchase_date | Purchasing |

## Design decisions
| Decision | Reason |
|---|---|
| Extract nested fields once in `events_clean` | Later queries need no UNNEST → simpler and cheaper |
| `session_key` = user_pseudo_id + ga_session_id | ga_session_id alone undercounts sessions by ~3% |
| **Separate `orders` table, de-duplicated by transaction_id** | 335 duplicate purchase events (326 IDs) inflated orders and revenue by 6.3% |
| Orders without a transaction_id kept but flagged | 906 orders ($31,817) cannot be de-duplicated; dropping them would understate revenue |
| Orders and revenue in sessions/users come from `orders` | Fix the problem once at the source; every downstream query is correct |
| Device, country and landing page from the first event of a visit | One stable value per session |
| One first-touch medium per user (from first event) | The sample has users under several mediums; medium totals exceeded user totals |
| Funnel steps as 0/1 flags | Funnel = simple SUMs; easy to use in Looker Studio |
| `CLUSTER BY event_name`, no date partitioning | Clustering cuts scanned data; sandbox deletes partitions older than 60 days, which would remove 2020 data |
| Dataset location US | Must match the location of the public GA4 data |
| All SQL saved in one rebuild script | Sandbox tables expire after 60 days |

## Data-quality check: purchase events
| Check | Value |
|---|---|
| Purchase events | 5,692 |
| Events without a transaction ID | 906 |
| Distinct transaction IDs | 4,451 |
| IDs recorded more than once | 326 (335 duplicate events) |
| Orders recorded with $0 revenue | 450 |
| **Orders after de-duplication** | **5,357** (4,907 paid) |
| Revenue before → after | $362,165 → **$339,457** (−$22,708, −6.3%) |
| Purchasers before → after | 4,419 → **4,408** (11 users' only purchase was a copy of another user's transaction ID) |

## Validation (all reconcile)
| Metric | Raw | events_clean | orders | sessions | users |
|---|---|---|---|---|---|
| Events | 4,295,584 | 4,295,584 | — | — | — |
| Users | 270,154 | 270,154 | — | 270,154 | 270,154 |
| Sessions | 360,129 | 360,129 | — | 360,129 | 360,129 |
| Orders | — | — | 5,357 | 5,357 | 5,357 |
| Revenue (USD) | — | — | 339,457 | 339,457 | 339,457 |
| Purchasers | — | — | 4,408 | — | 4,408 |

Query cost after modelling: a user-level check scans ~18 MB instead of 125 MB+ on raw data.

## Notes
- Engaged-session rate is 88.9% (high vs typical 55–70%) → use for comparisons, not as an absolute benchmark