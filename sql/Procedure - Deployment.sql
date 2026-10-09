USE FinancialDataMart;


GO
CREATE OR ALTER PROCEDURE dbo.sp_Consolidate_Financial_Cube
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @StartTime AS DATETIME2 = SYSDATETIME();
    DECLARE @LogID AS INT;
    DECLARE @RowsAffected AS INT = 0;
    -- 1. Initialize Audit Log Record
    INSERT  INTO dbo.LoadLog (JobName, StartTime, Status)
    VALUES                  ('sp_Consolidate_Financial_Cube', @StartTime, 'RUNNING');
    SET @LogID = SCOPE_IDENTITY();
    BEGIN TRY
        BEGIN TRANSACTION;
        -- 2. Clear target summary
        TRUNCATE TABLE dbo.FactMonthlyFinancialSummary;
        -- 3. Materialize monthly aggregate summaries
        INSERT INTO dbo.FactMonthlyFinancialSummary (FiscalYearMonth, EntityRegion, AccountCategory, ActualAmount, BudgetAmount, VarianceAmount, VariancePct)
        SELECT   d.FiscalYearMonth,
                 e.Region AS EntityRegion,
                 gl.AccountCategory,
                 CAST (SUM(f.ActualAmount) AS DECIMAL (18, 2)) AS ActualAmount,
                 CAST (SUM(f.BudgetAmount) AS DECIMAL (18, 2)) AS BudgetAmount,
                 CAST (SUM(f.ActualAmount - f.BudgetAmount) AS DECIMAL (18, 2)) AS VarianceAmount,
                 CAST (ROUND((SUM(f.ActualAmount - f.BudgetAmount) / NULLIF (SUM(f.BudgetAmount), 0)) * 100.0, 2) AS DECIMAL (9, 2)) AS VariancePct
        FROM     dbo.FactFinancialTransactions AS f
                 INNER JOIN
                 dbo.DimDate AS d
                 ON f.DateKey = d.DateKey
                 INNER JOIN
                 dbo.DimLegalEntity AS e
                 ON f.EntityKey = e.EntityKey
                 INNER JOIN
                 dbo.DimGeneralLedger AS gl
                 ON f.AccountKey = gl.AccountKey
        GROUP BY d.FiscalYearMonth, e.Region, gl.AccountCategory;
        SET @RowsAffected = @@ROWCOUNT;
        COMMIT TRANSACTION;
        -- 4. Mark execution SUCCESS
        UPDATE dbo.LoadLog
        SET    EndTime    = SYSDATETIME(),
               RowsLoaded = @RowsAffected,
               Status     = 'SUCCESS'
        WHERE  LogID = @LogID;
    END TRY
    BEGIN CATCH
        -- Rollback if open transaction exists
        IF @@TRANCOUNT > 0
            ROLLBACK;
        -- Log failure details
        UPDATE dbo.LoadLog
        SET    EndTime  = SYSDATETIME(),
               Status   = 'FAILED',
               ErrorMsg = ERROR_MESSAGE()
        WHERE  LogID = @LogID;
        THROW;
    END CATCH
END