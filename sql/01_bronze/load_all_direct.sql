USE DWH;
GO

-- Load all bronze tables directly from the source CSV files using BULK INSERT into the appropriate tables created in the previous step.
TRUNCATE TABLE bronze.crm_cust_info;
BULK INSERT bronze.crm_cust_info FROM '$(RepoRoot)\data\crm\crm_cust_info.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',');
SELECT 'Customers: ' + CAST(@@ROWCOUNT AS VARCHAR) AS [Loaded];
GO

TRUNCATE TABLE bronze.crm_prd_info;
BULK INSERT bronze.crm_prd_info FROM '$(RepoRoot)\data\crm\crm_prd_info.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',');
SELECT 'Products: ' + CAST(@@ROWCOUNT AS VARCHAR) AS [Loaded];
GO

TRUNCATE TABLE bronze.crm_sales_details;
BULK INSERT bronze.crm_sales_details FROM '$(RepoRoot)\data\crm\crm_sales_details.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',');
SELECT 'Orders: ' + CAST(@@ROWCOUNT AS VARCHAR) AS [Loaded];
GO

TRUNCATE TABLE bronze.erp_cust_info;
BULK INSERT bronze.erp_cust_info FROM '$(RepoRoot)\data\erp\erp_cust_info.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',');
SELECT 'ERP Customers: ' + CAST(@@ROWCOUNT AS VARCHAR) AS [Loaded];
GO

TRUNCATE TABLE bronze.erp_locations;
BULK INSERT bronze.erp_locations FROM '$(RepoRoot)\data\erp\erp_locations.csv' 
WITH (FIRSTROW=2, FIELDTERMINATOR=',');
SELECT 'Locations: ' + CAST(@@ROWCOUNT AS VARCHAR) AS [Loaded];
GO

-- Verify all loaded
SELECT 'SUMMARY' AS [Step];
SELECT 'bronze.crm_cust_info' as [Table], COUNT(*) as [Rows] FROM bronze.crm_cust_info
UNION ALL SELECT 'bronze.crm_prd_info', COUNT(*) FROM bronze.crm_prd_info
UNION ALL SELECT 'bronze.crm_sales_details', COUNT(*) FROM bronze.crm_sales_details
UNION ALL SELECT 'bronze.erp_cust_info', COUNT(*) FROM bronze.erp_cust_info
UNION ALL SELECT 'bronze.erp_locations', COUNT(*) FROM bronze.erp_locations;
GO
