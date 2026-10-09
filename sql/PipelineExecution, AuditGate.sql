USE FinancialDataMart;


GO
-- 1. Run the procedure
EXECUTE dbo.sp_Consolidate_Financial_Cube ;

-- 2. Execute Source-to-Target Reconciliation
WITH   ReconciliationTotals
AS     (SELECT (SELECT SUM(ActualAmount)
                FROM   dbo.FactFinancialTransactions) AS FactActual,
               (SELECT SUM(BudgetAmount)
                FROM   dbo.FactFinancialTransactions) AS FactBudget,
               (SELECT SUM(ActualAmount)
                FROM   dbo.FactMonthlyFinancialSummary) AS SummaryActual,
               (SELECT SUM(BudgetAmount)
                FROM   dbo.FactMonthlyFinancialSummary) AS SummaryBudget)
SELECT FactActual,
       SummaryActual,
       CAST (FactActual - SummaryActual AS DECIMAL (18, 2)) AS ActualDelta,
       FactBudget,
       SummaryBudget,
       CAST (FactBudget - SummaryBudget AS DECIMAL (18, 2)) AS BudgetDelta,
       CASE WHEN (FactActual - SummaryActual) = 0.00
                 AND (FactBudget - SummaryBudget) = 0.00 THEN 'PASSED: 100% RECONCILED TO THE CENT' ELSE 'FAILED: AUDIT MISMATCH' END AS ReconciliationStatus
FROM   ReconciliationTotals;

-- 3. Verify LoadLog
SELECT   TOP 1 *
FROM     dbo.LoadLog
ORDER BY LogID DESC;