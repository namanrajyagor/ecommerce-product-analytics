-- ============================================================
-- 07_dashboard_views.sql
-- Phase 5: Views that feed the Looker Studio dashboard
-- ============================================================

-- 5.1a vw_dash_sessions: sessions + channel, week, visitor type and data-quality flag
CREATE OR REPLACE VIEW `ecommerce-analytics-513805.ga4_analytics.vw_dash_sessions` AS
SELECT
  s.session_key,
  s.user_pseudo_id,
  s.session_date,
  DATE_TRUNC(s.session_date, WEEK(MONDAY))                 AS week_start,
  s.device_category,
  s.country,
  u.first_touch_medium                                     AS channel,
  CASE
    WHEN s.session_number IS NULL THEN 'Unknown'
    WHEN s.session_number = 1     THEN 'New'
    ELSE 'Returning'
  END                                                      AS visitor_type,
  s.viewed_item,
  s.added_to_cart,
  s.began_checkout,
  s.added_shipping,
  s.added_payment,
  s.purchased,
  s.orders,
  s.revenue_usd,
  IF(DATE_TRUNC(s.session_date, WEEK(MONDAY)) = '2021-01-25', 1, 0) AS is_incomplete_revenue_week
FROM `ecommerce-analytics-513805.ga4_analytics.sessions` s
JOIN `ecommerce-analytics-513805.ga4_analytics.users` u USING (user_pseudo_id);
-- 5.1b vw_dash_funnel: one row per funnel step, split by device, channel and visitor type
--      (so the dashboard funnel can be filtered); step names are numbered so they sort correctly
CREATE OR REPLACE VIEW `ecommerce-analytics-513805.ga4_analytics.vw_dash_funnel` AS
SELECT
  t.device_category,
  t.channel,
  t.visitor_type,
  step.step_no,
  step.step,
  step.sessions
FROM (
  SELECT
    device_category, channel, visitor_type,
    COUNT(*)            AS s0,
    SUM(viewed_item)    AS s1,
    SUM(added_to_cart)  AS s2,
    SUM(began_checkout) AS s3,
    SUM(added_shipping) AS s4,
    SUM(added_payment)  AS s5,
    SUM(purchased)      AS s6
  FROM `ecommerce-analytics-513805.ga4_analytics.vw_dash_sessions`
  GROUP BY device_category, channel, visitor_type
) AS t,
UNNEST([
  STRUCT(0 AS step_no, '0. All sessions'   AS step, t.s0 AS sessions),
  STRUCT(1, '1. Viewed item',    t.s1),
  STRUCT(2, '2. Added to cart',  t.s2),
  STRUCT(3, '3. Began checkout', t.s3),
  STRUCT(4, '4. Added shipping', t.s4),
  STRUCT(5, '5. Added payment',  t.s5),
  STRUCT(6, '6. Purchased',      t.s6)
]) AS step;
-- 5.1 check: funnel view totals must match the Phase 4 funnel (360,129 → 4,837)
SELECT step_no, step, SUM(sessions) AS sessions
FROM `ecommerce-analytics-513805.ga4_analytics.vw_dash_funnel`
GROUP BY step_no, step
ORDER BY step_no;

-- 5.2a vw_dash_cohorts: weekly cohort retention in long format (weeks 1-12) for a heatmap
--      Cells beyond the end of the data simply do not exist (shown blank, not 0%)
CREATE OR REPLACE VIEW `ecommerce-analytics-513805.ga4_analytics.vw_dash_cohorts` AS
WITH activity AS (
  SELECT
    u.first_seen_week AS cohort_week,
    s.user_pseudo_id,
    DIV(DATE_DIFF(DATE_TRUNC(s.session_date, WEEK(MONDAY)), u.first_seen_week, DAY), 7) AS week_number
  FROM `ecommerce-analytics-513805.ga4_analytics.sessions` s
  JOIN `ecommerce-analytics-513805.ga4_analytics.users` u USING (user_pseudo_id)
),
cohorts AS (
  SELECT first_seen_week AS cohort_week, COUNT(*) AS cohort_users
  FROM `ecommerce-analytics-513805.ga4_analytics.users`
  GROUP BY cohort_week
),
counts AS (
  SELECT cohort_week, week_number, COUNT(DISTINCT user_pseudo_id) AS active_users
  FROM activity
  WHERE week_number BETWEEN 1 AND 12
  GROUP BY cohort_week, week_number
)
SELECT
  c.cohort_week,
  c.cohort_users,
  k.week_number,
  CONCAT('Week ', LPAD(CAST(k.week_number AS STRING), 2, '0')) AS week_label,
  k.active_users,
  k.active_users / c.cohort_users                             AS retention_rate
