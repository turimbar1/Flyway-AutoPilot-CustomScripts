SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT N'Altering [Logistics].[AddMaintenanceLog]'
GO
ALTER PROCEDURE [Logistics].[AddMaintenanceLog] @FlightID INT, @Description NVARCHAR(500)
AS BEGIN
-- Dostuff another 2
    INSERT INTO Logistics.MaintenanceLog(FlightID, Description, MaintenanceStatus)
    VALUES(@FlightID, @Description, 'Pending');
    PRINT 'Maintenance log entry created.';
END;
GO
PRINT N'Altering [dbo].[MissionDetail]'
GO
ALTER TABLE [dbo].[MissionDetail] ADD
[Color1] [nvarchar] (50) NULL,
[Color2] [nchar] (10) NULL,
[Color3] [nchar] (10) NULL, 
Color4 [nchar] (10) NULL
GO

