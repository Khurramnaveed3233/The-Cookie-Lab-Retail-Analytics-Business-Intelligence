create database The_Cookie_Lab

use The_Cookie_Lab

SELECT COUNT(*) AS TotalRows FROM transactions;

-- 1. Check for any negative or illogical amounts

SELECT COUNT(*) AS InvalidAmounts 
FROM transactions 
WHERE Amount < 0 OR RefundAmount < 0;

-- 2. Verify that RefundAmount is not greater than the Transaction Amount

SELECT COUNT(*) AS InvalidRefunds 
FROM transactions 
WHERE RefundAmount > Amount;

-- 3. Check Payment Status distribution to ensure no weird/corrupted text

SELECT PaymentStatus, COUNT(*) AS TotalCount 
FROM transactions 
GROUP BY PaymentStatus;

-- 4. Standardize / Clean whitespace in text columns (e.g., Channels, Payment Methods)
UPDATE transactions 
SET Channel = LTRIM(RTRIM(Channel)),
    [PaymentMethod] = LTRIM(RTRIM([PaymentMethod]));

select channel , paymentmethod 
from transactions

-- 1. Channel-wise Revenue, Net Sales, and Refund Performance Analysis

SELECT 
    Channel,
    [PaymentMethod],
    COUNT(TransactionID) AS TotalTransactions,
    SUM(Amount) AS GrossRevenue,
    SUM(RefundAmount) AS TotalRefunds,
    (SUM(Amount) - SUM(RefundAmount)) AS NetRevenue,
    CAST(SUM(RefundAmount) * 100.0 / NULLIF(SUM(Amount), 0) AS DECIMAL(5,2)) AS RefundPercentage,
    CAST(AVG(Amount) AS DECIMAL(10,2)) AS AverageTransactionValue
FROM transactions
WHERE PaymentStatus NOT IN ('Failed', 'Cancelled') -- Sirf successful ya relevant transactions
GROUP BY Channel, [PaymentMethod]
ORDER BY NetRevenue DESC;

-- 2. Monthly Sales Trend & Growth Analysis
SELECT 
    FORMAT(CAST(TransactionDate AS DATE), 'yyyy-MM') AS SalesMonth,
    COUNT(TransactionID) AS TotalTransactions,
    SUM(Amount) AS GrossRevenue,
    SUM(RefundAmount) AS TotalRefunds,
    (SUM(Amount) - SUM(RefundAmount)) AS NetRevenue,
    CAST(AVG(Amount) AS DECIMAL(10,2)) AS AvgOrderValue
FROM transactions
WHERE PaymentStatus NOT IN ('Failed', 'Cancelled')
GROUP BY FORMAT(CAST(TransactionDate AS DATE), 'yyyy-MM')
ORDER BY SalesMonth ASC;

-- Step 1: Calculate Raw RFM Metrics per Customer
WITH RFM_Raw AS (
    SELECT 
        CustomerID,
        DATEDIFF(DAY, MAX(CAST(TransactionDate AS DATE)), '2027-01-01') AS Recency, -- Reference date set ki hai
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(Amount) AS Monetary
    FROM transactions
    WHERE PaymentStatus NOT IN ('Failed', 'Cancelled')
    GROUP BY CustomerID
),

-- Step 2: Assign RFM Scores from 1 to 5 using NTILE
RFM_Scores AS (
    SELECT 
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        NTILE(5) OVER (ORDER BY Recency DESC) AS R_Score, -- Kam recency (zyaada recent) ko behtar score
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score, -- Zyaada frequency ko behtar score
        NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Score   -- Zyaada monetary ko behtar score
    FROM RFM_Raw
),

-- Step 3: Combine Scores and Create Customer Segments

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
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        NTILE(5) OVER (ORDER BY Recency DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Score
    FROM RFM_Raw
),
RFM_Final AS (
    SELECT 
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        (R_Score + F_Score + M_Score) AS RFM_Total_Score,
        CASE 
            WHEN (R_Score + F_Score + M_Score) >= 13 THEN 'Champions / VIP'
            WHEN (R_Score + F_Score + M_Score) >= 10 THEN 'Loyal Customers'
            WHEN (R_Score + F_Score + M_Score) >= 7  THEN 'Potential Loyalists'
            ELSE 'At Risk / Churned'
        END AS CustomerSegment
    FROM RFM_Scores
)
SELECT 
    CustomerSegment,
    COUNT(CustomerID) AS TotalCustomers,
    CAST(AVG(Monetary) AS DECIMAL(10,2)) AS AvgMonetarySpend,
    CAST(AVG(Frequency) AS DECIMAL(10,1)) AS AvgFrequency
