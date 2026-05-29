USE master;
GO

-- Drop and recreate the 'DWH' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DWH')
BEGIN
    ALTER DATABASE DWH SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DWH;
END;
GO

-- Create the 'DWH' database
CREATE DATABASE DWH;
GO

USE DWH;
GO

-- Creating Schemas within database to organize data warehouse

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO
CREATE SCHEMA ops;
GO

CREATE TABLE ops.etl_run_log (
    run_id UNIQUEIDENTIFIER NOT NULL,
    pipeline_layer VARCHAR(50) NOT NULL,
    procedure_name VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL,
    started_at DATETIME2(0) NOT NULL,
    ended_at DATETIME2(0) NULL,
    row_count INT NULL,
    error_message NVARCHAR(4000) NULL,
    created_at DATETIME2(0) NOT NULL CONSTRAINT DF_ops_etl_run_log_created_at DEFAULT SYSUTCDATETIME()
);
GO
 
 





