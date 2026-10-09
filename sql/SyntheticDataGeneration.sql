USE FinancialDataMart;


GO
-- Dimensions
INSERT  INTO dbo.DimLegalEntity (EntityKey, EntityName, Region, Currency)
VALUES                         (1, 'XYZ EMEA Ltd', 'EMEA', 'GBP'),
(2, 'XYZ APAC Pte', 'APAC', 'SGD'),
(3, 'XYZ Americas Inc', 'Americas', 'USD');

INSERT  INTO dbo.DimGeneralLedger (AccountKey, AccountNumber, AccountName, AccountCategory)
VALUES                           (1, '4000', 'Product Revenue', 'Revenue'),
(2, '4100', 'Service Revenue', 'Revenue'),
(3, '5000', 'Cost of Goods Sold', 'Cost of Sales'),
(4, '6000', 'Salaries & Wages', 'OPEX'),
(5, '6100', 'Marketing & Sales', 'OPEX'),
(6, '6200', 'Software & Infrastructure', 'OPEX'),
(7, '7000', 'Capital Equipment', 'CAPEX');

-- Calendar (2024-01-01 to 2025-12-31)
WITH DateSeries
AS   (SELECT CAST ('2024-01-01' AS DATE) AS d
      UNION ALL
      SELECT DATEADD(DAY, 1, d)
      FROM   DateSeries
      WHERE  d < '2025-12-31')
INSERT INTO dbo.DimDate (DateKey, FullDate, FiscalYearMonth, FiscalQuarter, IsWeekday)
SELECT CONVERT (INT, CONVERT (CHAR (8), d, 112)),
       d,
       CONVERT (CHAR (7), d, 120),
       'Q' + CAST (DATEPART(QUARTER, d) AS VARCHAR (1)),
       CASE WHEN DATEDIFF(DAY, '19000101', d) % 7 IN (5, 6) THEN 0 ELSE 1 END
FROM   DateSeries
OPTION (MAXRECURSION 800);

-- Fact: Generate Weekday Transactions (3 Entities x 7 Accounts x 522 Weekdays = 10,962 rows)
INSERT INTO dbo.FactFinancialTransactions (DateKey, AccountKey, EntityKey, ActualAmount, BudgetAmount)
SELECT d.DateKey,
       g.AccountKey,
       e.EntityKey,
       -- Deterministic pseudo-random variation (85% to 115% of budget)
       CAST (ROUND(x.BaseAmount * (0.85 + (ABS(CHECKSUM(HASHBYTES('MD5', CONCAT(d.DateKey, g.AccountKey, e.EntityKey)))) % 31) / 100.0), 2) AS DECIMAL (18, 2)) AS ActualAmount,
       CAST (ROUND(x.BaseAmount, 2) AS DECIMAL (18, 2)) AS BudgetAmount
FROM   dbo.DimDate AS d CROSS JOIN dbo.DimGeneralLedger AS g CROSS JOIN dbo.DimLegalEntity AS e CROSS APPLY (SELECT CAST (CHOOSE(g.AccountKey, 9000, 4000, 5500, 3500, 1200, 800, 600) * CHOOSE(e.EntityKey, 1.0, 0.7, 1.4) AS DECIMAL (18, 2)) AS BaseAmount) AS x
WHERE  d.IsWeekday = 1;