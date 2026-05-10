-- ============================================================
-- 00_run_all.sql
-- MASTER SCRIPT — runs all scripts in correct order
--
-- BEFORE RUNNING:
--   1. Set @data_path to your MySQL secure_file_priv folder
--      Run: SHOW VARIABLES LIKE 'secure_file_priv';
--   2. Copy these files into that folder:
--        sales_transactions.csv
--        product_master.csv
--        customer_demographics.json
--   3. Run this entire script as root in MySQL Workbench
-- ============================================================

-- ── CONFIGURE YOUR DATA PATH HERE ────────────────────────────
-- Windows example: 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/'
-- Mac/Linux example: '/var/lib/mysql-files/'
SET @data_path = 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/';

-- ──────────────────────────────────────────────────────────────
-- PHASE 1: Create database and tables
-- ──────────────────────────────────────────────────────────────
SELECT '>>> PHASE 1: Creating schema...' AS Status;

CREATE DATABASE IF NOT EXISTS sales_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE sales_db;

-- Fact table
DROP TABLE IF EXISTS sales_transactions;
CREATE TABLE sales_transactions (
    TransactionID   INT             NOT NULL,
    ProductID       VARCHAR(10)     NOT NULL,
    CustomerID      VARCHAR(10)     NOT NULL,
    SaleDate        DATE            NOT NULL,
    Quantity        INT             NOT NULL,
    UnitPrice       DECIMAL(10,2)   NOT NULL,
    Region          VARCHAR(50),
    SalesChannel    VARCHAR(50)
);

-- Dimension: product
DROP TABLE IF EXISTS product_master;
CREATE TABLE product_master (
    ProductID           VARCHAR(10)     NOT NULL,
    ProductName         VARCHAR(100),
    ProductCategory     VARCHAR(50),
    ProductSubcategory  VARCHAR(50),
    CostPrice           DECIMAL(10,2)
);

-- Dimension: customer (staging + final)
DROP TABLE IF EXISTS customer_demographics;
CREATE TABLE customer_demographics (
    CustomerID          VARCHAR(10)     NOT NULL,
    CustomerName        VARCHAR(100),
    CustomerSegment     VARCHAR(50),
    City                VARCHAR(100),
    Country             VARCHAR(100)
);

-- JSON staging table (temporary — used only during load)
DROP TABLE IF EXISTS _json_staging;
CREATE TABLE _json_staging (raw_json LONGTEXT);

SELECT '>>> Schema created OK' AS Status;

-- ──────────────────────────────────────────────────────────────
-- PHASE 2: Create BI user
-- ──────────────────────────────────────────────────────────────
SELECT '>>> PHASE 2: Creating bi_reader user...' AS Status;

DROP USER IF EXISTS 'bi_reader'@'%';

CREATE USER 'bi_reader'@'%'
  IDENTIFIED WITH mysql_native_password
  BY 'BIread2024!';

GRANT SELECT ON sales_db.* TO 'bi_reader'@'%';
FLUSH PRIVILEGES;

SELECT '>>> bi_reader user created OK' AS Status;

-- ──────────────────────────────────────────────────────────────
-- PHASE 3: Bulk load — disable overhead
-- ──────────────────────────────────────────────────────────────
SELECT '>>> PHASE 3: Loading data...' AS Status;

SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS      = 0;
SET autocommit         = 0;

-- ── Load sales_transactions.csv ───────────────────────────────
SET @sql_transactions = CONCAT(
  "LOAD DATA INFILE '", @data_path, "sales_transactions.csv' ",
  "INTO TABLE sales_transactions ",
  "FIELDS TERMINATED BY ',' ENCLOSED BY '\"' ",
  "LINES TERMINATED BY '\\n' ",
  "IGNORE 1 ROWS ",
  "(TransactionID, ProductID, CustomerID, ",
  " @sale_date, Quantity, UnitPrice, Region, SalesChannel) ",
  "SET SaleDate = STR_TO_DATE(@sale_date, '%Y-%m-%d')"
);
PREPARE stmt FROM @sql_transactions;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
COMMIT;

SELECT CONCAT('>>> sales_transactions loaded: ', COUNT(*), ' rows') AS Status
FROM sales_transactions;

-- ── Load product_master.csv ───────────────────────────────────
SET @sql_products = CONCAT(
  "LOAD DATA INFILE '", @data_path, "product_master.csv' ",
  "INTO TABLE product_master ",
  "FIELDS TERMINATED BY ',' ENCLOSED BY '\"' ",
  "LINES TERMINATED BY '\\n' ",
  "IGNORE 1 ROWS ",
  "(ProductID, ProductName, ProductCategory, ProductSubcategory, CostPrice)"
);
PREPARE stmt FROM @sql_products;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
COMMIT;

