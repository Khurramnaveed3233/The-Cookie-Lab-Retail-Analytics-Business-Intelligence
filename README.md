<div align="center">

#  The Cookie Lab — Retail Analytics & Business Intelligence

**SQL Server → Business Analysis → Power BI**

A decision-oriented retail analytics case study covering revenue, sales channels, customers, RFM segmentation, products, stores, refunds, churn risk, and retention.

*Prepared as a Data Analyst Portfolio Project by **Khurram Naveed***

</div>

---

##  Project Overview

The Cookie Lab is a premium omnichannel cookie retailer. This project simulates a real-world analyst engagement: a relational dataset of **824,838+ transaction records** was analyzed in **SQL Server**, and the findings were translated into a **four-page interactive Power BI dashboard** built for executive review and operational decision-making.

**The core principle behind this project:**

> SQL was used to discover what is happening in the business. Power BI was used to communicate, explore, and monitor those insights.

| | |
|---|---|
| **Business Context** | Canadian premium omnichannel cookie retailer |
| **Data Scale** | 824,838+ transaction records + interconnected operational tables |
| **Tools** | Microsoft SQL Server (SSMS), Power BI |
| **SQL Techniques** | Joins, CTEs, window functions (`NTILE`), aggregation, cohort logic |
| **BI Output** | 4-page Power BI dashboard |
| **Decision Focus** | Revenue, customer value, product & store performance, refund risk, retention |

---

##  Business Problem

The Cookie Lab operates across physical stores and digital channels, generating a large volume of transaction, customer, product, and operational data — but no consolidated view of performance.

**Objective:** Move from raw relational data to a decision-ready view that answers:
- Where is revenue coming from, and through which channels?
- Which customers matter most — and which are at risk of leaving?
- Which products and stores lead performance?
- Where are refunds creating financial and operational risk?

---

##  Dataset Architecture

```
transactions   →  Fact table: channel, payment method, revenue, refunds
order_details  →  Fact/bridge: order-level product quantities and line totals
customers      →  Dimension: customer identity & geography
products       →  Dimension: product catalog & category
stores         →  Dimension: physical store & location
suppliers      →  Dimension: supplier/vendor info
shipments      →  Logistics: delivery status & fulfillment tracking
```

**Key relationships:**
```
transactions.CustomerID  → customers.CustomerID
transactions.StoreID     → stores.StoreID
order_details.ProductID  → products.ProductID
shipments.SupplierID     → suppliers.SupplierID
```

> Failed and Cancelled transactions are excluded from revenue, RFM, and customer analyses. RFM and churn calculations use **January 1, 2027** as the reference date.

---

##  Analytical Workflow

| Stage | Description |
|---|---|
| 1. Business Understanding | Define the commercial questions worth answering |
| 2. Data Preparation | Apply quality controls (status filters, revenue definitions, correct grain) |
| 3. SQL Analysis | Answer each business question with query logic in SQL Server |
| 4. Power BI Development | Translate SQL findings into an interactive 4-page dashboard |
| 5. Business Recommendations | Convert insights into specific, monitorable management actions |

---

## 🧾 SQL Analysis Highlights

All queries live in [`/sql`](./sql). Each one is built around a business question rather than a syntax demo.

<details>
<summary><b>Revenue, Channel & Transaction Performance</b></summary>

```sql
SELECT
    Channel,
    PaymentMethod,
    COUNT(TransactionID) AS TotalTransactions,
    SUM(Amount) AS GrossRevenue,
    SUM(RefundAmount) AS TotalRefunds,
    (SUM(Amount) - SUM(RefundAmount)) AS NetRevenue,
    CAST(SUM(RefundAmount) * 100.0 /
        NULLIF(SUM(Amount), 0) AS DECIMAL(5,2)) AS RefundPercentage,
    CAST(AVG(Amount) AS DECIMAL(10,2)) AS AverageTransactionValue
FROM transactions
WHERE PaymentStatus NOT IN ('Failed', 'Cancelled')
GROUP BY Channel, PaymentMethod
ORDER BY NetRevenue DESC;
```
</details>

<details>
<summary><b>Customer RFM Segmentation</b></summary>

```sql
WITH RFM_Raw AS (
    SELECT
        CustomerID,
        DATEDIFF(DAY, MAX(CAST(TransactionDate AS DATE)), '2027-01-01') AS Recency,
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(Amount) AS Monetary
    FROM transactions
    WHERE PaymentStatus NOT IN ('Failed', 'Cancelled')
    GROUP BY CustomerID
),
RFM_Scores AS (
    SELECT
        CustomerID, Recency, Frequency, Monetary,
        NTILE(5) OVER (ORDER BY Recency DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC)  AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary ASC)   AS M_Score
    FROM RFM_Raw
)
SELECT CustomerID, Recency, Frequency, Monetary,
       (R_Score + F_Score + M_Score) AS RFM_Total_Score
FROM RFM_Scores;
```

