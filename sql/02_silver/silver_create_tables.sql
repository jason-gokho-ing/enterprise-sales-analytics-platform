USE DWH;
GO

-- Silver: Customer Master (deduplicated, latest record per cust_key)
IF OBJECT_ID('silver.dim_customer', 'U') IS NOT NULL 
    DROP TABLE silver.dim_customer;
CREATE TABLE silver.dim_customer (
    cust_key VARCHAR(35) PRIMARY KEY,
    customer_id INT,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(120),
    phone VARCHAR(20),
    gender VARCHAR(20),
    birthdate DATE,
    province VARCHAR(10),
    country VARCHAR(50),
    created_date DATETIME,
    dwh_loaded_date DATETIME2 DEFAULT GETDATE()
);
GO

-- Silver: Product Master (shows latest record per prd_key)
IF OBJECT_ID('silver.dim_product', 'U') IS NOT NULL 
    DROP TABLE silver.dim_product;
CREATE TABLE silver.dim_product (
    prd_key VARCHAR(35) PRIMARY KEY,
    product_id INT,
    product_name VARCHAR(150),
    category VARCHAR(50),
    cost DECIMAL(10,2),
    list_price DECIMAL(10,2),
    launch_date DATE,
    discontinued_date DATE,
    is_active BIT,
    dwh_loaded_date DATETIME2 DEFAULT GETDATE()
);
GO

-- Silver: Order Fact Table (cleaned order-level facts without discount/return logic)
-- Grain: One row per order
IF OBJECT_ID('silver.fact_orders', 'U') IS NOT NULL 
    DROP TABLE silver.fact_orders;
CREATE TABLE silver.fact_orders (
    order_id INT,
    order_number VARCHAR(35),
    cust_key VARCHAR(35),
    prd_key VARCHAR(35),
    qty INT,
    unit_price DECIMAL(10,2),
    cost DECIMAL(10,2),
    order_date DATETIME,
    order_channel VARCHAR(20),
    dwh_loaded_date DATETIME2 DEFAULT GETDATE()
);
GO


