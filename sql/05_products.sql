-- ============================================================
-- 05_products.sql
-- Phase 4: Product analysis (Q7)
-- Note: view-based rates are relative indicators (view_item events can list several products)
-- ============================================================

-- 4.9b-1 Top 15 products by revenue (shares are of total item revenue)
SELECT
  item_name,
  item_category,
  viewers,
  cart_adders,
  buyers,
  units_sold,
  ROUND(revenue_usd, 0)                                  AS revenue_usd,
  ROUND(100 * revenue_usd / SUM(revenue_usd) OVER (), 1) AS share_of_item_revenue_pct,
  ROUND(100 * SAFE_DIVIDE(cart_adders, viewers), 1)      AS view_to_cart_pct,
  ROUND(100 * SAFE_DIVIDE(buyers, viewers), 2)           AS view_to_buy_pct
FROM `ecommerce-analytics-513805.ga4_analytics.products`
ORDER BY revenue_usd DESC
LIMIT 15;
-- 4.9b-2 "Viewed a lot, bought little": popular products (2,000+ viewers) converting below the median
--        missed revenue = (median rate - product rate) x viewers x average revenue per buyer (rough estimate)
WITH p AS (
  SELECT *, SAFE_DIVIDE(buyers, viewers) AS buy_rate
  FROM `ecommerce-analytics-513805.ga4_analytics.products`
  WHERE viewers >= 2000
),
bench AS (
  SELECT
    (SELECT APPROX_QUANTILES(buy_rate, 2)[OFFSET(1)] FROM p) AS median_buy_rate,
    (SELECT SUM(revenue_usd) / SUM(buyers)
       FROM `ecommerce-analytics-513805.ga4_analytics.products`
       WHERE buyers > 0)                                      AS revenue_per_buyer
)
SELECT
  item_name,
  item_category,
  viewers,
  buyers,
  ROUND(100 * buy_rate, 2)                                         AS view_to_buy_pct,
  ROUND(100 * median_buy_rate, 2)                                  AS median_view_to_buy_pct,
  ROUND((median_buy_rate - buy_rate) * viewers)                    AS missed_buyers,
  ROUND((median_buy_rate - buy_rate) * viewers * revenue_per_buyer, 0) AS missed_revenue_usd
FROM p CROSS JOIN bench
WHERE buy_rate < median_buy_rate
ORDER BY missed_revenue_usd DESC
LIMIT 10;