SELECT (SELECT SUM(ActualAmount)
        FROM   dbo.FactFinancialTransactions) AS fact_total,
       (SELECT SUM(ActualAmount)
        FROM   dbo.FactMonthlyFinancialSummary) AS summary_total;

SELECT   TOP 5 *
FROM     dbo.LoadLog
ORDER BY 1 DESC;