/*
=========================================================================================
Project:        Northwind Data Warehouse
Layer:          Data Delivery Store (DDS) - Sales Data Mart
File Name:      Northwind_Sale_CreateTables.sql
Author:         Sepide Moghadam
Description:    Creates Dimension and Fact tables for the Northwind Sales Data Mart.

                Architecture:
                - Target Database : dds
                - Target Schema   : sale
                - Model           : Star Schema
                - Fact Grain      : One row per Order ID + Product ID

                Dimensional Design:
                - Category is denormalized into sale.dim_product.
                - Therefore, sale.dim_category is intentionally not created.
                - Product Dimension contains Product, Supplier reference, and
                  Category descriptive attributes.
                - Date Dimension is an existing shared dimension located at:
                  [Northwind_dw].[dbo].[DimDate]

                Date Mapping:
                - Northwind dates are Gregorian.
                - Fact date keys are retrieved using:
                  DimDate.MiladiDate -> DimDate.MiladiDateKey

                Unknown Members:
                - All Dimensions include an Unknown Member with surrogate key = 0.
                - This prevents Fact load failures when source data has missing
                  or unmatched Dimension values.

Source Database: stage_dw
Target Database: dds
Target Schema:   sale
=========================================================================================
*/

-----------------------------------------------------------------------------------------
-- 1. Create DDS Database
-----------------------------------------------------------------------------------------
IF DB_ID(N'dds') IS NULL
BEGIN
    CREATE DATABASE dds;
END;
GO

USE dds;
GO

-----------------------------------------------------------------------------------------
-- 2. Create Sale Schema
-----------------------------------------------------------------------------------------
IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = N'sale'
)
BEGIN
    EXEC(N'CREATE SCHEMA sale');
END;
GO

-----------------------------------------------------------------------------------------
-- 3. Create Geography Dimension
--
-- Geography is integrated from Customers, Employees, Suppliers,
-- and the shipping address of Orders.
-----------------------------------------------------------------------------------------
IF OBJECT_ID(N'sale.dim_geography', N'U') IS NULL
BEGIN
    CREATE TABLE sale.dim_geography
    (
        geography_key       INT IDENTITY(1,1) NOT NULL,
        country             NVARCHAR(100)     NOT NULL,
        region              NVARCHAR(100)     NOT NULL,
        city                NVARCHAR(100)     NOT NULL,
        postal_code         NVARCHAR(30)      NOT NULL,
        dwh_inserted_at     DATETIME2(3)      NOT NULL
            CONSTRAINT df_dim_geography_dwh_inserted_at
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT pk_dim_geography PRIMARY KEY (geography_key),

        CONSTRAINT uq_dim_geography_location
            UNIQUE (country, region, city, postal_code)
    );
END;
GO
-----------------------------------------------------------------------------------------
-- 3. Create Customer Dimension
-----------------------------------------------------------------------------------------
IF OBJECT_ID(N'sale.dim_customer', N'U') IS NULL
BEGIN
    CREATE TABLE sale.dim_customer
    (
        customer_key        INT IDENTITY(1,1) NOT NULL,
        customer_id         VARCHAR(20)       NOT NULL,
        company_name        NVARCHAR(255)     NOT NULL,
        contact_name        NVARCHAR(255)     NOT NULL,
        contact_title       NVARCHAR(100)     NOT NULL,
        phone               NVARCHAR(50)      NOT NULL,
        fax                 NVARCHAR(50)      NOT NULL,
		geography_key       INT               NOT NULL,
        dwh_inserted_at     DATETIME2(3)      NOT NULL
            CONSTRAINT df_dim_customer_dwh_inserted_at
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT pk_dim_customer PRIMARY KEY (customer_key),
        CONSTRAINT uq_dim_customer_customer_id UNIQUE (customer_id),
			 CONSTRAINT fk_fact_order_geography
            FOREIGN KEY (geography_key)
            REFERENCES sale.dim_geography(geography_key)
    );
END;
GO

