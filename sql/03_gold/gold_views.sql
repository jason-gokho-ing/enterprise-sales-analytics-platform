USE DWH;
GO

-- ============================================================================
-- GOLD LAYER: Reporting Views for Power BI and Analytics
-- 
-- Purpose:
--   Create business-ready views that combine dimensions with facts.
--   Each view includes calculated fields and business logic that can be used directly in Power BI
--
--   - dim_customer_info: For organizing orders by customer attributes
--   - dim_product_info: For organizing orders by product attributes  
--   - sales_analytics: Complete denormalized table with all order details
-- ============================================================================

-- ============================================================================
-- VIEW 1: dim_customer_info - Customer Dimension with Segments
-- ============================================================================
-- What this view does:
--   Adds business segments to Silver customer dimension table (customer tenure)
-- Business Value:
--   Easier to categorize customers by tenure for targeting campaigns (retention focus).
-- ============================================================================
IF OBJECT_ID('gold.dim_customer_info', 'V') IS NOT NULL
    DROP VIEW gold.dim_customer_info;
GO

CREATE VIEW gold.dim_customer_info AS
SELECT
    c.cust_key,
    c.customer_id,
    c.first_name,
    c.last_name,
    LTRIM(RTRIM(CONCAT(c.first_name, ' ', c.last_name))) AS customer_name,
    c.gender,
    c.birthdate,
    CASE
        WHEN c.birthdate IS NULL THEN NULL
        ELSE DATEDIFF(YEAR, c.birthdate, GETDATE())
            - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, c.birthdate, GETDATE()), c.birthdate) > GETDATE() THEN 1 ELSE 0 END
    END AS customer_age,
    CASE
        WHEN c.birthdate IS NULL THEN 'Unknown'
        WHEN DATEDIFF(YEAR, c.birthdate, GETDATE()) < 25 THEN 'Under 25'
        WHEN DATEDIFF(YEAR, c.birthdate, GETDATE()) < 35 THEN '25-34'
        WHEN DATEDIFF(YEAR, c.birthdate, GETDATE()) < 45 THEN '35-44'
        WHEN DATEDIFF(YEAR, c.birthdate, GETDATE()) < 55 THEN '45-54'
        ELSE '55+'
    END AS age_group,
    c.province,
    c.created_date,
    DATEDIFF(DAY, c.created_date, GETDATE()) AS customer_tenure_days,
    CAST(DATEDIFF(DAY, c.created_date, GETDATE()) / 365.25 AS DECIMAL(10,2)) AS customer_tenure_years,
    -- Customer Segment: How long have they been with us?
    -- New (0-1 year) = acquisition focus, Regular (1-3 years) = growth, Loyal (3+ years) = retention
    CASE 
        WHEN DATEDIFF(YEAR, c.created_date, GETDATE()) <= 1 THEN 'New'
        WHEN DATEDIFF(YEAR, c.created_date, GETDATE()) <= 3 THEN 'Regular'
        ELSE 'Loyal' 
    END AS customer_segment
FROM silver.dim_customer c;
GO

-- ============================================================================
-- VIEW 2: dim_product_info - Product Dimension with Pricing Tiers
-- ============================================================================
-- What this view does:
--   Takes the Silver product dimension and calculates price tier for product grouping.
--   - Price tier: Is this a luxury, premium, mid-range, or budget item?
-- Business Value:
--   Used in Power BI to color-code products and analyze margin by product segment.
-- ============================================================================
IF OBJECT_ID('gold.dim_product_info', 'V') IS NOT NULL
    DROP VIEW gold.dim_product_info;
GO

CREATE VIEW gold.dim_product_info AS
SELECT
    p.prd_key,
    p.product_id,
    p.product_name,
    p.category,
    p.cost,
    p.list_price,
    -- Price Tier: Group products into strategic tiers 
    -- Luxury ($2000+): High-end devices, brand visibility
    -- Premium ($1500-2000): High-end devices, brand visibility
    -- Mid-Range ($1000-1500): Sweet spot for volume
    -- Budget (<$1000): Entry-level, high volume potential
    CASE 
        WHEN p.list_price > 2000 THEN 'Luxury'
        WHEN p.list_price > 1500 THEN 'Premium'
        WHEN p.list_price > 1000 THEN 'Mid-Range'
        ELSE 'Budget'
    END AS price_tier
FROM silver.dim_product p;
GO

-- ============================================================================
-- VIEW 3: sales_analytics - Complete Fact Table for Power BI & Analysis
-- ============================================================================
-- What this view does:
--   The main reporting table. Combines order facts with customer and product
--   dimensions into one view. Includes all metrics + dimensions
--   needed to analyze sales by customer, product, geography, and time.
-- Business Value:
--   Power BI and SQL analysts query this directly for dashboards and reports.
-- How to use:
--   - Filter by province for regional analysis
--   - Filter by price_tier for product performance
--   - Filter by customer_segment for customer value analysis
--   - Aggregate by order_date for trend analysis
-- ============================================================================
IF OBJECT_ID('gold.sales_analytics', 'V') IS NOT NULL
    DROP VIEW gold.sales_analytics;
GO

CREATE VIEW gold.sales_analytics AS
SELECT
    -- Order Keys & IDs
    f.order_id,
    -- Customer & Product Keys (for joining to dimensions if needed)
    f.cust_key,
    f.prd_key,
    -- Customer Attributes 
    LTRIM(RTRIM(CONCAT(c.first_name, ' ', c.last_name))) AS customer_name,
    c.gender,
    c.birthdate,
    c.customer_age,
    c.age_group,
    c.province,
    c.customer_segment,
    -- Product Attributes
    p.product_name,
    p.category,
    p.price_tier,
    -- Order Quantities & Pricing
    f.qty,                        -- How many units ordered
    f.unit_price,                 -- Price per unit
    f.cost,                        -- What we paid for this product (from cost accounting)
    -- Date (single reporting date; use Date table in Power BI for year/month/week breakdown)
    CAST(f.order_date AS DATE) AS order_date,
    -- Order Status & Channel
    f.order_channel               -- Online, In-Store, Phone, etc.
FROM silver.fact_orders f
LEFT JOIN gold.dim_customer_info c ON f.cust_key = c.cust_key
LEFT JOIN gold.dim_product_info p ON f.prd_key = p.prd_key;
GO

PRINT '[Complete] Gold layer views created successfully';
GO

