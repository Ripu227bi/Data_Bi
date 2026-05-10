-- ============================================================
-- 05_load_customers_json.sql
-- Loads customer_demographics.json DIRECTLY into MySQL
-- using native MySQL 8.x JSON_TABLE() — no Python, no API
--
-- HOW IT WORKS:
--   Step 1: LOAD DATA INFILE reads the entire JSON file as one
--           text blob into a staging table (_json_staging)
--   Step 2: JSON_TABLE() shreds the JSON array into individual
--           rows and inserts them into customer_demographics
--   Step 3: Staging table is dropped
--
-- REQUIRES: MySQL 8.x (JSON_TABLE is not available in MySQL 5.x)
--
-- BEFORE RUNNING:
--   Copy customer_demographics.json to your secure_file_priv folder.
--   CHANGE THE FILE PATH BELOW to match your system.
-- ============================================================

USE sales_db;

-- ── Step 0: Create staging table ─────────────────────────────
-- This table temporarily holds the raw JSON text as a single row
DROP TABLE IF EXISTS _json_staging;
CREATE TABLE _json_staging (
    raw_json LONGTEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Step 1: Load the JSON file as raw text ───────────────────
-- FIELDS TERMINATED BY '\0' treats the whole file as one field
-- LINES TERMINATED BY '\0' treats the whole file as one row
-- This works because JSON arrays contain no null bytes

SET FOREIGN_KEY_CHECKS = 0;
SET autocommit         = 0;

TRUNCATE TABLE customer_demographics;

LOAD DATA INFILE
    'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customer_demographics.json'

INTO TABLE _json_staging

FIELDS
    TERMINATED BY   '\0'
    ENCLOSED BY     ''
LINES
    TERMINATED BY   '\0'

-- No header row to skip — JSON file has none
(raw_json);

COMMIT;

-- Verify staging received the JSON
SELECT
    LENGTH(raw_json)    AS JSONFileSize,
    LEFT(raw_json, 80)  AS Preview
FROM _json_staging;

-- ── Step 2: Parse JSON → rows using JSON_TABLE ───────────────
-- JSON_TABLE() is a MySQL 8.x native table-valued function
-- It maps each JSON array element [$[*]] to a table row
-- PATH expressions extract individual fields from each object

INSERT INTO customer_demographics
    (CustomerID, CustomerName, CustomerSegment, City, Country)

SELECT
    jt.CustomerID,
    jt.CustomerName,
    jt.CustomerSegment,
    jt.City,
    jt.Country

FROM _json_staging s,

-- JSON_TABLE syntax:
--   JSON_TABLE(json_column, path COLUMNS (col_name type PATH '$.field'))
-- '$[*]' iterates over every element in the top-level JSON array

JSON_TABLE(
    s.raw_json,
    '$[*]'                                      -- iterate each array element

    COLUMNS (
        CustomerID      VARCHAR(10)  PATH '$.CustomerID'
                                     ERROR ON ERROR   -- raise if key missing
                                     NULL  ON EMPTY,  -- use NULL if key absent

        CustomerName    VARCHAR(100) PATH '$.CustomerName'
                                     NULL ON ERROR
                                     NULL ON EMPTY,

        CustomerSegment VARCHAR(50)  PATH '$.CustomerSegment'
                                     NULL ON ERROR
                                     NULL ON EMPTY,

        City            VARCHAR(100) PATH '$.City'
                                     NULL ON ERROR
                                     NULL ON EMPTY,

        Country         VARCHAR(100) PATH '$.Country'
                                     NULL ON ERROR
                                     NULL ON EMPTY
    )
) AS jt

-- Skip rows with NULL CustomerID (malformed JSON elements)
WHERE jt.CustomerID IS NOT NULL;

COMMIT;

SET FOREIGN_KEY_CHECKS = 1;

-- ── Step 3: Drop staging table ───────────────────────────────
DROP TABLE IF EXISTS _json_staging;

-- ── Step 4: Verify ───────────────────────────────────────────
SELECT
    COUNT(*)                        AS TotalCustomers,
    COUNT(DISTINCT CustomerSegment) AS Segments,
    COUNT(DISTINCT Country)         AS Countries
FROM customer_demographics;

-- Segment breakdown
SELECT
    CustomerSegment,
    COUNT(*)            AS Customers,
    GROUP_CONCAT(DISTINCT Country ORDER BY Country SEPARATOR ', ') AS Countries
FROM customer_demographics
GROUP BY CustomerSegment
ORDER BY CustomerSegment;

-- Expected:
-- TotalCustomers: 120 | Segments: 3 | Countries: 6