-----------------------------------------------------------------------------------------
-- 4. Create Employee Dimension
-----------------------------------------------------------------------------------------
IF OBJECT_ID(N'sale.dim_employee', N'U') IS NULL
BEGIN
    CREATE TABLE sale.dim_employee
    (
        employee_key            INT IDENTITY(1,1) NOT NULL,
        employee_id             INT               NOT NULL,
        first_name              NVARCHAR(100)     NOT NULL,
        last_name               NVARCHAR(100)     NOT NULL,
        full_name               NVARCHAR(250)     NOT NULL,
        title                   NVARCHAR(100)     NOT NULL,
        title_of_courtesy       NVARCHAR(50)      NOT NULL,
        birth_date              DATE              NULL,
        hire_date               DATE              NULL,
        reports_to_employee_id  INT               NULL,
		geography_key           INT               NOT NULL,
        dwh_inserted_at         DATETIME2(3)      NOT NULL
            CONSTRAINT df_dim_employee_dwh_inserted_at
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT pk_dim_employee PRIMARY KEY (employee_key),
        CONSTRAINT uq_dim_employee_employee_id UNIQUE (employee_id),
		 CONSTRAINT fk_dim_geography
            FOREIGN KEY (geography_key)
            REFERENCES sale.dim_geography(geography_key)
    );
END;
GO

-----------------------------------------------------------------------------------------
-- 5. Create Supplier Dimension
-----------------------------------------------------------------------------------------
IF OBJECT_ID(N'sale.dim_supplier', N'U') IS NULL
BEGIN
    CREATE TABLE sale.dim_supplier
    (
        supplier_key        INT IDENTITY(1,1) NOT NULL,
        supplier_id         INT               NOT NULL,
        company_name        NVARCHAR(255)     NOT NULL,
        contact_name        NVARCHAR(255)     NOT NULL,
        contact_title       NVARCHAR(100)     NOT NULL,
        phone               NVARCHAR(50)      NOT NULL,
        home_page           NVARCHAR(MAX)     NOT NULL,
		geography_key       INT               NOT NULL,
        dwh_inserted_at     DATETIME2(3)      NOT NULL
            CONSTRAINT df_dim_supplier_dwh_inserted_at
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT pk_dim_supplier PRIMARY KEY (supplier_key),
        CONSTRAINT uq_dim_supplier_supplier_id UNIQUE (supplier_id),
		 CONSTRAINT fk_dim_key_geography
            FOREIGN KEY (geography_key)
            REFERENCES sale.dim_geography(geography_key)
    );
END;
GO

-----------------------------------------------------------------------------------------
-- 6. Create Product Dimension
--
-- Category is denormalized in this Dimension.
-- There is intentionally no independent dim_category table.
-----------------------------------------------------------------------------------------
IF OBJECT_ID(N'sale.dim_product', N'U') IS NULL
BEGIN
    CREATE TABLE sale.dim_product
    (
        product_key             INT IDENTITY(1,1) NOT NULL,
        product_id              INT               NOT NULL,
        product_name            NVARCHAR(255)     NOT NULL,

        -- Supplier Business Key retained for lineage and analytical use.
        supplier_id             INT               NULL,

        -- Denormalized Category Attributes
        category_id             INT               NULL,
        category_name           NVARCHAR(100)     NOT NULL,
        category_desc           NVARCHAR(MAX)     NOT NULL,

        -- Product Packaging Attributes
        quantity_per_unit       NVARCHAR(100)     NOT NULL,
        package_quantity        INT               NULL,
        package_unit            NVARCHAR(100)     NOT NULL,

        -- Product Inventory / Status Attributes
        current_unit_price      DECIMAL(19,4)     NOT NULL,
        units_in_stock          INT               NOT NULL,
        units_on_order          INT               NOT NULL,
        reorder_level           INT               NOT NULL,
        discontinued_status     VARCHAR(20)       NOT NULL,

        dwh_inserted_at         DATETIME2(3)      NOT NULL
            CONSTRAINT df_dim_product_dwh_inserted_at
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT pk_dim_product PRIMARY KEY (product_key),
        CONSTRAINT uq_dim_product_product_id UNIQUE (product_id)
    );
