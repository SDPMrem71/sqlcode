-- تمامی دسترسی ها دیتابیس
SELECT * FROM sys.fn_builtin_permissions(DEFAULT) WHERE permission_name LIKE 'View%' ORDER BY permission_name, class_desc, parent_class_desc;

--اجازه به دیدن تمامی دیتابیس ها
GRANT VIEW ANY DATABASE ON SCHEMA::dbo TO test

--ساخت یک نقش در سطح دیتابیس
CREATE ROLE TestRole AUTHORIZATION dbo
GO
--اضافه کردن کاربر به دارندگان نقش
EXECUTE sp_addrolemember 'TestRole','test'
--دادن دسترسی های مورد نیاز به نقش
GRANT VIEW DEFINITION ON dbo.cal TO TestRole--UXUX
GRANT SELECT ON dbo.BOMIng TO TestRole

--داینامیک کوئری برای موارد مورد نیاز
  
DECLARE @Role sysname = 'TestRole'


IF OBJECT_ID('tempdb..#runSQL') IS NOT null DROP TABLE #runSQL

	--ساخت کوئری ها
		SELECT	'GRANT SELECT ON ' + SCHEMA_NAME( s.schema_id ) + '.' + s.name + ' ' + 'TO' + ' ' + @Role AS sqlqry
		INTO	#runSQL
		FROM	sys.all_objects s
		WHERE
				s.type IN (/* 'P', 'V', 'FN',  'TR' , 'IF', 'TF', */ 'U')
			AND s.is_ms_shipped = 0
			AND s.name LIKE '%ty%'
		ORDER BY
				s.type, s.name;

		--داینامیک کوئری برای موارد مورد نیاز
        DECLARE @variable NVARCHAR(MAX)
        
        DECLARE sqlcur CURSOR FAST_FORWARD READ_ONLY FOR 
		
		SELECT sqlqry 
		FROM #runSQL
        
        OPEN sqlcur
        
        FETCH NEXT FROM sqlcur INTO @variable
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
			EXEC(@variable)
            FETCH NEXT FROM sqlcur INTO @variable
        END
        
        CLOSE sqlcur
        DEALLOCATE sqlcur

