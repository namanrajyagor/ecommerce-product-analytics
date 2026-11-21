# Data Studio (Looker Studio) — Calculated fields

Data source: `vw_dash_sessions`

| Field | Formula | Format |
|---|---|---|
| Users | `COUNT_DISTINCT(user_pseudo_id)` | Number |
| Sessions | `COUNT(session_key)` | Number |
| Purchasers | `COUNT_DISTINCT(CASE WHEN purchased = 1 THEN user_pseudo_id ELSE NULL END)` | Number |
| Total Orders | `SUM(orders)` | Number |
| Revenue | `SUM(revenue_usd)` | Currency (USD) |
| Session conversion | `SUM(purchased) / COUNT(session_key)` | Percent |
| User conversion | `COUNT_DISTINCT(CASE WHEN purchased = 1 THEN user_pseudo_id ELSE NULL END) / COUNT_DISTINCT(user_pseudo_id)` | Percent |
| Avg order value | `SUM(revenue_usd) / SUM(orders)` | Currency (USD) |
| Revenue per user | `SUM(revenue_usd) / COUNT_DISTINCT(user_pseudo_id)` | Currency (USD) |
| Add-to-cart rate | `SUM(added_to_cart) / COUNT(session_key)` | Percent |