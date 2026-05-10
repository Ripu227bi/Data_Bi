-- ============================================================
-- 07_custom_source_query.sql
-- Tableau Custom SQL Data Source
--
-- HOW TO USE IN TABLEAU:
--   1. Connect → MySQL → sign in with bi_reader credentials
--   2. On the Data Source canvas: drag "New Custom SQL"
--   3. Paste the SELECT statement below (the part after the dashes)
--   4. Click OK → switch to Extract mode
--
-- WHY CUSTOM SQL INSTEAD OF DRAG-AND-DROP JOIN:
--   - Join computation runs at MySQL level (faster)
--   - Pre-computed GrossSales and Profit reduce Tableau calc load
--   - Derived date columns (SaleYear, SaleQuarter) available as
--     plain dimensions without needing Tableau date functions
-- ============================================================

-- ══════════════════════════════════════════════════════════════
-- PASTE THIS INTO TABLEAU'S "NEW CUSTOM SQL" DIALOG
-- ══════════════════════════════════════════════════════════════

SELECT
    -- Transaction identifiers
    t.TransactionID,
    t.SaleDate,

    -- Derived date dimensions (avoids repeated YEAR()/QUARTER() in Tableau)
    YEAR(t.SaleDate)                                         AS SaleYear,
    QUARTER(t.SaleDate)                                      AS SaleQuarter,
    CONCAT('Q', QUARTER(t.SaleDate), ' ', YEAR(t.SaleDate)) AS QuarterLabel,
    MONTHNAME(t.SaleDate)                                    AS MonthName,
    MONTH(t.SaleDate)                                        AS MonthNum,
    DAYNAME(t.SaleDate)                                      AS DayOfWeek,

    -- Sales dimensions
    t.Region,
    t.SalesChannel,
    t.Quantity,
    t.UnitPrice,

    -- Product dimensions
    p.ProductID,
    p.ProductName,
    p.ProductCategory,
    p.ProductSubcategory,
    p.CostPrice,

    -- Customer dimensions
    c.CustomerID,
    c.CustomerName,
    c.CustomerSegment,
    c.City,
    c.Country,

    -- Pre-computed metrics (pushed to MySQL engine — reduces Tableau calc overhead)
    -- NOTE: These are row-level values.
    -- Tableau calculated fields still use SUM() for correct aggregation.
    (t.Quantity * t.UnitPrice)                               AS GrossSales,
    ((t.UnitPrice - IFNULL(p.CostPrice, 0)) * t.Quantity)   AS Profit,
    (IFNULL(p.CostPrice, 0) * t.Quantity)                    AS TotalCost

FROM sales_transactions t

-- LEFT JOIN preserves all transactions even if product/customer not found
LEFT JOIN product_master        p ON t.ProductID  = p.ProductID
LEFT JOIN customer_demographics c ON t.CustomerID = c.CustomerID

ORDER BY t.SaleDate, t.TransactionID;

-- ══════════════════════════════════════════════════════════════
-- AFTER CONNECTING IN TABLEAU:
--   1. Switch connection mode: Live → Extract (top-right toggle)
--   2. Click Sheet 1 → Tableau builds the extract
--   3. Create calculated fields (see tableau/calculated_fields/)
--   4. Right-click data source → Extract → Refresh to update data
-- ══════════════════════════════════════════════════════════════
