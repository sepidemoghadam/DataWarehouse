/*
=========================================================================================
Project:        Northwind Data Warehouse (Modern BI Architecture)
Layer:          Staging Area (stage_dw)
File Name:      Northwind_Stage_CreateTables.sql
Author:         sepide Moghadam
Date:           2026-09-20
Description:    This script initializes the schema and table structures for the 
                Staging Layer. It follows strict naming conventions (snake_case).
                Each table reflects a source entity from the Northwind OLTP database,
                enhanced with 'dwh_inserted_at' metadata for audit tracking.
                
Target Database: stage_dw
Schema:          stage
=========================================================================================
*/

USE master;
GO

IF DB_ID(N'stage_dw') IS NOT NULL
BEGIN
    ALTER DATABASE stage_dw SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE stage_dw;
END
GO

CREATE DATABASE stage_dw;
GO

USE stage_dw;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'stage')
    EXEC(N'CREATE SCHEMA stage');
GO

DROP TABLE IF EXISTS stage.northwind_etrun_log;
CREATE TABLE stage.northwind_etrun_log (
    log_id INT IDENTITY(1,1) PRIMARY KEY,
    package_name NVARCHAR(100) NOT NULL,
    table_name NVARCHAR(100) NOT NULL,
    rows_inserted INT NOT NULL,
    status NVARCHAR(20) NOT NULL,
    error_message NVARCHAR(MAX) NULL,
    start_time DATETIME2(3) NOT NULL,
    end_time DATETIME2(3) NOT NULL,
    dwh_inserted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS stage.northwind_categories;
CREATE TABLE stage.northwind_categories (
    category_id INT NOT NULL,
    category_name NVARCHAR(15) NOT NULL,
    category_desc NVARCHAR(MAX) NULL,
    picture IMAGE NULL,
    dwh_inserted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS stage.northwind_customers;
CREATE TABLE stage.northwind_customers (
    customer_id NCHAR(5) NOT NULL,
    company_name NVARCHAR(40) NOT NULL,
    contact_name NVARCHAR(30) NULL,
    contact_title NVARCHAR(30) NULL,
    address NVARCHAR(60) NULL,
    city NVARCHAR(15) NULL,
    region NVARCHAR(15) NULL,
    postal_code NVARCHAR(10) NULL,
    country NVARCHAR(15) NULL,
    phone NVARCHAR(24) NULL,
    fax NVARCHAR(24) NULL,
    dwh_inserted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS stage.northwind_employees;
CREATE TABLE stage.northwind_employees (
    employee_id INT NOT NULL,
    last_name NVARCHAR(20) NOT NULL,
    first_name NVARCHAR(10) NOT NULL,
    title NVARCHAR(30) NULL,
    title_of_courtesy NVARCHAR(25) NULL,
    birth_date DATETIME NULL,
    hire_date DATETIME NULL,
    address NVARCHAR(60) NULL,
    city NVARCHAR(15) NULL,
    region NVARCHAR(15) NULL,
    postal_code NVARCHAR(10) NULL,
    country NVARCHAR(15) NULL,
    home_phone NVARCHAR(24) NULL,
    extension NVARCHAR(4) NULL,
    photo IMAGE NULL,
    notes NVARCHAR(MAX) NULL,
    reports_to INT NULL,
    photo_path NVARCHAR(255) NULL,
    dwh_inserted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS stage.northwind_suppliers;
CREATE TABLE stage.northwind_suppliers (
    supplier_id INT NOT NULL,
    company_name NVARCHAR(40) NOT NULL,
    contact_name NVARCHAR(30) NULL,
    contact_title NVARCHAR(30) NULL,
    address NVARCHAR(60) NULL,
    city NVARCHAR(15) NULL,
    region NVARCHAR(15) NULL,
    postal_code NVARCHAR(10) NULL,
    country NVARCHAR(15) NULL,
    phone NVARCHAR(24) NULL,
    fax NVARCHAR(24) NULL,
    home_page NVARCHAR(MAX) NULL,
    dwh_inserted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS stage.northwind_products;
CREATE TABLE stage.northwind_products (
    product_id INT NOT NULL,
    product_name NVARCHAR(40) NOT NULL,
    supplier_id INT NULL,
    category_id INT NULL,
    quantity_per_unit NVARCHAR(20) NULL,
    unit_price MONEY NULL,
    units_in_stock SMALLINT NULL,
    units_on_order SMALLINT NULL,
    reorder_level SMALLINT NULL,
    discontinued BIT NOT NULL,
    dwh_inserted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS stage.northwind_shippers;
CREATE TABLE stage.northwind_shippers (
    shipper_id INT NOT NULL,
    company_name NVARCHAR(40) NOT NULL,
    phone NVARCHAR(24) NULL,
    dwh_inserted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS stage.northwind_orders;
CREATE TABLE stage.northwind_orders (
    order_id INT NOT NULL,
    customer_id NCHAR(5) NULL,
    employee_id INT NULL,
    order_date DATETIME NULL,
    required_date DATETIME NULL,
    shipped_date DATETIME NULL,
    ship_via INT NULL,
    freight MONEY NULL,
    ship_name NVARCHAR(40) NULL,
    ship_address NVARCHAR(60) NULL,
    ship_city NVARCHAR(15) NULL,
    ship_region NVARCHAR(15) NULL,
    ship_postal_code NVARCHAR(10) NULL,
    ship_country NVARCHAR(15) NULL,
    dwh_inserted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);

DROP TABLE IF EXISTS stage.northwind_order_details;
CREATE TABLE stage.northwind_order_details (
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    unit_price MONEY NOT NULL,
    quantity SMALLINT NOT NULL,
    discount REAL NOT NULL,
    dwh_inserted_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO
