-- =============================================
-- Author:		mrh
-- Create date: 1398/11/26
-- ModifiedBy:
-- ModifiedOn:
-- Description: نمایش پکیج های ثبت شده برای اجرا در جاب های سرور
-- =============================================

ALTER VIEW dbo.PackagesInJobs --WITH SCHEMABINDING
AS
WITH jobs AS (
		SELECT	job.name AS JobName, steps.step_name, job.job_id, steps.step_id,
				CASE 
					WHEN steps.command LIKE '/DTS%' OR steps.command LIKE '/ISSERVER%' THEN SUBSTRING(steps.command, pinfo.StartIndex + 1, pinfo.EndIndex)
					WHEN steps.command LIKE '/SQL%' THEN '\MSDB' + SUBSTRING(steps.command, pinfo.StartIndex, pinfo.EndIndex)
					WHEN steps.command LIKE '/SERVER%' THEN '\MSDB\' + SUBSTRING(steps.command, pinfo.StartIndex, pinfo.EndIndex)
					ELSE N' --- Too Long ---'
				END AS command, job.date_modified AS Job_Modified_date
		FROM	msdb.dbo.sysjobs job INNER JOIN 
					msdb.dbo.sysjobsteps steps ON steps.job_id = job.job_id LEFT JOIN 
						( SELECT	J.job_id,JS.step_id,
									--This worked for me except the PackageFolderPath. I use File System when deploying. – Marco Rosas Jul 3 at 16:57
									StartIndex = 
										CASE 
											WHEN JS.command LIKE '/DTS%' OR JS.command LIKE '/SQL%' OR JS.command LIKE '/ISSERVER%' THEN CHARINDEX('\',JS.command, CHARINDEX('\',JS.command) + 1) --'
											WHEN JS.command LIKE '/SERVER%' THEN CHARINDEX('"', JS.command, CHARINDEX(' ',JS.command, CHARINDEX(' ',JS.command) + 1) + 1) + 1
											ELSE 0
										END,
									EndIndex = 
										CASE 
											WHEN JS.command LIKE '/DTS%' OR JS.command LIKE '/SQL%'  OR JS.command LIKE '/ISSERVER%' 
												THEN  CHARINDEX('"',JS.command, CHARINDEX('\',JS.command, CHARINDEX('\',JS.command) + 1)) --'
													- CHARINDEX('\',JS.command, CHARINDEX('\',JS.command) + 1) - 1 --'
											WHEN JS.command LIKE '/SERVER%' 
												THEN  CHARINDEX('"',JS.command, CHARINDEX('"', JS.command, CHARINDEX(' ',JS.command, CHARINDEX(' ',JS.command) + 1) + 1) + 1)
													- CHARINDEX('"', JS.command, CHARINDEX(' ',JS.command, CHARINDEX(' ',JS.command) + 1) + 1) - 1
											ELSE 0
										END
	
							FROM	msdb.dbo.sysjobsteps JS	INNER JOIN	
										msdb.dbo.sysjobs J ON JS.job_id = J.job_id
							WHERE JS.subsystem = 'SSIS') pinfo ON pinfo.job_id = job.job_id AND pinfo.step_id = steps.step_id

)

SELECT	dir.name AS FolderName, prj.name AS ProjectName, pkg.name AS PackageName,
		jobs.JobName, jobs.step_name, jobs.command, jobs.Job_Modified_date,
		CAST(prj.last_deployed_time AS DATETIME) AS last_deployed_time, prj.deployed_by_name, schd.name AS scheduleName,
		jobs.job_id, jobs.step_id
FROM	catalog.folders dir INNER JOIN 
			catalog.projects prj ON prj.folder_id = dir.folder_id INNER JOIN 
				catalog.packages pkg ON pkg.project_id = prj.project_id LEFT JOIN 
					jobs ON jobs.command = 	CONCAT('SSISDB\',dir.name,'\',prj.name,'\',pkg.name,'\') LEFT JOIN 
						msdb.dbo.sysjobschedules jobsSchd ON jobs.job_id = jobsSchd.job_id LEFT JOIN 
							msdb.dbo.sysschedules schd ON schd.schedule_id = jobsSchd.schedule_id


GO
