/*
=========================================================================================
Project:        Northwind Data Warehouse (Modern BI Architecture)
Layer:          Staging Area (stage_dw)
File Name:      Northwind_Stage_LoadData.sql
Author:         Sepide Moghadam
Date:           2026-09-20
Description:    Modular Insert/Update scripts for initial data ingestion. 
                These scripts use the TRUNCATE-AND-LOAD pattern (Full Load) 
                to ensure the staging layer is a clean replica of source data.
                Optimized with WITH (TABLOCK) for bulk logging performance.
                
Source:         Northwind OLTP Database
Target:         stage_dw.stage.*
=========================================================================================
*/

-- ۱. پاک‌سازی جدول هدف
TRUNCATE TABLE stage.northwind_categories;

-- ۲. درج داده‌های جدید
INSERT INTO stage.northwind_categories WITH (TABLOCK) (
    category_id, 
    category_name, 
    category_desc, 
    picture, 
    dwh_inserted_at
)
SELECT 
    CategoryID, 
    CategoryName, 
    Description, 
    Picture, 
    SYSUTCDATETIME()
FROM Northwind.dbo.Categories;
--*******************************************************
-- ۱. پاک‌سازی جدول هدف
TRUNCATE TABLE stage.northwind_customers;

-- ۲. درج داده‌های جدید
INSERT INTO stage.northwind_customers WITH (TABLOCK) (
    customer_id, 
    company_name, 
    contact_name, 
    contact_title, 
    address, 
    city, 
    region, 
    postal_code, 
    country, 
    phone, 
    fax, 
    dwh_inserted_at
)
SELECT 
    CustomerID, 
    CompanyName, 
    ContactName, 
    ContactTitle, 
    Address, 
    City, 
    Region, 
    PostalCode, 
    Country, 
    Phone, 
    Fax, 
    SYSUTCDATETIME()
FROM Northwind.dbo.Customers;
--***************************************************
-- ۱. پاک‌سازی جدول هدف
TRUNCATE TABLE stage.northwind_employees;

-- ۲. درج داده‌های جدید
INSERT INTO stage.northwind_employees WITH (TABLOCK) (
    employee_id, 
    last_name, 
    first_name, 
    title, 
    title_of_courtesy, 
    birth_date, 
    hire_date, 
    address, 
    city, 
    region, 
    postal_code, 
    country, 
    home_phone, 
    extension, 
    photo, 
    notes, 
    reports_to, 
    photo_path, 
    dwh_inserted_at
)
SELECT 
    EmployeeID, 
    LastName, 
    FirstName, 
    Title, 
    TitleOfCourtesy, 
    BirthDate, 
    HireDate, 
    Address, 
    City, 
    Region, 
    PostalCode, 
    Country, 
    HomePhone, 
    Extension, 
    Photo, 
    Notes, 
    ReportsTo, 
    PhotoPath, 
    SYSUTCDATETIME()
FROM Northwind.dbo.Employees;
--****************************************************
-- ۱. پاک‌سازی جدول هدف
TRUNCATE TABLE stage.northwind_suppliers;

-- ۲. درج داده‌های جدید
INSERT INTO stage.northwind_suppliers WITH (TABLOCK) (
    supplier_id, 
    company_name, 
    contact_name, 
    contact_title, 
    address, 
    city, 
    region, 
    postal_code, 
    country, 
    phone, 
    fax, 
    home_page, 
    dwh_inserted_at
)
SELECT 
    SupplierID, 
    CompanyName, 
    ContactName, 
    ContactTitle, 
    Address, 
    City, 
    Region, 
    PostalCode, 
    Country, 
    Phone, 
    Fax, 
    HomePage, 
    SYSUTCDATETIME()
FROM Northwind.dbo.Suppliers;
--***************************************************
-- ۱. پاک‌سازی جدول هدف
TRUNCATE TABLE stage.northwind_products;

-- ۲. درج داده‌های جدید
INSERT INTO stage.northwind_products WITH (TABLOCK) (
    product_id, 
    product_name, 
    supplier_id, 
    category_id, 
    quantity_per_unit, 
    unit_price, 
    units_in_stock, 
    units_on_order, 
    reorder_level, 
    discontinued, 
    dwh_inserted_at
)
SELECT 
    ProductID, 
    ProductName, 
    SupplierID, 
    CategoryID, 
    QuantityPerUnit, 
    UnitPrice, 
    UnitsInStock, 
    UnitsOnOrder, 
    ReorderLevel, 
    Discontinued, 
    SYSUTCDATETIME()
FROM Northwind.dbo.Products;
--*************************************************
-- ۱. پاک‌سازی جدول هدف
TRUNCATE TABLE stage.northwind_shippers;

-- ۲. درج داده‌های جدید
INSERT INTO stage.northwind_shippers WITH (TABLOCK) (
    shipper_id, 
    company_name, 
    phone, 
    dwh_inserted_at
)
SELECT 
    ShipperID, 
    CompanyName, 
    Phone, 
    SYSUTCDATETIME()
FROM Northwind.dbo.Shippers;
--**************************************************
-- ۱. پاک‌سازی جدول هدف
TRUNCATE TABLE stage.northwind_orders;

-- ۲. درج داده‌های جدید
INSERT INTO stage.northwind_orders WITH (TABLOCK) (
    order_id, 
    customer_id, 
    employee_id, 
    order_date, 
    required_date, 
    shipped_date, 
    ship_via, 
    freight, 
    ship_name, 
    ship_address, 
    ship_city, 
    ship_region, 
    ship_postal_code, 
    ship_country, 
    dwh_inserted_at
)
SELECT 
    OrderID, 
    CustomerID, 
    EmployeeID, 
    OrderDate, 
    RequiredDate, 
    ShippedDate, 
    ShipVia, 
    Freight, 
    ShipName, 
    ShipAddress, 
    ShipCity, 
    ShipRegion, 
    ShipPostalCode, 
    ShipCountry, 
    SYSUTCDATETIME()
FROM Northwind.dbo.Orders;
--****************************************************
-- ۱. پاک‌سازی جدول هدف
TRUNCATE TABLE stage.northwind_order_details;

-- ۲. درج داده‌های جدید
INSERT INTO stage.northwind_order_details WITH (TABLOCK) (
    order_id, 
    product_id, 
    unit_price, 
    quantity, 
    discount, 
    dwh_inserted_at
)
SELECT 
    OrderID, 
    ProductID, 
    UnitPrice, 
    Quantity, 
    Discount, 
    SYSUTCDATETIME()
FROM Northwind.dbo.[Order Details];
--************************************************
