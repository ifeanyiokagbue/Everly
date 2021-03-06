﻿-- ======================================================================================================================================
-- Author:		 <Author - Ifeanyi Nnamdi-Okagbue>
-- Name:         <Name - Everly>
-- Type:         <Type - Stored Procedure>
-- Create date:  <Create Date - 10th July, 2017>
-- Description:	 <Description - This Stored Procedure (Everly) enables a DBA or developer to do all CRUD operations on any table in the Database. It also makes accomodation for custom queries.
--               It also helps to reverse actions done in SQL.
-- Dependencies: <Dependencies - 1. dbo.Fetch_ReturnCommaSeparatedString() Function, 2. dbo.IsValueValid() Function, 3. dbo.IsValuesValid() Function, 
--               4. dbo.IsValuesValid() Function - This function can be found in everly-prerequisites.sql
-- ======================================================================================================================================

CREATE PROCEDURE Everly
	@Action varchar(10), --Actions to be performed on SQL by Everly - FETCH, INSERT, UPDATE, DELETE, CUSTOM, REVERSE (NEW ACTION), REVERSE-ID (NEW ACTION)
	@ColumnValues varchar(max) = NULL, --All Column Values arranged in order they were created in the table excluding Identity Columns
	@TableName varchar(100) = NULL, --The name of the table to perform the action on
	@Conditions varchar(max) = '', --The where clauses for the UPDATE, FETCH AND DELETE actions.
	@Optional varchar(max) = NULL
