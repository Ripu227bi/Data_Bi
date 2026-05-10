-- ============================================================
-- 02_create_bi_user.sql
-- Creates a read-only BI user for Tableau and Qlik connections
-- Run as root AFTER 01_schema.sql
-- ============================================================

USE sales_db;

-- Drop if exists (safe to re-run)
DROP USER IF EXISTS 'bi_reader'@'%';

-- Create with mysql_native_password
-- Required for Tableau ODBC and Qlik REST connectors
-- caching_sha2_password (MySQL 8 default) causes SSL auth errors
CREATE USER 'bi_reader'@'%'
  IDENTIFIED WITH mysql_native_password
  BY 'BIread2024!';

-- Grant SELECT only — never INSERT, UPDATE, DELETE, DROP
GRANT SELECT ON sales_db.* TO 'bi_reader'@'%';

FLUSH PRIVILEGES;

-- ── Verify ───────────────────────────────────────────────────
SELECT
    user        AS User,
    host        AS Host,
    plugin      AS AuthPlugin
FROM mysql.user
WHERE user = 'bi_reader';

-- Expected: bi_reader | % | mysql_native_password

SHOW GRANTS FOR 'bi_reader'@'%';
-- Expected: GRANT SELECT ON `sales_db`.* TO `bi_reader`@`%`
