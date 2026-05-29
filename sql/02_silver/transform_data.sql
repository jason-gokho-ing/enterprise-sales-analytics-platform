USE DWH;
GO

-- ============================================================================
-- SILVER LAYER: Data Transformation Procedure
-- 
-- PURPOSE:
--   Applies deduplication, standardization, and business calculations to make data analysis-ready.
--
-- KEY CONCEPTS:
--   - Deduplication: keep only the most recent record to prevent duplicates (identified by cust_key or prd_key)
--   - JOINs: Link CRM + ERP data to get complete customer/product profiles
--   - Create Calculated Fields: Create product and customer categories (gender, active status)
--
-- FINAL OUTPUT:
--   1. dim_customer: One row per unique customer with all demographics
--   2. dim_product: One row per unique product with cost + pricing
--   3. fact_orders: One row per order line with all order details
-- ============================================================================

CREATE OR ALTER PROCEDURE silver.silver_load_table_data
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @start_time DATETIME, @end_time DATETIME;
    DECLARE @rows_loaded INT;
    DECLARE @start_batch_time DATETIME, @end_batch_time DATETIME;

    SET @start_batch_time = GETDATE();

    BEGIN TRY
        BEGIN TRAN;

        --======================================================================
        -- STEP 1: Load Customers (Deduplication + Enrichment)
        --======================================================================
        -- Uses ROW_NUMBER() to deduplicate customer records, keeping only the most recent per cust_key.
        -- Joins CRM customer info with ERP demographics and location data to create a complete customer profile in dim_customer.
        --
        -- Business Value: Gives marketing one trusted view of customer with location and demographics for segmentation.
        --======================================================================
        PRINT '[Step 1/3] Loading dim_customer...';
        SET @start_time = GETDATE();

        TRUNCATE TABLE silver.dim_customer;

        -- Simpler approach: dedupe CRM by cust_key first, then enrich with ERP tables
        WITH dedup_crm AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY cust_key ORDER BY cust_create_date DESC) AS rn
            FROM bronze.crm_cust_info
        )
        INSERT INTO silver.dim_customer (
            cust_key, customer_id, first_name, last_name, email, phone, gender,
            birthdate, province, country, created_date
        )
        SELECT
            c.cust_key,
            c.cust_id,
            TRIM(c.cust_firstname),
            TRIM(c.cust_lastname),
            c.cust_email,
            c.cust_phone,
            CASE WHEN c.cust_gender IN ('M','Male') THEN 'Male'
                 WHEN c.cust_gender IN ('F','Female') THEN 'Female'
                 ELSE 'Unknown' END AS gender,
            e.birthdate,
            l.province,
            l.country,
              c.cust_create_date
        FROM dedup_crm c
        LEFT JOIN bronze.erp_cust_info e ON c.cust_key = e.cust_key
        LEFT JOIN bronze.erp_locations l ON c.cust_key = l.cust_key
        WHERE c.rn = 1;

        SET @rows_loaded = @@ROWCOUNT;

        SET @end_time = GETDATE();
        PRINT 'Loaded ' + CAST(@rows_loaded AS VARCHAR) + ' customers in ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + 's';
        PRINT '';
        
        --======================================================================
        -- STEP 2: Load Products (Deduplication + Consumer Behaviors)
        --======================================================================
        -- Products may have multiple records due to updates. Important to keep latest version using ROW_NUMBER() to prevent duplicates.
        -- Joins CRM product info with ERP category data to create a complete product profile in dim_product.
        --
        -- Business Value: Creates an easy to manage inventory that can easily identify aging/new products for promotions.
        --======================================================================
        PRINT '[Step 2/3] Loading dim_product...';
        SET @start_time = GETDATE();

        TRUNCATE TABLE silver.dim_product;

        -- Remove duplicate product entries by selecting the most recent launch date
        WITH dedup_prd AS (
            SELECT *, ROW_NUMBER() OVER (PARTITION BY prd_key ORDER BY prd_launch_date DESC) AS rn
            FROM bronze.crm_prd_info
        )
        INSERT INTO silver.dim_product (
            prd_key, product_id, product_name, category,
            cost, list_price, launch_date, discontinued_date, is_active
        )
        SELECT
            p.prd_key,
            p.prd_id,
            p.prd_name,
            p.prd_category,
            p.prd_cost,
            p.prd_list_price,
            p.prd_launch_date,
            p.prd_discontinued_date,
            -- Active if not discontinued (1), otherwise inactive (0)
            CASE WHEN p.prd_discontinued_date IS NULL THEN 1 ELSE 0 END AS is_active
        FROM dedup_prd p
        WHERE p.rn = 1;

        SET @rows_loaded = @@ROWCOUNT;

        SET @end_time = GETDATE();
        PRINT 'Loaded ' + CAST(@rows_loaded AS VARCHAR) + ' products in ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + 's';
        PRINT '';
        
        --======================================================================
        -- STEP 3: Load Orders
        --======================================================================
        -- One row per order.
        --
        -- Business Value: Keeps the fact table lean and easy to explain while preserving the core sales fields needed for the report.
        --======================================================================
        PRINT '[Step 3/3] Loading fact_orders (clean order lines)...';
        SET @start_time = GETDATE();

        TRUNCATE TABLE silver.fact_orders;
        INSERT INTO silver.fact_orders (
            order_id, order_number, cust_key, prd_key, qty, unit_price,
            cost, order_date, order_channel
        )
        SELECT
            ord.ord_id,
            ord.ord_number,
            sc.cust_key,
            ord.prd_key,
            ord.qty,
            ord.unit_price,
            p.cost,
            ord.order_date,
            ord.channel
        FROM bronze.crm_sales_details ord
        LEFT JOIN silver.dim_customer sc ON ord.cust_id = sc.customer_id
        LEFT JOIN silver.dim_product p ON ord.prd_key = p.prd_key;

        SET @rows_loaded = @@ROWCOUNT;

        SET @end_time = GETDATE();
        PRINT 'Loaded ' + CAST(@rows_loaded AS VARCHAR) + ' order lines in ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS VARCHAR) + 's';

        SET @end_batch_time = GETDATE();
        PRINT '[Complete] Total silver load time: ' + CAST(DATEDIFF(SECOND, @start_batch_time, @end_batch_time) AS VARCHAR) + 's';

        COMMIT TRAN;

    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;
        PRINT 'Error occurred during Silver layer loading process';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        THROW;
    END CATCH
END

GO

EXEC silver.silver_load_table_data;