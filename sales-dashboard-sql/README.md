# 📊 Sales Performance Dashboard — Tableau
### SQL-Only Data Load Edition (No Python / No API required)

> **BI Lead Case Study** | Design & Development Lifecycle  
> Tool: Tableau Desktop | Database: MySQL 8.x

---

## 📁 Repository Structure

```
sales-dashboard-sql/
│
├── README.md                              ← You are here
├── DESIGN_DOCUMENT.md                     ← Full technical design spec
├── CHANGELOG.md                           ← Version history
├── .gitignore
│
├── data/
│   ├── raw/
│   │   ├── sales_transactions.csv         ← 5,000 rows, 2020–2025
│   │   ├── product_master.csv             ← 20 products
│   │   └── customer_demographics.json     ← 120 customers (JSON)
│   └── processed/
│       └── customer_demographics.csv      ← JSON converted to CSV for SQL
│
├── sql/
│   ├── 00_run_all.sql                     ← Master script — runs everything in order
│   ├── 01_schema.sql                      ← CREATE TABLE + indexes
│   ├── 02_create_bi_user.sql              ← Read-only BI user setup
│   ├── 03_load_transactions.sql           ← LOAD DATA INFILE (CSV)
│   ├── 04_load_products.sql               ← LOAD DATA INFILE (CSV)
│   ├── 05_load_customers_json.sql         ← Load JSON using JSON_TABLE()
│   ├── 06_add_indexes.sql                 ← Add indexes AFTER bulk load
│   ├── 07_custom_source_query.sql         ← Tableau Custom SQL source
│   └── 08_validate.sql                    ← Row counts + grand total check
│
├── tableau/
│   └── calculated_fields/
│       ├── gross_sales.txt
│       ├── profit.txt
│       ├── profit_margin_pct.txt
│       ├── dynamic_date.txt
│       ├── yoy_growth_pct.txt
│       └── in_top_n.txt
│
├── tests/
│   └── validate_totals.sql               ← Grand total correctness proof
│
└── docs/
    └── Tableau_Dashboard_Design_Document.docx
```

---

## 🚀 Setup — Step by Step

### Prerequisites
- MySQL 8.x Community Server running on `localhost:3306`
- MySQL Workbench (for GUI) OR MySQL CLI
- Tableau Desktop (Free Edition or Trial)

---

### Step 1 — Copy data files to MySQL's secure folder

MySQL's `LOAD DATA INFILE` requires files to be in the `secure_file_priv` directory.

**Find your secure folder:**
```sql
SHOW VARIABLES LIKE 'secure_file_priv';
-- Returns something like: C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\
```

**Copy these files to that folder:**
```
data/raw/sales_transactions.csv   → MySQL Uploads folder
data/raw/product_master.csv       → MySQL Uploads folder
data/raw/customer_demographics.json → MySQL Uploads folder
```

> On Windows: `C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\`  
> On Mac: `/var/lib/mysql-files/`

---

### Step 2 — Run the master SQL script

Open MySQL Workbench → connect as root → open `sql/00_run_all.sql`

**Update the file path variable at the top of `00_run_all.sql`:**
```sql
SET @data_path = 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/';
```

Then click **Run All (⚡)**. This executes all scripts in order:

| Script | Action |
|---|---|
| `01_schema.sql` | Creates database and all three tables |
| `02_create_bi_user.sql` | Creates bi_reader user with SELECT only |
| `03_load_transactions.sql` | Bulk loads 5,000 transactions from CSV |
| `04_load_products.sql` | Loads 20 products from CSV |
| `05_load_customers_json.sql` | Loads 120 customers from JSON via JSON_TABLE |
| `06_add_indexes.sql` | Adds all indexes after load |
| `08_validate.sql` | Confirms row counts and grand totals |

---

### Step 3 — Connect Tableau to MySQL

| Setting | Value |
|---|---|
| Connector | MySQL (native) |
| Server | `127.0.0.1` |
| Port | `3306` |
| Database | `sales_db` |
| Username | `bi_reader` |
| Password | `BIread2024!` |

Paste `sql/07_custom_source_query.sql` into Tableau's **New Custom SQL** dialog.

---

## 🔑 Calculated Fields

Create these in Tableau **before** building any chart (Data pane → right-click → Create Calculated Field):

| Field | Formula |
|---|---|
| Gross Sales | `SUM([UnitPrice] * [Quantity])` |
| Profit | `SUM(([UnitPrice] - IFNULL([CostPrice],0)) * [Quantity])` |
| Profit Margin % | `SUM([Profit]) / SUM([Gross Sales]) * 100` |
| Avg Order Value | `SUM([Gross Sales]) / COUNTD([TransactionID])` |

> ⚠️ **Never write** `([UnitPrice]-[CostPrice])*[Quantity]` without `SUM()` — grand totals will be wrong.

---

## 🛡️ Security

- `bi_reader` has **SELECT only** on `sales_db` — never expose root credentials to Tableau
- Use `.env` file for any scripts (not committed to Git)
- `CostPrice` is confidential — restrict in Tableau Server RLS

---

## 🐛 Common Issues

| Issue | Fix |
|---|---|
| `ERROR 1290: secure_file_priv` | Move CSV/JSON files to the path shown by `SHOW VARIABLES LIKE 'secure_file_priv'` |
| `Incorrect decimal value` | Use the provided CSVs — UnitPrice is pre-formatted to 2 decimal places |
| `caching_sha2_password auth error` | Script `02_create_bi_user.sql` uses `mysql_native_password` — re-run it |
| Bars stretched in Tableau | Toolbar → Fit dropdown → change to **Standard** |
| Grand total wrong | Wrap formula in `SUM()` — see `tableau/calculated_fields/profit.txt` |

---

## 📋 Reviewer Checklist

```
[ ] SHOW VARIABLES LIKE 'secure_file_priv' returns a valid path
[ ] All 3 data files copied to secure_file_priv folder
[ ] 00_run_all.sql completes without errors
[ ] SELECT COUNT(*) FROM sales_transactions returns 5,000
[ ] SELECT COUNT(*) FROM product_master returns 20
[ ] SELECT COUNT(*) FROM customer_demographics returns 120
[ ] bi_reader user: SHOW GRANTS shows SELECT only
[ ] Tableau connects using bi_reader credentials
[ ] Grand total in 08_validate.sql: CorrectProfit = sum of regions
[ ] All 24 quarters have ~208 rows (shown in validate output)
```
