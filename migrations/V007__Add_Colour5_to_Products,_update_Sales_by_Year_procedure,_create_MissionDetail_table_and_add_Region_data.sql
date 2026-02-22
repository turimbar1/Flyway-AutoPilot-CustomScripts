SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT N'Altering [Operation].[Products]'
GO
ALTER TABLE [Operation].[Products] ADD
[Colour5] [nvarchar] (50) NULL
GO
PRINT N'Altering [Sales].[Sales by Year]'
GO
ALTER PROCEDURE [Sales].[Sales by Year] @Beginning_Date DATETIME, @Ending_Date DATETIME
AS
SELECT Orders.ShippedDate, Orders.OrderID, "Order Subtotals".Subtotal, DATENAME(yy, ShippedDate) AS Year
FROM Orders -- orders new line - change id check 
     INNER JOIN "Order Subtotals" ON Orders.OrderID="Order Subtotals".OrderID
WHERE Orders.ShippedDate BETWEEN @Beginning_Date AND @Ending_Date;
GO
PRINT N'Refreshing [Sales].[Order Details Extended]'
GO
EXEC sp_refreshview N'[Sales].[Order Details Extended]'
GO
PRINT N'Refreshing [Sales].[Sales by Category]'
GO
EXEC sp_refreshview N'[Sales].[Sales by Category]'
GO
PRINT N'Creating [dbo].[MissionDetail]'
GO
CREATE TABLE [dbo].[MissionDetail]
(
[Mission] [varchar] (255) NOT NULL,
[LogicalDestinationID] [varchar] (32) NOT NULL,
[WaveID] [varchar] (32) NOT NULL,
[OrderID] [varchar] (32) NOT NULL,
[ShipmentID] [varchar] (32) NOT NULL,
[ConsolidationID] [varchar] (255) NOT NULL,
[PickTaskID] [varchar] (50) NULL,
[Priority] [int] NULL,
[CreatedTime] [datetime2] (3) NOT NULL,
[Status] [int] NULL,
[StatusTime] [datetime2] (3) NULL,
[Expected] [int] NULL,
[Dispatched] [int] NULL,
[Diverted] [int] NULL,
[EOWFlag] [varchar] (3) NULL,
[LastUpdateTime] [datetime2] (3) NOT NULL,
[RecordID] [bigint] NOT NULL IDENTITY(1, 1),
[Finished] AS (case  when [Status]=(100) OR [Status]=(75) then (1) else (0) end) PERSISTED NOT NULL
)
GO

SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS, NOCOUNT ON
GO
SET DATEFORMAT YMD
GO
SET XACT_ABORT ON
GO

PRINT(N'Add 4 rows to [Logistics].[Region]')
INSERT INTO [Logistics].[Region] ([RegionID], [RegionDescription], [RegionName]) VALUES (1, N'Eastern                                           ', NULL)
INSERT INTO [Logistics].[Region] ([RegionID], [RegionDescription], [RegionName]) VALUES (2, N'Western                                           ', NULL)
INSERT INTO [Logistics].[Region] ([RegionID], [RegionDescription], [RegionName]) VALUES (3, N'Northern                                          ', NULL)
INSERT INTO [Logistics].[Region] ([RegionID], [RegionDescription], [RegionName]) VALUES (4, N'Southern                                          ', NULL)

