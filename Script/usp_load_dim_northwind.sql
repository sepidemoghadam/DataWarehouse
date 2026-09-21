/*
=========================================================================================
Project:        Northwind Data Warehouse
Layer:          DDS - Sales Data Mart
Object Name:    sale.usp_load_dim_northwind
Author:         Sepide Moghadam
Description:    Loads and transforms Northwind Stage data into Sales Dimensions.

                Target Dimensions:
                - sale.dim_customer
                - sale.dim_employee
                - sale.dim_supplier
                - sale.dim_product
                - sale.dim_shipper
                - sale.dim_geography

                Design Note:
                - Category is denormalized into sale.dim_product.
                - Product and Category Stage tables are joined to create a richer,
                  analysis-ready Product Dimension.
                - The shared Date Dimension is not loaded by this procedure.

                Loading Strategy:
                - Type 1 Slowly Changing Dimension (SCD Type 1)
                - Existing Dimension records are updated.
                - New business keys are inserted.
                - Historical attribute changes are not retained.

                Transformation Techniques Demonstrated:
                1.  Deduplication
                2.  Filtering (Rows and Columns)
                3.  Cleaning and Mapping
                4.  Value Standardization
                5.  Joining / Integration
                6.  Splitting
                7.  Aggregation
                8.  Deriving New Values
                9.  Remove Unwanted Space
                10. Handling Missing Values

Source Database: stage_dw
Source Schema:   stage
Target Database: dds
Target Schema:   sale

Execution:      EXEC sale.usp_load_dim_northwind;
=========================================================================================
*/

USE dds;
GO

