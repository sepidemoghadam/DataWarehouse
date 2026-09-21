
# Data Catalog — Sales ETL / Data Warehouse Project

**Owner:** Reza Afkhamnia 
**Role:** Data Warehouse Developer
**Platform:** Microsoft SQL Server  
**Language:** T-SQL  
**Architecture:** Staging → Dimension → Fact  
**Document Type:** Markdown (`.md`)  
**Last Updated:** 2026-08-10

---

## 1. Purpose

This Data Catalog is the official metadata reference for the Sales ETL / Data Warehouse project.

It documents:

- the business meaning of tables and columns
- the warehouse architecture and layer responsibilities
- the grain of each dataset
- standard ETL transaction handling
- data cleansing and null-handling rules
- data quality checks
- governance and security expectations
- reporting and KPI usage

This catalog is intended to be the single source of truth for developers, analysts, and stakeholders working with the project.

---

## 2. Architecture Overview

### Data Flow

```text
Source Systems
    ↓
Staging Layer (stg)
    ↓
ETL Transformation
    ↓
Dimension Layer (dim)
    ↓
Fact Layer (fact)
    ↓
BI / Reports / Dashboards
```

### Layer Responsibilities

| Layer | Schema | Responsibility |
|---|---|---|
| Raw ingestion | `stg` | Stores extracted source data with minimal transformation |
| Business entities | `dim` | Stores descriptive attributes used for slicing and grouping |
| Measurements | `fact` | Stores transactional metrics and business events |
| Operations | `etl` | Stores execution logs, errors, and ETL control metadata |

---

## 3. Business Glossary

| Term | Definition | Notes |
|---|---|---|
| **Fact Table** | A table that stores measurable business events | Example: sales transactions |
| **Dimension Table** | A table that stores descriptive context | Example: product, customer, date |
| **Grain** | The lowest level of detail in a table | Must be clearly defined for every fact |
| **Surrogate Key** | Warehouse-generated integer key | Usually an identity column |
| **Business Key** | Source-system identifier | Example: CustomerID, ProductID |
| **Unknown Member** | Default dimension row for missing lookup values | Commonly mapped to key `0` |
| **PII** | Personally Identifiable Information | Example: phone, email |
| **Data Lineage** | Path of data from source to consumption | Important for trust and auditing |
| **KPI** | Key Performance Indicator | Example: Net Sales, Quantity Sold |

---

## 4. Data Inventory

| Schema | Table | Type | Purpose | Grain |
|---|---|---|---|---|
| `stg` | `stg.SalesOrder` | Staging | Raw sales order lines from source systems | One row per order line |
| `stg` | `stg.Customer` | Staging | Raw customer records | One row per customer |
| `stg` | `stg.Product` | Staging | Raw product records | One row per product |
| `dim` | `dim.Date` | Dimension | Calendar and time analysis | One row per day |
| `dim` | `dim.Customer` | Dimension | Customer descriptive attributes | One row per customer |
| `dim` | `dim.Product` | Dimension | Product descriptive attributes | One row per product |
| `fact` | `fact.Sales` | Fact | Sales transactions and measures | One row per order line |
| `etl` | `etl.ETLExecutionLog` | Operational | ETL run tracking | One row per run |
| `etl` | `etl.ETLErrorLog` | Operational | ETL error tracking | One row per error |

---

## 5. Staging Layer

### 5.1 `stg.SalesOrder`

**Purpose:**  
Stores raw sales order line records loaded from the source system before transformation.

**Grain:**  
One row per sales order line.

