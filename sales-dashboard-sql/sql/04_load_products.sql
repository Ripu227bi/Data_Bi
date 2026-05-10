-- ============================================================
-- 04_load_products.sql
-- Bulk loads product_master.csv into MySQL
--
-- BEFORE RUNNING:
--   Copy product_master.csv to your secure_file_priv folder.
--   CHANGE THE FILE PATH BELOW to match your system.
-- ============================================================

USE sales_db;

SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS      = 0;
SET autocommit         = 0;

TRUNCATE TABLE product_master;

LOAD DATA INFILE
    'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/product_master.csv'

INTO TABLE product_master

FIELDS
    TERMINATED BY   ','
    ENCLOSED BY     '"'
LINES
    TERMINATED BY   '\n'

IGNORE 1 ROWS

(
    ProductID,
    ProductName,
    ProductCategory,
    ProductSubcategory,
    CostPrice
);

COMMIT;

SET FOREIGN_KEY_CHECKS = 1;
SET UNIQUE_CHECKS      = 1;

-- ── Verify ───────────────────────────────────────────────────
SELECT
    COUNT(*)                        AS TotalProducts,
    COUNT(DISTINCT ProductCategory) AS Categories,
    COUNT(DISTINCT ProductSubcategory) AS Subcategories,
    MIN(CostPrice)                  AS MinCost,
    MAX(CostPrice)                  AS MaxCost
FROM product_master;

-- Breakdown by category
SELECT
    ProductCategory,
    COUNT(*) AS Products,
    MIN(CostPrice) AS MinCost,
    MAX(CostPrice) AS MaxCost
FROM product_master
GROUP BY ProductCategory
ORDER BY ProductCategory;
