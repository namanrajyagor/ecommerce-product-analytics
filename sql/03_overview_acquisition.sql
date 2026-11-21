-- ============================================================
-- 03_overview_acquisition.sql
-- Phase 4: Data-quality check, KPIs, weekly trend, channels, devices, countries
-- Dataset: ecommerce-analytics-513805.ga4_analytics
-- ============================================================

-- 4.1 Data-quality check: are there duplicate or unidentified purchase events?
WITH p AS (
  SELECT session_key, transaction_id, purchase_revenue_usd
  FROM `ecommerce-analytics-513805.ga4_analytics.events_clean`
  WHERE event_name = 'purchase'
),
tx AS (
  SELECT transaction_id, COUNT(*) AS events, SUM(purchase_revenue_usd) AS revenue
  FROM p
  WHERE transaction_id IS NOT NULL AND transaction_id != '(not set)'
  GROUP BY transaction_id
)
SELECT
  (SELECT COUNT(*) FROM p)                                                          AS purchase_events,
  (SELECT COUNTIF(transaction_id IS NULL OR transaction_id = '(not set)') FROM p)    AS events_without_transaction_id,
  (SELECT COUNTIF(purchase_revenue_usd IS NULL OR purchase_revenue_usd = 0) FROM p)  AS events_with_zero_revenue,
  (SELECT COUNT(*) FROM tx)                                                         AS distinct_transactions,
  (SELECT COUNTIF(events > 1) FROM tx)                                              AS transaction_ids_repeated,
  (SELECT IFNULL(SUM(events - 1), 0) FROM tx WHERE events > 1)                      AS duplicate_events,
  (SELECT ROUND(SUM(revenue), 2) FROM tx)                                           AS revenue_on_identified_transactions;

  -- 4.2 Store KPIs (Q1) incl. the North Star metric and its breakdown
--     Revenue per user = purchase conversion x average order value x orders per purchaser
WITH s AS (
  SELECT
    COUNT(DISTINCT user_pseudo_id)  AS users,
    COUNT(*)                        AS sessions,
    SUM(purchased)                  AS purchase_sessions,
    AVG(is_engaged)                 AS engaged_rate
  FROM `ecommerce-analytics-513805.ga4_analytics.sessions`
),
o AS (
  SELECT
    COUNT(*)                        AS orders,
    COUNTIF(revenue_usd > 0)        AS paid_orders,
    COUNT(DISTINCT user_pseudo_id)  AS purchasers,
    SUM(revenue_usd)                AS revenue
  FROM `ecommerce-analytics-513805.ga4_analytics.orders`
)
SELECT
  users,
  sessions,
  purchasers,
  orders,
  paid_orders,
  ROUND(revenue, 2)                          AS revenue_usd,
  ROUND(100 * purchasers / users, 2)         AS user_conversion_pct,
  ROUND(100 * purchase_sessions / sessions, 2) AS session_conversion_pct,
  ROUND(revenue / orders, 2)                 AS avg_order_value_usd,
  ROUND(revenue / paid_orders, 2)            AS avg_paid_order_value_usd,
  ROUND(orders / purchasers, 2)              AS orders_per_purchaser,
  ROUND(revenue / users, 2)                  AS revenue_per_user_usd,
  ROUND(100 * engaged_rate, 2)               AS engaged_session_rate_pct
FROM s CROSS JOIN o;

-- 4.3 Weekly trend (Q1): holiday season, week-on-week change with LAG()
--     Weeks start on Monday; the first week (26 Oct) contains only 1 day of data (1 Nov)
--     Aggregate by week first (CTE), then apply LAG() on the weekly rows
WITH weekly AS (
  SELECT
    DATE_TRUNC(session_date, WEEK(MONDAY))  AS week_start,
    COUNT(DISTINCT session_date)            AS days_in_data,
    COUNT(DISTINCT user_pseudo_id)          AS users,
    COUNT(*)                                AS sessions,
    SUM(purchased)                          AS purchase_sessions,
    SUM(orders)                             AS orders,
    SUM(revenue_usd)                        AS revenue
  FROM `ecommerce-analytics-513805.ga4_analytics.sessions`
  GROUP BY week_start
)
SELECT
  week_start,
  days_in_data,
  users,
  sessions,
  orders,
  ROUND(revenue, 0)                                    AS revenue_usd,
  ROUND(100 * purchase_sessions / sessions, 2)         AS session_conversion_pct,
  ROUND(SAFE_DIVIDE(revenue, orders), 2)               AS avg_order_value_usd,
  ROUND(revenue / users, 2)                            AS revenue_per_user_usd,
  ROUND(100 * (SAFE_DIVIDE(revenue, LAG(revenue) OVER (ORDER BY week_start)) - 1), 1)
                                                       AS revenue_wow_change_pct
