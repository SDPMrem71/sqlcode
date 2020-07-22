--job
SELECT	steps.subsystem, job.name AS JobName, steps.step_name,
				CONVERT(DATETIME,CONCAT(LEFT(steps.last_run_date, 04),'/',SUBSTRING( CAST(steps.last_run_date AS CHAR(10)), 5, 2 ),'/',RIGHT(steps.last_run_date, 2),' ',
									STUFF( STUFF( RIGHT(REPLICATE( '0', 6 ) + CAST(steps.last_run_time AS VARCHAR(6)), 6), 3, 0, ':' ), 6, 0, ':' ))) AS LastRun_DateTime,
				act.last_executed_step_date, act.next_scheduled_run_date,
				CASE	WHEN sch.freq_type = 4 THEN 'Daily' WHEN sch.freq_type = 8 THEN 'Weekly' WHEN sch.freq_type IN ('16','32') THEN 'Monthly' END frequency,
				CASE	WHEN sch.freq_type = 4 THEN 'every ' + CAST (sch.freq_interval AS VARCHAR(3)) + ' day(s)' 
						WHEN sch.freq_type = 8 THEN (	CASE WHEN sch.freq_interval&1 = 1 THEN 'Sunday, ' ELSE '' END +
														CASE WHEN sch.freq_interval&2 = 2 THEN 'Monday, ' ELSE '' END + 
														CASE WHEN sch.freq_interval&4 = 4 THEN 'Tuesday, ' ELSE '' END + 
														CASE WHEN sch.freq_interval&8 = 8 THEN 'Wednesday, ' ELSE '' END +
														CASE WHEN sch.freq_interval&16 = 16 THEN 'Thursday, ' ELSE '' END + 
														CASE WHEN sch.freq_interval&32 = 32 THEN 'Friday, ' ELSE '' END + 
														CASE WHEN sch.freq_interval&64 = 64 THEN 'Saturday, ' ELSE '' END )
				END Interval,
			CASE	WHEN sch.freq_subday_type = 2 THEN 'Every ' + CAST(sch.freq_subday_interval AS VARCHAR(7))  + ' seconds' + ' starting at ' + STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(sch.active_start_time AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':') 
					WHEN sch.freq_subday_type = 4 THEN 'Every ' + CAST(sch.freq_subday_interval AS VARCHAR(7)) + ' minutes' + ' starting at '+ STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(sch.active_start_time AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':')
					WHEN sch.freq_subday_type = 8 THEN 'Every ' + CAST(sch.freq_subday_interval AS VARCHAR(7)) + ' hours'   + ' starting at '+ STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(sch.active_start_time AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':')
			 ELSE ' starting at ' + STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(sch.active_start_time AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':')
			END Timing

		FROM	msdb.dbo.sysjobs job INNER JOIN 
					msdb.dbo.sysjobsteps steps ON steps.job_id = job.job_id LEFT JOIN 
						msdb.dbo.sysjobschedules jsch ON jsch.job_id = job.job_id LEFT JOIN 
							msdb.dbo.sysschedules sch ON sch.schedule_id = jsch.schedule_id 
								OUTER APPLY (SELECT *, ROW_NUMBER() OVER(PARTITION BY a.job_id ORDER BY a.job_history_id DESC) rn
												FROM msdb.dbo.sysjobactivity a WHERE a.job_id = job.job_id
												) AS act
		WHERE	
				--steps.command LIKE N'%sp_x_SRM_ConfirmSanadZemanati_transfer%'  AND 
			act.rn=1
