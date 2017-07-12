# Everly
Everly is an SQL Server Stored Procedure that enables one to perform any CRUD operation on a database, manages audit trail and 
even helps to reverse an operation done using it.

Requirements
------------
Everly requires two scripts everly-prerequisites.sql and everyly.sql. The former contains four user-defined functions which are: 
1. Fetch_ReturnCommaSeparatedString - This is used to get values from a comma seperated string using the index.
2. IsValueValid - This is used to check that the value of a parameter is valid comparing it with the datatype of the column to use it.
3. IsValuesValid - This is used to check that all the parameters passed are valid. It loops through each of the value using IsValueValid
                   for each of the parameter
4. IsValuesValid_Description - This is used to get the details of the columns that didn't pass the validation

While the latter contains the Everly stored procedure.

How to use Everly
-----------------
Everly requires four parameters namely @Action for INSERT/UPDATE/DELETE/FETCH, @ColumnValues for values to be inserted or updated into
columns, @TableName for Table to be modified and @Condition for the condition for an update or delete action

Examples on How to use Everly
-----------------------------
For a table called Bank which has columns BankID int, BankName varchar(50), CreatedBy int and DateCreated datetime, everly can be used 
to perform CRUD operations with the following queries.

Everly 'FETCH','','Banks',''
Everly 'INSERT','"WALLY","WALLY BANK",1,fshdgffh','Banks',''
Everly 'UPDATE','"WALLY","WALLY BANK",1,GETDATE()','Banks','BankID=1028'
Everly 'DELETE','','Banks','BankID=1027'

Finally, if you have done any action in error like UPDATE/DELETE/INSERT you can simply reverse it using Everly like this:
Everly 'REVERSE'

Feel free to make contributions.

Updates coming very soon....