| Column | Type | Nullable | Description | Rule |
|---|---|---:|---|---|
| `SourceOrderID` | `NVARCHAR(50)` | No | Source order identifier | Must not be blank |
| `SourceOrderLineID` | `NVARCHAR(50)` | No | Source order line identifier | Must be unique with order ID |
| `OrderDate` | `DATE` | No | Order date | Must be valid |
| `CustomerID` | `NVARCHAR(50)` | Yes | Customer business key | Empty string becomes NULL |
| `ProductID` | `NVARCHAR(50)` | Yes | Product business key | Empty string becomes NULL |
| `Quantity` | `INT` | No | Quantity sold | Must be greater than zero unless returns are modeled |
| `UnitPrice` | `DECIMAL(18,2)` | No | Unit price | Must be `>= 0` |
| `DiscountAmount` | `DECIMAL(18,2)` | Yes | Discount value | Default to `0` if NULL |
| `SourceCreatedDate` | `DATETIME2` | Yes | Source creation timestamp | Used for incremental logic |
| `SourceModifiedDate` | `DATETIME2` | Yes | Source modification timestamp | Used for incremental logic |
| `LoadDate` | `DATETIME2` | No | Warehouse load timestamp | Default `SYSDATETIME()` |

---

### 5.2 `stg.Customer`

**Purpose:**  
Stores raw customer data before cleansing and loading to `dim.Customer`.

**Grain:**  
One row per customer.

| Column | Type | Nullable | Description | Rule |
|---|---|---:|---|---|
| `CustomerID` | `NVARCHAR(50)` | No | Source customer business key | Must not be blank |
| `CustomerName` | `NVARCHAR(200)` | Yes | Customer name | Trim spaces and handle missing values |
| `CustomerPhone` | `NVARCHAR(50)` | Yes | Customer phone number | Classified as PII |
| `CustomerEmail` | `NVARCHAR(255)` | Yes | Customer email address | Classified as PII |
| `CustomerCity` | `NVARCHAR(100)` | Yes | City | Standardize text |
| `CustomerProvince` | `NVARCHAR(100)` | Yes | Province / region | Standardize text |
| `IsActive` | `BIT` | Yes | Active flag | Default depends on source |
| `SourceModifiedDate` | `DATETIME2` | Yes | Source update timestamp | Used for incremental logic |
| `LoadDate` | `DATETIME2` | No | Warehouse load timestamp | Default `SYSDATETIME()` |

---

### 5.3 `stg.Product`

**Purpose:**  
Stores raw product data before transformation and loading to `dim.Product`.

**Grain:**  
One row per product.

| Column | Type | Nullable | Description | Rule |
|---|---|---:|---|---|
| `ProductID` | `NVARCHAR(50)` | No | Source product business key | Must not be blank |
| `ProductName` | `NVARCHAR(250)` | Yes | Product title | Trim spaces and handle missing values |
| `CategoryName` | `NVARCHAR(150)` | Yes | Product category | Standardize text |
| `BrandName` | `NVARCHAR(150)` | Yes | Brand name | Standardize text |
| `UnitPrice` | `DECIMAL(18,2)` | Yes | Product price | Must be `>= 0` |
| `IsActive` | `BIT` | Yes | Activity flag | Depends on source |
| `SourceModifiedDate` | `DATETIME2` | Yes | Source update timestamp | Used for incremental logic |
| `LoadDate` | `DATETIME2` | No | Warehouse load timestamp | Default `SYSDATETIME()` |

---

## 6. Dimension Layer

### 6.1 `dim.Date`

**Purpose:**  
Provides a reusable calendar dimension for reporting and time-based analysis.

**Grain:**  
One row per calendar day.

| Column | Type | Nullable | Description |
|---|---|---:|---|
| `DateKey` | `INT` | No | Surrogate date key in `YYYYMMDD` format |
| `FullDate` | `DATE` | No | Actual calendar date |
| `DayNameOfWeek` | `NVARCHAR(20)` | No | Day name |
| `DayNumberOfWeek` | `TINYINT` | No | Day number |
| `MonthName` | `NVARCHAR(20)` | No | Month name |
| `MonthNumberOfYear` | `TINYINT` | No | Month number |
| `QuarterNumber` | `TINYINT` | No | Quarter number |
| `YearNumber` | `SMALLINT` | No | Calendar year |
| `IsWeekend` | `BIT` | No | Weekend flag |

---

### 6.2 `dim.Customer`

**Purpose:**  
Stores customer attributes for reporting and analysis.

**Grain:**  
One row per customer.

**SCD Type:**  
Type 1

