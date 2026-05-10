-- ============================================================
-- 08_validate.sql
-- Post-load validation queries
-- Run after all load scripts to confirm data quality
-- ============================================================

USE sales_db;

-- ── 1. Row count summary ──────────────────────────────────────
SELECT '=== ROW COUNTS ===' AS Section;

SELECT 'sales_transactions'    AS TableName, COUNT(*) AS RowCount,
       'Expected: 5000'        AS Expected
FROM sales_transactions

UNION ALL

SELECT 'product_master'        AS TableName, COUNT(*) AS RowCount,
       'Expected: 20'          AS Expected
FROM product_master

UNION ALL

SELECT 'customer_demographics' AS TableName, COUNT(*) AS RowCount,
       'Expected: 120'         AS Expected
FROM customer_demographics;

-- ── 2. Date range check ───────────────────────────────────────
SELECT '=== DATE RANGE ===' AS Section;

SELECT
    MIN(SaleDate)   AS EarliestDate,
    MAX(SaleDate)   AS LatestDate,
    DATEDIFF(MAX(SaleDate), MIN(SaleDate)) AS SpanDays,
    COUNT(DISTINCT YEAR(SaleDate))          AS YearsCovered,
    'Expected: 2020-01-01 to 2025-12-31'   AS Expected
FROM sales_transactions;

-- ── 3. Quarter distribution ───────────────────────────────────
SELECT '=== QUARTER DISTRIBUTION (should be ~208 rows each) ===' AS Section;

SELECT
    YEAR(SaleDate)    AS SaleYear,
    QUARTER(SaleDate) AS SaleQuarter,
    COUNT(*)          AS Rows,
    CASE
        WHEN COUNT(*) BETWEEN 190 AND 230 THEN 'OK'
        ELSE 'CHECK - outside expected range'
    END               AS Status
FROM sales_transactions
GROUP BY SaleYear, SaleQuarter
ORDER BY SaleYear, SaleQuarter;

-- ── 4. Dimension integrity ────────────────────────────────────
SELECT '=== DIMENSION VALUES ===' AS Section;

SELECT 'Regions' AS Dimension,
       GROUP_CONCAT(DISTINCT Region ORDER BY Region SEPARATOR ' | ') AS Values
FROM sales_transactions

UNION ALL

SELECT 'Channels',
       GROUP_CONCAT(DISTINCT SalesChannel ORDER BY SalesChannel SEPARATOR ' | ')
FROM sales_transactions

UNION ALL

SELECT 'Segments',
       GROUP_CONCAT(DISTINCT CustomerSegment ORDER BY CustomerSegment SEPARATOR ' | ')
FROM customer_demographics

UNION ALL

SELECT 'Categories',
       GROUP_CONCAT(DISTINCT ProductCategory ORDER BY ProductCategory SEPARATOR ' | ')
FROM product_master;

-- ── 5. Join integrity check ───────────────────────────────────
SELECT '=== JOIN INTEGRITY ===' AS Section;

-- Orphan check: transactions with no matching product
SELECT
    'Transactions with no matching Product' AS Check_Name,
    COUNT(*) AS Count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL - check ProductID values' END AS Result
FROM sales_transactions t
LEFT JOIN product_master p ON t.ProductID = p.ProductID
WHERE p.ProductID IS NULL

UNION ALL

-- Orphan check: transactions with no matching customer
SELECT
    'Transactions with no matching Customer',
    COUNT(*),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL - check CustomerID values' END
FROM sales_transactions t
LEFT JOIN customer_demographics c ON t.CustomerID = c.CustomerID
WHERE c.CustomerID IS NULL;

-- ── 6. Grand total validation ─────────────────────────────────
SELECT '=== GRAND TOTAL VALIDATION ===' AS Section;

-- This proves the SUM() wrapper is necessary in Tableau
SELECT
    -- CORRECT: sum each row's profit first, then total
    ROUND(
        SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity), 2
    )                                       AS CorrectProfit,

    -- WRONG: what happens if Tableau uses raw field formula on totals
    ROUND(
        (SUM(t.UnitPrice) - SUM(IFNULL(p.CostPrice,0))) * SUM(t.Quantity), 2
    )                                       AS WrongFormula_DoNotUse,

    -- Difference %
    ROUND(
        ABS(
            ((SUM(t.UnitPrice) - SUM(IFNULL(p.CostPrice,0))) * SUM(t.Quantity))
            - SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity)
        )
        / SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity) * 100
    , 1)                                    AS ErrorPct

FROM sales_transactions t
LEFT JOIN product_master p ON t.ProductID = p.ProductID;

-- ── 7. Regional profit breakdown ─────────────────────────────
SELECT '=== PROFIT BY REGION (sum should equal grand total) ===' AS Section;

SELECT
    t.Region,
    ROUND(SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity), 2) AS Profit,
    ROUND(SUM(t.UnitPrice * t.Quantity), 2)                           AS GrossSales,
    ROUND(
        SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity)
        / SUM(t.UnitPrice * t.Quantity) * 100, 1
    )                                                                   AS MarginPct,
    COUNT(*)                                                            AS Transactions
FROM sales_transactions t
LEFT JOIN product_master p ON t.ProductID = p.ProductID
GROUP BY t.Region
ORDER BY Profit DESC

UNION ALL

SELECT
    'GRAND TOTAL',
    ROUND(SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity), 2),
    ROUND(SUM(t.UnitPrice * t.Quantity), 2),
    ROUND(SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity)
        / SUM(t.UnitPrice * t.Quantity) * 100, 1),
    COUNT(*)
FROM sales_transactions t
LEFT JOIN product_master p ON t.ProductID = p.ProductID;

-- ── 8. Top 10 products by revenue ────────────────────────────
SELECT '=== TOP 10 PRODUCTS BY REVENUE ===' AS Section;

SELECT
    t.ProductID,
    p.ProductName,
    p.ProductCategory,
    ROUND(SUM(t.UnitPrice * t.Quantity), 2) AS GrossSales,
    ROUND(SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity), 2) AS Profit,
    ROUND(
        SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity)
        / SUM(t.UnitPrice * t.Quantity) * 100, 1
    ) AS MarginPct
FROM sales_transactions t
LEFT JOIN product_master p ON t.ProductID = p.ProductID
GROUP BY t.ProductID, p.ProductName, p.ProductCategory
ORDER BY GrossSales DESC
LIMIT 10;

SELECT '=== VALIDATION COMPLETE ===' AS Section;
