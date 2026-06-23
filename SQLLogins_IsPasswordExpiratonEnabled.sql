select name, type_desc, is_disabled, is_expiration_checked from sys.sql_logins
where is_expiration_checked = 1




select name, type_desc, is_disabled, is_expiration_checked, * from sys.sql_logins
where is_expiration_checked = 1

DECLARE @sql NVARCHAR(MAX);

SET @sql = 'ALTER LOGIN [' + + '] WITH CHECK_POLICY = OFF;
			ALTER LOGIN [' + + '] WITH CHECK_EXPIRATION = OFF;'






ALTER LOGIN [G2pcservus_admin] WITH CHECK_POLICY = OFF;
ALTER LOGIN [G2pcservus_admin] WITH CHECK_POLICY = ON;
GO

CHECK_EXPIRATION = { ON | OFF }