| Column | Type | Nullable | Description |
|---|---|---:|---|
| `CustomerKey` | `INT IDENTITY(1,1)` | No | Surrogate primary key |
| `CustomerAltKey` | `NVARCHAR(50)` | No | Source customer identifier |
| `CustomerName` | `NVARCHAR(200)` | No | Cleaned customer name |
| `CustomerPhone` | `NVARCHAR(50)` | Yes | PII field |
| `CustomerEmail` | `NVARCHAR(255)` | Yes | PII field |
| `CustomerCity` | `NVARCHAR(100)` | Yes | Customer city |
| `CustomerProvince` | `NVARCHAR(100)` | Yes | Customer province |
| `IsActive` | `BIT` | No | Current active status |
| `CreatedDate` | `DATETIME2` | No | Record creation timestamp |
| `ModifiedDate` | `DATETIME2` | Yes | Record last update timestamp |

**Unknown Member:**  
Use `CustomerKey = 0` for unmatched or missing customers.

| CustomerKey | CustomerAltKey | CustomerName |
|---:|---|---|
| `0` | `UNKNOWN` | `Unknown Customer` |

---

### 6.3 `dim.Product`

**Purpose:**  
Stores product attributes for reporting and analysis.

**Grain:**  
One row per product.

**SCD Type:**  
Type 1

| Column | Type | Nullable | Description |
|---|---|---:|---|
| `ProductKey` | `INT IDENTITY(1,1)` | No | Surrogate primary key |
| `ProductAltKey` | `NVARCHAR(50)` | No | Source product identifier |
| `ProductName` | `NVARCHAR(250)` | No | Cleaned product name |
| `CategoryName` | `NVARCHAR(150)` | Yes | Product category |
| `BrandName` | `NVARCHAR(150)` | Yes | Product brand |
| `CurrentUnitPrice` | `DECIMAL(18,2)` | Yes | Current selling price |
| `IsActive` | `BIT` | No | Current active status |
| `CreatedDate` | `DATETIME2` | No | Record creation timestamp |
| `ModifiedDate` | `DATETIME2` | Yes | Record update timestamp |

**Unknown Member:**  
Use `ProductKey = 0` for unmatched or missing products.

| ProductKey | ProductAltKey | ProductName |
|---:|---|---|
| `0` | `UNKNOWN` | `Unknown Product` |

---

## 7. Fact Layer

### 7.1 `fact.Sales`

**Purpose:**  
Stores sales transaction measures for analysis and reporting.

**Grain:**  
One row per order line item.

| Column | Type | Nullable | Description | Rule |
|---|---|---:|---|---|
| `SalesKey` | `BIGINT IDENTITY(1,1)` | No | Surrogate primary key | System generated |
| `OrderKey` | `INT` | No | Order reference | FK to `dim.Order` if used |
| `CustomerKey` | `INT` | No | Customer reference | Default to `0` if not found |
| `ProductKey` | `INT` | No | Product reference | Default to `0` if not found |
| `OrderDateKey` | `INT` | No | Date reference | FK to `dim.Date` |
| `OrderLineNumber` | `INT` | No | Source line number | Degenerate attribute |
| `Quantity` | `INT` | No | Units sold | Must be positive |
| `UnitPrice` | `DECIMAL(18,2)` | No | Unit price | Must be `>= 0` |
| `GrossAmount` | `DECIMAL(18,2)` | No | Amount before discount | `Quantity * UnitPrice` |
| `DiscountAmount` | `DECIMAL(18,2)` | No | Discount amount | Default `0` if NULL |
| `NetAmount` | `DECIMAL(18,2)` | No | Final sales amount | `GrossAmount - DiscountAmount` |
| `LoadDate` | `DATETIME2` | No | Load timestamp | Default `SYSDATETIME()` |

---

## 8. Business Rules