FROM RFM_Final
GROUP BY CustomerSegment
ORDER BY AvgMonetarySpend DESC;

-- Step 4. Product & Category Performance Analysis

SELECT TOP 10 
    p.ProductID,
    p.ProductName,
    p.ProductCategory,
    COUNT(od.OrderID) AS TotalTimesOrdered,
    SUM(od.Quantity) AS TotalUnitsSold,
    SUM(od.LineTotal) AS GrossRevenue
FROM products p
JOIN order_details od ON p.ProductID = od.ProductID
GROUP BY p.ProductID, p.ProductName, p.ProductCategory
ORDER BY GrossRevenue DESC;

-- Step 5 . Store-Wise Revenue & Regional Comparison

SELECT 
    st.StoreID,
    st.StoreName,
    COUNT(t.TransactionID) AS TotalTransactions,
    SUM(t.Amount) AS TotalRevenue,
    CAST(AVG(t.Amount) AS DECIMAL(10,2)) AS AvgOrderValue
FROM stores st
JOIN transactions t ON st.StoreID = t.StoreID
WHERE t.PaymentStatus NOT IN ('Failed', 'Cancelled')
GROUP BY st.StoreID, st.StoreName
ORDER BY TotalRevenue DESC;

-- Step 6 . Store-Wise Revenue & Regional Comparison

SELECT TOP 20
    c.CustomerID,
    CONCAT(FirstName,'' , LastName) as CustomerName,
    c.City,
    COUNT(DISTINCT t.OrderID) AS TotalOrders,
    SUM(t.Amount) AS LifetimeSpend,
    CAST(MAX(t.TransactionDate) AS DATE) AS LastPurchaseDate
FROM customers c
JOIN transactions t ON c.CustomerID = t.CustomerID
WHERE t.PaymentStatus NOT IN ('Failed', 'Cancelled')
GROUP BY c.CustomerID, CONCAT(FirstName,'' , LastName) , c.City
ORDER BY LifetimeSpend DESC;

-- Step 7 .  .Customer Lifetime Value (LTV) & Top Spenders

SELECT TOP 20
    c.CustomerID,
    CONCAT(FirstName,'' , LastName) as CustomerName,
    c.City,
    COUNT(DISTINCT t.OrderID) AS TotalOrders,
    SUM(t.Amount) AS LifetimeSpend,
    CAST(MAX(t.TransactionDate) AS DATE) AS LastPurchaseDate
FROM customers c
JOIN transactions t ON c.CustomerID = t.CustomerID
WHERE t.PaymentStatus NOT IN ('Failed', 'Cancelled')
GROUP BY c.CustomerID, CONCAT(FirstName,'' , LastName)  , c.City
ORDER BY LifetimeSpend DESC;

-- step 8. Inventory & Product Return / Refund Hotspots (Quality Control)

SELECT TOP 10 
    p.ProductID,
    p.ProductName,
    p.ProductCategory,
    COUNT(t.TransactionID) AS TotalOrders,
    SUM(t.RefundAmount) AS TotalRefundAmount,
    CAST(SUM(t.RefundAmount) * 100.0 / NULLIF(SUM(t.Amount), 0) AS DECIMAL(5,2)) AS RefundRatePercentage
FROM products p
JOIN order_details od ON p.ProductID = od.ProductID
JOIN transactions t ON od.OrderID = t.OrderID
GROUP BY p.ProductID, p.ProductName, p.ProductCategory
HAVING SUM(t.RefundAmount) > 0
ORDER BY TotalRefundAmount DESC;

-- 9. High-Value Customer Churn Risk Analysis (At-Risk VIPs)

SELECT TOP 20
    c.CustomerID,
    CONCAT(FirstName,'' , LastName) as CustomerName,
    c.Email,
    MAX(t.TransactionDate) AS LastPurchaseDate,
    DATEDIFF(day, MAX(CAST(t.TransactionDate AS DATE)), '2027-01-01') AS DaysSinceLastOrder,
    SUM(t.Amount) AS HistoricalSpend
FROM customers c
JOIN transactions t ON c.CustomerID = t.CustomerID
WHERE t.PaymentStatus NOT IN ('Failed', 'Cancelled')
GROUP BY c.CustomerID, CONCAT(FirstName,'' , LastName) , c.Email
HAVING DATEDIFF(day, MAX(CAST(t.TransactionDate AS DATE)), '2027-01-01') > 90 -- Jinhein 90 din se zyada ho gaye
ORDER BY HistoricalSpend DESC; -- Sab se baray spenders jo ab inactive hain