| Segment | RFM Rule | Meaning |
|---|---|---|
| Champions / VIP | ≥ 13 | Highest-value, highly engaged customers |
| Loyal Customers | ≥ 10 | Strong repeat customers |
| Potential Loyalists | ≥ 7 | Room to grow into higher value |
| At Risk / Churned | < 7 | Declining engagement |
</details>

<details>
<summary><b>Refund Hotspots</b></summary>

```sql
SELECT TOP 10
    p.ProductID, p.ProductName, p.ProductCategory,
    COUNT(t.TransactionID) AS TotalOrders,
    SUM(t.RefundAmount) AS TotalRefundAmount,
    CAST(SUM(t.RefundAmount) * 100.0 /
        NULLIF(SUM(t.Amount), 0) AS DECIMAL(5,2)) AS RefundRatePercentage
FROM products p
JOIN order_details od ON p.ProductID = od.ProductID
JOIN transactions t ON od.OrderID = t.OrderID
GROUP BY p.ProductID, p.ProductName, p.ProductCategory
HAVING SUM(t.RefundAmount) > 0
ORDER BY TotalRefundAmount DESC;
```
</details>

<details>
<summary><b>Cohort & Retention Analysis</b></summary>

```sql
WITH FirstPurchase AS (
    SELECT CustomerID,
           MIN(FORMAT(CAST(TransactionDate AS DATE), 'yyyy-MM')) AS CohortMonth
    FROM transactions
    WHERE PaymentStatus NOT IN ('Failed', 'Cancelled')
    GROUP BY CustomerID
),
CustomerActivity AS (
    SELECT DISTINCT
        fp.CohortMonth,
        FORMAT(CAST(t.TransactionDate AS DATE), 'yyyy-MM') AS ActivityMonth,
        t.CustomerID
    FROM transactions t
    JOIN FirstPurchase fp ON t.CustomerID = fp.CustomerID
    WHERE t.PaymentStatus NOT IN ('Failed', 'Cancelled')
)
SELECT CohortMonth, ActivityMonth, COUNT(DISTINCT CustomerID) AS ActiveCustomers
FROM CustomerActivity
GROUP BY CohortMonth, ActivityMonth
ORDER BY CohortMonth, ActivityMonth;
```
</details>

Full query set (revenue & channel, monthly trend, RFM, product/category, store & LTV, refund hotspots, churn risk, cohort retention) is available in [`/sql`](./sql).

---

##  Power BI Dashboard

A 4-page report, each built around a specific decision theme.

### Page 1 — Retail Sales, Customer & Operational Performance

<img width="1536" height="1024" alt="The Cookie Lab — Retail Sales   Customer Analytics_page-1" src="https://github.com/user-attachments/assets/218bf08d-d832-44c2-a0cd-9b35377091e7" />

Page 1 acts as the **executive overview**. It brings the most important commercial KPIs and revenue drivers into a single screen so that management can understand the overall business position before moving into detailed analysis. It answers the first management question: *"How is the business performing overall, and what are the major commercial drivers?"*

**What the Page Solves**
- Provides Net Revenue, Gross Revenue, Total Refunds, Total Orders, and Total Customers at a glance.
- Compares Net Revenue across sales channels (In-Store, Mobile App, Website, Third-Party Delivery).
- Compares Gross Revenue against Refunds by channel to expose where refund exposure is concentrated.
- Shows revenue contribution by payment method.
- Highlights the Top 10 Products by Gross Revenue.

**Key Results**
- **82.60M** Gross Revenue and **78.94M** Net Revenue.
- **3.66M** Total Refunds.
- **750K** Total Orders and **115K** Total Customers.
- **In-Store** is the leading sales channel, ahead of Mobile App and Website.
- **Credit Card** is the dominant payment method, generating approximately **36M** in revenue.
- **Cookie Cake (3)** leads product gross revenue at approximately **7.1M**.

**Business Impact**
This page functions as a single executive snapshot of revenue, customer scale, channel performance, payment behavior, and product performance. Rather than requiring stakeholders to cross-reference multiple reports, it consolidates the health of the business into one view — making it the natural starting point before drilling into channel trends (Page 2), customer segments (Page 3), or product/store detail (Page 4).

