
# Data Warehouse Project

An end-to-end **Data Warehouse project using Microsoft SQL Server and T-SQL**, designed to demonstrate the implementation of a practical data warehousing pipeline from source data ingestion to business-ready analytical data.

The project covers **database creation, staging, data transformation, dimensional modeling, ETL processing, data loading through stored procedures, data quality, metadata management, and data cataloging**.

The overall architecture follows the flow:

```text
Source Data
    ↓
Staging
    ↓
ETL / Transformation
    ↓
Dimension & Fact
    ↓
Business-Ready Data
    ↓
BI / Reporting / Analytics
```

---

## 🎯 Project Overview

The goal of this project is to build a structured and maintainable Data Warehouse environment for analyzing **Sales data**.

Instead of querying raw source data directly, the project separates data processing into logical layers. Each layer has a specific responsibility:

* **Source** – Raw operational/source data
* **Staging** – Initial ingestion and preparation of source data
* **Transformation** – Data cleansing, standardization, normalization and enrichment
* **Dimension** – Business entities and descriptive attributes
* **Fact** – Transactional measurements and business events
* **ETL** – Execution control, logging and error handling
* **Reporting / BI** – Consumption of curated warehouse data

This separation makes the data pipeline easier to understand, maintain, validate and extend.

---

## 🏗️ Data Warehouse Architecture

The architecture used in this project separates **raw data, cleaned data and business-ready data**.

```text
                    ┌──────────────────────┐
                    │     Source Systems   │
                    │      Raw Data        │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │       Staging        │
                    │   Raw / Prepared     │
                    │      Source Data     │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │   ETL / Transform    │
                    │                      │
                    │ • Cleansing          │
                    │ • Standardization    │
                    │ • Normalization      │
                    │ • Derived Columns    │
                    │ • Enrichment         │
                    │ • Integration        │
                    └──────────┬───────────┘
                               │
                               ▼
             ┌──────────────────────────────────┐
             │          Data Warehouse           │
             │                                  │
             │       Star Schema Model          │
             │                                  │
             │   ┌──────────┐  ┌──────────┐     │
             │   │ Customer │  │ Product  │     │
             │   │   Dim    │  │   Dim    │     │
             │   └────┬─────┘  └────┬─────┘     │
             │        │             │            │
             │        └──────┬──────┘            │
             │               ▼                   │
             │          ┌──────────┐             │
             │          │  Sales   │             │
             │          │   Fact   │             │
             │          └──────────┘             │
             │                                  │
             └──────────────────┬───────────────┘
                                │
                                ▼
                    ┌──────────────────────┐
                    │    BI / Reporting   │
                    │     Analytics       │
                    └──────────────────────┘
```

The architecture document defines the staging layer as the area where source data is loaded and transformed, while the warehouse layer provides the business-ready dimensional model. The documented transformation activities include cleansing, standardization, normalization, derived columns, enrichment and data integration.

---

## 🧱 Data Warehouse Layers

### 1. Source

The source layer represents the operational data coming from source systems.

The source data is treated as the starting point of the pipeline and is not directly used as the primary reporting model.

---

### 2. Staging

The `stg` layer is responsible for receiving source data before it is transformed and loaded into the dimensional warehouse.

The project contains staging structures for:

* `stg.SalesOrder`
* `stg.Customer`
* `stg.Product`

The staging layer keeps the source-oriented representation of the data and provides the input for subsequent ETL processing.

The Data Catalog defines the grain of these datasets explicitly:

| Table            | Grain                  |
| ---------------- | ---------------------- |
| `stg.SalesOrder` | One row per order line |
| `stg.Customer`   | One row per customer   |
| `stg.Product`    | One row per product    |

The catalog also defines source identifiers, timestamps and data-quality rules for the staging data.

---

### 3. Transformation / ETL

The ETL layer is responsible for converting source-oriented data into clean and consistent warehouse data.

The project follows transformation concepts such as:

* Data Cleansing
* Data Standardization
* Data Normalization
* Derived Columns
* Data Enrichment
* Data Integration