| Rule | Description |
|---|---|
| Grain must remain stable | Every fact row represents one order line |
| Unknown members are required | Missing dimension lookups must map to key `0` |
| Gross amount must be calculated consistently | `GrossAmount = Quantity * UnitPrice` |
| Net amount must be calculated consistently | `NetAmount = GrossAmount - DiscountAmount` |
| Empty strings are not valid business values | Convert to `NULL` and handle with defaults |
| PII must be protected | Mask or restrict phone and email data |
| ETL must be atomic | Use transaction management and rollback on error |

---

## 9. Standard Data Cleansing Pattern

The standard pattern for text cleaning is:

```sql
COALESCE(NULLIF(LTRIM(RTRIM(SourceColumn)), N''), N'Unknown')
```

### Meaning

| Function | Purpose |
|---|---|
| `LTRIM()` | Removes leading spaces |
| `RTRIM()` | Removes trailing spaces |
| `NULLIF()` | Converts empty string to `NULL` |
| `COALESCE()` | Replaces `NULL` with a fallback value |

### Example

```sql
SELECT
    COALESCE(
        NULLIF(LTRIM(RTRIM(CustomerName)), N''),
        N'Unknown Customer'
    ) AS CleanCustomerName
FROM stg.Customer;
```

### Numeric Default Example

```sql
SELECT
    COALESCE(DiscountAmount, 0) AS CleanDiscountAmount
FROM stg.SalesOrder;
```

---

## 10. Transaction Management Standard

All ETL procedures must use controlled transactions.

```sql
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- ETL operations:
    -- 1. Read from staging
    -- 2. Clean data
    -- 3. Load dimensions
    -- 4. Load facts
    -- 5. Write logs

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
```

### Why this pattern is required

- `SET XACT_ABORT ON` ensures runtime errors cause automatic transaction failure.
- `BEGIN TRANSACTION` starts an atomic unit of work.
- `COMMIT TRANSACTION` saves all changes permanently.
- `ROLLBACK TRANSACTION` cancels all changes if any step fails.
- `THROW` propagates the error to the caller or monitoring tool.

---

## 11. ETL Loading Rules

### Load Sequence

1. Load staging tables
2. Clean and validate source records
3. Load dimension tables
4. Resolve surrogate keys
5. Load fact tables
6. Log success or failure

### Recommended Order

| Step | Object |
|---|---|
| 1 | `stg.Customer` |
| 2 | `stg.Product` |
| 3 | `stg.SalesOrder` |
| 4 | `dim.Date` |
| 5 | `dim.Customer` |
| 6 | `dim.Product` |
| 7 | `fact.Sales` |
| 8 | `etl.ETLExecutionLog` |

---

## 12. Data Quality Checks

### Duplicate Source Lines

```sql
SELECT
    SourceOrderID,
    SourceOrderLineID,
    COUNT(*) AS DuplicateCount
FROM stg.SalesOrder
GROUP BY
    SourceOrderID,
    SourceOrderLineID
HAVING COUNT(*) > 1;
```

### Invalid Quantities

```sql
SELECT *
FROM stg.SalesOrder
WHERE Quantity <= 0;
```

### Invalid Financial Values

```sql
SELECT *
FROM fact.Sales
WHERE GrossAmount <> Quantity * UnitPrice
   OR NetAmount <> GrossAmount - DiscountAmount;
```

### Orphan Fact Records

```sql
SELECT f.SalesKey
FROM fact.Sales f
LEFT JOIN dim.Product p
    ON f.ProductKey = p.ProductKey
WHERE p.ProductKey IS NULL;
```

### Unknown Member Rate

```sql
SELECT
    COUNT(*) AS TotalRows,
    SUM(CASE WHEN CustomerKey = 0 THEN 1 ELSE 0 END) AS UnknownCustomerRows,
    SUM(CASE WHEN ProductKey = 0 THEN 1 ELSE 0 END) AS UnknownProductRows
FROM fact.Sales;
```

---

## 13. KPI Definitions

| KPI | Definition | Formula |
|---|---|---|
| **Gross Sales** | Total revenue before discount | `SUM(GrossAmount)` |
| **Net Sales** | Total revenue after discount | `SUM(NetAmount)` |
| **Total Discount** | Total discount amount | `SUM(DiscountAmount)` |
| **Total Quantity Sold** | Total number of units sold | `SUM(Quantity)` |
| **Average Selling Price** | Average revenue per sold unit | `SUM(NetAmount) / NULLIF(SUM(Quantity), 0)` |
| **Order Count** | Number of unique orders | `COUNT(DISTINCT OrderKey)` |