-- step 10 . Monthly Cohort & Customer Retention Analysis

WITH FirstPurchase AS (
    -- Har customer ka pehla mahina find karna (Acquisition Month)
    SELECT 
        CustomerID,
        MIN(FORMAT(CAST(TransactionDate AS DATE), 'yyyy-MM')) AS CohortMonth
    FROM transactions
    WHERE PaymentStatus NOT IN ('Failed', 'Cancelled')
    GROUP BY CustomerID
),
CustomerActivity AS (
    -- Har customer ki transactions ko unke cohort month ke sath map karna
    SELECT DISTINCT
        fp.CohortMonth,
        FORMAT(CAST(t.TransactionDate AS DATE), 'yyyy-MM') AS ActivityMonth,
        t.CustomerID
    FROM transactions t
    JOIN FirstPurchase fp ON t.CustomerID = fp.CustomerID
    WHERE t.PaymentStatus NOT IN ('Failed', 'Cancelled')
)
-- Final aggregation to see active customers per cohort over time
SELECT 
    CohortMonth,
    ActivityMonth,
    COUNT(DISTINCT CustomerID) AS ActiveCustomers
FROM CustomerActivity
GROUP BY CohortMonth, ActivityMonth
ORDER BY CohortMonth, ActivityMonth;


WITH RFM_Raw AS
(
    SELECT
        CustomerID,

        DATEDIFF(
            DAY,
            MAX(CAST(TransactionDate AS DATE)),
            '2027-01-01'
        ) AS Recency,

        COUNT(DISTINCT OrderID) AS Frequency,

        SUM(Amount) AS Monetary

    FROM transactions

    WHERE PaymentStatus NOT IN ('Failed', 'Cancelled')

    GROUP BY CustomerID
),

RFM_Scores AS
(
    SELECT
        CustomerID,
        Recency,
        Frequency,
        Monetary,

        NTILE(5) OVER (
            ORDER BY Recency DESC
        ) AS R_Score,

        NTILE(5) OVER (
            ORDER BY Frequency ASC
        ) AS F_Score,

        NTILE(5) OVER (
            ORDER BY Monetary ASC
        ) AS M_Score

    FROM RFM_Raw
),

RFM_Final AS
(
    SELECT
        CustomerID,
        Recency,
        Frequency,
        Monetary,

        R_Score,
        F_Score,
        M_Score,

        (R_Score + F_Score + M_Score) AS RFM_Total_Score,

        CASE
            WHEN (R_Score + F_Score + M_Score) >= 13
                THEN 'Champions / VIP'

            WHEN (R_Score + F_Score + M_Score) >= 10
                THEN 'Loyal Customers'

            WHEN (R_Score + F_Score + M_Score) >= 7
                THEN 'Potential Loyalists'

            ELSE 'At Risk / Churned'
        END AS CustomerSegment

    FROM RFM_Scores
)

SELECT *
FROM RFM_Final;


CREATE VIEW vw_RFM_Customers
AS
WITH RFM_Raw AS
(
    SELECT
        CustomerID,
        DATEDIFF(
            DAY,
            MAX(CAST(TransactionDate AS DATE)),
            '2027-01-01'
        ) AS Recency,
        COUNT(DISTINCT OrderID) AS Frequency,
        SUM(Amount) AS Monetary
    FROM transactions
    WHERE PaymentStatus NOT IN ('Failed', 'Cancelled')
    GROUP BY CustomerID
),

RFM_Scores AS
(
    SELECT
        CustomerID,
        Recency,
        Frequency,
        Monetary,

        NTILE(5) OVER (ORDER BY Recency DESC) AS R_Score,
        NTILE(5) OVER (ORDER BY Frequency ASC) AS F_Score,
        NTILE(5) OVER (ORDER BY Monetary ASC) AS M_Score

    FROM RFM_Raw
)

SELECT
    CustomerID,
    Recency,
    Frequency,
    Monetary,
    R_Score,
    F_Score,
    M_Score,

    R_Score + F_Score + M_Score AS RFM_Total_Score,

    CASE
        WHEN R_Score + F_Score + M_Score >= 13
            THEN 'Champions / VIP'
        WHEN R_Score + F_Score + M_Score >= 10
            THEN 'Loyal Customers'
        WHEN R_Score + F_Score + M_Score >= 7
            THEN 'Potential Loyalists'
        ELSE 'At Risk / Churned'
    END AS CustomerSegment

FROM RFM_Scores;