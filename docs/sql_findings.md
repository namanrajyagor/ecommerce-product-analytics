# SQL Analysis — Key Findings (BigQuery, GA4 Google Merchandise Store)

## Scope and definitions
- **Period:** 1 Nov 2020 – 31 Jan 2021 (includes Black Friday, Cyber Monday and the holiday season)
- **Tables:** `events_clean` → `orders` → `sessions` → `users`, plus `products` (see `data_model.md`)
- **Orders** are de-duplicated by transaction_id; **revenue** = order revenue in USD
- **Session** = user_pseudo_id + ga_session_id; **channel** = the user's first-touch medium (one per user)
- **Funnel** = open session funnel (each step counts sessions that reached it)

## Data-quality issues found and handled
| Issue | Evidence | Handling |
|---|---|---|
| Duplicate purchase events | 335 duplicates across 326 transaction IDs | De-duplicated `orders` table; revenue $362,165 → **$339,457** (−6.3%) |
| Purchases without a transaction ID | 906 orders ($31,817) | Kept as separate orders, flagged `has_transaction_id = 0` |
| Missing revenue in the final week | Week of 25 Jan: **70%** of orders at $0 vs 0–12% in other weeks | Excluded from revenue/AOV trend conclusions; kept for order counts |
| view_item events list several products | Summed product viewers (976,652) > view_item events (386,068) | View-based product rates used only as relative indicators |
| Engaged-session flag unrealistic | 99.9% for first visits vs 59.7% for returning | Not used as a guardrail; add-to-cart rate and revenue per session used instead |
| Users under several first-touch mediums | Medium totals > total users | One medium per user, from the first event |
| ga_session_id not unique across users | 349,545 IDs vs 360,129 true sessions | Session key = user + session ID |
| Inconsistent product categories; obfuscated values | e.g. blank or mixed categories; `<Other>`, `(data deleted)` | Product-level analysis; obfuscated groups reported, not interpreted |

## Q1. Store KPIs and the North Star
| KPI | Value |
|---|---|
| Users / sessions | 270,154 / 360,129 |
| Purchasers / paying customers | 4,408 / 4,055 |
| Orders (paid) | 5,357 (4,907) |
| Revenue | **$339,457** |
| User conversion / session conversion | **1.63% / 1.34%** |
| Average order value | **$63.37** ($69.18 on paid orders) |
| Orders per purchaser | 1.22 |
| **Revenue per user (North Star)** | **$1.26** = 1.63% × $63.37 × 1.22 |

## Q1. Weekly trend
- **Peak week: 7 Dec** ($59,100; 17% of 3-month revenue) — not Black Friday week
- **23 Nov – 20 Dec (4 weeks) = $188K = 55% of revenue**
- Week of 21 Dec: revenue **−69%** (likely the pre-Christmas shipping cut-off)
- **Traffic ≠ revenue:** weeks of 30 Nov and 4 Jan had almost equal users (24.5K vs 24.7K) but $42.7K vs $9.2K revenue — driven by conversion (1.90% vs 0.55%)

## Q2. Channels (first-touch medium)
| Medium | Share of users | Share of revenue | User conv. | Revenue per user |
|---|---|---|---|---|
| organic | 37.7% | 34.3% | 1.52% | $1.14 |
| (none) direct | 23.7% | 23.2% | 1.57% | $1.23 |
| `<Other>` | 17.4% | 14.6% | 1.44% | $1.05 |
| **referral** | 14.8% | **16.8%** | **1.85%** | **$1.42** |
| cpc (paid) | 5.3% | 5.0% | 1.53% | $1.18 (highest AOV $68.22) |
- Referral is the most valuable readable channel (+13% revenue per user vs average)
- Paid search looked worst (0.98%) before the one-medium-per-user fix; it is actually average. ROI cannot be judged without ad spend

## Q3. Devices and countries
- Desktop 58% / mobile 40% / tablet 2% of sessions; **conversion almost identical** (1.31% / 1.39% / 1.30%) — unusual, possibly flattened by obfuscation; device is not a lever in this data
- **US 43.9%** of users (44.1% revenue); **India #2** (9.4%); **Canada over-delivers**: 7.5% of users, 9.2% of revenue, $1.55 revenue per user (+23%)

