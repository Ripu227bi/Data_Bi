# Changelog — Sales Performance Dashboard (SQL Edition)

## [1.0.0] — 2025-05-10

### Added
- Full SQL-only data pipeline — no Python or API required
- `00_run_all.sql` master script runs all phases in one click
- `01_schema.sql` — full DDL with data types and comments
- `02_create_bi_user.sql` — bi_reader user with SELECT only
- `03_load_transactions.sql` — LOAD DATA INFILE for 5,000 rows CSV
- `04_load_products.sql` — LOAD DATA INFILE for product master CSV
- `05_load_customers_json.sql` — JSON loaded directly via JSON_TABLE() (MySQL 8.x native, no Python)
- `06_add_indexes.sql` — all indexes added AFTER bulk load for speed
- `07_custom_source_query.sql` — Tableau Custom SQL with pre-joined star schema
- `08_validate.sql` — row counts, quarter distribution, join integrity, grand total proof
- `tests/validate_totals.sql` — proves why SUM() wrapper is required
- 3 raw data files: sales_transactions.csv, product_master.csv, customer_demographics.json
- 6 Tableau calculated field definitions

### Key Design Decisions
- JSON loaded using MySQL 8.x `JSON_TABLE()` — no external tools needed
- Indexes created AFTER bulk load (~10x faster than before)
- `SET autocommit=0` wraps all inserts in single transaction
- `mysql_native_password` auth avoids caching_sha2_password SSL error
- UnitPrice stored as DECIMAL(10,2) — prevents floating-point errors