FROM counts k
JOIN cohorts c USING (cohort_week)
WHERE DATE_ADD(c.cohort_week, INTERVAL k.week_number WEEK) <= '2021-01-25';
-- 5.2b vw_dash_customers: one row per paying customer, with segment labels
CREATE OR REPLACE VIEW `ecommerce-analytics-513805.ga4_analytics.vw_dash_customers` AS
SELECT
  user_pseudo_id,
  first_touch_medium AS channel,
  first_country      AS country,
  orders,
  revenue_usd,
  CASE WHEN orders >= 3 THEN '3+ orders' WHEN orders = 2 THEN '2 orders' ELSE '1 order' END AS frequency,
  CASE WHEN revenue_usd >= 150 THEN 'High ($150+)'
       WHEN revenue_usd >= 50  THEN 'Mid ($50-150)'
       ELSE 'Low (<$50)' END                                               AS spend_tier,
  CASE
    WHEN orders >= 2 AND revenue_usd >= 150 THEN 'VIP (repeat, $150+)'
    WHEN orders = 1  AND revenue_usd >= 150 THEN 'One-time big spender ($150+)'
    WHEN orders >= 2                        THEN 'Repeat (under $150)'
    ELSE 'One-time (under $150)'
  END                                                                       AS customer_segment
FROM `ecommerce-analytics-513805.ga4_analytics.users`
WHERE revenue_usd > 0;
-- 5.2c vw_dash_products: products with rates, missed revenue and a zero-sale flag
--      Rates are fractions (Looker Studio formats them as %); view-based rates are relative indicators
CREATE OR REPLACE VIEW `ecommerce-analytics-513805.ga4_analytics.vw_dash_products` AS
WITH bench AS (
  SELECT
    (SELECT APPROX_QUANTILES(SAFE_DIVIDE(buyers, viewers), 2)[OFFSET(1)]
       FROM `ecommerce-analytics-513805.ga4_analytics.products`
       WHERE viewers >= 2000)                                  AS median_buy_rate,
    (SELECT SUM(revenue_usd) / SUM(buyers)
       FROM `ecommerce-analytics-513805.ga4_analytics.products`
       WHERE buyers > 0)                                       AS revenue_per_buyer
)
SELECT
  p.item_name,
  p.item_category,
  p.viewers,
  p.cart_adders,
  p.buyers,
  p.units_sold,
  p.revenue_usd,
  SAFE_DIVIDE(p.cart_adders, p.viewers)                        AS view_to_cart_rate,
  SAFE_DIVIDE(p.buyers, p.viewers)                             AS view_to_buy_rate,
  IF(p.viewers >= 2000 AND SAFE_DIVIDE(p.buyers, p.viewers) < b.median_buy_rate,
     ROUND((b.median_buy_rate - SAFE_DIVIDE(p.buyers, p.viewers)) * p.viewers * b.revenue_per_buyer, 0),
     0)                                                        AS missed_revenue_usd,
  IF(p.viewers >= 2000 AND p.buyers = 0, 1, 0)                 AS is_zero_sale_popular
FROM `ecommerce-analytics-513805.ga4_analytics.products` p
CROSS JOIN bench b;
-- 5.2d vw_dash_opportunity: +5 percentage-point improvement at each funnel step, in dollars
CREATE OR REPLACE VIEW `ecommerce-analytics-513805.ga4_analytics.vw_dash_opportunity` AS
WITH t AS (
  SELECT
    COUNT(*)            AS s0,
    SUM(viewed_item)    AS s1,
    SUM(added_to_cart)  AS s2,
    SUM(began_checkout) AS s3,
    SUM(added_shipping) AS s4,
    SUM(added_payment)  AS s5,
    SUM(purchased)      AS s6,
    SUM(revenue_usd)    AS revenue
  FROM `ecommerce-analytics-513805.ga4_analytics.sessions`
),
tr AS (
  SELECT x.*, t.s6 AS purchases, t.revenue
  FROM t,
  UNNEST([
    STRUCT(1 AS step_no, '1. Visitors -> Viewed item' AS transition, s0 AS from_sessions, s1 AS to_sessions),
    STRUCT(2, '2. Viewed item -> Added to cart',   s1, s2),
    STRUCT(3, '3. Added to cart -> Began checkout', s2, s3),
    STRUCT(4, '4. Added shipping -> Added payment', s4, s5),
    STRUCT(5, '5. Added payment -> Purchased',      s5, s6)
  ]) AS x
)
SELECT
  step_no,
  transition,
  from_sessions,
  to_sessions / from_sessions                                   AS current_rate,
  0.05 / (to_sessions / from_sessions)                          AS relative_improvement_needed,
  ROUND(from_sessions * 0.05 * purchases / to_sessions)         AS extra_purchases,
  ROUND(from_sessions * 0.05 * revenue / to_sessions)           AS extra_revenue_usd
FROM tr;
-- 5.2 check: row counts and totals of the four new views
SELECT
  (SELECT COUNT(*) FROM `ecommerce-analytics-513805.ga4_analytics.vw_dash_cohorts`)                 AS cohort_cells,
  (SELECT COUNT(*) FROM `ecommerce-analytics-513805.ga4_analytics.vw_dash_customers`)               AS paying_customers,
  (SELECT ROUND(SUM(revenue_usd)) FROM `ecommerce-analytics-513805.ga4_analytics.vw_dash_customers`) AS customer_revenue_usd,
  (SELECT COUNT(*) FROM `ecommerce-analytics-513805.ga4_analytics.vw_dash_products`)                AS products,
  (SELECT COUNTIF(is_zero_sale_popular = 1) FROM `ecommerce-analytics-513805.ga4_analytics.vw_dash_products`) AS zero_sale_popular_products,
  (SELECT ROUND(SUM(extra_revenue_usd)) FROM `ecommerce-analytics-513805.ga4_analytics.vw_dash_opportunity`) AS opportunity_total_check;