### Page 2 — Sales & Channel Performance
*Monthly revenue trend, average transaction value by channel, refund rate by channel, top stores.*

<img width="1536" height="1024" alt="The Cookie Lab — Retail Sales   Customer Analytics_page-2" src="https://github.com/user-attachments/assets/b8e82239-273b-4d40-a2bf-119d36db4d53" />

### Page 3 — Customer Intelligence & RFM Analysis
*RFM segment distribution, average monetary value & frequency by segment, top 20 high-value customers.*

<img width="1536" height="1024" alt="The Cookie Lab — Retail Sales   Customer Analytics_page-3" src="https://github.com/user-attachments/assets/b2ea871b-3468-4f6b-bbb2-c341064535b8" />

### Page 4 — Product & Store Performance
*Top products by revenue/units/refunds, category performance, store-level gross revenue.*

<img width="1448" height="1086" alt="The Cookie Lab — Retail Sales   Customer Analytics_page-4" src="https://github.com/user-attachments/assets/c6a0edb0-3cea-41e8-89cc-686ad1b345f4" />


---

##  Headline Findings

- **Gross Revenue:** 82.60M | **Net Revenue:** 78.94M | **Total Refunds:** 3.66M
- **Total Orders:** 750K | **Total Customers:** 115K
- **In-Store** is the leading sales channel, followed by Mobile App and Website
- **Credit Card** is the dominant payment method (~36M revenue)
- **Cookie Cake (3)** leads gross revenue (~7.1M); **Cakes** is the top category (~18.3M)
- **Champions/VIP** customers show the strongest monetary value and purchase frequency
- **Holiday Cookie Tin** leads unit sales (~233K units) but is also the top refund hotspot (~0.76M)
- **The Cookie Lab London Main Street** is the top-performing store (~4.8M gross revenue)

---

##  Business Recommendations

| Recommendation | KPI to Monitor |
|---|---|
| Strengthen high-performing channels (protect In-Store, grow digital) | Net Revenue by Channel, ATV, Channel Growth |
| Investigate refund hotspots (Holiday Cookie Tin) | Refund Amount, Refund Rate |
| Prioritize high-value (Champions/VIP) customers | Repeat Purchase Rate, Monetary Value, RFM Migration |
| Reactivate at-risk customers with win-back campaigns | Reactivation Rate, Days Since Last Order |
| Optimize product portfolio (revenue vs. volume leaders) | Gross Revenue, Units Sold, Revenue per Unit |
| Benchmark store performance against top locations | Store Revenue, AOV, Growth |
| Establish continuous BI monitoring, not a one-time report | Revenue, Refunds, Segments, Product/Store KPIs |

---

##  Tech Stack

`Microsoft SQL Server` · `SQL Server Management Studio (SSMS)` · `Power BI`

**Techniques demonstrated:** SQL aggregation & multi-table joins · CTEs · window functions (`NTILE`) · RFM segmentation · customer lifetime value · cohort & retention analysis · trend analysis · refund & churn-risk analysis · product/category analysis · store benchmarking · KPI & dashboard design

---

##  Repository Structure

```
cookie-lab-retail-analytics/
│
├── README.md
├── sql/
│   ├── 01_revenue_channel_performance.sql
│   ├── 02_monthly_sales_trend.sql
│   ├── 03_rfm_segmentation.sql
│   ├── 04_product_category_performance.sql
│   ├── 05_store_performance_ltv.sql
│   ├── 06_refund_hotspots.sql
│   ├── 07_churn_risk.sql
│   └── 08_cohort_retention.sql
│
├── dashboard-images/
│   ├── page1-overview.png
│   ├── page2-sales-channel.png
│   ├── page3-customer-intelligence.png
│   └── page4-product-store.png
│
├── powerbi/
│   └── cookie-lab-dashboard.pbix
│
└── docs/
    └── The_Cookie_Lab_Retail_Analytics_Portfolio_Khurram_Naveed.pdf
```

---

##  Full Case Study

The complete write-up — including the full analyst narrative, data dictionary, and page-by-page dashboard breakdown — is available here:
📥 [`docs/The_Cookie_Lab_Retail_Analytics_Portfolio_Khurram_Naveed.pdf`](./docs/The_Cookie_Lab_Retail_Analytics_Portfolio_Khurram_Naveed.pdf)

---

##  Author

**Khurram Naveed**
Data Analyst
[LinkedIn](#) · [Portfolio](#) · [Email](#)

---

<div align="center">

*If this project was useful or interesting, consider ⭐ starring the repo.*

</div>