Typical cleansing operations include trimming text values, handling empty strings, replacing missing values and applying numeric defaults.

For example:

```sql
COALESCE(
    NULLIF(LTRIM(RTRIM(SourceColumn)), N''),
    N'Unknown'
)
```

This pattern combines `LTRIM`, `RTRIM`, `NULLIF` and `COALESCE` to normalize empty or missing text values.

---

## ⭐ Dimensional Model

The warehouse uses a **Star Schema** approach for analytical consumption.

The main dimensional structures are:

### Dimensions

* `dim.Date`
* `dim.Customer`
* `dim.Product`

### Fact

* `fact.Sales`

The Data Catalog identifies the fact table grain as:

> One row per order line item.

This grain is important because all measures and relationships in the fact table must remain consistent with that level of detail.

---

## 📅 Date Dimension

`dim.Date` provides a reusable calendar dimension for time-based analysis.

It contains attributes such as:

* Date Key
* Full Date
* Day Name
* Day Number
* Month Name
* Month Number
* Quarter
* Year
* Weekend Flag

The date key follows the `YYYYMMDD` format.

This structure allows reports to analyze sales by day, month, quarter and year without repeatedly deriving calendar attributes from transaction data.

---

## 👤 Customer Dimension

`dim.Customer` stores cleaned and business-ready customer attributes.

Important characteristics include:

* Surrogate key
* Source/business key
* Customer name
* Phone
* Email
* City
* Province
* Active status
* Creation and modification timestamps

The project uses **SCD Type 1** for the customer dimension, meaning the current value of an attribute is maintained rather than preserving historical versions.

A dedicated **Unknown Member** is also defined:

```text
CustomerKey = 0
CustomerAltKey = UNKNOWN
CustomerName = Unknown Customer
```

This allows fact records with missing or unmatched customer references to remain loadable without introducing invalid foreign-key relationships.

---

## 📦 Product Dimension

`dim.Product` stores descriptive product information used for analytical slicing and grouping.

The dimension contains attributes such as:

* Product surrogate key
* Source product identifier
* Product name
* Category
* Brand
* Current unit price
* Active status
* Creation and modification timestamps

The product dimension also follows **SCD Type 1** and provides an Unknown Member using:

```text
ProductKey = 0
ProductAltKey = UNKNOWN
ProductName = Unknown Product
```

This supports consistent surrogate-key resolution during fact loading.

---

## 💰 Sales Fact

`fact.Sales` is the central transactional table of the warehouse.

Its grain is:

```text
One row = One sales order line
```

The fact contains references to dimensions together with measurable business values.

Important fields include:

* `SalesKey`
* `OrderKey`
* `CustomerKey`
* `ProductKey`
* `OrderDateKey`
* `OrderLineNumber`
* `Quantity`
* `UnitPrice`
* `GrossAmount`
* `DiscountAmount`
* `NetAmount`
* `LoadDate`

Financial measures are calculated using consistent business rules:

```text
GrossAmount = Quantity × UnitPrice

NetAmount = GrossAmount - DiscountAmount
```

These rules are explicitly defined in the project's Data Catalog.

---

## 🔑 Surrogate Keys & Unknown Members

The dimensional model distinguishes between:

### Business Key

The identifier coming from the source system.

Examples:

```text
CustomerID
ProductID
```

### Surrogate Key

A warehouse-generated identifier used inside the dimensional model.

Examples:

```text
CustomerKey
ProductKey
SalesKey
```

The project also uses the **Unknown Member pattern**, where unmatched dimension references are mapped to key `0`.

This prevents missing lookup values from breaking fact loading and preserves referential consistency.

---

## ⚙️ ETL Loading Strategy

The documented ETL sequence is:

```text
1. Load staging tables
        ↓
2. Clean and validate source records
        ↓
3. Load dimensions
        ↓
4. Resolve surrogate keys
        ↓
5. Load fact tables
        ↓
6. Log success or failure
```

The recommended loading order is:

```text
stg.Customer
      ↓
stg.Product
      ↓
stg.SalesOrder
      ↓
dim.Date
      ↓
dim.Customer
      ↓
dim.Product
      ↓
fact.Sales
      ↓
etl.ETLExecutionLog
```

This sequence ensures that the required dimension keys exist before transactional data is inserted into the fact table.

---

## 🔄 Stored Procedures

The project uses stored procedures as part of the ETL/data-loading approach.

The procedures encapsulate database-side processing and provide a repeatable mechanism for loading and transforming warehouse data.

The ETL design follows controlled transaction management:

```sql
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    -- ETL operations

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH

    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;

END CATCH;
```

This pattern provides atomicity for ETL operations: if a failure occurs during the process, the transaction can be rolled back rather than leaving the warehouse in a partially loaded state.

---

## 🧹 Data Cleansing

Data cleansing is an important part of the staging-to-warehouse transformation.

The project defines rules for:

* Removing leading and trailing spaces
* Converting empty strings to `NULL`
* Applying default values
* Standardizing textual attributes
* Validating numeric values
* Validating transaction quantities
* Handling missing dimension references

For example:

```sql
COALESCE(DiscountAmount, 0)
```

is used to provide a consistent default for missing discount values.

---

## ✅ Data Quality

The project includes data-quality checks to validate warehouse consistency.

Examples include:

### Duplicate Sales Order Lines

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

### Financial Consistency

```sql
SELECT *
FROM fact.Sales
WHERE GrossAmount <> Quantity * UnitPrice
   OR NetAmount <> GrossAmount - DiscountAmount;
```

### Unknown Dimension Members

The project also monitors the number of fact records mapped to the Unknown Customer or Unknown Product member.

These checks help identify source-data problems, transformation issues and dimension lookup failures.

---

## 📊 Business KPIs

The warehouse supports common sales analytics and KPI calculations.

| KPI                   | Definition                         |
| --------------------- | ---------------------------------- |
| Gross Sales           | Total revenue before discount      |
| Net Sales             | Total revenue after discount       |
| Total Discount        | Total discount amount              |
| Total Quantity Sold   | Total number of units sold         |
| Average Selling Price | Net sales divided by quantity sold |
| Order Count           | Number of unique orders            |

The KPI definitions and formulas are maintained in the Data Catalog so that reporting logic remains consistent across consumers.

---

## 📝 Data Catalog

The project includes a dedicated **Data Catalog** that acts as the metadata reference for the warehouse.

It documents:

* Table and column meanings
* Data types
* Data grain
* Business rules
* ETL standards
* Data cleansing rules
* Data-quality checks
* KPI definitions
* Security considerations
* Data governance
* ETL logging requirements
* Reporting recommendations

The catalog is intended to serve as a single source of truth for developers, analysts and stakeholders working with the warehouse.

---

## 🔍 Data Governance & Security

The project identifies customer phone numbers and email addresses as **PII (Personally Identifiable Information)**.

The documented security principles include:

* Least-privilege access
* Restricted access to staging tables
* PII masking in non-production environments
* Using curated reporting views for consumers
* Avoiding credentials, secrets and tokens in the repository

These practices help separate raw operational data from the data exposed for analytical consumption.

---

## 📋 ETL Logging

ETL execution monitoring is represented through operational structures under the `etl` schema.

The catalog defines:

### `etl.ETLExecutionLog`

Used to track:

* Process name
* Start time
* End time
* Execution status
* Inserted rows
* Updated rows
* Rejected rows
* Error message

### `etl.ETLErrorLog`

Used to capture:

* Error number
* Severity
* State
* Procedure
* Line number
* Error message
* Error timestamp

This provides an operational foundation for monitoring ETL execution and troubleshooting failures.

---

## 📈 Reporting Layer

The warehouse is designed to provide curated data for BI and reporting.

Recommended reporting views documented by the project include:

```text
rpt.vw_SalesSummary
rpt.vw_ProductPerformance
rpt.vw_CustomerSales
rpt.vw_DailySalesTrend
```

The reporting logic can combine:

