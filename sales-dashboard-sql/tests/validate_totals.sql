-- ============================================================
-- tests/validate_totals.sql
-- Proves why the SUM() wrapper is required in Tableau
-- calculated fields to get correct grand totals
--
-- Run in MySQL Workbench after all data is loaded
-- ============================================================

USE sales_db;

SELECT '=== GRAND TOTAL PROOF ===' AS Test;

-- Shows the difference between:
--   CORRECT: SUM each row's profit → then total
--   WRONG:   Apply formula to pre-aggregated column totals
SELECT
    ROUND(
        SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity), 2
    )                           AS CorrectProfit,

    ROUND(
        (SUM(t.UnitPrice) - SUM(IFNULL(p.CostPrice,0))) * SUM(t.Quantity), 2
    )                           AS WrongFormula,

    ROUND(
        ABS(
            ((SUM(t.UnitPrice) - SUM(IFNULL(p.CostPrice,0))) * SUM(t.Quantity))
            - SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity)
        ) / SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity) * 100, 1
    )                           AS ErrorPct,

    'Use SUM(([UnitPrice]-IFNULL([CostPrice],0))*[Quantity]) in Tableau'
                                AS TableauFormula

FROM sales_transactions t
LEFT JOIN product_master p ON t.ProductID = p.ProductID;


SELECT '=== VERIFY SUM OF REGIONS = GRAND TOTAL ===' AS Test;

-- Each region's profit should sum to exactly the grand total
SELECT
    t.Region,
    ROUND(SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity), 2) AS Profit
FROM sales_transactions t
LEFT JOIN product_master p ON t.ProductID = p.ProductID
GROUP BY t.Region WITH ROLLUP;
-- WITH ROLLUP adds a grand total row automatically