AS
BEGIN

	--Declare Variables to be used in Everly
	DECLARE @ColumnsList varchar(max), @ColumnsListExIdentity varchar(max), @ColumnsCount int, @ColumnsCountExIdentity int, @ColumnName varchar(100), @ColumnValue varchar(max), @IdentityColumn varchar(100), @ColumnDataType varchar(50), @ColumnsDataTypeExIdentity varchar(max), @ColumnsDataType varchar(max)
	DECLARE @Fetch nvarchar(max), @Insert nvarchar(max), @Update nvarchar(max), @Delete nvarchar(max), @Custom nvarchar(max), @Reverse nvarchar(max)
	DECLARE @ReturnValue varchar(max), @TableUpdateCount int, @IsTableValid int, @TableID int, @Count int, @OldColumnValues varchar(max)
	DECLARE @EverlyID int
	DECLARE @sColumns varchar(max), @xColumns varchar(max), @DSQL nvarchar(max), @ReturnExecValue varchar(max), @Param nvarchar(500), @xDataType varchar(50)

	--Initialize some varaibles to be used in Everly
	IF (@TableName = '' OR @TableName IS NULL) AND @Action = 'REVERSE'
	BEGIN
		SET @TableName = (Select Top 1 TableName from Everly_AuditTrail order by Id desc)
	END
	ELSE IF @TableName = '' AND @Action = 'REVERSE-ID'
	BEGIN
		SET @TableName = (Select Top 1 TableName from Everly_AuditTrail order by Id desc)
	END
	IF SUBSTRING(@ColumnValues,len(@ColumnValues),1) = ','
	BEGIN
	Set @ColumnValues = SUBSTRING(@ColumnValues,1,len(@ColumnValues)-1)
	END

	SET @IsTableValid = (Select Count(COLUMN_NAME) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName)
	SELECT @ColumnsList = COALESCE(@ColumnsList + ',', '') + COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName ORDER BY ORDINAL_POSITION
	SELECT @ColumnsListExIdentity = COALESCE(@ColumnsListExIdentity + ',', '') + COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMNPROPERTY(object_id(TABLE_SCHEMA+'.'+TABLE_NAME), COLUMN_NAME, 'IsIdentity') <> 1 ORDER BY ORDINAL_POSITION
	SELECT @ColumnsDataType = COALESCE(@ColumnsDataType + ',', '') + DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName ORDER BY ORDINAL_POSITION
	SELECT @ColumnsDataTypeExIdentity = COALESCE(@ColumnsDataTypeExIdentity + ',', '') + DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMNPROPERTY(object_id(TABLE_SCHEMA+'.'+TABLE_NAME), COLUMN_NAME, 'IsIdentity') <> 1 ORDER BY ORDINAL_POSITION
	SET @ColumnsCount = (SELECT Count(COLUMN_NAME) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName)
	SET @ColumnsCountExIdentity = (SELECT Count(COLUMN_NAME) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMNPROPERTY(object_id(TABLE_SCHEMA+'.'+TABLE_NAME), COLUMN_NAME, 'IsIdentity') <> 1)
	SET @IdentityColumn = (SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMNPROPERTY(object_id(TABLE_SCHEMA+'.'+TABLE_NAME), COLUMN_NAME, 'IsIdentity') = 1 AND TABLE_NAME = @TableName)
	SET @Count = 1

	--Install Everly_AuditTrail if it does not exists - This helps to track Everly actions and also to reverse everly actions
	IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = N'Everly_AuditTrail')
	BEGIN
		CREATE TABLE Everly_AuditTrail
		(
			Id int NOT NULL PRIMARY KEY IDENTITY(1,1),
			[Action] varchar(50) NOT NULL,
			TableName varchar(50) NOT NULL,
			TableID varchar(50) NULL,
			ColumnValues varchar(max) NOT NULL,
			OldColumnValues varchar(max) NULL,
			TSQLStatement varchar(max) NOT NULL,
			Conditions varchar(max) NULL,
			RunStatus bit DEFAULT ((0)) NOT NULL,
			IsReversal bit DEFAULT ((0)) NOT NULL,
			DateEffected datetime NOT NULL DEFAULT GETDATE()
		)
	END

	--This is to check if @TableName parameter is not empty
	IF @TableName = ''
	BEGIN
		SET @TableUpdateCount = 0
		SET @ReturnValue = 'Table name parameter is empty'
	END
	--This is to check if the Table (@TableName) is valid or exists and has a column inside
	ELSE IF @IsTableValid = 0
	BEGIN
		SET @TableUpdateCount = 0
		SET @ReturnValue = 'Table name not valid'
	END
	--This is to check that @TableName parameter is existing
	ELSE IF @ColumnsCount = 0 AND @ColumnsList = '' 
	BEGIN
		SET @TableUpdateCount = 0
		SET @ReturnValue = 'Table does not exist'
	END
	--This is to check that condition is specified or Update or Delete action
	ELSE IF (@Action = 'UPDATE' OR @Action = 'DELETE') AND (@Conditions IS NULL OR @Conditions = '')
	BEGIN
		SET @TableUpdateCount = 0
		SET @ReturnValue = 'Condition not specified for ' + @Action + ' action.'
	END
	--This runs if @TableName parameter is not empty and it is an existing table
	ELSE
	BEGIN
		--This is to run Select Statements
		IF @Action = 'FETCH'
		BEGIN
			IF @Conditions = ''
			BEGIN
				SET @Fetch = 'SELECT ' + @ColumnsList + ' FROM ' + @TableName

				--This is to insert into Everly_AuditTrail
				INSERT INTO [dbo].[Everly_AuditTrail]([Action],[TableName],[ColumnValues],[TSQLStatement],[RunStatus],[DateEffected])
				VALUES(@Action,@TableName,@ColumnsList,@Fetch,0,getdate())
				SET @EverlyID = SCOPE_IDENTITY()
				
				EXEC (@Fetch)
				SET @TableUpdateCount = @@ROWCOUNT
				SET @ReturnValue = 'Fetch action ran successfully on ' + @TableName + ' !'

				--This is to update the Audit Trail after successful run of the Everly action
				UPDATE Everly_AuditTrail SET RunStatus = 1 WHERE Id = @EverlyID
			END
			ELSE
			BEGIN
				SET @Fetch = 'SELECT ' + @ColumnsList + ' FROM ' + @TableName + ' WHERE ' + @Conditions

				--This is to insert into Everly_AuditTrail
				INSERT INTO [dbo].[Everly_AuditTrail]([Action],[TableName],[ColumnValues],[TSQLStatement],[RunStatus],[DateEffected])
				VALUES(@Action,@TableName,@ColumnsList,@Fetch,0,getdate())
				SET @EverlyID = SCOPE_IDENTITY()

				EXEC (@Fetch)
				SET @TableUpdateCount = @@ROWCOUNT
				SET @ReturnValue = 'Fetch action with condition ran successfully on ' + @TableName + ' !'
				
				--This is to update the Audit Trail after successful run of the Everly action
				UPDATE Everly_AuditTrail SET RunStatus = 1,Conditions = @Conditions WHERE Id = @EverlyID
			END
		END
		--This is to run Insert Statements
		ELSE IF @Action = 'INSERT'
		BEGIN
			--Check that all values are valid
			IF dbo.IsValuesValid(@ColumnValues,@ColumnsDataTypeExIdentity,@ColumnsCountExIdentity) = 1
			BEGIN
				SET @Insert = 'INSERT INTO ' + @TableName + '(' + @ColumnsListExIdentity + ') VALUES (' + REPLACE(@ColumnValues,'"','''') + ') SELECT @TableID = SCOPE_IDENTITY()'
				
				--This is to insert into Everly_AuditTrail---
				INSERT INTO [dbo].[Everly_AuditTrail]([Action],[TableName],[ColumnValues],[TSQLStatement],[RunStatus],[DateEffected])
				VALUES(@Action,@TableName,@ColumnValues,@Insert,0,getdate())
				SET @EverlyID = SCOPE_IDENTITY()

				EXEC sp_executesql @Insert, N'@TableID int OUTPUT', @TableID OUTPUT

				SET @TableUpdateCount = @@ROWCOUNT
				SET @ReturnValue = 'Insert action ran successfully on ' + @TableName + ' !'
				
				--This is to update the Audit Trail after successful run of the Everly action
				UPDATE Everly_AuditTrail SET RunStatus = 1, TableID = @TableID WHERE Id = @EverlyID
			END
			ELSE
			BEGIN
				SET @TableUpdateCount = 1
				SET @ReturnValue = dbo.IsValuesValid_Description(@ColumnValues,@ColumnsDataTypeExIdentity,@ColumnsCountExIdentity)
			END
		END
		--This is to run Update statements
		ELSE IF @Action = 'UPDATE'
		BEGIN
			--Check that all values are valid
			IF dbo.IsValuesValid(@ColumnValues,@ColumnsDataTypeExIdentity,@ColumnsCountExIdentity) = 1
			BEGIN
				SET @Update = 'UPDATE ' + @TableName + ' SET '

				WHILE @Count <> @ColumnsCount
				BEGIN
					SET @ColumnValue = dbo.Fetch_ReturnCommaSeparatedString(@ColumnValues,@Count)
					SET @ColumnName = dbo.Fetch_ReturnCommaSeparatedString(@ColumnsListExIdentity,@Count)

					SET @Update = @Update + @ColumnName + ' = ' + @ColumnValue + ', '
			
					Set @Count = @Count + 1
				END
				SET @Update = SUBSTRING(@Update,0,len(@Update))
				SET @Update = REPLACE(@Update,'"','''')
				SET @Update = @Update + ' WHERE ' + @Conditions

				SET @Count = 1
				SET @sColumns = ''
				--This is used to get the existing values in the row about to be updated. It is be used during Everly REVERSE action
				WHILE @Count <= @ColumnsCountExIdentity
				BEGIN
					SET @xColumns = dbo.Fetch_ReturnCommaSeparatedString(@ColumnsListExIdentity,@Count)
					SET @xDataType = (Select DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMN_NAME = @xColumns)
					IF @xDataType = 'int' OR @xDataType = 'float' OR @xDataType = 'bit'
					BEGIN
						SET @sColumns = @sColumns + 'isnull(cast(' + @xColumns + ' as varchar),'''')+'',''+'
					END
					ELSE IF @xDataType = 'datetime'
					BEGIN
						SET @sColumns = @sColumns + '''"''+isnull(cast(' + @xColumns + ' as varchar),'''')+''",''+'
					END
					ELSE
					BEGIN
						SET @sColumns = @sColumns + '''"''+isnull(' + @xColumns + ','''')+''",''+'
					END
					Set @Count = @Count + 1
				END

				IF SUBSTRING(@sColumns,len(@sColumns)-2,len(@sColumns)) = '+,+'
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-3)
				END
				ELSE
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-1)
				END

				IF SUBSTRING(@sColumns,len(@sColumns),1) = ','
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-1)
				END

				SET @DSQL = 'SELECT @ReturnExecValueOUT = ' + @sColumns + ' FROM ' + @TableName + ' WHERE ' + @Conditions
				SET @Param = N'@ReturnExecValueOUT varchar(max) OUTPUT'
				EXEC sp_executesql @DSQL, @Param, @ReturnExecValueOUT=@ReturnExecValue OUTPUT
				
				--This is to insert into Everly_AuditTrail---
				INSERT INTO [dbo].[Everly_AuditTrail]([Action],[TableName],[ColumnValues],[OldColumnValues],[TSQLStatement],[Conditions],[RunStatus],[DateEffected])
				VALUES(@Action,@TableName,@ColumnValues,@ReturnExecValue,@Update,@Conditions,0,getdate())
				SET @EverlyID = SCOPE_IDENTITY()
				
				EXEC (@Update)
				SET @TableUpdateCount = @@ROWCOUNT
				SET @ReturnValue = 'Update action ran successfully on ' + @TableName + ' !'

				--This is to update the Audit Trail after successful run of the Everly action
				UPDATE Everly_AuditTrail SET RunStatus = 1, Conditions = @Conditions WHERE Id = @EverlyID					
			END
			ELSE
			BEGIN
				SET @TableUpdateCount = 1
				SET @ReturnValue = dbo.IsValuesValid_Description(@ColumnValues,@ColumnsDataTypeExIdentity,@ColumnsCountExIdentity)
			END		
		END
		--This is to run Delete statements
		ELSE IF @Action = 'DELETE'
		BEGIN
			IF @Conditions = ''
			BEGIN
				SET @TableUpdateCount = 0
				SET @ReturnValue = '@Conditions parameter cannot be empty for a delete statement!'
			END
			ELSE
			BEGIN
				IF @Conditions = 'ALL'
				BEGIN
					Set @Delete = 'DELETE FROM ' + @TableName
				END
				ELSE IF @Conditions <> ''
				BEGIN
					Set @Delete = 'DELETE FROM ' + @TableName + ' WHERE ' + @Conditions
				END

				SET @Count = 1
				SET @sColumns = ''
				--This is used to get the existing values in the row about to be updated/deleted. It is be used during Everly REVERSE action
				WHILE @Count <= @ColumnsCountExIdentity
				BEGIN
					SET @xColumns = dbo.Fetch_ReturnCommaSeparatedString(@ColumnsListExIdentity,@Count)
					SET @xDataType = (Select DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @TableName AND COLUMN_NAME = @xColumns)
					IF @xDataType = 'int' OR @xDataType = 'float' OR @xDataType = 'bit'
					BEGIN
						SET @sColumns = @sColumns + 'isnull(cast(' + @xColumns + ' as varchar),'''')+'',''+'
					END
					ELSE IF @xDataType = 'datetime'
					BEGIN
						SET @sColumns = @sColumns + '''"''+isnull(cast(' + @xColumns + ' as varchar),'''')+''",''+'
					END
					ELSE
					BEGIN
						SET @sColumns = @sColumns + '''"''+isnull(' + @xColumns + ','''')+''",''+'
					END
					Set @Count = @Count + 1
				END

				IF SUBSTRING(@sColumns,len(@sColumns)-2,len(@sColumns)) = '+,+'
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-3)
				END
				ELSE
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-1)
				END

				IF SUBSTRING(@sColumns,len(@sColumns),1) = ','
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-1)
				END

				SET @DSQL = 'SELECT @ReturnExecValueOUT = ' + @sColumns + ' FROM ' + @TableName + ' WHERE ' + @Conditions
				SET @Param = N'@ReturnExecValueOUT varchar(max) OUTPUT'
				EXEC sp_executesql @DSQL, @Param, @ReturnExecValueOUT=@ReturnExecValue OUTPUT

				--This is to insert into Everly_AuditTrail---
				INSERT INTO [dbo].[Everly_AuditTrail]([Action],[TableName],[ColumnValues],[OldColumnValues],[TSQLStatement],[RunStatus],[DateEffected])
				VALUES(@Action,@TableName,@ColumnsList,@ReturnExecValue,@Delete,0,getdate())
				SET @EverlyID = SCOPE_IDENTITY()

				EXEC (@Delete)
				SET @TableUpdateCount = @@ROWCOUNT
				SET @ReturnValue = 'Delete action with condition ran successfully on ' + @TableName + ' !'
				
				--This is to update the Audit Trail after successful run of the Everly action
				UPDATE Everly_AuditTrail SET RunStatus = 1, Conditions = @Conditions WHERE Id = @EverlyID
			END
		END
		--This is to run custom queries
		ELSE IF @Action = 'CUSTOM'
		BEGIN
			IF @Conditions = ''
			BEGIN
				Set @Custom = @ColumnValues
				
				--This is to insert into Everly_AuditTrail---
				INSERT INTO [dbo].[Everly_AuditTrail]([Action],[TableName],[ColumnValues],[TSQLStatement],[RunStatus],[DateEffected])
				VALUES(@Action,@TableName,@ColumnsList,@Fetch,0,getdate())
				SET @EverlyID = SCOPE_IDENTITY()

				PRINT (@Custom)
				SET @TableUpdateCount = @@ROWCOUNT
				SET @ReturnValue = 'Custom action ran successfully!'

				--This is to update the Audit Trail after successful run of the Everly action
				UPDATE Everly_AuditTrail SET RunStatus = 1 WHERE Id = @EverlyID
			END
			ELSE
			BEGIN
				Set @Custom = @ColumnValues + ' WHERE ' + @Conditions
				
				--This is to insert into Everly_AuditTrail---
				INSERT INTO [dbo].[Everly_AuditTrail]([Action],[TableName],[ColumnValues],[TSQLStatement],[RunStatus],[DateEffected])
				VALUES(@Action,@TableName,@ColumnsList,@Fetch,0,getdate())
				SET @EverlyID = SCOPE_IDENTITY()

				EXEC (@Custom)
				SET @TableUpdateCount = @@ROWCOUNT
				SET @ReturnValue = 'Custom action with condition ran successfully!'

				--This is to update the Audit Trail after successful run of the Everly action
				UPDATE Everly_AuditTrail SET RunStatus = 1 WHERE Id = @EverlyID
			END
		END
		ELSE IF @Action = 'REVERSE'
		BEGIN
			--Declare and gets the values of the last action run to use to reverse
			DECLARE @LastEverlyID int, @LastEverlyAction varchar(10), @LastEverlyTable varchar(50), @LastEverlyColumnValues varchar(max), @LastEverlyConditions varchar(max)
			SET @LastEverlyID = (Select Top 1 TableID from Everly_AuditTrail order by Id desc)
			SET @LastEverlyAction = (Select Top 1 [Action] from Everly_AuditTrail order by Id desc)
			SET @LastEverlyTable = (Select Top 1 TableName from Everly_AuditTrail order by Id desc)
			SET @IdentityColumn = (SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMNPROPERTY(object_id(TABLE_SCHEMA+'.'+TABLE_NAME), COLUMN_NAME, 'IsIdentity') = 1 AND TABLE_NAME = @LastEverlyTable)
			SET @LastEverlyColumnValues = (Select Top 1 OldColumnValues from Everly_AuditTrail order by Id desc)
			SET @LastEverlyConditions = (Select Top 1 Conditions from Everly_AuditTrail order by Id desc)

			IF SUBSTRING(@LastEverlyColumnValues,len(@LastEverlyColumnValues),1) = ','
			BEGIN
				Set @LastEverlyColumnValues = SUBSTRING(@LastEverlyColumnValues,1,len(@LastEverlyColumnValues)-1)
			END

			IF @LastEverlyAction = 'INSERT'
			BEGIN
				SET @Reverse = 'DELETE FROM ' + @LastEverlyTable + ' WHERE ' + @IdentityColumn + ' = ' + cast(@LastEverlyID as varchar)

				SET @Count = 1
				SET @sColumns = ''

				--This is used to get the existing values in the row about to be updated/deleted. It is be used during Everly REVERSE action
				WHILE @Count <= @ColumnsCountExIdentity
				BEGIN
					SET @xColumns = dbo.Fetch_ReturnCommaSeparatedString(@ColumnsListExIdentity,@Count)
					SET @xDataType = (Select DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @LastEverlyTable AND COLUMN_NAME = @xColumns)
					IF @xDataType = 'int' OR @xDataType = 'float' OR @xDataType = 'bit'
					BEGIN
						SET @sColumns = @sColumns + 'isnull(cast(' + @xColumns + ' as varchar),'''')+'',''+'
					END
					ELSE IF @xDataType = 'datetime'
					BEGIN
						SET @sColumns = @sColumns + '''"''+isnull(cast(' + @xColumns + ' as varchar),'''')+''",''+'
					END
					ELSE
					BEGIN
						SET @sColumns = @sColumns + '''"''+isnull(' + @xColumns + ','''')+''",''+'
					END
					Set @Count = @Count + 1
				END

				IF SUBSTRING(@sColumns,len(@sColumns)-2,len(@sColumns)) = '+,+'
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-3)
				END
				ELSE
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-1)
				END

				IF SUBSTRING(@sColumns,len(@sColumns),1) = ','
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-1)
				END

				SET @DSQL = 'SELECT @ReturnExecValueOUT = ' + @sColumns + ' FROM ' + @TableName + ' WHERE ' + @IdentityColumn + ' = ' + cast(@LastEverlyID as varchar)
				SET @Param = N'@ReturnExecValueOUT varchar(max) OUTPUT'
				EXEC sp_executesql @DSQL, @Param, @ReturnExecValueOUT=@ReturnExecValue OUTPUT

				--This is to insert into Everly_AuditTrail---
				INSERT INTO [dbo].[Everly_AuditTrail]([Action],[TableName],[TableID],[ColumnValues],[TSQLStatement],[RunStatus],[IsReverse],[DateEffected])
				VALUES('DELETE',@LastEverlyTable,@LastEverlyID,@ReturnExecValue,@Reverse,0,1,getdate())
				SET @EverlyID = SCOPE_IDENTITY()

				EXEC (@Reverse)
				SET @TableUpdateCount = @@ROWCOUNT
				SET @ReturnValue = 'Everly reverse performed successfully on ' + @LastEverlyTable + ' !'

				UPDATE Everly_AuditTrail SET RunStatus = 1 WHERE Id = @EverlyID
			END
			ELSE IF @LastEverlyAction = 'DELETE'
			BEGIN
				SET @Reverse = 'INSERT INTO ' + @LastEverlyTable + '(' + @ColumnsListExIdentity + ') VALUES (' + REPLACE(@LastEverlyColumnValues,'"','''') + ') SELECT @TableID = SCOPE_IDENTITY()'

				--This is to insert into Everly_AuditTrail---
				INSERT INTO [dbo].[Everly_AuditTrail]([Action],[TableName],[ColumnValues],[TSQLStatement],[RunStatus],[IsReverse],[DateEffected])
				VALUES('INSERT',@TableName,@LastEverlyColumnValues,@Reverse,0,1,getdate())
				SET @EverlyID = SCOPE_IDENTITY()

				EXEC sp_executesql @Reverse, N'@TableID int OUTPUT', @TableID OUTPUT

				SET @TableUpdateCount = @@ROWCOUNT
				SET @ReturnValue = 'Everly reverse performed successfully on ' + @LastEverlyTable + ' !'

				--This is to update the Audit Trail after successful run of the Everly action
				UPDATE Everly_AuditTrail SET RunStatus = 1, TableID = @TableID WHERE Id = @EverlyID
			END
			ELSE IF @LastEverlyAction = 'UPDATE'
			BEGIN
				SET @Reverse = 'UPDATE ' + @LastEverlyTable + ' SET '

				WHILE @Count <= @ColumnsCountExIdentity
				BEGIN
					SET @ColumnValue = dbo.Fetch_ReturnCommaSeparatedString(@LastEverlyColumnValues,@Count)
					SET @ColumnName = dbo.Fetch_ReturnCommaSeparatedString(@ColumnsListExIdentity,@Count)

					SET @Reverse = @Reverse + @ColumnName + ' = ' + @ColumnValue + ', '
			
					Set @Count = @Count + 1
				END
				SET @Reverse = SUBSTRING(@Reverse,0,len(@Reverse))
				SET @Reverse = REPLACE(@Reverse,'"','''')
				SET @Reverse = @Reverse + ' WHERE ' + @LastEverlyConditions

				SET @Count = 1
				SET @sColumns = ''
				--This is used to get the existing values in the row about to be updated/deleted. It is be used during Everly REVERSE action
				WHILE @Count <= @ColumnsCountExIdentity
				BEGIN
					SET @xColumns = dbo.Fetch_ReturnCommaSeparatedString(@ColumnsListExIdentity,@Count)
					SET @xDataType = (Select DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = @LastEverlyTable AND COLUMN_NAME = @xColumns)
					IF @xDataType = 'int' OR @xDataType = 'float' OR @xDataType = 'bit'
					BEGIN
						SET @sColumns = @sColumns + 'isnull(cast(' + @xColumns + ' as varchar),'''')+'',''+'
					END
					ELSE IF @xDataType = 'datetime'
					BEGIN
						SET @sColumns = @sColumns + '''"''+isnull(cast(' + @xColumns + ' as varchar),'''')+''",''+'
					END
					ELSE
					BEGIN
						SET @sColumns = @sColumns + '''"''+isnull(' + @xColumns + ','''')+''",''+'
					END
					Set @Count = @Count + 1
				END

				IF SUBSTRING(@sColumns,len(@sColumns)-2,len(@sColumns)) = '+,+'
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-3)
				END
				ELSE
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-1)
				END

				IF SUBSTRING(@sColumns,len(@sColumns),1) = ','
				BEGIN
					Set @sColumns = SUBSTRING(@sColumns,1,len(@sColumns)-1)
				END

				SET @DSQL = 'SELECT @ReturnExecValueOUT = ' + @sColumns + ' FROM ' + @LastEverlyTable + ' WHERE ' + @LastEverlyConditions
				SET @Param = N'@ReturnExecValueOUT varchar(max) OUTPUT'
				EXEC sp_executesql @DSQL, @Param, @ReturnExecValueOUT=@ReturnExecValue OUTPUT

				SET @LastEverlyColumnValues = (Select Top 1 ColumnValues from Everly_AuditTrail order by Id desc)

				--This is to insert into Everly_AuditTrail---
				INSERT INTO [dbo].[Everly_AuditTrail]([Action],[TableName],[ColumnValues],[OldColumnValues],[TSQLStatement],[Conditions],[RunStatus],[IsReverse],[DateEffected])
				VALUES('UPDATE',@LastEverlyTable,@LastEverlyColumnValues,@ReturnExecValue,@Reverse,@LastEverlyConditions,0,1,getdate())
				SET @EverlyID = SCOPE_IDENTITY()

				EXEC (@Reverse)
				SET @TableUpdateCount = @@ROWCOUNT
				SET @ReturnValue = 'Everly reverse performed successfully on ' + @LastEverlyTable + ' !'

				--This is to update the Audit Trail after successful run of the Everly action
				UPDATE Everly_AuditTrail SET RunStatus = 1 WHERE Id = @EverlyID
			END
		END
		ELSE IF @Action = ''
		BEGIN
			SET @TableUpdateCount = 0
			SET @ReturnValue = '@Action parameter is empty'
		END
		ELSE
		BEGIN
			SET @TableUpdateCount = 0
			SET @ReturnValue = '@Action parameter is not valid - Valid values are INSERT or UPDATE or FETCH or DELETE or CUSTOM.'
		END
	END
END

SELECT @ReturnValue EverlyMessage, @TableUpdateCount EverlyActionCount
