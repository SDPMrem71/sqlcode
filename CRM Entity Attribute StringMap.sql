SELECT		/*موجودیت*/Entity.ObjectTypeCode [EobjCd], Entity.Name [EntityName], COALESCE(ELbl_Fa.Label,ELbl_en.Label) [EntityLabel],
			/*فیلدها*/ Attrib.Name [AttributeName], Attrib.MinValue, Attrib.MaxValue, Attrib.ColumnNumber [Col#], COALESCE(ALbl_Fa.Label, ALbl_en.Label) [AttributeLabel], COALESCE(ALbl_Fa.LanguageId , ALbl_en.LanguageId) [Lang],Attrib.AttributeRequiredLevelId,Attrib.ReferencedEntityObjectTypeCode [Ref_EObjCd],
			-- Attrib.IsNullable, Attrib.IsAuditEnabled,attrib.IsSecured,
				/*== رفتار فیلد ====*/
			( SELECT TOP (1) [Name] FROM dbo.EntityView WHERE ObjectTypeCode = Attrib.ReferencedEntityObjectTypeCode ) [Ref_EntityLabel],/*موجودیت مرتبط*/
			CASE Attrib.Behavior WHEN 3 THEN 'Time-Zone Indep' WHEN 1 THEN 'User Local' WHEN 2 THEN 'Date Only' ELSE NULL END [DT_Behavior],/* رفتار تاریخ*/
				/*option/set*/
			ops.OptionSet [OptionSets]
			/*نوع داده ای*/,AttribType.Description, AttribType.XmlType
FROM			dbo.EntityView Entity 
	INNER JOIN	dbo.AttributeView Attrib ON Attrib.EntityId = Entity.EntityId 
	INNER JOIN dbo.AttributeTypes AttribType ON AttribType.AttributeTypeId = Attrib.AttributeTypeId 
		/*لیبل های انگلیسی*/ 
	LEFT JOIN	dbo.LocalizedLabelView ELbl_en ON ELbl_en.ObjectId = Entity.EntityId  AND ELbl_en.ObjectColumnName = 'LocalizedCollectionName' /*نام گروهی یک موجودیت*/ AND  ELbl_en.LanguageId = 1033
	LEFT JOIN	dbo.LocalizedLabelView ALbl_en ON ALbl_en.ObjectId = Attrib.AttributeId AND ALbl_en.ObjectColumnName = 'DisplayName' AND ALbl_en.LanguageId = 1033
		/*لیبل های فارسی*/
	LEFT JOIN	dbo.LocalizedLabelView ELbl_Fa ON ELbl_Fa.ObjectId = Entity.EntityId  AND ELbl_Fa.ObjectColumnName = 'LocalizedCollectionName'  AND  ELbl_Fa.LanguageId = 1065
	LEFT JOIN	dbo.LocalizedLabelView ALbl_Fa ON ALbl_Fa.ObjectId = Attrib.AttributeId AND ALbl_Fa.ObjectColumnName = 'DisplayName' AND ALbl_Fa.LanguageId = 1065

	OUTER APPLY	(	SELECT CONCAT('[', os.LangId,': ', os.AttributeValue, ': ', os.Value,']','x;')  FROM ( SELECT * FROM dbo.StringMap SM WHERE  SM.ObjectTypeCode = Entity.ObjectTypeCode AND SM.AttributeName = Attrib.Name AND SM.LangId=1065 
																											UNION ALL SELECT * FROM dbo.StringMap SM WHERE  SM.ObjectTypeCode = Entity.ObjectTypeCode AND SM.AttributeName = Attrib.Name AND SM.LangId=1033 
																																						AND NOT EXISTS( SELECT 1 FROM dbo.StringMap sm1 WHERE sm.ObjectTypeCode=sm1.ObjectTypeCode AND sm.AttributeName = sm1.AttributeName AND sm1.Value=sm.Value AND sm1.LangId=1065) ) AS os FOR XML PATH('') ) AS ops(OptionSet)
WHERE	Entity.[Name] LIKE N'%%'
	AND COALESCE(ELbl_Fa.[Label] , ELbl_en.[Label],'') LIKE N'%%'
	AND ISNULL(Attrib.[Name],'') LIKE  N'%%'
	AND COALESCE(ALbl_Fa.[Label], ALbl_en.[Label],'') LIKE N'%%'
ORDER BY Col#
