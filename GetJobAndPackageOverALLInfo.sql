-- =============================================
-- Author:		mrh
-- Create date: 1398/10/12
-- ModifiedBy: mrh
-- ModifiedOn: 1399/05/14
-- Description:
-- =============================================
ALTER PROCEDURE ssrs.GetJobAndPackageOverALLInfo
AS
BEGIN
	SET NOCOUNT ON;
	EXECUTE AS LOGIN = 'SDP\Administrator';
	------------------------------
	DECLARE @StartOfToday DATETIME = DATEADD(dd, DATEDIFF(dd, 0, getdate()), 0); --cast(getdate() as date)
	------------------ TempDb Control
	IF(OBJECT_ID('tempdb..#PackageData') IS NOT NULL) DROP TABLE #PackageData;
	
	IF(OBJECT_ID('tempdb..#JobHistory') IS NOT NULL) DROP TABLE #JobHistory;
	IF(OBJECT_ID('tempdb..#JobsData') IS NOT NULL) DROP TABLE #JobsData;
	
	--------------- Job History
	SELECT	sjh.server, sjh.job_id, sjh.step_id,
			sjh.step_name, sjh.message, sjh.run_status,
			CONVERT(DATETIME,CONCAT(LEFT(sjh.run_date, 04),'/',SUBSTRING( CAST(sjh.run_date AS CHAR(10)), 5, 2 ),'/',RIGHT(sjh.run_date, 2),' ',
					STUFF( STUFF( RIGHT(REPLICATE( '0', 6 ) + CAST(sjh.run_time AS VARCHAR(6)), 6), 3, 0, ':' ), 6, 0, ':' ))) AS Run_DateTime,
	
			[AvgJobDuration] =CAST( (SUM( ((sjh.run_duration / 10000 * 3600) + ((sjh.run_duration % 10000) / 100 * 60) + (sjh.run_duration % 10000) % 100)) OVER (PARTITION BY sjh.job_id) * 1.0)
							/ COUNT( sjh.job_id ) OVER (PARTITION BY sjh.job_id)AS INT),
			[AvgStepDuration] =CAST( (SUM( ((sjh.run_duration / 10000 * 3600) + ((sjh.run_duration % 10000) / 100 * 60) + (sjh.run_duration % 10000) % 100)) OVER (PARTITION BY sjh.job_id, sjh.step_id) * 1.0)
							/ COUNT( sjh.job_id ) OVER (PARTITION BY sjh.job_id, sjh.step_id) AS INT),
	
			STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + CAST( sjh.run_duration AS VARCHAR(8)), 8), 3, 0, ':'), 6, 0, ':'), 9, 0, ':') AS [run_duration (DD:HH:MM:SS)],
			sjh.retries_attempted,
			ROW_NUMBER() OVER (PARTITION BY sjh.job_id, sjh.step_id ORDER BY sjh.run_date DESC, sjh.run_time DESC) rowN,
			(SELECT MAX(st.step_id) FROM msdb.dbo.sysjobsteps st  WHERE st.job_id = sjh.job_id ) TotalStep
	INTO #JobHistory
	FROM	msdb.dbo.sysjobhistory AS sjh
	WHERE	sjh.step_id <> 0
	
	---------------Jobs Over all Data
	/*
	اگر هیستوری پاک شود، اطلاعات نمایش داده نمیشود بنابر این باید به تاریخچه لفت جوین زد و در صورت عدم وجود تاریخچه از جدول سرور_جاب استفاده کرد تا وضعیت آن ها را کسب نمود
	--CONVERT( DECIMAL(10, 2), History.AvgJobDurationثانیه ) AvgJobDuration,
			--CONVERT( DECIMAL(10, 2), History.AvgStepDurationثانیه ) AvgStepDuration,
	
			History.run_status/*در صورتی که در قدم تیکت خروج در تاریخچه خورده باشد همیشه 4 است*/,
			در صورت اجرا 0 است
	*/
	SELECT	ji.JobName AS [نام], ji.job_id ,
			STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + 
									CAST(	(H.AvgJobDuration / 3600  % 24 * 10000) +
											(H.AvgJobDuration / 60 % 60 * 100) + 
											(H.AvgJobDuration % 3600 % 60) AS VARCHAR(8)), 8), 3, 0, ':'), 6, 0, ':'), 9, 0, ':') AS AvgJobDuration,

			CONCAT(dbo.getShamsiDate( JI.Job_start_execution_date ),' ',CAST(JI.Job_start_execution_date AS TIME(0))) AS [شروع جاب] ,
			CONCAT(dbo.getShamsiDate( H.Run_DateTime ),' ',CAST(Run_DateTime AS TIME(0) )) AS [شروع قدم] ,
			CASE WHEN Job_stop_execution_date IS NULL
					THEN CONCAT(N'در حال اجرای قدم ', JI.JobLastStepExecuted + 1)
						ELSE dbo.getShamsiDate(JI.Job_stop_execution_date ) + ' ' + CAST(CAST(JI.Job_stop_execution_date AS TIME(0) )AS varchar(8) ) END
			AS [پایان جاب],
			H.TotalStep,
			 '}{' AS Seperator,
			JI.step_id AS [قدم],JI.step_name AS [نام_قدم],
			IIF(JI.JobLastStepExecuted  < JI.step_id AND Job_stop_execution_date IS NULL, 4, JI.StepLastRunOutcome) AS last_run_outcome,
			IIF(JI.JobLastStepExecuted  < JI.step_id AND Job_stop_execution_date IS NULL, 'In Progress', JI.StepLastRunOutcomeName) --در حال حرکت در اجرا
					AS [نتیجه آخرین اجرا],
			CONCAT(NULLIF(dbo.getShamsiDate( JI.next_scheduled_run_date ),'') + ' ' ,CONVERT(TIME(0),JI.next_scheduled_run_date)) [تاریخ اجرای بعدی],
			--History.run_status/*دارای توضیح*/, 
			H.[run_duration (DD:HH:MM:SS)],
			
			STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + 
									CAST(	(H.AvgStepDuration / 3600  % 24 * 10000) +
											(H.AvgStepDuration / 60 % 60 * 100) + 
											(H.AvgStepDuration % 3600 % 60) AS VARCHAR(8)), 8), 3, 0, ':'), 6, 0, ':'), 9, 0, ':') AS AvgStepDuration,
			H.server,
			PackageFolderPath = ISNULL(pj.command,'Nلطفا به جاب مراجعه بفرمایید.')
	INTO #JobsData
	FROM	JobsInfo JI INNER JOIN 
				#JobHistory AS H ON	JI.job_id = H.job_id
								AND JI.step_id = H.step_id 
								AND H.rowN =1	LEFT JOIN
					dbo.PackagesInJobs pj ON pj.job_id = JI.job_id AND JI.step_id = pj.step_id
	WHERE	JI.JobEnabled = 1
		AND JI.JobName NOT LIKE 'syspolicy%'
		--تغییر سشن از طریق ریستارت و غیره می باشد
	---------------------- Package Total Run Data
  ;WITH TotalAnalyze 
	AS(	SELECT	CONCAT('SSISDB\',e.folder_name,'\',e.project_name,'\',e.package_name,'\') AS Package_path,
			e.package_name,
			AVG(DATEDIFF( MILLISECOND, op.start_time, op.end_time )) AS [TotalAVG],
			MAX(CONVERT(DATETIME,op.end_time)) [TotalLastRunEndTime],
			--MAX(CONVERT(DATETIME,e.start_time)) OVER( PARTITION BY e.folder_name, e.project_name, e.package_name) [TotalLastRunStartTime],
			MAX(e.execution_id)  LastRunExecutionID,
			COUNT( IIF(op.status=7,1,NULL) )  TotalSuccess,
			COUNT( IIF(op.status=2,1,NULL) ) TotalRunning,
			COUNT( IIF(op.status=3,1,NULL) )  TotalCanceled,
			COUNT( IIF(op.status=4,1,NULL) ) TotalFailed--,
			--MAX( IIF(op.status=4, e.execution_id ,NULL) ) LastestFailedExecutionID
		FROM	internal.executions e INNER JOIN
					internal.operations op ON op.operation_id = e.execution_id INNER JOIN 
					/* فقط پکیج هایی که در حال حاضر در سرور هستند*/
						internal.folders dir ON e.folder_name = dir.name INNER JOIN 
						--شرط ورژن پروژه ها بررسی نشده است تا اجرای همه ی ورژن ها بررسی شود
							internal.projects prj ON e.project_name = prj.name
		GROUP BY e.folder_name, e.project_name, e.package_name

	 ), LastDayAnalyse
	AS  (	SELECT		CONCAT('SSISDB\',e.folder_name,'\',e.project_name,'\',e.package_name,'\') AS Package_path,
		 				MIN(CONVERT(DATETIME,op.start_time)) LastDayStartTime,
						--CONVERT(VARCHAR(8),DATEADD(MILLISECOND,AVG(DATEDIFF(MILLISECOND, op.start_time,op.end_time)),0),114) LastDayAVGDuration,
						CONVERT(TIME(0),DATEADD(MILLISECOND,AVG(DATEDIFF(MILLISECOND, op.start_time,op.end_time)),0)) LastDayAVGDuration,
		 				COUNT( IIF(op.status=7,1,NULL) ) LastDaySuccessCount,
		 				COUNT( IIF(op.status=4,1,NULL) ) LastDayFailedCount,
						--تعداد موفق از شروع روز
						COUNT(IIF( op.status=7 AND CONVERT(DATETIME,op.start_time) >= @StartOfToday ,1,NULL)) TodaySuccessCount,
						COUNT(IIF( op.status=4 AND CONVERT(DATETIME,op.start_time) >= @StartOfToday ,1,NULL)) TodayFailedCount,
						--آخرین وضعیت اجرا
							(SELECT op1.status
								FROM internal.operations op1 
									 WHERE op1.operationid = MAX(op.operationid)
											) AS LastRunStatus,
						DATEDIFF( MILLISECOND, MAX(op.start_time), MAX(op.end_time) ) AS LastRunDuration

			FROM	internal.executions e INNER JOIN
						internal.operations op ON op.operation_id = e.execution_id  

			WHERE	CAST(op.start_time AS DATETIME) > DATEADD( DAY, -1, GETDATE())
			GROUP BY e.folder_name,e.project_name,e.package_name
	)
	SELECT	DISTINCT 
			TA.Package_path,TA.package_name,
			CONVERT(VARCHAR(8),DATEADD(MILLISECOND,TA.TotalAVG,0),114) TotalAVG,
			LDA.LastDayAVGDuration, LDA.LastDayStartTime, 
			TA.TotalLastRunEndTime, LDA.LastRunStatus, LastRunExecutionID,
			--CONVERT(VARCHAR(8),DATEADD(MILLISECOND,LDA.LastRunDuration,0),114) LastRunDuration,
			CONVERT(TIME(0),DATEADD(MILLISECOND,LDA.LastRunDuration,0)) LastRunDuration,
			TA.TotalSuccess, TA.TotalRunning, TA.TotalCanceled, TA.TotalFailed ,
			LDA.LastDaySuccessCount, LDA.LastDayFailedCount,
			LDA.TodaySuccessCount,LDA.TodayFailedCount, LastestFailedExecutionID
	INTO #PackageData
	FROM	TotalAnalyze TA LEFT JOIN 
				LastDayAnalyse LDA ON LDA.Package_path = TA.Package_path;
	
	---------------------------------------------------------------------
	
	SELECT	J.نام, J.job_id, J.AvgJobDuration,
			J.[شروع جاب], J.[شروع قدم], J.[پایان جاب], J.TotalStep,
			J.Seperator, 
			J.قدم, J.نام_قدم, J.last_run_outcome, J.[نتیجه آخرین اجرا], J.[تاریخ اجرای بعدی],
			J.[run_duration (DD:HH:MM:SS)],
			J.AvgStepDuration, J.server,
			--------
			p.Package_path, p.package_name,
			P.TotalAVG, P.LastDayAVGDuration,
			P.LastDayStartTime, P.TotalLastRunEndTime,
			P.LastRunStatus,  dbo.GetExecutionStatusName(P.LastRunStatus) LastRunStatusName,
			P.LastRunDuration, LastRunExecutionID, LastestFailedExecutionID,
			P.LastDaySuccessCount,P.LastDayFailedCount ,
			P.TodaySuccessCount,P.TodayFailedCount,
			P.TotalSuccess, P.TotalRunning, P.TotalCanceled, P.TotalFailed,
			---------------------------
			NULLIF(COUNT( IIF(J.last_run_outcome=0 
							AND (  dbo.GetExecutionStatusName(p.LastRunStatus) ='failed' 
								OR p.LastRunStatus IS NULL
								) ,1,NULL) 
						) OVER(), 0) 
			AS OverallFailedCount,
			NULLIF(COUNT( IIF(	J.last_run_outcome=1 
							AND (  dbo.GetExecutionStatusName(p.LastRunStatus) ='succeeded' 
								OR p.LastRunStatus IS NULL
								) ,1,NULL) 
						) OVER(), 0) 
			AS OverallSucessCount,
			
			NULLIF(COUNT( IIF(j.[نتیجه آخرین اجرا] LIKE N'In Progress' ,1,NULL) ) OVER(), 0) AS OverallRunningCount
	FROM	#JobsData J FULL JOIN
				#PackageData P ON J.PackageFolderPath = P.Package_path
	--فقط پکیج یا جاب های روز قبل
	-- یک جاب میتواند پکیج نداشته باشد، یا یک پکیج میتواند بدون جاب اجرا شود
	WHERE	P.LastDayStartTime IS NOT NULL OR J.job_id IS NOT null
END
GO
