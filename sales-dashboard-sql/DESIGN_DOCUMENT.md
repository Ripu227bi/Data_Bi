# Sales Performance Dashboard — Design Document

> SQL-only edition. No Python. JSON loaded directly via MySQL `JSON_TABLE()`.  
> See `docs/Tableau_Dashboard_Design_Document.docx` for the full formatted Word version.

---

## 1. Data Pipeline — SQL Flow

```
data/raw/
  sales_transactions.csv      ──► 03_load_transactions.sql  ──► sales_transactions table
  product_master.csv           ──► 04_load_products.sql      ──► product_master table
  customer_demographics.json   ──► 05_load_customers_json.sql ──► customer_demographics table
                                    (via JSON_TABLE — no Python)
```

**Run order:**
```
00_run_all.sql   ← runs everything below in sequence
  01_schema.sql
  02_create_bi_user.sql
  03_load_transactions.sql
  04_load_products.sql
  05_load_customers_json.sql
  06_add_indexes.sql
  08_validate.sql
```

---

## 2. JSON Loading Technique (MySQL 8.x)

The JSON file is loaded **directly into MySQL** in two SQL steps — no Python, no API:

**Step 1 — Load raw JSON as a single text blob:**
```sql
CREATE TABLE _json_staging (raw_json LONGTEXT);

LOAD DATA INFILE 'path/customer_demographics.json'
INTO TABLE _json_staging
FIELDS TERMINATED BY '\0'
LINES TERMINATED BY '\0';
```

**Step 2 — Shred JSON array → rows using JSON_TABLE:**
```sql
INSERT INTO customer_demographics (CustomerID, CustomerName, CustomerSegment, City, Country)
SELECT jt.*
FROM _json_staging s,
JSON_TABLE(
    s.raw_json, '$[*]'
    COLUMNS (
        CustomerID      VARCHAR(10)  PATH '$.CustomerID',
        CustomerName    VARCHAR(100) PATH '$.CustomerName',
        CustomerSegment VARCHAR(50)  PATH '$.CustomerSegment',
        City            VARCHAR(100) PATH '$.City',
        Country         VARCHAR(100) PATH '$.Country'
    )
) AS jt;
```

> Requires **MySQL 8.x** — `JSON_TABLE()` is not available in MySQL 5.x.

---

## 3. Star Schema

```
product_master              customer_demographics
  ProductID ◄──────────┐  ┌──────────► CustomerID
  ProductCategory       │  │            CustomerSegment
  ProductSubcategory    │  │            City / Country
  CostPrice             │  │
                        │  │
            sales_transactions  (FACT)
              TransactionID
              ProductID  ──► product_master
              CustomerID ──► customer_demographics
              SaleDate
              Quantity · UnitPrice · Region · SalesChannel
```

**Tableau connection:** Relationship canvas (not Join) — preserves row-level context.

---

## 4. Calculated Fields

> ⚠️ Always wrap multiplications in `SUM()` — unwrapped formulas give wrong grand totals.

| Field | Formula |
|---|---|
| Gross Sales | `SUM([UnitPrice] * [Quantity])` |
| Profit | `SUM(([UnitPrice] - IFNULL([CostPrice],0)) * [Quantity])` |
| Profit Margin % | `SUM([Profit]) / SUM([Gross Sales]) * 100` |
| Avg Order Value | `SUM([Gross Sales]) / COUNTD([TransactionID])` |
| Dynamic Date | `IF [Date Granularity]="Year" THEN DATETRUNC('year',[SaleDate]) ELSEIF...` |
| In Top N | `RANK(SUM([GrossSales]),'desc') <= [Top N]` |

---

## 5. Dashboard Layout

```
┌─────────────────────────────────────────────────────────┐
│  FILTERS: Year | Region | Channel | Segment | Category  │
├──────────┬──────────┬──────────┬────────────────────────┤
│ KPI      │ KPI      │ KPI      │ KPI Avg Order          │
│ Sales    │ Profit   │ Margin % │ BAN + Sparkline        │
├──────────┴──────────┴──────────┴────────────────────────┤
│       TREND CHART — Dual axis: Sales area + Profit line  │
│       X: Dynamic Date   Granularity toggle: Y/Q/M        │
├──────────────────────┬──────────────────────────────────┤
│  Sales by Region     │  Sales by Channel                 │
│  Stacked bar         │  Horizontal bar + margin line     │
├──────────────────────┼──────────────────────────────────┤
│  Category Treemap    │  Segment Donut + Segment Bar      │
│  Size=Sales          │  Share % + margin efficiency      │
│  Color=Margin        │                                   │
└──────────────────────┴──────────────────────────────────┘
```

**Dashboard settings:** Fixed 1200×800 | Fit mode: Standard | Mode: Extract

---

## 6. Color System

| Hex | Used For |
|---|---|
| `#378ADD` | Gross Sales · North America · Online · High-Value |
| `#1D9E75` | Profit · Europe · Retail Store · Regular |
| `#BA7517` | Margin % · Asia · Partner · New |
| `#C0392B` | Negative YoY delta only |
| `#1A3A5C` | Headings and primary text |

---

## 7. Security

```sql
-- bi_reader: SELECT only — never expose root to Tableau
GRANT SELECT ON sales_db.* TO 'bi_reader'@'%';

-- Required auth plugin for Tableau ODBC compatibility
IDENTIFIED WITH mysql_native_password BY 'BIread2024!';
```
