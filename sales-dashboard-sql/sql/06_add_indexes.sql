-- ============================================================
-- 06_add_indexes.sql
-- Adds primary keys and performance indexes AFTER bulk load
--
-- WHY AFTER LOAD (not before):
--   Adding indexes before inserting data means MySQL rebuilds
--   the index after every single row — up to 100x slower.
--   Adding them after load builds the index once over all rows.
-- ============================================================

USE sales_db;

-- ── sales_transactions ───────────────────────────────────────
ALTER TABLE sales_transactions
    ADD PRIMARY KEY (TransactionID);

CREATE INDEX idx_product  ON sales_transactions (ProductID);
CREATE INDEX idx_customer ON sales_transactions (CustomerID);
CREATE INDEX idx_date     ON sales_transactions (SaleDate);
CREATE INDEX idx_region   ON sales_transactions (Region);
CREATE INDEX idx_channel  ON sales_transactions (SalesChannel);

-- Composite index — optimises the Tableau Custom SQL join query
CREATE INDEX idx_join_combo ON sales_transactions (ProductID, CustomerID, SaleDate);

-- ── product_master ────────────────────────────────────────────
ALTER TABLE product_master
    ADD PRIMARY KEY (ProductID);

CREATE INDEX idx_prod_cat ON product_master (ProductCategory);
CREATE INDEX idx_prod_sub ON product_master (ProductSubcategory);

-- ── customer_demographics ─────────────────────────────────────
ALTER TABLE customer_demographics
    ADD PRIMARY KEY (CustomerID);

CREATE INDEX idx_cust_seg     ON customer_demographics (CustomerSegment);
CREATE INDEX idx_cust_country ON customer_demographics (Country);

-- ── Verify indexes ───────────────────────────────────────────
SHOW INDEX FROM sales_transactions;
SHOW INDEX FROM product_master;
SHOW INDEX FROM customer_demographics;

-- ── Analyse tables (updates query planner statistics) ────────
ANALYZE TABLE sales_transactions;
ANALYZE TABLE product_master;
ANALYZE TABLE customer_demographics;

SELECT 'All indexes created and tables analysed' AS Result;
