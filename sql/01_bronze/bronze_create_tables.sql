USE DWH;
GO

-- CRM: customer basic info
IF OBJECT_ID('bronze.crm_cust_info', 'U') IS NOT NULL 
    DROP TABLE bronze.crm_cust_info;
CREATE TABLE bronze.crm_cust_info (
    cust_id INT,
    cust_key VARCHAR(35),
    cust_firstname VARCHAR(100),
    cust_lastname VARCHAR(100),
    cust_email VARCHAR(120),
    cust_phone VARCHAR(20),
    cust_gender VARCHAR(10),
    cust_create_date DATETIME
);
GO

-- CRM: product reference information
IF OBJECT_ID('bronze.crm_prd_info', 'U') IS NOT NULL 
    DROP TABLE bronze.crm_prd_info;
CREATE TABLE bronze.crm_prd_info (
    prd_id INT,
    prd_key VARCHAR(35),
    prd_name VARCHAR(150),
    prd_category VARCHAR(50),
    prd_subcategory VARCHAR(50),
    prd_cost DECIMAL(10,2),
    prd_list_price DECIMAL(10,2),
    prd_launch_date DATE,
    prd_discontinued_date DATE
);
GO

-- CRM: sales orders (raw)
IF OBJECT_ID('bronze.crm_sales_details', 'U') IS NOT NULL 
    DROP TABLE bronze.crm_sales_details;
CREATE TABLE bronze.crm_sales_details (
    ord_id INT,
    ord_number VARCHAR(35),
    cust_id INT,
    prd_key VARCHAR(35),
    qty INT,
    unit_price DECIMAL(10,2),
    order_date DATETIME,
    ship_date DATETIME,
    due_date DATETIME,
    channel VARCHAR(20),
    status VARCHAR(20)
);
GO

-- ERP: customer demographics / identifiers
IF OBJECT_ID('bronze.erp_cust_info', 'U') IS NOT NULL 
    DROP TABLE bronze.erp_cust_info;
CREATE TABLE bronze.erp_cust_info (
    cust_key VARCHAR(35),
    birthdate DATE
);
GO

-- ERP: location lookup
IF OBJECT_ID('bronze.erp_locations', 'U') IS NOT NULL 
    DROP TABLE bronze.erp_locations;
CREATE TABLE bronze.erp_locations (
    cust_key VARCHAR(35),
    street_address VARCHAR(150),
    city VARCHAR(50),
    province VARCHAR(10),
    postal_code VARCHAR(10),
    country VARCHAR(50)
);
GO