## Q4. Funnel (sessions)
| Step | Sessions | Step conversion | Lost |
|---|---|---|---|
| All sessions | 360,129 | — | — |
| Viewed item | 77,020 | 21.4% | 283,109 |
| Added to cart | 15,188 | **19.7%** | 61,832 |
| Began checkout | 11,106 | 73.1% | 4,082 |
| Added shipping | 11,105 | 100% (fires with checkout) | 1 |
| Added payment | 6,815 | **61.4%** | 4,290 |
| Purchased | 4,837 | 71.0% | 1,978 |
- Weakest step: **product view → cart (19.7%)**; most valuable leak: **shipping → payment (39% of high-intent users leave)**
- Cart abandonment 68% (industry average ≈ 70%)

## Q5. Funnel by device and channel
- Every device and channel leaks at the same two steps (within ~3 points) → **store-wide fixes**, not segment-specific
- Referral is slightly better at most steps; cpc has the weakest view → cart (18.6%) but strongest payment → purchase (72.4%)

## Q6. Opportunity sizing (+5 points per step, 3-month revenue)
| Fix | Relative improvement needed | Extra revenue |
|---|---|---|
| Visitors → product view | 23.4% | $79,361 |
| **Product → cart** | 25.4% | **$86,071** |
| Cart → checkout | 6.8% | $23,211 |
| **Shipping → payment** | 8.1% | **$27,657** |
| Payment → purchase | 7.0% | $23,914 |
- **Revenue uplift % = relative improvement %** at any step (funnel steps multiply) → prioritise by effort and likelihood, not raw dollars
- Priority: (1) shipping → payment quick win, (2) product page as the big bet with A/B tests, (3) payment options, (4) navigation and merchandising

## Q7. Products
- 422 products; revenue is spread out — top product (Google Zip Hoodie) 3.9%, top 15 ≈ 31% of item revenue
- Apparel dominates the winter season (11 of top 15); best converters are bike (4.83%) and bottle (4.71%); bottles sell 2.3 units per buyer (bundle opportunity)
- **9 popular products (2,000+ viewers) had zero sales** — the largest had 5,700–9,600 viewers (e.g. F/C Long Sleeve Tee Charcoal, Women's Striped L/S) → likely stock or add-to-cart issues; top 10 underperformers ≈ $12.9K missed (rough)

## Q8. Cohort retention (weekly, by first-visit week)
- Week-1 return: **5.8–6.7%** (November cohorts) vs **≈3%** (peak gift weeks 7 and 14 Dec)
- Week-8 return < 1% for all cohorts → the store behaves like a one-time gift shop
- Holiday cohorts show a **return bump in the week of 4 Jan** (re-engagement window)
- January cohorts improving (3.2% → 4.1% week-1)
- Recent cohorts shown as NULL where weeks are not yet observable (right-censoring); cookie-based IDs understate true retention

## Q9. New vs returning visits
| | New | Returning |
|---|---|---|
| Share of sessions | 72.5% | 27.5% |
| Share of revenue | 33.1% | **66.9%** |
| Session conversion | 0.68% | **3.09%** |
| Revenue per session | $0.43 | **$2.30 (5.3×)** |

## Q10. Revenue concentration and segments
- Top 1% of customers = 9.3% of revenue; top 10% = 36.8%; **top 20% = 53.4%**
- **87% of customers bought once** (73% of revenue); repeat customers (13%) bring 27% at $172 each vs $71
- **VIPs:** 205 customers with 2+ orders and $150+ spend = 5% of customers, 18.8% of revenue
- **One-time big spenders:** 318 customers averaging $253 per order = 23.7% of revenue → convert to repeat

## Early recommendations (for the product memo)
1. Fix the shipping step: show shipping cost and delivery dates earlier; test a free-shipping threshold
2. Improve product pages (photos, size guide, reviews, clear add-to-cart) — validate with A/B tests
3. Check stock and add-to-cart on the five zero-sale popular products
4. Build re-engagement: cart reminders, back-in-stock alerts, a January win-back campaign for holiday shoppers
5. Loyalty for the 205 VIPs; second-order offers (team/bulk) for the 318 one-time big spenders
6. Grow referral partnerships; target Canada; plan the holiday calendar around the 7 Dec peak and the 21 Dec shipping cut-off