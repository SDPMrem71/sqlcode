-- =============================================
-- Author:		mrh
-- Create date: 1399/05/12
-- ModifiedBy:
-- ModifiedOn:
-- Description: نمایش تمای جاب ها به همراه اطلاعات آخرین اجرا و زمانبندی تعریف شده
-- =============================================
ALTER VIEW dbo.JobsInfo AS

SELECT	/*info*/
		steps.subsystem, lastactivity.session_id, job.name AS JobName, steps.step_name,
		job.enabled AS JobEnabled, sch.enabled AS ScheduleEnabled,
		steps.last_run_outcome AS StepLastRunOutcome, lastactivity.last_executed_step_id AS JobLastStepExecuted,
		CASE steps.last_run_outcome WHEN 0 THEN 'Failed'	WHEN 1 THEN 'Succeeded'		WHEN 2 THEN 'Retry'	
									WHEN 3 THEN 'Canceled'	WHEN 4 THEN 'In Progress'	WHEN 5 THEN'UnknownEND' ELSE NULL END
		AS StepLastRunOutcomeName,
		/*Execution Times*/
		STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + CAST( steps.last_run_duration AS VARCHAR(8)), 8), 3, 0, ':'), 6, 0, ':'), 9, 0, ':') AS last_run_duration,
		CONVERT(DATETIME,CONCAT(LEFT(steps.last_run_date, 04),'/',SUBSTRING( CAST(steps.last_run_date AS CHAR(10)), 5, 2 ),'/',RIGHT(steps.last_run_date, 2),' ',
							STUFF( STUFF( RIGHT(REPLICATE( '0', 6 ) + CAST(steps.last_run_time AS VARCHAR(6)), 6), 3, 0, ':' ), 6, 0, ':' ))) 
		AS Step_StartDate, lastactivity.start_execution_date AS Job_start_execution_date, 
		lastactivity.stop_execution_date AS Job_stop_execution_date, lastactivity.next_scheduled_run_date,
		/*Schedule info*/
		CASE	WHEN sch.freq_type = 4 THEN 'Daily' WHEN sch.freq_type = 8 THEN 'Weekly' WHEN sch.freq_type IN ('16','32') THEN 'Monthly' END frequency,
		CASE	WHEN sch.freq_type = 4 THEN 'every ' + CAST (sch.freq_interval AS VARCHAR(3)) + ' day(s)' 
				WHEN sch.freq_type = 8 THEN (	CASE WHEN sch.freq_interval&64 = 64 THEN 'Saturday, ' ELSE '' END +
												CASE WHEN sch.freq_interval&1 = 1 THEN 'Sunday, ' ELSE '' END +
												CASE WHEN sch.freq_interval&2 = 2 THEN 'Monday, ' ELSE '' END + 
												CASE WHEN sch.freq_interval&4 = 4 THEN 'Tuesday, ' ELSE '' END + 
												CASE WHEN sch.freq_interval&8 = 8 THEN 'Wednesday, ' ELSE '' END +
												CASE WHEN sch.freq_interval&16 = 16 THEN 'Thursday, ' ELSE '' END + 
												CASE WHEN sch.freq_interval&32 = 32 THEN 'Friday, ' ELSE '' END)
		END Interval,
		CASE	WHEN sch.freq_subday_type = 2 THEN 'Every ' + CAST(sch.freq_subday_interval AS VARCHAR(7))  + ' seconds' + ' starting at ' + STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(sch.active_start_time AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':') 
				WHEN sch.freq_subday_type = 4 THEN 'Every ' + CAST(sch.freq_subday_interval AS VARCHAR(7)) + ' minutes' + ' starting at '+ STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(sch.active_start_time AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':')
				WHEN sch.freq_subday_type = 8 THEN 'Every ' + CAST(sch.freq_subday_interval AS VARCHAR(7)) + ' hours'   + ' starting at '+ STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(sch.active_start_time AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':')
			ELSE ' starting at ' + STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(sch.active_start_time AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':')
		END Timing,
		job.job_id, steps.step_id

FROM	msdb.dbo.sysjobs job INNER JOIN 
			msdb.dbo.sysjobsteps steps ON steps.job_id = job.job_id LEFT JOIN 
				msdb.dbo.sysjobschedules jsch ON jsch.job_id = job.job_id LEFT JOIN 
					msdb.dbo.sysschedules sch ON sch.schedule_id = jsch.schedule_id 
						OUTER APPLY (SELECT *, ROW_NUMBER() OVER(PARTITION BY a.job_id ORDER BY a.run_requested_date DESC) rn
										FROM msdb.dbo.sysjobactivity a WHERE a.job_id = job.job_id
										) AS lastactivity
WHERE	lastactivity.rn=1 --آخرین اجرای، تمامی جاب های تعریف شده

GO