---

## 14. Security and Governance

### Sensitive Data

The following fields are considered PII and must be protected:

- `CustomerPhone`
- `CustomerEmail`

### Security Principles

- Apply least privilege access
- Restrict staging table access
- Mask PII in non-production environments
- Expose curated views instead of raw tables to report consumers
- Never store credentials, secrets, or tokens in the repository

### Data Stewardship

| Domain | Steward | Responsibility |
|---|---|---|
| Sales | Reza Afkhamnia / BI Team | Maintain sales logic and KPI definitions |
| Customer | Data Team / CRM Team | Maintain customer quality and privacy rules |
| Product | Data Team / Product Team | Maintain product hierarchy and master data |
| Warehouse | Data Warehouse Owner | Maintain ETL, catalog, and technical governance |

---

## 15. Reporting Recommendations

Consumers should use curated reporting views instead of querying raw tables directly.

### Recommended Reporting Layer

- `rpt.vw_SalesSummary`
- `rpt.vw_ProductPerformance`
- `rpt.vw_CustomerSales`
- `rpt.vw_DailySalesTrend`

### Example Reporting Logic

```text
fact.Sales
    + dim.Customer
    + dim.Product
    + dim.Date
    = Business Reporting Views
```

---

## 16. ETL Logging Requirements

Every ETL execution should log:

- process name
- start time
- end time
- execution status
- row counts
- error message if failed

### Suggested Log Tables

#### `etl.ETLExecutionLog`

| Column | Purpose |
|---|---|
| `ExecutionLogKey` | Unique log record ID |
| `ProcessName` | Name of the ETL job |
| `StartDateTime` | Execution start time |
| `EndDateTime` | Execution end time |
| `ExecutionStatus` | Started / Success / Failed |
| `InsertedRows` | Number of inserted rows |
| `UpdatedRows` | Number of updated rows |
| `RejectedRows` | Number of rejected rows |
| `ErrorMessage` | Failure details |

#### `etl.ETLErrorLog`

| Column | Purpose |
|---|---|
| `ErrorLogKey` | Unique error record ID |
| `ProcessName` | Failed ETL process |
| `ErrorNumber` | SQL Server error number |
| `ErrorSeverity` | Error severity |
| `ErrorState` | Error state |
| `ErrorProcedure` | Failing procedure |
| `ErrorLine` | Error line number |
| `ErrorMessage` | Error text |
| `ErrorDateTime` | Time of error |

---

## 17. Change Management

Any structural or business change must be reflected in this catalog.

### Update the catalog when:

- a new table is added
- a column is renamed or removed
- a data type changes
- a KPI formula changes
- a source system changes
- a business rule changes
- a new sensitive field is introduced
- a new ETL procedure is deployed

---

## 18. Maintenance Checklist

- [ ] Tables are documented
- [ ] Columns are documented
- [ ] Grain is defined
- [ ] Business rules are documented
- [ ] ETL transaction pattern is applied
- [ ] Data cleansing pattern is used
- [ ] Quality checks are defined
- [ ] PII fields are identified
- [ ] Logging strategy is documented
- [ ] Catalog version is updated

---

## 19. Version History

| Version | Date | Author | Notes |
|---|---|---|---|
| `1.0.0` | `2026-08-10` | Reza Afkhamnia | Initial Data Catalog for Sales ETL / Data Warehouse project |

---

## 20. Final Statement

This Data Catalog defines the operational and business metadata standards for the project and should be treated as a living document.

Any modification to the ETL pipeline, warehouse schema, business logic, or reporting layer must be synchronized with this catalog to preserve consistency, reliability, and trust.

---

**Maintained by:** Reza Afkhamnia  
**Format:** Markdown (`.md`)  
**Repository Use:** GitHub Documentation