END;
GO

-----------------------------------------------------------------------------------------
-- 7. Create Shipper Dimension
-----------------------------------------------------------------------------------------
IF OBJECT_ID(N'sale.dim_shipper', N'U') IS NULL
BEGIN
    CREATE TABLE sale.dim_shipper
    (
        shipper_key         INT IDENTITY(1,1) NOT NULL,
        shipper_id          INT               NOT NULL,
        company_name        NVARCHAR(255)     NOT NULL,
        phone               NVARCHAR(50)      NOT NULL,
        dwh_inserted_at     DATETIME2(3)      NOT NULL
            CONSTRAINT df_dim_shipper_dwh_inserted_at
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT pk_dim_shipper PRIMARY KEY (shipper_key),
        CONSTRAINT uq_dim_shipper_shipper_id UNIQUE (shipper_id)
    );
END;
GO



-----------------------------------------------------------------------------------------
-- 9. Create Order Fact
--
-- Fact Grain:
-- One record per Order ID + Product ID.
--
-- order_id is a Degenerate Dimension because there is no separate Order Dimension.
-----------------------------------------------------------------------------------------
IF OBJECT_ID(N'sale.fact_order', N'U') IS NULL
BEGIN
    CREATE TABLE sale.fact_order
    (
        order_fact_key          BIGINT IDENTITY(1,1) NOT NULL,

        -- Business / Degenerate Keys
        order_id                INT                   NOT NULL,
        source_product_id       INT                   NOT NULL,

        -- Dimension Surrogate Keys
        customer_key            INT                   NOT NULL,
        employee_key            INT                   NOT NULL,
        supplier_key            INT                   NOT NULL,
        product_key             INT                   NOT NULL,
        shipper_key             INT                   NOT NULL,
     

        /*
            Date keys originate from the shared DimDate table:
            [Northwind_dw].[dbo].[DimDate].[MiladiDateKey]

            SQL Server does not allow Cross-Database Foreign Keys.
            Therefore these columns do not have FK constraints.
        */
        order_date_key          INT                   NOT NULL,
        required_date_key       INT                   NOT NULL,
        shipped_date_key        INT                   NOT NULL,

        -- Transaction Measures
        unit_price              DECIMAL(19,4)         NOT NULL,
        quantity                INT                   NOT NULL,
        discount_rate           DECIMAL(9,6)          NOT NULL,

        -- Derived Measures
        gross_amount            DECIMAL(19,4)         NOT NULL,
        discount_amount         DECIMAL(19,4)         NOT NULL,
        net_amount              DECIMAL(19,4)         NOT NULL,
        freight_amount          DECIMAL(19,4)         NOT NULL,

        dwh_inserted_at         DATETIME2(3)          NOT NULL
            CONSTRAINT df_fact_order_dwh_inserted_at
            DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT pk_fact_order PRIMARY KEY (order_fact_key),

        -- Prevents duplicate records at Fact Grain.
        CONSTRAINT uq_fact_order_business_key
            UNIQUE (order_id, source_product_id),

        CONSTRAINT fk_fact_order_customer
            FOREIGN KEY (customer_key)
            REFERENCES sale.dim_customer(customer_key),

        CONSTRAINT fk_fact_order_employee
            FOREIGN KEY (employee_key)
            REFERENCES sale.dim_employee(employee_key),

        CONSTRAINT fk_fact_order_supplier
            FOREIGN KEY (supplier_key)
            REFERENCES sale.dim_supplier(supplier_key),

        CONSTRAINT fk_fact_order_product
            FOREIGN KEY (product_key)
            REFERENCES sale.dim_product(product_key),

        CONSTRAINT fk_fact_order_shipper
            FOREIGN KEY (shipper_key)
            REFERENCES sale.dim_shipper(shipper_key),

     
    );
