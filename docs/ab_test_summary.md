# A/B Test — New Landing Page: Analysis and Launch Decision

## Decision
**Do not launch the new landing page.** It did not improve conversion; the best realistic case is a +0.77% relative lift (below the +2% minimum worthwhile lift), and the most likely effect is slightly negative (−1.2%). Keep the old page and redirect effort to the funnel fixes identified in the GA4 analysis.

## Test setup
- **Data:** `ab_data.csv` (Kaggle) — 294,478 rows, 290,584 unique users
- **Period:** 2 Jan – 24 Jan 2017 (≈ 3 weeks, partial first and last days)
- **Groups:** control = old page, treatment = new page; planned 50/50 split
- **Metric:** user conversion (converted = 1)
- **Test:** two-sided two-proportion z-test, α = 0.05; 95% confidence interval for the difference

## 1. Data-quality checks
| Check | Finding | Action |
|---|---|---|
| Group vs page mismatch | 3,893 rows: control users on the new page (1,928) or treatment users on the old page (1,965) | — |
| Duplicate users | 3,894 users appeared more than once | — |
| Overlap | Every mismatched row belonged to a different user who **also** had a correct row → these users saw **both pages** | **Removed the 3,893 contaminated users entirely** (not just the bad rows) |
| Remaining duplicate | 1 user (773192) twice with the same group and page | Kept the first visit |
| **Clean dataset** | **286,691 users** (1.34% removed); 0 mismatches | Saved as `data/processed/ab_clean.csv` |

## 2. Sample Ratio Mismatch (SRM) check
| | Users |
|---|---|
| Control | 143,293 |
| Treatment | 143,398 |
- Treatment share **50.02%**; chi-square = 0.0385, **p = 0.8445** → **PASS** (alarm threshold p < 0.001)
- Daily treatment share 49.24%–50.62% on every day → randomisation worked throughout

## 3. Result
| | Control (old) | Treatment (new) |
|---|---|---|
| Users | 143,293 | 143,398 |
| Conversions | 17,220 | 17,025 |
| **Conversion rate** | **12.017%** | **11.873%** |

| Statistic | Value |
|---|---|
| Difference (treatment − control) | **−0.145 percentage points** |
| Relative lift | **−1.20%** |
| z / p-value | −1.195 / **0.232** |
| **95% CI (difference)** | **−0.382 to +0.093 pp** |
| **95% CI (relative)** | **−3.18% to +0.77%** |
| Statistically significant? | **No** |

## 4. Practical significance
- Minimum worthwhile lift set at **+2% relative** (+0.24 pp)
- Best case from the CI = **+0.77%** → a meaningful lift is **ruled out**, not just "not proven"
- The test's MDE was +0.342 pp (+2.85% relative) at 80% power; the observed interval still excluded +2% because the estimate came out negative

## 5. Stability and novelty check
| Period | Control | Treatment | Difference | p-value |
|---|---|---|---|---|
| Days 1–7 | 11.919% | 11.784% | −0.135 pp | 0.546 |
| Days 8–14 | 11.925% | 11.817% | −0.108 pp | 0.614 |
| Days 15–23 | 12.166% | 11.985% | −0.181 pp | 0.353 |
- New page slightly behind in **all three periods** → **no novelty effect**
- New page won on only **9 of 23 days** (consistent with noise around no improvement)
- **Peeking trap:** the cumulative difference started at −0.66 pp, briefly turned **positive (+0.05 pp) around 10 Jan**, then settled at ≈ −0.15 pp. Stopping early on 10 Jan would have led to launching a page that is actually slightly worse → fix sample size and duration in advance; do not stop on interim results
- Chart: `images/ab_daily_stability.png`

## 6. Sample-size planning for the Google Merchandise Store (Q12)
α = 0.05, power = 80%, two-sided; baselines and traffic from the GA4 analysis (92 days)

| Test | Baseline → target | Total sample | Days needed |
|---|---|---|---|
| Store-wide conversion +5% rel | 1.34% → 1.41% | 947,274 sessions | 242 |
| Store-wide conversion +10% rel | 1.34% → 1.47% | 242,412 sessions | 62 |
| Store-wide conversion +20% rel | 1.34% → 1.61% | 63,352 sessions | 17 |
| Product page view → cart +2 pts | 19.7% → 21.7% | 12,878 sessions viewing items | 16 |
| Product page view → cart +5 pts | 19.7% → 24.7% | 2,164 sessions viewing items | 3 (run ≥ 14) |
| Shipping → payment +5 pts | 61.4% → 66.4% | 2,894 sessions at shipping | 24 |

- Small lifts on overall conversion are impractical to detect (1.34% baseline is noisy)
- **Measure each fix at the funnel step it changes** → product-page and shipping-step tests are feasible in 2–4 weeks
- Always run at least two full weeks to cover weekly cycles, even if the sample size is reached sooner
- Saved as `data/processed/ab_sample_size_plan.csv`

## Recommendations
1. **Do not launch** the new landing page; keep the old page
2. Spend experimentation effort on the **shipping step** (≈ 24-day test) and **product page** (≈ 16-day test) — the highest-value leaks from the funnel analysis
3. For every test: pre-register the metric, minimum worthwhile lift, sample size and duration; run SRM checks; report confidence intervals; do not stop early