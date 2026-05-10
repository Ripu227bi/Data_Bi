-- ============================================================
-- 03_load_transactions.sql
-- Bulk loads sales_transactions.csv into MySQL
--
-- BEFORE RUNNING:
--   Copy sales_transactions.csv to your secure_file_priv folder.
--   Find the path: SHOW VARIABLES LIKE 'secure_file_priv';
--
-- Update the file path below to match your system.
-- ============================================================

USE sales_db;

-- ── Performance settings — disable per-row overhead ──────────
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS      = 0;
SET autocommit         = 0;

-- ── Truncate before reload (safe to re-run) ──────────────────
TRUNCATE TABLE sales_transactions;

-- ── LOAD DATA INFILE ─────────────────────────────────────────
-- Windows path example:
--   'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/sales_transactions.csv'
-- Mac/Linux path example:
--   '/var/lib/mysql-files/sales_transactions.csv'
--
-- CHANGE THE PATH BELOW TO MATCH YOUR MACHINE:

LOAD DATA INFILE
    'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/sales_transactions.csv'

INTO TABLE sales_transactions

-- CSV format settings
FIELDS
    TERMINATED BY   ','
    ENCLOSED BY     '"'
LINES
    TERMINATED BY   '\n'

IGNORE 1 ROWS   -- skips the header row

-- Column mapping
-- @sale_date is a user variable — converted from string to DATE below
(
    TransactionID,
    ProductID,
    CustomerID,
    @sale_date,
    Quantity,
    UnitPrice,
    Region,
    SalesChannel
)

-- Convert string date to MySQL DATE type
SET
    SaleDate = STR_TO_DATE(@sale_date, '%Y-%m-%d');

-- ── Commit all rows in one transaction ───────────────────────
COMMIT;

-- ── Restore settings ─────────────────────────────────────────
SET FOREIGN_KEY_CHECKS = 1;
SET UNIQUE_CHECKS      = 1;

-- ── Verify ───────────────────────────────────────────────────
SELECT
    COUNT(*)                    AS TotalRows,
    MIN(SaleDate)               AS EarliestDate,
    MAX(SaleDate)               AS LatestDate,
    COUNT(DISTINCT Region)      AS Regions,
    COUNT(DISTINCT SalesChannel) AS Channels,
    COUNT(DISTINCT ProductID)   AS Products,
    COUNT(DISTINCT CustomerID)  AS Customers
FROM sales_transactions;

-- Expected:
-- TotalRows: 5000 | EarliestDate: 2020-01-01 | LatestDate: 2025-12-31
-- Regions: 3 | Channels: 3 | Products: 20 | Customers: 120
