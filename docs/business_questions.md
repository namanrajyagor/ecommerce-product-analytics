# E-commerce Product Analytics — Business Questions & Metrics Framework

## Project Objective
Act as a Product Analyst for an online store (the Google Merchandise Store). The Product Manager wants to know
where customers drop off on the way to purchase, which channels and devices bring valuable users, whether
customers come back, and whether a new landing page design should be launched.

## Stakeholders
- **Product Manager** — wants to know which part of the shopping journey to fix first
- **Marketing Lead** — wants to know which channels bring buyers, not just visitors
- **Growth / Experimentation Team** — wants a trustworthy launch decision on the new landing page

## Data
| Dataset | Source | Size | Used for |
|---|---|---|---|
| GA4 Google Merchandise Store sample | BigQuery public data (`ga4_obfuscated_sample_ecommerce`) | 4,295,584 events, 270,154 users, 1 Nov 2020 – 31 Jan 2021 | Funnel, channels, devices, products, retention, customer segments |
| Landing page A/B test | Kaggle (`ab_data.csv`) | ~2.9 lakh users | Experiment analysis and launch decision |

- Currency: US Dollars ($)
- The period includes Black Friday, Cyber Monday and the holiday season, so seasonality must be considered
- The GA4 sample is obfuscated by Google (some values appear as `<Other>` or `(data deleted)`)

## Metrics Framework

### North Star Metric
**Revenue per user** = Total purchase revenue ÷ Total users
It captures both whether users buy (conversion) and how much they buy (order value), and can be broken down into:

> Revenue per user = Purchase conversion rate × Average order value × Orders per purchaser

### Input Metrics (levers the team can move)
| Area | Metric |
|---|---|
| Acquisition | Users, sessions, share of users by channel |
| Engagement | Engaged-session rate, pages per session |
| Funnel | Step-by-step conversion: view item → add to cart → begin checkout → shipping → payment → purchase |
| Order value | Average order value (AOV), items per order |
| Retention | % of users returning in later weeks; repeat-purchase rate |

### Guardrail Metrics (must not get worse when we change something)
- Engaged-session rate (users should not leave faster)
- Average order value (more orders should not come from much smaller orders)
- Mobile vs desktop conversion gap (changes should not hurt one device)

## Business Questions

### A. Overview & Acquisition
1. How many users, sessions, purchasers, orders and revenue did the store have, and what are the conversion rate and AOV? How did they change week by week across the holiday season?
2. Which traffic channels bring the most users, and which bring the most purchasers and revenue?
3. How do conversion and revenue differ by device and by country?

### B. Funnel
4. Where do users drop off between viewing a product and purchasing?
5. Which device or channel has the biggest funnel leak?
6. **Opportunity sizing:** how much extra revenue would fixing the biggest drop-off bring?

### C. Products
7. Which products and categories drive revenue, and which get many views but few purchases?

### D. Retention & Customers
8. Do users come back? What is weekly cohort retention by first-visit week?
9. How do new and returning users differ in conversion and revenue?
10. How concentrated is revenue among purchasers, and what customer segments exist (by frequency and spend)?

### E. Experiment
11. Should the new landing page be launched? (A/B test analysis)
12. How many users would a test on our store need to detect a meaningful lift in conversion?

## Success Criteria
- Clear, data-backed answers to all 12 questions
- A funnel analysis with the biggest drop-off sized in dollars
- A trustworthy A/B test decision, including data-quality and sample-ratio checks
- A dashboard the Product Manager can use without SQL
- A product memo with prioritised recommendations

## Deliverables
| Deliverable | Tool |
|---|---|
| Clean analysis tables | BigQuery (SQL) |
| Analysis queries | BigQuery (SQL) |
| Interactive dashboard | Looker Studio |
| A/B test analysis | Python (pandas, scipy, statsmodels) |
| Product memo with recommendations | Markdown |