```text
fact.Sales
      +
dim.Customer
      +
dim.Product
      +
dim.Date
      ↓
Business Reporting Views
```

This approach allows reporting consumers to work with business-ready structures rather than directly querying raw staging data.

---

## 📁 Repository Structure

The repository is organized around three main areas:

```text
DataWarehouse/
│
├── Dataset/
│   └── Source / sample datasets
│
├── Document/
│   ├── Data Warehouse Architecture
│   └── Data Catalog
│
├── Script/
│   ├── Database / schema creation
│   ├── Table creation
│   ├── Data loading
│   ├── ETL / transformation
│   └── Stored procedures
│
└── README.md
```

The GitHub repository currently exposes `Dataset`, `Document`, `Script` and `README.md` as its main top-level components.

---

## 🛠️ Technology Stack

| Technology               | Usage                                    |
| ------------------------ | ---------------------------------------- |
| **Microsoft SQL Server** | Database and Data Warehouse platform     |
| **T-SQL**                | DDL, DML, ETL and stored procedures      |
| **Star Schema**          | Dimensional warehouse modeling           |
| **Stored Procedures**    | ETL and data-loading logic               |
| **Git / GitHub**         | Source control and project documentation |
| **BI / Reporting Tools** | Analytical consumption                   |

The Data Catalog explicitly identifies Microsoft SQL Server as the platform and T-SQL as the project language.

---

## 🚀 Project Workflow

A typical execution flow can be summarized as:

```text
                 SOURCE DATA
                      │
                      ▼
              ┌───────────────┐
              │    STAGING    │
              │               │
              │ Customer      │
              │ Product       │
              │ SalesOrder    │
              └───────┬───────┘
                      │
                      ▼
              ┌───────────────┐
              │      ETL      │
              │               │
              │ Clean         │
              │ Validate      │
              │ Standardize   │
              │ Transform     │
              │ Enrich        │
              └───────┬───────┘
                      │
             ┌────────┴────────┐
             ▼                 ▼
       ┌───────────┐     ┌───────────┐
       │ Dimensions│     │   Facts   │
       │           │     │           │
       │ Date      │     │ Sales     │
       │ Customer  │     │           │
       │ Product   │     │           │
       └─────┬─────┘     └─────┬─────┘
             │                 │
             └────────┬────────┘
                      ▼
              BUSINESS-READY DATA
                      │
                      ▼
                BI / REPORTING
```

---

## 🎓 What This Project Demonstrates

This project demonstrates practical knowledge of the complete Data Warehouse development lifecycle, including:

* Data Warehouse architecture
* Staging layer design
* ETL concepts
* Data cleansing
* Data standardization
* Dimensional modeling
* Star Schema
* Fact and Dimension tables
* Surrogate and Business Keys
* SCD Type 1
* Unknown Member handling
* Stored Procedures
* Transaction management
* Error handling
* Data quality validation
* ETL logging
* KPI definition
* Metadata management
* Data Catalog
* Data governance
* PII identification
* BI-ready data preparation

---

## 📚 Documentation

The repository contains project documentation covering the architecture and metadata of the warehouse.

### Data Warehouse Architecture

Describes the overall flow from source data through staging and transformation to business-ready warehouse data.

### Data Catalog

Provides detailed metadata for the project's tables, columns, grains, business rules, data-quality checks, KPIs, security and ETL standards.

---

## 🔮 Future Improvements

Potential extensions to the project include:

* Incremental ETL optimization
* Additional Slowly Changing Dimension strategies
* Automated data-quality pipelines
* Metadata-driven ETL
* ETL scheduling and orchestration
* Automated testing
* Reporting views and semantic models
* Power BI dashboards
* Performance optimization and indexing
* Data lineage visualization
* CI/CD for database deployment
* Automated documentation generation

---

## 👤 Author

**Sepide Moghadam**

**Role:** Data Warehouse Developer

**Technology Focus:**

```text
SQL Server
T-SQL
Data Warehouse
ETL
Dimensional Modeling
Business Intelligence
Data Analytics
```

---

