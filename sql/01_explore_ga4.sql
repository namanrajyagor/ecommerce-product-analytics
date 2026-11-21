-- ============================================================
-- 01_explore_ga4.sql
-- Phase 2: Understanding the GA4 Google Merchandise Store data
-- ============================================================

-- 2.1 Which event types exist, how often, and for how many users?
--     One row in GA4 = one event (page view, add to cart, purchase ...)
SELECT
  event_name,
  COUNT(*)                       AS events,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY event_name
ORDER BY events DESC;


-- 2.2 What is inside event_params? (one day only, to keep the query cheap)
--     event_params is a list of {key, value}; UNNEST turns each item into its own row.
--     value has 4 possible types: string_value, int_value, float_value, double_value
SELECT
  ep.key,
  COUNT(*)                          AS times_present,
  ANY_VALUE(ep.value.string_value)  AS example_string_value,
  ANY_VALUE(ep.value.int_value)     AS example_int_value
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
     UNNEST(event_params) AS ep
WHERE _TABLE_SUFFIX = '20201201'
GROUP BY ep.key
ORDER BY times_present DESC;


-- 2.3 What is inside items? Top 15 products by purchase revenue
--     items is a list of products attached to e-commerce events (view_item, add_to_cart, purchase ...)
SELECT
  item.item_name,
  item.item_category,
  COUNT(DISTINCT event_timestamp) AS purchase_events,
  SUM(item.quantity)              AS units_sold,
  ROUND(SUM(item.item_revenue), 2) AS item_revenue_usd
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
     UNNEST(items) AS item
WHERE event_name = 'purchase'
GROUP BY item.item_name, item.item_category
ORDER BY item_revenue_usd DESC
LIMIT 15;


-- 2.4 Counting sessions correctly
--     Pattern to extract one parameter: (SELECT value.X FROM UNNEST(event_params) WHERE key = '...')
--     A session = user_pseudo_id + ga_session_id (ga_session_id alone is NOT unique across users)
WITH events AS (
  SELECT
    user_pseudo_id,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
)
SELECT
  COUNT(DISTINCT ga_session_id)                                            AS session_ids_alone_WRONG,
  COUNT(DISTINCT CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING))) AS true_sessions,
  COUNTIF(ga_session_id IS NULL)                                           AS events_without_session_id
FROM events;


-- 2.5 Device and first-touch channel: users, purchasers and conversion
--     device / geo / traffic_source are structs (read with a dot)
--     traffic_source = the channel that FIRST acquired the user (does not change per session)
WITH base AS (
  SELECT
    user_pseudo_id,
    event_name,
    device.category       AS device_category,
    traffic_source.medium AS first_touch_medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),
by_dim AS (
  SELECT 'Device' AS dimension, device_category AS value,
         COUNT(DISTINCT user_pseudo_id) AS users,
         COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)) AS purchasers
  FROM base GROUP BY device_category
  UNION ALL
  SELECT 'First-touch medium', first_touch_medium,
         COUNT(DISTINCT user_pseudo_id),
         COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL))
  FROM base GROUP BY first_touch_medium
)
SELECT
  dimension,
  value,
  users,
  purchasers,
  ROUND(100 * purchasers / users, 2) AS user_conversion_pct
FROM by_dim
ORDER BY dimension, users DESC;