-- ============================================================
-- 02_build_tables.sql
-- Phase 3: Layered data model in BigQuery
--   raw GA4 events → events_clean → sessions → users
-- Project: ecommerce-analytics-513805 | Dataset: ga4_analytics
-- Re-run this file top to bottom to rebuild every table
-- (sandbox tables expire after 60 days)
-- ============================================================

-- 3.1 Create the dataset (in the US, the same location as the public GA4 data)
CREATE SCHEMA IF NOT EXISTS `ecommerce-analytics-513805.ga4_analytics`
OPTIONS (location = 'US');


-- 3.2 events_clean: one row per event, key fields extracted (no more UNNEST later)
CREATE OR REPLACE TABLE `ecommerce-analytics-513805.ga4_analytics.events_clean`
CLUSTER BY event_name AS
WITH base AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date)   AS event_date,
    TIMESTAMP_MICROS(event_timestamp)  AS event_ts,
    event_name,
    user_pseudo_id,
    (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'ga_session_id')        AS ga_session_id,
    (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'ga_session_number')    AS ga_session_number,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_location')        AS page_location,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'page_title')           AS page_title,
    (SELECT COALESCE(value.string_value, CAST(value.int_value AS STRING))
       FROM UNNEST(event_params) WHERE key = 'session_engaged')                              AS session_engaged,
    (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_time_msec,
    device.category                    AS device_category,
    device.operating_system            AS operating_system,
    geo.country                        AS country,
    traffic_source.medium              AS first_touch_medium,
    traffic_source.source              AS first_touch_source,
    ecommerce.transaction_id           AS transaction_id,
    ecommerce.purchase_revenue_in_usd  AS purchase_revenue_usd,
    ecommerce.total_item_quantity      AS items_in_order
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
)
SELECT
  *,
  CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)) AS session_key
FROM base;

-- 3.2 check: rows, users, sessions and revenue in events_clean
SELECT
  COUNT(*)                                             AS events,
  COUNT(DISTINCT user_pseudo_id)                       AS users,
  COUNT(DISTINCT session_key)                          AS sessions,
  COUNTIF(event_name = 'purchase')                     AS purchase_events,
  ROUND(SUM(IF(event_name = 'purchase', purchase_revenue_usd, 0)), 2) AS purchase_revenue_usd
