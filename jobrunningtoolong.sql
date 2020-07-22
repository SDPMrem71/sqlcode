SELECT *,DATEDIFF(SECOND,start_execution_date,GETDATE()) [PassedTime] ,DATEDIFF(SECOND,start_execution_date,T1.NextRunTimeCalculated) AS [AllowedRunTime]
												FROM (
														SELECT jbAct.start_execution_date, jbAct.stop_execution_date, jbAct.next_scheduled_run_date, sysJb.name,
																CASE (freq_subday_type)
																	WHEN 2 THEN DATEADD(SECOND,freq_subday_interval,jbAct.start_execution_date) --'Every seconds'
																	WHEN 4 THEN DATEADD(MINUTE,freq_subday_interval,jbAct.start_execution_date)-- 'Every minutes'
																	WHEN 8 THEN DATEADD(HOUR,freq_subday_interval,jbAct.start_execution_date)-- 'Every hours'
																END AS [NextRunTimeCalculated]

														FROM msdb.dbo.sysjobactivity jbAct INNER JOIN
																msdb.dbo.sysjobs sysJb ON sysJb.job_id = jbAct.job_id INNER JOIN
																	msdb.dbo.sysjobschedules sys_sch ON sys_sch.job_id = sysJb.job_id INNER JOIN
																		msdb.dbo.sysschedules sch ON sch.schedule_id = sys_sch.schedule_id

														WHERE jbAct.stop_execution_date IS NULL -- job hasn't stopped running
															AND jbAct.start_execution_date IS NOT NULL -- job is currently running 
															AND freq_type = 4 AND freq_interval = 1 -- Daily job and Everyday
															AND NOT EXISTS( -- make sure this is the most recent run
																SELECT 1
																FROM msdb..sysjobactivity new
																WHERE new.job_id = jbAct.job_id
																AND new.start_execution_date > jbAct.start_execution_date
															)
															)AS T1 ) AS T2
												WHERE T2.PassedTime >= (T2.AllowedRunTime +60)
