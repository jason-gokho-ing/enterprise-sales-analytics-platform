-- Quick validation checks for Enterprise Sales Analytics Platform
-- Run with: sqlcmd -S .\SQLEXPRESS -d DWH -E -i sql/validation/quick_checks.sql

-- Layer counts (sanity)
SELECT 'Bronze' AS Layer, COUNT(*) FROM bronze.crm_cust_info;
SELECT 'Silver' AS Layer, COUNT(*) FROM silver.dim_customer;
SELECT 'Gold' AS Layer, COUNT(*) FROM gold.sales_analytics;

-- Top-line KPIs
SELECT SUM(qty * unit_price) AS total_sales,
       SUM((unit_price - cost) * qty) AS total_gross_profit
FROM gold.sales_analytics;