FROM `ecommerce-analytics-513805.ga4_analytics.events_clean`;
-- 3.2b orders: one row per order, with duplicate purchase events removed
--   orders WITH a transaction_id    -> one row per ID (first event kept)
--   orders WITHOUT a transaction_id -> kept individually, flagged has_transaction_id = 0
CREATE OR REPLACE TABLE `ecommerce-analytics-513805.ga4_analytics.orders` AS
WITH p AS (
  SELECT event_ts, session_key, user_pseudo_id, transaction_id,
         IFNULL(purchase_revenue_usd, 0) AS revenue_usd, items_in_order
  FROM `ecommerce-analytics-513805.ga4_analytics.events_clean`
  WHERE event_name = 'purchase'
),
with_id AS (
  SELECT
    transaction_id AS order_id,
    ARRAY_AGG(STRUCT(event_ts, session_key, user_pseudo_id, revenue_usd, items_in_order)
              ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS o,
    COUNT(*) AS purchase_events
  FROM p
  WHERE transaction_id IS NOT NULL AND transaction_id != '(not set)'
  GROUP BY transaction_id
)
SELECT o.event_ts AS order_ts, DATE(o.event_ts) AS order_date, order_id,
       o.session_key, o.user_pseudo_id, o.revenue_usd, o.items_in_order,
       1 AS has_transaction_id, purchase_events
FROM with_id
UNION ALL
SELECT event_ts, DATE(event_ts),
       CONCAT('no_id_', session_key, '_', CAST(UNIX_MICROS(event_ts) AS STRING)),
       session_key, user_pseudo_id, revenue_usd, items_in_order,
       0, 1
FROM p
WHERE transaction_id IS NULL OR transaction_id = '(not set)';
-- 3.2b check: orders after de-duplication
SELECT
  COUNT(*)                                      AS orders,
  COUNTIF(has_transaction_id = 1)               AS orders_with_id,
  COUNTIF(has_transaction_id = 0)               AS orders_without_id,
  SUM(purchase_events)                          AS purchase_events_covered,
  COUNTIF(revenue_usd > 0)                      AS paid_orders,
  ROUND(SUM(revenue_usd), 2)                    AS revenue_usd,
  ROUND(SUM(IF(has_transaction_id = 0, revenue_usd, 0)), 2) AS revenue_without_id,
  COUNT(DISTINCT user_pseudo_id)                AS purchasers
FROM `ecommerce-analytics-513805.ga4_analytics.orders`;


-- 3.3 sessions: one row per visit; orders and revenue come from the de-duplicated orders table
CREATE OR REPLACE TABLE `ecommerce-analytics-513805.ga4_analytics.sessions` AS
WITH s AS (
  SELECT
    session_key,
    user_pseudo_id,
    MIN(event_ts)                                   AS session_start_ts,
    DATE(MIN(event_ts))                             AS session_date,
    MAX(ga_session_number)                          AS session_number,
    IF(MAX(ga_session_number) = 1, 1, 0)            AS is_first_session,
    ARRAY_AGG(device_category ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS device_category,
    ARRAY_AGG(country         ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS country,
    ARRAY_AGG(IF(event_name = 'page_view', page_title, NULL) IGNORE NULLS
              ORDER BY event_ts LIMIT 1)[SAFE_OFFSET(0)]            AS landing_page_title,
    MAX(IF(session_engaged = '1', 1, 0))            AS is_engaged,
    COUNTIF(event_name = 'page_view')               AS page_views,
    ROUND(SUM(IFNULL(engagement_time_msec, 0)) / 1000, 1) AS engagement_time_sec,
    MAX(IF(event_name = 'view_item',         1, 0)) AS viewed_item,
    MAX(IF(event_name = 'add_to_cart',       1, 0)) AS added_to_cart,
    MAX(IF(event_name = 'begin_checkout',    1, 0)) AS began_checkout,
    MAX(IF(event_name = 'add_shipping_info', 1, 0)) AS added_shipping,
    MAX(IF(event_name = 'add_payment_info',  1, 0)) AS added_payment
  FROM `ecommerce-analytics-513805.ga4_analytics.events_clean`
  GROUP BY session_key, user_pseudo_id
),
o AS (
  SELECT session_key, COUNT(*) AS orders, SUM(revenue_usd) AS revenue_usd
  FROM `ecommerce-analytics-513805.ga4_analytics.orders`
  GROUP BY session_key
)
SELECT
  s.*,
  IF(o.orders IS NULL, 0, 1)            AS purchased,
  IFNULL(o.orders, 0)                   AS orders,
  ROUND(IFNULL(o.revenue_usd, 0), 2)    AS revenue_usd
FROM s
LEFT JOIN o USING (session_key);
-- 3.3 check: must match the orders table
SELECT
  COUNT(*)                         AS sessions,
  COUNT(DISTINCT session_key)      AS distinct_session_keys,
  COUNT(DISTINCT user_pseudo_id)   AS users,
  SUM(orders)                      AS orders,
  ROUND(SUM(revenue_usd), 2)       AS revenue_usd,
  SUM(viewed_item)                 AS sessions_viewed_item,
  SUM(added_to_cart)               AS sessions_added_to_cart,
  SUM(purchased)                   AS sessions_with_purchase,
  ROUND(100 * AVG(is_engaged), 2)  AS engaged_session_rate_pct
FROM `ecommerce-analytics-513805.ga4_analytics.sessions`;

-- 3.4 users: one row per user
CREATE OR REPLACE TABLE `ecommerce-analytics-513805.ga4_analytics.users` AS
WITH first_touch AS (
  SELECT
    user_pseudo_id,
    ARRAY_AGG(first_touch_medium ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS first_touch_medium,
    ARRAY_AGG(first_touch_source ORDER BY event_ts LIMIT 1)[OFFSET(0)] AS first_touch_source
  FROM `ecommerce-analytics-513805.ga4_analytics.events_clean`
  GROUP BY user_pseudo_id
),
user_sessions AS (
  SELECT
    user_pseudo_id,
    MIN(session_start_ts)                                AS first_seen_ts,
    MAX(session_date)                                    AS last_seen_date,
    ARRAY_AGG(device_category ORDER BY session_start_ts LIMIT 1)[OFFSET(0)] AS first_device,
    ARRAY_AGG(country         ORDER BY session_start_ts LIMIT 1)[OFFSET(0)] AS first_country,
    COUNT(*)                                             AS sessions,
    COUNT(DISTINCT session_date)                         AS active_days,
    MAX(purchased)                                       AS is_purchaser,
    SUM(orders)                                          AS orders,
    SUM(purchased)                                       AS purchase_sessions,
    ROUND(SUM(revenue_usd), 2)                           AS revenue_usd,
    MIN(IF(purchased = 1, session_date, NULL))           AS first_purchase_date
  FROM `ecommerce-analytics-513805.ga4_analytics.sessions`
  GROUP BY user_pseudo_id
)
SELECT
  s.user_pseudo_id,
  DATE(s.first_seen_ts)                                  AS first_seen_date,
  DATE_TRUNC(DATE(s.first_seen_ts), WEEK(MONDAY))        AS first_seen_week,
  s.last_seen_date,
  f.first_touch_medium,
  f.first_touch_source,
  s.first_device,
  s.first_country,
  s.sessions,
  s.active_days,
  s.is_purchaser,
  s.orders,
  s.purchase_sessions,
  s.revenue_usd,
  s.first_purchase_date
FROM user_sessions s
JOIN first_touch f USING (user_pseudo_id);
-- 3.4 check: must match the sessions and orders tables
SELECT
  COUNT(*)                           AS users,
  COUNT(DISTINCT user_pseudo_id)     AS distinct_users,
  SUM(sessions)                      AS sessions,
  SUM(is_purchaser)                  AS purchasers,
  SUM(orders)                        AS orders,
  ROUND(SUM(revenue_usd), 2)         AS revenue_usd,
  COUNT(DISTINCT first_touch_medium) AS mediums
FROM `ecommerce-analytics-513805.ga4_analytics.users`;

-- 3.5 products: one row per product (from the nested items array)
--     purchases de-duplicated by transaction_id, like the orders table
CREATE OR REPLACE TABLE `ecommerce-analytics-513805.ga4_analytics.products` AS
WITH ev AS (
  SELECT
    event_name,
    event_timestamp,
    user_pseudo_id,
    ecommerce.transaction_id   AS transaction_id,
    it.item_name,
    it.item_category,
    it.quantity,
    it.item_revenue_in_usd     AS item_revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
       UNNEST(items) AS it
  WHERE event_name IN ('view_item', 'add_to_cart', 'purchase')
),
purchases AS (
  SELECT * EXCEPT (rn)
  FROM (
    SELECT *,
      ROW_NUMBER() OVER (
        PARTITION BY
          IF(transaction_id IS NULL OR transaction_id = '(not set)',
             CONCAT(user_pseudo_id, '-', CAST(event_timestamp AS STRING)),
             transaction_id),
          item_name
        ORDER BY event_timestamp
      ) AS rn
    FROM ev
    WHERE event_name = 'purchase'
  )
  WHERE rn = 1
),
views AS (
  SELECT item_name, ANY_VALUE(item_category) AS item_category,
         COUNT(DISTINCT user_pseudo_id) AS viewers
  FROM ev WHERE event_name = 'view_item' GROUP BY item_name
),
carts AS (
  SELECT item_name, COUNT(DISTINCT user_pseudo_id) AS cart_adders
  FROM ev WHERE event_name = 'add_to_cart' GROUP BY item_name
),
buys AS (
  SELECT item_name,
         COUNT(DISTINCT user_pseudo_id) AS buyers,
         SUM(quantity)                  AS units_sold,
         SUM(item_revenue_usd)          AS revenue_usd
  FROM purchases GROUP BY item_name
)
SELECT
  v.item_name,
  v.item_category,
  v.viewers,
  IFNULL(c.cart_adders, 0)          AS cart_adders,
  IFNULL(b.buyers, 0)               AS buyers,
  IFNULL(b.units_sold, 0)           AS units_sold,
  ROUND(IFNULL(b.revenue_usd, 0), 2) AS revenue_usd
FROM views v
LEFT JOIN carts c USING (item_name)
LEFT JOIN buys  b USING (item_name);
-- 3.5 check: products table totals
SELECT
  COUNT(*)                        AS products,
  SUM(viewers)                    AS product_viewers_total,
  SUM(buyers)                     AS product_buyers_total,
  SUM(units_sold)                 AS units_sold,
  ROUND(SUM(revenue_usd), 2)      AS item_revenue_usd,
  COUNTIF(viewers >= 1000)        AS products_with_1000_plus_viewers
FROM `ecommerce-analytics-513805.ga4_analytics.products`;

