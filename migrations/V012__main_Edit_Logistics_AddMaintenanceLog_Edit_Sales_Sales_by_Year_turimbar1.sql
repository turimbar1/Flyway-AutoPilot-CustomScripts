SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT N'Altering [Logistics].[AddMaintenanceLog]'
GO
IF OBJECT_ID(N'[Logistics].[AddMaintenanceLog]', 'P') IS NOT NULL
EXEC sp_executesql N'ALTER PROCEDURE [Logistics].[AddMaintenanceLog] @FlightID INT, @Description NVARCHAR(500)
AS BEGIN
-- Dostuff another go
    INSERT INTO Logistics.MaintenanceLog(FlightID, Description, MaintenanceStatus)
    VALUES(@FlightID, @Description, ''Pending'');
    PRINT ''Maintenance log entry created.'';
END;
'
GO
PRINT N'Altering [Sales].[Sales by Year]'
GO
IF OBJECT_ID(N'[Sales].[Sales by Year]', 'P') IS NOT NULL
EXEC sp_executesql N'ALTER PROCEDURE [Sales].[Sales by Year] @Beginning_Date DATETIME, @Ending_Date DATETIME
AS
SELECT Orders.ShippedDate, Orders.OrderID, "Order Subtotals".Subtotal, DATENAME(yy, ShippedDate) AS Year
FROM Orders -- orders new line wassup hello world
     INNER JOIN "Order Subtotals" ON Orders.OrderID="Order Subtotals".OrderID
WHERE Orders.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date;
'
GO

