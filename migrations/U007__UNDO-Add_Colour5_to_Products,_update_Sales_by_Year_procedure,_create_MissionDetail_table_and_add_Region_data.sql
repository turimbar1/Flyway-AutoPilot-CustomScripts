SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT N'Dropping [dbo].[MissionDetail]'
GO
DROP TABLE [dbo].[MissionDetail]
GO
PRINT N'Altering [Operation].[Products]'
GO
ALTER TABLE [Operation].[Products] DROP
COLUMN [Colour5]
GO
PRINT N'Refreshing [Sales].[Order Details Extended]'
GO
EXEC sp_refreshview N'[Sales].[Order Details Extended]'
GO
PRINT N'Refreshing [Sales].[Sales by Category]'
GO
EXEC sp_refreshview N'[Sales].[Sales by Category]'
GO
PRINT N'Altering [Sales].[Sales by Year]'
GO
ALTER PROCEDURE [Sales].[Sales by Year] @Beginning_Date DATETIME, @Ending_Date DATETIME
AS
SELECT Orders.ShippedDate, Orders.OrderID, "Order Subtotals".Subtotal, DATENAME(yy, ShippedDate) AS Year
FROM Orders
     INNER JOIN "Order Subtotals" ON Orders.OrderID="Order Subtotals".OrderID
WHERE Orders.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date;
GO

SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS, NOCOUNT ON
GO
SET DATEFORMAT YMD
GO
SET XACT_ABORT ON
GO

PRINT(N'Delete 4 rows from [Logistics].[Region]')
DELETE FROM [Logistics].[Region] WHERE [RegionID] = 1
DELETE FROM [Logistics].[Region] WHERE [RegionID] = 2
DELETE FROM [Logistics].[Region] WHERE [RegionID] = 3
DELETE FROM [Logistics].[Region] WHERE [RegionID] = 4

