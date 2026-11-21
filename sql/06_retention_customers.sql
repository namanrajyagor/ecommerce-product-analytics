-- ============================================================
-- 06_retention_customers.sql
-- Phase 4: Cohort retention (Q8), new vs returning (Q9), revenue concentration and segments (Q10)
-- ============================================================

-- 4.10 Weekly cohort retention (Q8): % of each first-visit cohort active N weeks later
--      Cells are NULL when the cohort has not had N weeks of data yet (data ends week of 2021-01-25)
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
retention AS (
  SELECT
    c.cohort_week,
    c.cohort_users,
    COUNT(DISTINCT IF(a.week_number = 1, a.user_pseudo_id, NULL)) AS w1,
    COUNT(DISTINCT IF(a.week_number = 2, a.user_pseudo_id, NULL)) AS w2,
    COUNT(DISTINCT IF(a.week_number = 3, a.user_pseudo_id, NULL)) AS w3,
    COUNT(DISTINCT IF(a.week_number = 4, a.user_pseudo_id, NULL)) AS w4,
    COUNT(DISTINCT IF(a.week_number = 6, a.user_pseudo_id, NULL)) AS w6,
    COUNT(DISTINCT IF(a.week_number = 8, a.user_pseudo_id, NULL)) AS w8
  FROM cohorts c
  LEFT JOIN activity a USING (cohort_week)
  GROUP BY c.cohort_week, c.cohort_users
)
SELECT
  cohort_week,
  cohort_users,
  IF(DATE_ADD(cohort_week, INTERVAL 1 WEEK) <= '2021-01-25', ROUND(100 * w1 / cohort_users, 2), NULL) AS week1_pct,
  IF(DATE_ADD(cohort_week, INTERVAL 2 WEEK) <= '2021-01-25', ROUND(100 * w2 / cohort_users, 2), NULL) AS week2_pct,
  IF(DATE_ADD(cohort_week, INTERVAL 3 WEEK) <= '2021-01-25', ROUND(100 * w3 / cohort_users, 2), NULL) AS week3_pct,
  IF(DATE_ADD(cohort_week, INTERVAL 4 WEEK) <= '2021-01-25', ROUND(100 * w4 / cohort_users, 2), NULL) AS week4_pct,
  IF(DATE_ADD(cohort_week, INTERVAL 6 WEEK) <= '2021-01-25', ROUND(100 * w6 / cohort_users, 2), NULL) AS week6_pct,
  IF(DATE_ADD(cohort_week, INTERVAL 8 WEEK) <= '2021-01-25', ROUND(100 * w8 / cohort_users, 2), NULL) AS week8_pct
FROM retention
ORDER BY cohort_week;

-- 4.11 New vs returning visits (Q9): do returning visitors engage, convert and spend differently?
SELECT
  CASE
    WHEN session_number IS NULL THEN 'Unknown'
    WHEN session_number = 1     THEN 'New (first visit)'
    ELSE 'Returning'
  END                                                              AS visitor_type,
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
GROUP BY visitor_type
ORDER BY sessions DESC;

-- 4.12a Revenue concentration (Q10): share of revenue from the top X% of paying customers
WITH ranked AS (
  SELECT
    revenue_usd,
    ROW_NUMBER() OVER (ORDER BY revenue_usd DESC) / COUNT(*) OVER () AS top_fraction
  FROM `ecommerce-analytics-513805.ga4_analytics.users`
  WHERE revenue_usd > 0
)
SELECT
  COUNT(*)                                                               AS paying_customers,
  ROUND(SUM(revenue_usd), 0)                                             AS revenue_usd,
  ROUND(AVG(revenue_usd), 2)                                             AS avg_revenue_per_customer_usd,
  ROUND(100 * SUM(IF(top_fraction <= 0.01, revenue_usd, 0)) / SUM(revenue_usd), 1) AS top_1pct_share,
  ROUND(100 * SUM(IF(top_fraction <= 0.05, revenue_usd, 0)) / SUM(revenue_usd), 1) AS top_5pct_share,
  ROUND(100 * SUM(IF(top_fraction <= 0.10, revenue_usd, 0)) / SUM(revenue_usd), 1) AS top_10pct_share,
  ROUND(100 * SUM(IF(top_fraction <= 0.20, revenue_usd, 0)) / SUM(revenue_usd), 1) AS top_20pct_share,
  ROUND(100 * SUM(IF(top_fraction <= 0.50, revenue_usd, 0)) / SUM(revenue_usd), 1) AS top_50pct_share
FROM ranked;
-- 4.12b Customer segments (Q10): frequency (orders) x spend tier, simple RFM-style segmentation
SELECT
  CASE WHEN orders >= 3 THEN '3+ orders' WHEN orders = 2 THEN '2 orders' ELSE '1 order' END AS frequency,
  CASE WHEN revenue_usd >= 150 THEN 'High ($150+)'
       WHEN revenue_usd >= 50  THEN 'Mid ($50-150)'
       ELSE 'Low (<$50)' END                                       AS spend_tier,
  COUNT(*)                                                         AS customers,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                 AS share_of_customers_pct,
  ROUND(SUM(revenue_usd), 0)                                       AS revenue_usd,
  ROUND(100 * SUM(revenue_usd) / SUM(SUM(revenue_usd)) OVER (), 1) AS share_of_revenue_pct,
  ROUND(AVG(revenue_usd), 2)                                       AS avg_revenue_per_customer_usd
FROM `ecommerce-analytics-513805.ga4_analytics.users`
WHERE revenue_usd > 0
GROUP BY frequency, spend_tier
ORDER BY revenue_usd DESC;