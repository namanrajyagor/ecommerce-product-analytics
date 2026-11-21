-- ============================================================
-- 04_funnel.sql
-- Phase 4: Funnel drop-offs (Q4), funnel by device and channel (Q5), opportunity sizing (Q6)
-- ============================================================

-- 4.6 Session funnel (Q4): where do visits drop off on the way to purchase?
--     Open funnel: each step counts sessions that reached that step
--     UNNEST of an array of STRUCTs turns 7 totals into 7 rows (one per step)
WITH totals AS (
  SELECT
    COUNT(*)            AS s0,
    SUM(viewed_item)    AS s1,
    SUM(added_to_cart)  AS s2,
    SUM(began_checkout) AS s3,
    SUM(added_shipping) AS s4,
    SUM(added_payment)  AS s5,
    SUM(purchased)      AS s6
  FROM `ecommerce-analytics-513805.ga4_analytics.sessions`
),
steps AS (
  SELECT step.*
  FROM totals,
  UNNEST([
    STRUCT(0 AS step_no, 'All sessions'   AS step, s0 AS sessions),
    STRUCT(1, 'Viewed item',    s1),
    STRUCT(2, 'Added to cart',  s2),
    STRUCT(3, 'Began checkout', s3),
    STRUCT(4, 'Added shipping', s4),
    STRUCT(5, 'Added payment',  s5),
    STRUCT(6, 'Purchased',      s6)
  ]) AS step
)
SELECT
  step_no,
  step,
  sessions,
  ROUND(100 * sessions / FIRST_VALUE(sessions) OVER (ORDER BY step_no), 2)  AS pct_of_all_sessions,
  ROUND(100 * SAFE_DIVIDE(sessions, LAG(sessions) OVER (ORDER BY step_no)), 1) AS step_conversion_pct,
  LAG(sessions) OVER (ORDER BY step_no) - sessions                          AS sessions_lost
FROM steps
ORDER BY step_no;

-- 4.7 Funnel by device and first-touch channel (Q5): which segment leaks most, and at which step?
--     Joins sessions to users to get each session's first-touch medium
WITH s AS (
  SELECT s.*, u.first_touch_medium
  FROM `ecommerce-analytics-513805.ga4_analytics.sessions` s
  JOIN `ecommerce-analytics-513805.ga4_analytics.users` u USING (user_pseudo_id)
),
seg AS (
  SELECT 'All' AS dimension, 'All sessions' AS value,
         COUNT(*) AS sessions, SUM(viewed_item) AS v, SUM(added_to_cart) AS c,
         SUM(began_checkout) AS b, SUM(added_shipping) AS sh, SUM(added_payment) AS p, SUM(purchased) AS pu
  FROM s
  UNION ALL
  SELECT 'Device', device_category,
         COUNT(*), SUM(viewed_item), SUM(added_to_cart),
         SUM(began_checkout), SUM(added_shipping), SUM(added_payment), SUM(purchased)
  FROM s GROUP BY device_category
  UNION ALL
  SELECT 'First-touch medium', first_touch_medium,
         COUNT(*), SUM(viewed_item), SUM(added_to_cart),
         SUM(began_checkout), SUM(added_shipping), SUM(added_payment), SUM(purchased)
  FROM s GROUP BY first_touch_medium
)
SELECT
  dimension,
  value,
  sessions,
  ROUND(100 * v / sessions, 1)              AS view_item_rate_pct,
  ROUND(100 * SAFE_DIVIDE(c, v), 1)         AS view_to_cart_pct,
  ROUND(100 * SAFE_DIVIDE(b, c), 1)         AS cart_to_checkout_pct,
  ROUND(100 * SAFE_DIVIDE(p, sh), 1)        AS shipping_to_payment_pct,
  ROUND(100 * SAFE_DIVIDE(pu, p), 1)        AS payment_to_purchase_pct,
  ROUND(100 * pu / sessions, 2)             AS session_conversion_pct
FROM seg
ORDER BY dimension, sessions DESC;

-- 4.8 Opportunity sizing (Q6): what is a +5 percentage-point improvement at each step worth?
--     extra next-step sessions = from_sessions x 5%
--     extra purchases          = extra sessions x current completion from next step to purchase
--     extra revenue            = extra purchases x revenue per purchasing session
--     relative_improvement_needed shows how hard that +5 points is
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
    STRUCT(1 AS step_no, 'All sessions -> Viewed item' AS transition, s0 AS from_sessions, s1 AS to_sessions),
    STRUCT(2, 'Viewed item -> Added to cart',   s1, s2),
    STRUCT(3, 'Added to cart -> Began checkout', s2, s3),
    STRUCT(4, 'Added shipping -> Added payment', s4, s5),
    STRUCT(5, 'Added payment -> Purchased',      s5, s6)
  ]) AS x
)
SELECT
  transition,
  from_sessions,
  ROUND(100 * to_sessions / from_sessions, 1)                         AS current_rate_pct,
  ROUND(100 * LEAST(to_sessions / from_sessions + 0.05, 1), 1)        AS improved_rate_pct,
  ROUND(100 * 0.05 / (to_sessions / from_sessions), 1)                AS relative_improvement_needed_pct,
  ROUND(from_sessions * 0.05)                                         AS extra_next_step_sessions,
  ROUND(from_sessions * 0.05 * purchases / to_sessions)               AS extra_purchases,
  ROUND(from_sessions * 0.05 * purchases / to_sessions * revenue / purchases) AS extra_revenue_usd,
  ROUND(100 * (from_sessions * 0.05 * purchases / to_sessions) / purchases, 1) AS revenue_uplift_pct
FROM tr
ORDER BY step_no;