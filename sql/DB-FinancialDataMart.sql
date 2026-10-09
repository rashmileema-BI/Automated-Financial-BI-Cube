-- Create database if it doesn't exist
IF NOT EXISTS (SELECT 1
               FROM   sys.databases
               WHERE  name = 'FinancialDataMart')
    BEGIN
        CREATE DATABASE FinancialDataMart;
    END


GO
USE FinancialDataMart;


GO
-- 1. Drop existing objects in dependency order if rebuilding
IF OBJECT_ID('dbo.FactMonthlyFinancialSummary', 'U') IS NOT NULL
    DROP TABLE dbo.FactMonthlyFinancialSummary;

IF OBJECT_ID('dbo.FactFinancialTransactions', 'U') IS NOT NULL
    DROP TABLE dbo.FactFinancialTransactions;

IF OBJECT_ID('dbo.DimDate', 'U') IS NOT NULL
    DROP TABLE dbo.DimDate;

IF OBJECT_ID('dbo.DimGeneralLedger', 'U') IS NOT NULL
    DROP TABLE dbo.DimGeneralLedger;

IF OBJECT_ID('dbo.DimLegalEntity', 'U') IS NOT NULL
    DROP TABLE dbo.DimLegalEntity;

IF OBJECT_ID('dbo.LoadLog', 'U') IS NOT NULL
    DROP TABLE dbo.LoadLog;


GO
-- 2. Audit Run Log Table
CREATE TABLE dbo.LoadLog (
    LogID INT IDENTITY (1, 1) PRIMARY KEY,
    JobName VARCHAR (100) NOT NULL,
    StartTime DATETIME2 NOT NULL,
    EndTime DATETIME2 NULL,
    RowsLoaded INT NULL,
    Status VARCHAR (20) NOT NULL,
    ErrorMsg NVARCHAR (4000) NULL
);


GO
-- 3. Dimension: Date Calendar
CREATE TABLE dbo.DimDate (
    DateKey INT PRIMARY KEY,
    FullDate DATE NOT NULL,
    FiscalYearMonth VARCHAR (7) NOT NULL,
    FiscalQuarter VARCHAR (2) NOT NULL,
    IsWeekday BIT NOT NULL
);


GO
-- 4. Dimension: Legal Entity
CREATE TABLE dbo.DimLegalEntity (
    EntityKey INT PRIMARY KEY,
    EntityName VARCHAR (100) NOT NULL,
    Region VARCHAR (50) NOT NULL,
    Currency VARCHAR (3) NOT NULL
);


GO
-- 5. Dimension: General Ledger Accounts
CREATE TABLE dbo.DimGeneralLedger (
    AccountKey INT PRIMARY KEY,
    AccountNumber VARCHAR (10) NOT NULL,
    AccountName VARCHAR (100) NOT NULL,
    AccountCategory VARCHAR (50) NOT NULL
);


GO
-- 6. Fact: Transaction Level Data
CREATE TABLE dbo.FactFinancialTransactions (
    TransactionID BIGINT IDENTITY (1, 1) PRIMARY KEY,
    DateKey INT NOT NULL FOREIGN KEY REFERENCES dbo.DimDate (DateKey),
    EntityKey INT NOT NULL FOREIGN KEY REFERENCES dbo.DimLegalEntity (EntityKey),
    AccountKey INT NOT NULL FOREIGN KEY REFERENCES dbo.DimGeneralLedger (AccountKey),
    ActualAmount DECIMAL (18, 2) NOT NULL,
    BudgetAmount DECIMAL (18, 2) NOT NULL
);

CREATE NONCLUSTERED INDEX IX_FactFinancialTransactions_Lookup
    ON dbo.FactFinancialTransactions(DateKey, EntityKey, AccountKey)
    INCLUDE(ActualAmount, BudgetAmount);


GO
-- 7. Fact Aggregate: Monthly Financial Summary
CREATE TABLE dbo.FactMonthlyFinancialSummary (
    FiscalYearMonth VARCHAR (7) NOT NULL,
    EntityRegion VARCHAR (50) NOT NULL,
    AccountCategory VARCHAR (50) NOT NULL,
    ActualAmount DECIMAL (18, 2) NOT NULL,
    BudgetAmount DECIMAL (18, 2) NOT NULL,
    VarianceAmount DECIMAL (18, 2) NOT NULL,
    VariancePct DECIMAL (9, 2) NULL,
    CONSTRAINT PK_FactMonthlySummary PRIMARY KEY (FiscalYearMonth, EntityRegion, AccountCategory)
);