SELECT CONCAT('>>> product_master loaded: ', COUNT(*), ' rows') AS Status
FROM product_master;

-- ── Load customer_demographics.json ───────────────────────────
-- MySQL 8.x JSON_TABLE approach:
-- Step 1: load entire JSON file as a single text blob into staging
-- Step 2: use JSON_TABLE to shred the JSON array into rows

SET @sql_json_load = CONCAT(
  "LOAD DATA INFILE '", @data_path, "customer_demographics.json' ",
  "INTO TABLE _json_staging ",
  "FIELDS TERMINATED BY '\\0' ",
  "LINES TERMINATED BY '\\0'"
);
PREPARE stmt FROM @sql_json_load;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
COMMIT;

-- Step 2: Parse JSON array → rows using JSON_TABLE (MySQL 8.x native)
INSERT INTO customer_demographics
  (CustomerID, CustomerName, CustomerSegment, City, Country)
SELECT
    j.CustomerID,
    j.CustomerName,
    j.CustomerSegment,
    j.City,
    j.Country
FROM _json_staging s,
JSON_TABLE(
    s.raw_json,
    '$[*]'
    COLUMNS (
        CustomerID      VARCHAR(10)  PATH '$.CustomerID'      DEFAULT NULL ON ERROR,
        CustomerName    VARCHAR(100) PATH '$.CustomerName'    DEFAULT NULL ON ERROR,
        CustomerSegment VARCHAR(50)  PATH '$.CustomerSegment' DEFAULT NULL ON ERROR,
        City            VARCHAR(100) PATH '$.City'            DEFAULT NULL ON ERROR,
        Country         VARCHAR(100) PATH '$.Country'         DEFAULT NULL ON ERROR
    )
) AS j;

COMMIT;

-- Clean up staging table
DROP TABLE IF EXISTS _json_staging;

SELECT CONCAT('>>> customer_demographics loaded: ', COUNT(*), ' rows') AS Status
FROM customer_demographics;

-- ── Restore settings ──────────────────────────────────────────
SET FOREIGN_KEY_CHECKS = 1;
SET UNIQUE_CHECKS      = 1;

-- ──────────────────────────────────────────────────────────────
-- PHASE 4: Add indexes AFTER load (faster this way)
-- ──────────────────────────────────────────────────────────────
SELECT '>>> PHASE 4: Adding indexes...' AS Status;

ALTER TABLE sales_transactions ADD PRIMARY KEY (TransactionID);
CREATE INDEX idx_product  ON sales_transactions(ProductID);
CREATE INDEX idx_customer ON sales_transactions(CustomerID);
CREATE INDEX idx_date     ON sales_transactions(SaleDate);
CREATE INDEX idx_region   ON sales_transactions(Region);
CREATE INDEX idx_channel  ON sales_transactions(SalesChannel);

ALTER TABLE product_master       ADD PRIMARY KEY (ProductID);
ALTER TABLE customer_demographics ADD PRIMARY KEY (CustomerID);

SELECT '>>> Indexes created OK' AS Status;

-- ──────────────────────────────────────────────────────────────
-- PHASE 5: Validate
-- ──────────────────────────────────────────────────────────────
SELECT '>>> PHASE 5: Validation...' AS Status;

-- Row counts
SELECT 'sales_transactions'  AS TableName, COUNT(*) AS RowCount FROM sales_transactions
UNION ALL
SELECT 'product_master'      AS TableName, COUNT(*) AS RowCount FROM product_master
UNION ALL
SELECT 'customer_demographics' AS TableName, COUNT(*) AS RowCount FROM customer_demographics;

-- Quarter distribution
SELECT
    YEAR(SaleDate)    AS Year,
    QUARTER(SaleDate) AS Quarter,
    COUNT(*)          AS Rows
FROM sales_transactions
GROUP BY YEAR(SaleDate), QUARTER(SaleDate)
ORDER BY Year, Quarter;

-- Grand total validation
SELECT
    SUM((t.UnitPrice - IFNULL(p.CostPrice,0)) * t.Quantity) AS CorrectProfit,
    (SUM(t.UnitPrice) - SUM(IFNULL(p.CostPrice,0))) * SUM(t.Quantity) AS WrongFormula_DoNotUse
FROM sales_transactions t
LEFT JOIN product_master p ON t.ProductID = p.ProductID;

SELECT '>>> ALL DONE — database ready for Tableau connection' AS Status;
