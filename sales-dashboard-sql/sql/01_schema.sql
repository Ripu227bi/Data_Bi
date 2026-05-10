-- ============================================================
-- 01_schema.sql
-- Creates sales_db database and all three tables
-- Run BEFORE loading any data
-- ============================================================

CREATE DATABASE IF NOT EXISTS sales_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE sales_db;

-- ── Fact table: sales_transactions ───────────────────────────
DROP TABLE IF EXISTS sales_transactions;
CREATE TABLE sales_transactions (
    TransactionID   INT             NOT NULL COMMENT 'Unique transaction key',
    ProductID       VARCHAR(10)     NOT NULL COMMENT 'FK → product_master',
    CustomerID      VARCHAR(10)     NOT NULL COMMENT 'FK → customer_demographics',
    SaleDate        DATE            NOT NULL COMMENT 'Transaction date YYYY-MM-DD',
    Quantity        INT             NOT NULL COMMENT 'Units sold',
    UnitPrice       DECIMAL(10,2)   NOT NULL COMMENT 'Selling price per unit',
    Region          VARCHAR(50)     NULL     COMMENT 'North America / Europe / Asia',
    SalesChannel    VARCHAR(50)     NULL     COMMENT 'Online / Retail Store / Partner'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Fact table: 5,000 transactions 2020-2025';

-- ── Dimension: product_master ─────────────────────────────────
DROP TABLE IF EXISTS product_master;
CREATE TABLE product_master (
    ProductID           VARCHAR(10)     NOT NULL COMMENT 'P001–P020',
    ProductName         VARCHAR(100)    NULL,
    ProductCategory     VARCHAR(50)     NULL     COMMENT 'Electronics / Home Goods / Apparel',
    ProductSubcategory  VARCHAR(50)     NULL,
    CostPrice           DECIMAL(10,2)   NULL     COMMENT 'CONFIDENTIAL — Finance role only'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Dimension: customer_demographics ─────────────────────────
DROP TABLE IF EXISTS customer_demographics;
CREATE TABLE customer_demographics (
    CustomerID          VARCHAR(10)     NOT NULL COMMENT 'C101–C220',
    CustomerName        VARCHAR(100)    NULL,
    CustomerSegment     VARCHAR(50)     NULL     COMMENT 'High-Value / Regular / New',
    City                VARCHAR(100)    NULL,
    Country             VARCHAR(100)    NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SELECT 'Schema created successfully' AS Result;
