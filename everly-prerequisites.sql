IF OBJECT_ID('[dbo].[Fetch_ReturnCommaSeparatedString]') IS NOT NULL
BEGIN
	DROP FUNCTION [dbo].[Fetch_ReturnCommaSeparatedString]
END
GO
CREATE FUNCTION [dbo].[Fetch_ReturnCommaSeparatedString] 
		(@String varchar(200),@Position int)  
	--
	-- Retrieves the String from position
	-- 
	RETURNS varchar(50)      
	--WITH ENCRYPTION
	  AS  
	BEGIN
		Declare @Holder varchar(200)
		Declare    @Len    int
		Declare @Count    int
		Declare    @Loop    int

		IF Substring(@String,@Len,1) <> ','
		BEGIN
			SET @String = @String + ','        
		END

		Set @Len = Len(@String)
		Set @Count = 1
		Set @Loop = 0
		Set @Holder = ''

		WHILE @Count <= @Len
			BEGIN
				IF Substring(@String,@Count,1) <> ','
					BEGIN
						SET @Holder = @Holder + Substring(@String,@Count,1)
					END
				ELSE IF Substring(@String,@Count,1) = ',' 
					BEGIN
						SET @Loop = @Loop + 1 
					END
            
				IF @Loop = @Position and Substring(@String,@Count,1) = ',' 
					BEGIN
						BREAK
					END
				ELSE IF @Loop <> @Position and Substring(@String,@Count,1) = ','
					BEGIN
						SET @Holder = ''
					END

				SET @Count = @Count + 1
			END

		IF @Holder = ''
			BEGIN
				SET @Holder = 0
			END        

		return @Holder
	END
GO
IF OBJECT_ID('[dbo].[IsValueValid]') IS NOT NULL
BEGIN
	DROP FUNCTION [dbo].[IsValueValid]
END
GO
CREATE FUNCTION [dbo].[IsValueValid]
(
	@Value varchar(max),
	@DataType varchar(max)
)
RETURNS bit
AS
BEGIN
	DECLARE @ReturnValue bit, @ValueDataType varchar(10)
	IF ISNUMERIC(@Value) = 1
	BEGIN
		IF CHARINDEX('.',@Value) <> 0
		BEGIN
			Set @ValueDataType = 'float'
		END
		ELSE
		BEGIN
			Set @ValueDataType = 'int'
		END
	END
	ELSE IF ISDATE(@Value) = 1
	BEGIN
		Set @ValueDataType = 'datetime'
	END
	ELSE
	BEGIN
		Set @ValueDataType = 'varchar'
	END

	IF @ValueDataType = @DataType OR (@ValueDataType = 'float' AND @DataType = 'decimal')
	BEGIN
		Set @ReturnValue = 1
	END
	ELSE IF @ValueDataType = 'int' AND @DataType = 'float'
	BEGIN
		Set @ReturnValue = 1
	END
	ELSE IF @DataType = 'varchar'
	BEGIN
		Set @ReturnValue = 1
	END
	ELSE
	BEGIN
		Set @ReturnValue = 0
	END

	RETURN @ReturnValue
END
GO
IF OBJECT_ID('[dbo].[IsValuesValid]') IS NOT NULL
BEGIN
	DROP FUNCTION dbo.IsValuesValid
END
GO
CREATE FUNCTION [dbo].[IsValuesValid]
(
	@Values varchar(max),
	@ValuesDataType varchar(max),
	@Count int
)
RETURNS bit AS
BEGIN
	DECLARE @ReturnValue bit, @Value varchar(max), @ValueDataType varchar(max)
	DECLARE @True bit, @False bit, @sCount int

	SET @False = 0
	SET @True = 0
	SET @sCount = 1

	WHILE @sCount <= @Count
	BEGIN
		SET @Value = dbo.Fetch_ReturnCommaSeparatedString(@Values,@sCount)
		SET @ValueDataType = dbo.Fetch_ReturnCommaSeparatedString(@ValuesDataType,@sCount)

		IF dbo.IsValueValid(@Value,@ValueDataType) = 1
		BEGIN
			SET @True = 1
		END
		ELSE
		BEGIN
			SET @False = 1
		END

		SET @sCount = @sCount + 1
	END

	IF @False = 1
	BEGIN
		SET @ReturnValue = 0
	END
	ELSE IF @False = 0 AND @True = 0
	BEGIN
		SET @ReturnValue = 0
	END
	ELSE
	BEGIN
		SET @ReturnValue = 1
	END
	
	RETURN @ReturnValue
END
GO
IF OBJECT_ID('[dbo].[IsValuesValid_Description]') IS NOT NULL
BEGIN
	DROP FUNCTION [dbo].[IsValuesValid_Description]
END
GO
CREATE FUNCTION [dbo].[IsValuesValid_Description]
(
	@Values varchar(max),
	@ValuesDataType varchar(max),
	@Count int
)
RETURNS varchar(max) AS
BEGIN
	DECLARE @ReturnValue bit, @Value varchar(max), @ValueDataType varchar(max)
	DECLARE @True bit, @False bit, @sCount int, @Description varchar(max)

	SET @False = 0
	SET @True = 0
	SET @sCount = 1
	SET @Description = ''

	WHILE @sCount <= @Count
	BEGIN
		SET @Value = dbo.Fetch_ReturnCommaSeparatedString(@Values,@sCount)
		SET @ValueDataType = dbo.Fetch_ReturnCommaSeparatedString(@ValuesDataType,@sCount)

		IF dbo.IsValueValid(@Value,@ValueDataType) = 1
		BEGIN
			SET @True = 1
		END
		ELSE
		BEGIN
			SET @False = 1
			SET @Description = @Description + ' The value ''' + @Value + ''' is not of datatype ' + @ValueDataType + ','
		END

		SET @sCount = @sCount + 1
	END

	IF @False = 1
	BEGIN
		SET @ReturnValue = 0
	END
	ELSE IF @False = 0 AND @True = 0
	BEGIN
		SET @ReturnValue = 0
	END
	ELSE
	BEGIN
		SET @ReturnValue = 1
	END

	SET @Description = SUBSTRING(@Description,1,LEN(@Description)-1)
	SET @Description = @Description + '.'
	
	RETURN @Description
END
GO
IF OBJECT_ID('[dbo].[IsValuesValid]') IS NOT NULL
BEGIN
	DROP FUNCTION [dbo].[IsValuesValid]
END
GO
CREATE FUNCTION [dbo].[IsValuesValid]
(
	@Values varchar(max),
	@ValuesDataType varchar(max),
	@Count int
)
RETURNS bit AS
BEGIN
	DECLARE @ReturnValue bit, @Value varchar(max), @ValueDataType varchar(max)
	DECLARE @True bit, @False bit, @sCount int

	SET @False = 0
	SET @True = 0
	SET @sCount = 1

	WHILE @sCount <= @Count
	BEGIN
		SET @Value = dbo.Fetch_ReturnCommaSeparatedString(@Values,@sCount)
		SET @ValueDataType = dbo.Fetch_ReturnCommaSeparatedString(@ValuesDataType,@sCount)

		IF dbo.IsValueValid(@Value,@ValueDataType) = 1
		BEGIN
			SET @True = 1
		END
		ELSE
		BEGIN
			SET @False = 1
		END

		SET @sCount = @sCount + 1
	END

	IF @False = 1
	BEGIN
		SET @ReturnValue = 0
	END
	ELSE IF @False = 0 AND @True = 0
	BEGIN
		SET @ReturnValue = 0
	END
	ELSE
	BEGIN
		SET @ReturnValue = 1
	END
	
	RETURN @ReturnValue
END
GO