FROM weekly
ORDER BY week_start;

-- 4.3b Data-quality check: are $0 orders concentrated in certain weeks?
SELECT
  DATE_TRUNC(order_date, WEEK(MONDAY))                    AS week_start,
  COUNT(*)                                                AS orders,
  COUNTIF(revenue_usd = 0)                                AS zero_revenue_orders,
  ROUND(100 * COUNTIF(revenue_usd = 0) / COUNT(*), 1)     AS zero_revenue_pct,
  ROUND(AVG(IF(revenue_usd > 0, revenue_usd, NULL)), 2)   AS avg_paid_order_value_usd
FROM `ecommerce-analytics-513805.ga4_analytics.orders`
GROUP BY week_start
ORDER BY week_start;

-- 4.4 Channels (Q2): which first-touch channels bring buyers and revenue, not just visitors?
--     Share of users vs share of revenue shows which channels over- or under-deliver
SELECT
  first_touch_medium                                              AS medium,
  COUNT(*)                                                        AS users,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                AS share_of_users_pct,
  SUM(is_purchaser)                                               AS purchasers,
  ROUND(100 * SUM(is_purchaser) / COUNT(*), 2)                    AS user_conversion_pct,
  SUM(orders)                                                     AS orders,
  ROUND(SUM(revenue_usd), 0)                                      AS revenue_usd,
  ROUND(100 * SUM(revenue_usd) / SUM(SUM(revenue_usd)) OVER (), 1) AS share_of_revenue_pct,
  ROUND(SUM(revenue_usd) / COUNT(*), 2)                           AS revenue_per_user_usd,
  ROUND(SAFE_DIVIDE(SUM(revenue_usd), SUM(orders)), 2)            AS avg_order_value_usd
FROM `ecommerce-analytics-513805.ga4_analytics.users`
GROUP BY medium
ORDER BY users DESC;

-- 4.5a Devices (Q3): session-level engagement, add-to-cart, conversion and value
SELECT
  device_category,
  COUNT(*)                                                         AS sessions,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                 AS share_of_sessions_pct,
  ROUND(100 * AVG(is_engaged), 2)                                  AS engaged_rate_pct,
  ROUND(100 * AVG(added_to_cart), 2)                               AS add_to_cart_rate_pct,
  ROUND(100 * AVG(purchased), 2)                                   AS session_conversion_pct,
  SUM(orders)                                                      AS orders,
  ROUND(SUM(revenue_usd), 0)                                       AS revenue_usd,
  ROUND(100 * SUM(revenue_usd) / SUM(SUM(revenue_usd)) OVER (), 1) AS share_of_revenue_pct,
  ROUND(SAFE_DIVIDE(SUM(revenue_usd), SUM(orders)), 2)             AS avg_order_value_usd,
  ROUND(SUM(revenue_usd) / COUNT(*), 2)                            AS revenue_per_session_usd
FROM `ecommerce-analytics-513805.ga4_analytics.sessions`
GROUP BY device_category
ORDER BY sessions DESC;
-- 4.5b Countries (Q3): top 10 countries by users; shares are of the whole store
SELECT
  first_country                                                    AS country,
  COUNT(*)                                                         AS users,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                 AS share_of_users_pct,
  ROUND(100 * SUM(is_purchaser) / COUNT(*), 2)                     AS user_conversion_pct,
  ROUND(SUM(revenue_usd), 0)                                       AS revenue_usd,
  ROUND(100 * SUM(revenue_usd) / SUM(SUM(revenue_usd)) OVER (), 1) AS share_of_revenue_pct,
  ROUND(SUM(revenue_usd) / COUNT(*), 2)                            AS revenue_per_user_usd
FROM `ecommerce-analytics-513805.ga4_analytics.users`
GROUP BY country
ORDER BY users DESC
LIMIT 10;