END;
GO
-----------------------------------------------------------------------------------------
-- 10. Insert Unknown Members
--
-- Unknown Members ensure that invalid, NULL, or unmatched source values
-- are mapped to Key = 0 instead of causing Fact Load failures.
-----------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sale.dim_geography WHERE geography_key = 0)
BEGIN
    SET IDENTITY_INSERT sale.dim_geography ON;

    INSERT INTO sale.dim_geography
    (
        geography_key,
        country,
        region,
        city,
        postal_code
    )
    VALUES
    (
        0,
        N'UNKNOWN',
        N'UNKNOWN',
        N'UNKNOWN',
        N'UNKNOWN'
    );

    SET IDENTITY_INSERT sale.dim_geography OFF;
END;
GO


IF NOT EXISTS (SELECT 1 FROM sale.dim_customer WHERE customer_key = 0)
BEGIN
    SET IDENTITY_INSERT sale.dim_customer ON;

    INSERT INTO sale.dim_customer
    (
        customer_key,
		geography_key,
        customer_id,
        company_name,
        contact_name,
        contact_title,
        phone,
        fax
		
    )
    VALUES
    (
        0,
		0,
        'UNKNOWN',
        N'Unknown Customer',
        N'Unknown',
        N'Unknown',
        N'Unknown',
        N'Not Available'
    );

    SET IDENTITY_INSERT sale.dim_customer OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sale.dim_employee WHERE employee_key = 0)
BEGIN
    SET IDENTITY_INSERT sale.dim_employee ON;

    INSERT INTO sale.dim_employee
    (
        employee_key,
		geography_key,
        employee_id,
        first_name,
        last_name,
        full_name,
        title,
        title_of_courtesy,
        birth_date,
        hire_date,
        reports_to_employee_id
    )
    VALUES
    (
        0,
        0,
		0,
        N'Unknown',
        N'Unknown',
        N'Unknown Employee',
        N'Unknown',
        N'Unknown',
        NULL,
        NULL,
        NULL
    );

    SET IDENTITY_INSERT sale.dim_employee OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sale.dim_supplier WHERE supplier_key = 0)
BEGIN
    SET IDENTITY_INSERT sale.dim_supplier ON;

    INSERT INTO sale.dim_supplier
    (
        supplier_key,
		geography_key,
        supplier_id,
        company_name,
        contact_name,
        contact_title,
        phone,
        home_page
    )
    VALUES
    (
        0,
		0,
        0,
        N'Unknown Supplier',
        N'Unknown',
        N'Unknown',
        N'Unknown',
        N'Not Available'
    );

    SET IDENTITY_INSERT sale.dim_supplier OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sale.dim_product WHERE product_key = 0)
BEGIN
    SET IDENTITY_INSERT sale.dim_product ON;

    INSERT INTO sale.dim_product
    (
        product_key,
        product_id,
        product_name,
        supplier_id,
        category_id,
        category_name,
        category_desc,
        quantity_per_unit,
        package_quantity,
        package_unit,
        current_unit_price,
        units_in_stock,
        units_on_order,
        reorder_level,
        discontinued_status
    )
    VALUES
    (
        0,
        0,
        N'Unknown Product',
        NULL,
        NULL,
        N'Unknown Category',
        N'Not Available',
        N'Unknown',
        NULL,
        N'Unknown',
        0,
        0,
        0,
        0,
        'UNKNOWN'
    );

    SET IDENTITY_INSERT sale.dim_product OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM sale.dim_shipper WHERE shipper_key = 0)
BEGIN
    SET IDENTITY_INSERT sale.dim_shipper ON;

    INSERT INTO sale.dim_shipper
    (
        shipper_key,
        shipper_id,
        company_name,
        phone
    )
    VALUES
    (
        0,
        0,
        N'Unknown Shipper',
        N'Unknown'
    );

    SET IDENTITY_INSERT sale.dim_shipper OFF;
END;
GO

