# Product Memo — Where to Focus Next

**To:** Product Manager · Marketing Lead · Growth / Experimentation Team
**From:** Naman Rajyagor, Product Analyst
**Data:** Google Merchandise Store, GA4 (1 Nov 2020 – 31 Jan 2021) · Landing-page A/B test (2–24 Jan 2017)
**Note:** $ figures are estimates for the 3-month window; not annualised (the window includes the holiday peak)

---

## TL;DR
1. **Fix the shipping step first.** 39% of users who enter shipping details never reach payment. A +5-point improvement is worth **≈ $27.7K** and needs only an 8% relative improvement — the quick win.
2. **Improve product pages next.** Only 19.7% of product views lead to add-to-cart. +2 points ≈ **$34.5K**, +5 points ≈ **$86K** — the big bet, to be validated with A/B tests.
3. **Bring visitors back.** Returning visits are worth **5.3×** a first visit ($2.30 vs $0.43 per session), but only 3–6% of new visitors return the next week.
4. **Check 9 popular products with zero sales** (5,700–9,600 viewers each) for stock or add-to-cart issues — no-cost fix.
5. **Do not launch the new landing page.** The A/B test showed no gain (−1.2%, best case +0.8%).

---

## Where we are (North Star: revenue per user)
| Metric | Value |
|---|---|
| Users / sessions | 270,154 / 360,129 |
| Orders / revenue | 5,357 / **$339,457** |
| User conversion × AOV × orders per purchaser | 1.63% × $63.37 × 1.22 |
| **Revenue per user** | **$1.26** |

**The weakest lever is conversion**, then repeat purchasing (87% of customers buy once). Order value ($63) is healthy.

---

## Prioritised recommendations

| # | Action | Evidence | Est. impact (3 months) | Effort | How to measure |
|---|---|---|---|---|---|
| 1 | **Shipping step:** show shipping cost and delivery date before checkout; test a free-shipping threshold | Shipping → payment only 61.4%; 4,290 high-intent sessions lost | **≈ $27.7K** for +5 pts | Low | A/B test on shipping → payment rate; ≈ 24 days |
| 2 | **Fix 9 zero-sale popular products** | 9 products with 2,000+ viewers and 0 buyers (e.g. F/C Long Sleeve Tee Charcoal: 9,640 viewers) | ≈ $12.9K (rough; top 10 underperformers) | Very low | Ops check of stock and add-to-cart; monitor buyers per product |
| 3 | **Product page:** better photos, size guide, reviews, clearer price and add-to-cart button | View → cart only 19.7% (8 in 10 viewers don't add); weakest step | **≈ $34.5K** for +2 pts; ≈ $86K for +5 pts | Medium–High | A/B test on view → cart rate; ≈ 16 days for +2 pts |
| 4 | **Re-engagement:** cart reminders, back-in-stock alerts, wishlist | Returning visits: 3.09% conversion vs 0.68% for first visits; 66.9% of revenue from 27.5% of sessions; ≈ 10,000 abandoned carts | ≈ $6.3K per 1% of abandoned carts recovered | Medium | Returning-visit share, cart-recovery rate |
| 5 | **January win-back campaign** for holiday shoppers | Holiday cohorts retain at ~3% (half of November's ~6%) but show a return bump in the week of 4 Jan | Not sized (depends on reach) | Low | Week-4/5 retention of Dec cohorts vs previous year |
| 6 | **Second-order offers for 318 one-time big spenders** (team / bulk orders, business accounts) | 318 customers, $253 average single order, 23.7% of revenue | ≈ $8K per 10% who order again | Low | Repeat rate of this segment |
| 7 | **Loyalty for 205 VIPs** (early access to new merchandise) | 5% of customers, 18.8% of revenue, $311 each | Protects ≈ $64K of revenue | Low | VIP repeat rate and revenue |
| 8 | **Payment step:** add wallets, reduce payment failures | Payment → purchase 71.0%; 1,978 sessions lost | ≈ $23.9K for +5 pts | Medium | Payment → purchase rate |
| 9 | **Grow referral partnerships; target Canada** | Referral: $1.42 revenue per user (+13% vs average); Canada: $1.55 (+23%) | Not sized (needs spend data) | Medium | Revenue per user by channel and country |
| 10 | **Plan the holiday calendar** around the 7 Dec peak and the 21 Dec shipping cut-off | 7 Dec week = 17% of revenue; 4 holiday weeks = 55%; revenue −69% in the week of 21 Dec | Protects the peak | Low | Weekly revenue and conversion vs plan |

**Order of work:** 1 → 2 (quick wins, this month) · 3 and 4 (next quarter, with tests) · 5–10 (campaign and merchandising calendar)

---

## Not recommended
**Launching the new landing page.** On 286,691 clean users: 11.87% vs 12.02% conversion (−1.2%, p = 0.232); 95% CI −3.2% to +0.8%, so even the best case is below a +2% worthwhile lift. No novelty effect; slightly behind in every period.

---

## Measurement plan
- **Test each fix at the step it changes.** Store-wide conversion is too noisy for small changes (+5% would need ≈ 242 days); step-level tests need 2–4 weeks.
- **Guardrails** for every test: average order value, add-to-cart rate, revenue per session, and the mobile vs desktop conversion gap (currently ≈ 0.08 pts)
- **Rules:** fix the metric, minimum worthwhile lift, sample size and duration before starting; run an SRM check; report confidence intervals; run at least two full weeks; do not stop early

---

## Data and tracking issues to fix (for the analytics team)
| Issue | Impact |
|---|---|
| Duplicate purchase events (335 across 326 transaction IDs) | Revenue overstated by 6.3% in raw data |
| 906 purchases without a transaction ID | Cannot be de-duplicated |
| Missing revenue in the final week (70% of orders at $0) | Week revenue understated |
| `view_item` events listing several products | Product view counts inflated |
| Engaged-session flag ≈ 100% for first visits | Engagement rate unusable as a guardrail |
| Inconsistent product categories | Category reporting unreliable |

---

## Limitations
- GA4 sample is obfuscated by Google (some channels and values hidden or altered)
- Users are identified by browser cookie → true retention is somewhat higher than measured
- No ad-spend data → channel ROI cannot be judged
- The A/B test dataset is separate from the GA4 store (different site and period); it is used to demonstrate the experimentation method and the launch decision
- $ estimates assume the current conversion further down the funnel stays the same

---

**Supporting documents:** `sql_findings.md` · `ab_test_summary.md` · `data_model.md` · Data Studio dashboard (4 pages)