CREATE OR ALTER PROCEDURE sale.usp_load_dim_northwind
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @load_datetime DATETIME2(3) = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        ---------------------------------------------------------------------------------
        -- 1. Load Customer Dimension
        ---------------------------------------------------------------------------------
        /*
            Transformations:
            - Deduplication:
              ROW_NUMBER retains only the latest record per customer_id.

            - Filtering Rows:
              Records with NULL or blank customer_id are excluded.

            - Filtering Columns:
              Address attributes are excluded because they are integrated into
              the separate Geography Dimension.

            - Remove Unwanted Space:
              LTRIM(RTRIM()) removes leading and trailing spaces.

            - Handling Missing Values / Cleaning and Mapping:
              NULLIF converts blank values to NULL.
              COALESCE maps NULL values to standard defaults.
        */
        ;WITH customer_ranked AS
        (
            SELECT
                customer_id,
                company_name,
                contact_name,
                contact_title,
                phone,
                fax,
                dwh_inserted_at,

                ROW_NUMBER() OVER
                (
                    PARTITION BY LTRIM(RTRIM(customer_id))
                    ORDER BY dwh_inserted_at DESC
                ) AS row_number_value
            FROM stage_dw.stage.northwind_customers
            WHERE NULLIF(LTRIM(RTRIM(customer_id)), '') IS NOT NULL
        ),
        customer_cleaned AS
        (
            SELECT
                LTRIM(RTRIM(customer_id)) AS customer_id,
                COALESCE(NULLIF(LTRIM(RTRIM(company_name)), ''), N'Unknown Company') AS company_name,
                COALESCE(NULLIF(LTRIM(RTRIM(contact_name)), ''), N'Unknown Contact') AS contact_name,
                COALESCE(NULLIF(LTRIM(RTRIM(contact_title)), ''), N'Unknown') AS contact_title,
                COALESCE(NULLIF(LTRIM(RTRIM(phone)), ''), N'Unknown') AS phone,
                COALESCE(NULLIF(LTRIM(RTRIM(fax)), ''), N'Not Available') AS fax
            FROM customer_ranked
            WHERE row_number_value = 1
        )
        MERGE sale.dim_customer AS target
        USING customer_cleaned AS source
            ON target.customer_id = source.customer_id

        WHEN MATCHED THEN
            UPDATE SET
                target.company_name = source.company_name,
                target.contact_name = source.contact_name,
                target.contact_title = source.contact_title,
                target.phone = source.phone,
                target.fax = source.fax,
                target.dwh_inserted_at = @load_datetime

        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                customer_id,
                company_name,
                contact_name,
                contact_title,
                phone,
                fax,
                dwh_inserted_at
            )
            VALUES
            (
                source.customer_id,
                source.company_name,
                source.contact_name,
                source.contact_title,
                source.phone,
                source.fax,
                @load_datetime
            );

        ---------------------------------------------------------------------------------
        -- 2. Load Employee Dimension
        ---------------------------------------------------------------------------------
        /*
            Transformations:
            - Deduplication:
              Keeps the latest row per employee_id.

            - Remove Unwanted Space:
              Employee names and titles are trimmed.

            - Deriving New Values:
              full_name is generated from first_name and last_name.

            - Handling Missing Values:
              Missing descriptive fields are replaced by 'Unknown'.
        */
        ;WITH employee_ranked AS
        (
            SELECT
                employee_id,
                first_name,
                last_name,
                title,
                title_of_courtesy,
                birth_date,
                hire_date,
                reports_to,
                dwh_inserted_at,

                ROW_NUMBER() OVER
                (
                    PARTITION BY employee_id
                    ORDER BY dwh_inserted_at DESC
                ) AS row_number_value
            FROM stage_dw.stage.northwind_employees
            WHERE employee_id IS NOT NULL
        ),
        employee_cleaned AS
        (
            SELECT
                employee_id,
                COALESCE(NULLIF(LTRIM(RTRIM(first_name)), ''), N'Unknown') AS first_name,
                COALESCE(NULLIF(LTRIM(RTRIM(last_name)), ''), N'Unknown') AS last_name,
                COALESCE(NULLIF(LTRIM(RTRIM(title)), ''), N'Unknown') AS title,
                COALESCE(NULLIF(LTRIM(RTRIM(title_of_courtesy)), ''), N'Unknown') AS title_of_courtesy,
                CAST(birth_date AS DATE) AS birth_date,
                CAST(hire_date AS DATE) AS hire_date,
                reports_to AS reports_to_employee_id
            FROM employee_ranked
            WHERE row_number_value = 1
        )
        MERGE sale.dim_employee AS target
        USING
        (
            SELECT
                employee_id,
                first_name,
                last_name,

                -- Deriving New Value
                CONCAT(first_name, N' ', last_name) AS full_name,

                title,
                title_of_courtesy,
                birth_date,
                hire_date,
                reports_to_employee_id
            FROM employee_cleaned
        ) AS source
            ON target.employee_id = source.employee_id

        WHEN MATCHED THEN
            UPDATE SET
                target.first_name = source.first_name,
                target.last_name = source.last_name,
                target.full_name = source.full_name,
                target.title = source.title,
                target.title_of_courtesy = source.title_of_courtesy,
                target.birth_date = source.birth_date,
                target.hire_date = source.hire_date,
                target.reports_to_employee_id = source.reports_to_employee_id,
                target.dwh_inserted_at = @load_datetime

        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                employee_id,
                first_name,
                last_name,
                full_name,
                title,
                title_of_courtesy,
                birth_date,
                hire_date,
                reports_to_employee_id,
                dwh_inserted_at
            )
            VALUES
            (
                source.employee_id,
                source.first_name,
                source.last_name,
                source.full_name,
                source.title,
                source.title_of_courtesy,
                source.birth_date,
                source.hire_date,
                source.reports_to_employee_id,
                @load_datetime
            );

        ---------------------------------------------------------------------------------
        -- 3. Load Supplier Dimension
        ---------------------------------------------------------------------------------
        /*
            Transformations:
            - Deduplication: Keeps the latest row per supplier_id.
            - Remove Unwanted Space: Trims all text values.
            - Handling Missing Values: Maps NULL / blank values to defaults.
        */
        ;WITH supplier_ranked AS
        (
            SELECT
                supplier_id,
                company_name,
                contact_name,
                contact_title,
                phone,
                home_page,
                dwh_inserted_at,

                ROW_NUMBER() OVER
                (
                    PARTITION BY supplier_id
                    ORDER BY dwh_inserted_at DESC
                ) AS row_number_value
            FROM stage_dw.stage.northwind_suppliers
            WHERE supplier_id IS NOT NULL
        )
        MERGE sale.dim_supplier AS target
        USING
        (
            SELECT
                supplier_id,
                COALESCE(NULLIF(LTRIM(RTRIM(company_name)), ''), N'Unknown Supplier') AS company_name,
                COALESCE(NULLIF(LTRIM(RTRIM(contact_name)), ''), N'Unknown') AS contact_name,
                COALESCE(NULLIF(LTRIM(RTRIM(contact_title)), ''), N'Unknown') AS contact_title,
                COALESCE(NULLIF(LTRIM(RTRIM(phone)), ''), N'Unknown') AS phone,
                COALESCE(NULLIF(LTRIM(RTRIM(home_page)), ''), N'Not Available') AS home_page
            FROM supplier_ranked
            WHERE row_number_value = 1
        ) AS source
            ON target.supplier_id = source.supplier_id

        WHEN MATCHED THEN
            UPDATE SET
                target.company_name = source.company_name,
                target.contact_name = source.contact_name,
                target.contact_title = source.contact_title,
                target.phone = source.phone,
                target.home_page = source.home_page,
                target.dwh_inserted_at = @load_datetime

        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                supplier_id,
                company_name,
                contact_name,
                contact_title,
                phone,
                home_page,
                dwh_inserted_at
            )
            VALUES
            (
                source.supplier_id,
                source.company_name,
                source.contact_name,
                source.contact_title,
                source.phone,
                source.home_page,
                @load_datetime
            );

        ---------------------------------------------------------------------------------
        -- 4. Load Product Dimension with Denormalized Category Attributes
        ---------------------------------------------------------------------------------
        /*
            Transformations:
            - Deduplication:
              Latest Product and Category record is retained per Business Key.

            - Joining / Integration:
              Product records are LEFT JOINed to Category records using category_id.
              Category details are physically stored in dim_product.

            - Filtering Rows:
              Records without product_id are excluded.

            - Filtering Columns:
              The binary category picture is deliberately not transferred because
              it is not needed for Sales Mart reporting.

            - Splitting:
              package_quantity is extracted from quantity_per_unit.
              Example:
              "24 - 12 oz bottles" => package_quantity = 24

            - Value Standardization:
              discontinued values are standardized as ACTIVE or DISCONTINUED.

            - Handling Missing Values:
              Missing category, stock, price, package and status values are mapped
              to safe reporting values.

            - Deriving New Values:
              package_quantity and discontinued_status are calculated.
        */
        ;WITH product_ranked AS
        (
            SELECT
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
                dwh_inserted_at,

                ROW_NUMBER() OVER
                (
                    PARTITION BY product_id
                    ORDER BY dwh_inserted_at DESC
                ) AS row_number_value
            FROM stage_dw.stage.northwind_products
            WHERE product_id IS NOT NULL
        ),
        category_ranked AS
        (
            SELECT
                category_id,
                category_name,
                category_desc,
                dwh_inserted_at,

                ROW_NUMBER() OVER
                (
                    PARTITION BY category_id
                    ORDER BY dwh_inserted_at DESC
                ) AS row_number_value
            FROM stage_dw.stage.northwind_categories
            WHERE category_id IS NOT NULL
        ),
        product_category_integrated AS
        (
            SELECT
                p.product_id,
                p.product_name,
                p.supplier_id,
                p.category_id,
                p.quantity_per_unit,
                p.unit_price,
                p.units_in_stock,
                p.units_on_order,
                p.reorder_level,
                p.discontinued,

                /*
                    Cleaning + Mapping + Missing Value Handling:
                    If a Product has no matching Category record, use Unknown Category.
                */
                COALESCE(NULLIF(LTRIM(RTRIM(c.category_name)), ''), N'Unknown Category') AS category_name,
                COALESCE(NULLIF(LTRIM(RTRIM(c.category_desc)), ''), N'Not Available') AS category_desc
            FROM product_ranked AS p
            LEFT JOIN category_ranked AS c
                ON p.category_id = c.category_id
               AND c.row_number_value = 1
            WHERE p.row_number_value = 1
        ),
        product_cleaned AS
        (
            SELECT
                product_id,
                COALESCE(NULLIF(LTRIM(RTRIM(product_name)), ''), N'Unknown Product') AS product_name,
                supplier_id,
                category_id,
                category_name,
                category_desc,
                COALESCE(NULLIF(LTRIM(RTRIM(quantity_per_unit)), ''), N'Unknown') AS quantity_per_unit,
                COALESCE(CAST(unit_price AS DECIMAL(19,4)), 0) AS current_unit_price,
                COALESCE(CAST(units_in_stock AS INT), 0) AS units_in_stock,
                COALESCE(CAST(units_on_order AS INT), 0) AS units_on_order,
                COALESCE(CAST(reorder_level AS INT), 0) AS reorder_level,

                CASE
                    WHEN COALESCE(discontinued, 0) = 1 THEN 'DISCONTINUED'
                    ELSE 'ACTIVE'
                END AS discontinued_status
            FROM product_category_integrated
        )
        MERGE sale.dim_product AS target
        USING
        (
            SELECT
                product_id,
                product_name,
                supplier_id,
                category_id,
                category_name,
                category_desc,
                quantity_per_unit,

                /*
                    Splitting:
                    Extracts the numeric value at the start of quantity_per_unit.
                */
                TRY_CAST
                (
                    LEFT
                    (
                        quantity_per_unit,
                        PATINDEX('%[^0-9]%', quantity_per_unit + 'X') - 1
                    ) AS INT
                ) AS package_quantity,

                quantity_per_unit AS package_unit,
                current_unit_price,
                units_in_stock,
                units_on_order,
                reorder_level,
                discontinued_status
            FROM product_cleaned
        ) AS source
            ON target.product_id = source.product_id

        WHEN MATCHED THEN
            UPDATE SET
                target.product_name = source.product_name,
                target.supplier_id = source.supplier_id,
                target.category_id = source.category_id,
                target.category_name = source.category_name,
                target.category_desc = source.category_desc,
                target.quantity_per_unit = source.quantity_per_unit,
                target.package_quantity = source.package_quantity,
                target.package_unit = source.package_unit,
                target.current_unit_price = source.current_unit_price,
                target.units_in_stock = source.units_in_stock,
                target.units_on_order = source.units_on_order,
                target.reorder_level = source.reorder_level,
                target.discontinued_status = source.discontinued_status,
                target.dwh_inserted_at = @load_datetime

        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
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
                discontinued_status,
                dwh_inserted_at
            )
            VALUES
            (
                source.product_id,
                source.product_name,
                source.supplier_id,
                source.category_id,
                source.category_name,
                source.category_desc,
                source.quantity_per_unit,
                source.package_quantity,
                source.package_unit,
                source.current_unit_price,
                source.units_in_stock,
                source.units_on_order,
                source.reorder_level,
                source.discontinued_status,
                @load_datetime
            );

        ---------------------------------------------------------------------------------
        -- 5. Load Shipper Dimension
        ---------------------------------------------------------------------------------
        /*
            Transformations:
            - Deduplication: Retains latest record per shipper_id.
            - Remove Unwanted Space: Cleans textual attributes.
            - Handling Missing Values: Converts NULL / blank values to Unknown.
        */
        ;WITH shipper_ranked AS
        (
            SELECT
                shipper_id,
                company_name,
                phone,
                dwh_inserted_at,

                ROW_NUMBER() OVER
                (
                    PARTITION BY shipper_id
                    ORDER BY dwh_inserted_at DESC
                ) AS row_number_value
            FROM stage_dw.stage.northwind_shippers
            WHERE shipper_id IS NOT NULL
        )
        MERGE sale.dim_shipper AS target
        USING
        (
            SELECT
                shipper_id,
                COALESCE(NULLIF(LTRIM(RTRIM(company_name)), ''), N'Unknown Shipper') AS company_name,
                COALESCE(NULLIF(LTRIM(RTRIM(phone)), ''), N'Unknown') AS phone
            FROM shipper_ranked
            WHERE row_number_value = 1
        ) AS source
            ON target.shipper_id = source.shipper_id

        WHEN MATCHED THEN
            UPDATE SET
                target.company_name = source.company_name,
                target.phone = source.phone,
                target.dwh_inserted_at = @load_datetime

        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                shipper_id,
                company_name,
                phone,
                dwh_inserted_at
            )
            VALUES
            (
                source.shipper_id,
                source.company_name,
                source.phone,
                @load_datetime
            );

        ---------------------------------------------------------------------------------
        -- 6. Load Geography Dimension
        ---------------------------------------------------------------------------------
        /*
            Transformations:
            - Integration:
              Geography values are combined from Customers, Employees, Suppliers,
              and Order Shipping Addresses.

            - Value Standardization:
              UPPER() converts variants such as:
              "Germany", " germany ", "GERMANY" -> "GERMANY".

            - Remove Unwanted Space:
              LTRIM(RTRIM()) removes surrounding whitespace.

            - Handling Missing Values:
              NULL and blank values are mapped to 'UNKNOWN'.

            - Aggregation and Deduplication:
              GROUP BY returns exactly one Dimension member for each distinct
              Country + Region + City + Postal Code combination.
        */
        ;WITH geography_raw AS
        (
            SELECT country, region, city, postal_code
            FROM stage_dw.stage.northwind_customers

            UNION ALL

            SELECT country, region, city, postal_code
            FROM stage_dw.stage.northwind_employees

            UNION ALL

            SELECT country, region, city, postal_code
            FROM stage_dw.stage.northwind_suppliers

            UNION ALL

            SELECT ship_country, ship_region, ship_city, ship_postal_code
            FROM stage_dw.stage.northwind_orders
        ),
        geography_cleaned AS
        (
            SELECT
                COALESCE(NULLIF(UPPER(LTRIM(RTRIM(country))), ''), N'UNKNOWN') AS country,
                COALESCE(NULLIF(UPPER(LTRIM(RTRIM(region))), ''), N'UNKNOWN') AS region,
                COALESCE(NULLIF(UPPER(LTRIM(RTRIM(city))), ''), N'UNKNOWN') AS city,
                COALESCE(NULLIF(UPPER(LTRIM(RTRIM(postal_code))), ''), N'UNKNOWN') AS postal_code
            FROM geography_raw
        ),
        geography_aggregated AS
        (
            SELECT
                country,
                region,
                city,
                postal_code,
                COUNT(*) AS source_record_count
            FROM geography_cleaned
            GROUP BY
                country,
                region,
                city,
                postal_code
        )
        MERGE sale.dim_geography AS target
        USING geography_aggregated AS source
            ON  target.country = source.country
            AND target.region = source.region
            AND target.city = source.city
            AND target.postal_code = source.postal_code

        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                country,
                region,
                city,
                postal_code,
                dwh_inserted_at
            )
            VALUES
            (
                source.country,
                source.region,
                source.city,
                source.postal_code,
                @load_datetime
            );

        COMMIT TRANSACTION;

        PRINT 'Sales Dimensions loaded successfully.';
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
