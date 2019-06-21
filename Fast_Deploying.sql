USE [TSQL2012]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

EXEC sp_configure 'show advanced options', 1
GO

RECONFIGURE
GO

EXEC sp_configure 'xp_cmdshell', 1
GO

RECONFIGURE
GO

CREATE TABLE [dbo].[PostProcessTestResults](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RunID] [int] NULL,
	[DB] [varchar](100) NULL,
	[DataSetname] [varchar](100) NULL,
	[QueryName] [varchar](255) NOT NULL,
	[Status] [varchar](255) NULL,
	[MissMatchCount] [bigint] NULL,
	[ExecutionTimeLength] [int] NULL,
	[RunTime] [datetime] NULL,
	[User] [varchar](255) NULL,
	[ErrorMessage] [varchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[PostProcessTestResults] ADD  DEFAULT ('Failed') FOR [Status]
GO

ALTER TABLE [dbo].[PostProcessTestResults] ADD  DEFAULT (getdate()) FOR [RunTime]
GO

ALTER TABLE [dbo].[PostProcessTestResults] ADD  DEFAULT (suser_sname()) FOR [User]
GO

CREATE TABLE [dbo].[PostProcess](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[DataSetName] [varchar](50) NULL,
	[QueryName] [varchar](150) NULL,
	[Query] [varchar](max) NULL,
	[UpdateDate] [datetime] NULL,
	[Username] [varchar](100) NULL,
 CONSTRAINT [pk_postprocess_ID] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[PostProcess] ADD  DEFAULT (getdate()) FOR [UpdateDate]
GO

ALTER TABLE [dbo].[PostProcess] ADD  DEFAULT (suser_name()) FOR [Username]
GO

CREATE proc [dbo].[spr_SendEmailResults]
@runID int,
@environment varchar(max)
AS
declare @xml2 varchar(max)
declare @xml varchar(max)
declare @body nvarchar(max)
declare @resultbody nvarchar(max)
declare @status varchar(100)
declare @subject varchar(max)
--declare @environment varchar(max) = ''
if 
	exists (select * from PostProcessTestResults where runid = @runiD and QueryName not like '%keepcurrent%' and status in ('Failed', 'Error'))
	or
	(select count(distinct status) from PostProcessTestResults where runid = @runiD and QueryName like '%keepcurrent%') > 1
begin
	set @status = 'FAILED'
end
else
begin
	set @status = 'SUCCESS'
end


set @xml = ''
  select @xml = @xml + '<tr>' +
   concat(
   '<td bgcolor="#FFFFFF">', ID     , '</td>' ,
   '<td bgcolor="#FFFFFF">', DB     , '</td>' ,
   '<td bgcolor="#FFFFFF">', DataSetName   , '</td>' ,
   '<td bgcolor="#FFFFFF">', QueryName    , '</td>' ,
   case [Status]
    when 'Passed' then '<td style="color:rgb(0, 150, 0);" bgcolor="#FFFFFF">Passed</td>'
    when 'Failed' then '<td style="color:rgb(176, 6, 6);" bgcolor="#FFFFFF">Failed</td>'
    when 'Error'  then '<td style="color:rgb(0, 0, 0);" bgcolor="#FFFFFF">Error</td>'
   end,
   '<td bgcolor="#FFFFFF">', MissMatchCount  , '</td>' ,
   '<td bgcolor="#FFFFFF">', ExecutionTimeLength , '</td>' ,
   '<td bgcolor="#FFFFFF">', RunTime    , '</td>' ,
   '<td bgcolor="#FFFFFF">', [User]    , '</td></tr>')
  from
   PostProcessTestResults
   where runid = @runiD
   and QueryName not like '%notkeepcurrent%'
  order
   by ID 

set @xml2 = ''
  select @xml2 = @xml2 + '<tr>' +
   concat(
   '<td bgcolor="#FFFFFF">', ID     , '</td>' ,
   '<td bgcolor="#FFFFFF">', DB     , '</td>' ,
   '<td bgcolor="#FFFFFF">', DataSetName   , '</td>' ,
   '<td bgcolor="#FFFFFF">', QueryName    , '</td>' ,
   case [Status]
    when 'Passed' then '<td style="color:rgb(0, 150, 0);" bgcolor="#FFFFFF">Passed</td>'
    when 'Failed' then '<td style="color:rgb(176, 6, 6);" bgcolor="#FFFFFF">Failed</td>'
    when 'Error'  then '<td style="color:rgb(0, 0, 0);" bgcolor="#FFFFFF">Error</td>'
   end,
   '<td bgcolor="#FFFFFF">', MissMatchCount  , '</td>' ,
   '<td bgcolor="#FFFFFF">', ExecutionTimeLength , '</td>' ,
   '<td bgcolor="#FFFFFF">', RunTime    , '</td>' ,
   '<td bgcolor="#FFFFFF">', [User]    , '</td></tr>')
  from
   PostProcessTestResults
   where runid = @runiD and QueryName like '%notkeepcurrent%'
  order
   by ID 

set @body = '
   <table style="border: 1px solid rgb(136, 136, 136); margin: 10px;" bgcolor="#DDDDDD" border="0" cellpadding="4" cellspacing="0" >
      <tbody>
        <tr>
          <td style="font: bold 11px Arial;">
            <span style="display:inline-block;cursor:pointer;background-color:#eeeeee;border: 1px solid #888888;height:14px;width:14px;text-align:center" onclick="var el=this.parentNode.parentNode.parentNode.rows[1]; el.style.display=el.style.display==''none''?'''':''none'';this.innerHTML=this.innerHTML==''+''?''-'':''+'';">&#160;-&#160;</span>
     Post Processing Test Results For "Keep Current" Logic
          </td>
        </tr>
        <tr>
          <td style="font: xx-small Verdana,Arial; padding: 7px;" bgcolor="#EFEFFF">
            <table bgcolor="#999999" border="0" cellpadding="0" cellspacing="0">
              <tbody>
                <tr>
                  <td>
                    <table style="font: 11px verdana;" border="0" cellpadding="2" cellspacing="1">
                      <tbody>
                        <tr>
                          <td bgcolor="#B9CCDF">ID</td>
                          <td bgcolor="#B9CCDF">DB</td>
                          <td bgcolor="#B9CCDF">DataSetName</td>
                          <td bgcolor="#B9CCDF">QueryName</td>
                          <td bgcolor="#B9CCDF">Status</td>
                          <td bgcolor="#B9CCDF">MissMatchCount</td>
                          <td bgcolor="#B9CCDF">ExecutionTime</td>
        <td bgcolor="#B9CCDF">RunTime</td>
        <td bgcolor="#B9CCDF">User</td>
                        </tr>
'

set @body = @body + @xml +'
                      </tbody>
                    </table>
                  </td>
                </tr>
              </tbody>
            </table>
          </td>
        </tr>
      </tbody>
    </table>
'

set @resultbody = @body 

set @subject = 'DB: ' +@environment+'. ' + 'PostProcessing Tests Completed With Status: ' + @Status

exec msdb.dbo.sp_send_dbmail  @recipients = '', @copy_recipients = '', @blind_copy_recipients='', @subject = @subject, @body = @resultbody , @body_format = 'HTML'
GO

CREATE proc [dbo].[spr_postProcessing]
@db varchar (max),
@ScriptSourceFolder varchar (max)
 
 as 
set nocount on

set ANSI_WARNINGS ON

--declare @ScriptSourceFolder varchar(255) = ('Script_Folder');
declare @ScriptName varchar(255)

declare @cmd varchar(8000)
declare @filepath varchar(max)
declare @fileName varchar(max)
declare @sql nvarchar(max)
declare @tempquery varchar(max)
declare @print varchar(max)
declare @fileRunStartTime datetime
declare @xml xml
declare @XMLfolder varchar(50)
declare @i int = 0
declare @ErrorMessage	nvarchar(max)=''
declare	@ErrorNumber	int=0

declare @env varchar(max)

--Generating @RUNID
declare @RUNID int
select @RUNID = isnull(max(runid), 0) + 1 from dbo.PostProcessTestResults


		declare @sqldir varchar(max) = @ScriptSourceFolder
		set @cmd = 'dir /b /s ' + @sqldir + '\*.sql |findstr /v "Archive"'

	--Creating temp table for moving query names
	if object_id('tempdb..#t') is not null drop table #t
	create table #t (queryname varchar(max) null)

	--inserting names into #t temp table
	insert into #t
	exec xp_cmdshell @cmd
	delete #t where queryname is NULL

	if @ScriptName <> ''
	BEGIN	 
		 delete #t where queryname <> REPLACE(@sqldir, '"','') + '\'+ @ScriptName +'.sql'
	END;
	
	--truncating table
	truncate table dbo.PostProcess

	--create temp table for xml processing(Getting DataSet name)
	if OBJECT_ID('tempdb..#xml') is not null
	begin
		drop table #xml
	end

	create table #xml(
	id int identity(1,1),
	folder varchar(50)
	)


	--inserting data from 
	while exists(select * from #t)
	begin
		 set @fileName = (select top 1 QueryName from #t)
		 set @filepath = @fileName


		 set @xml = cast('<x>' + replace(@fileName, '\', '</x><x>') + '</x>' as xml)
		 insert into #xml (folder)
		 select T.c.value('.', 'nvarchar(50)') as folder
		 from @xml.nodes('x') T(c)
		 set @XMLfolder = (select folder from #xml where id = (select max(id) -1 from #xml))


		 set @sql = '
		 select
		  @tempquery = f.BulkColumn
		 from openrowset
		 (
		  bulk ''' + @filepath + ''',
		  single_clob 
		 ) f
		 '
		exec sp_executesql @query = @sql, @params = N'@tempquery varchar(max) output', @tempquery = @tempquery output

		insert into dbo.PostProcess(Datasetname, QueryName, Query)
		values (@XMLfolder, right(@filename, charindex('\', REVERSE(@filename))-1), @tempquery )

		 delete #t where QueryName = @fileName
		 truncate table #xml
	end

	if object_id('tempdb..#rowcount') is not null   drop table #rowcount 
	create table #rowcount (rowcnt int)


	--enter into cycle
	declare @cursorQuery varchar(max)
	declare @cursorQueryname varchar(max)
	declare @cursorDataSetname varchar(max)

	if object_id('tempdb.dbo.#PostProcess') is not null
	delete #PostProcess

	select id, query, queryname, DataSetName
	into #PostProcess
	from dbo.PostProcess

	while exists (select * from #PostProcess)
	BEGIN
		select top 1 @cursorQuery = query, @cursorQueryName = queryname, @cursorDatasetname = DataSetName from #PostProcess
		order by id

		set @fileRunStartTime = getdate()
		--declare variable and assgning value to @sql
	
		set @sql = 'use ' + @db + '; set ANSI_WARNINGS OFF; ' + @cursorQuery
		truncate table #rowcount
		begin try
			insert into #rowcount
			exec sp_executesql @sql

			set @ErrorMessage = 'Success'
		end try
		begin catch
			declare 
				@ErrorMsg    nvarchar(4000),
				@ErrorSeverity   int,
				@ErrorState      int,
				@ErrorLine       int,
				@ErrorProcedure  nvarchar(200)

			-- Assign variables to error-handling functions that 
			select 
				@ErrorNumber = ERROR_NUMBER(),
				@ErrorSeverity = ERROR_SEVERITY(),
				@ErrorState = ERROR_STATE(),
				@ErrorLine = ERROR_LINE(),
				@ErrorProcedure = isnull(ERROR_PROCEDURE(), '-'),
				@ErrorMsg=error_message()

			set @ErrorMessage = concat('Error Message: ', @ErrorMsg, 'Error Line: ', @Errorline)
		
			insert into #rowcount 
			select -1
		end catch

		insert into dbo.PostProcessTestResults(RUNID, DB, DataSetname, QueryName, [Status], MissMatchCount, ExecutionTimeLength, ErrorMessage)
		select
			@RUNID as RunID,
			@DB as DB,
			@cursorDatasetname as Datasetname,
			@cursorQueryName as Queryname,
			(case rowcnt when 0 then 'Passed' when -1 then 'Error' else 'Failed' end) as Status,
			rowcnt as MissMatchCount,
			datediff(minute, @fileRunStartTime, getdate()) as ExecutionTimeLength,
			@ErrorMessage as ErrorMessage
		
		from #rowcount

		set @i = @i+1
		select @print = concat(cast(@i as char(4)), ' ', cast((@cursorDatasetname)as char(25)), ' ', cast (@cursorQueryName as char(50)), ': ' , case rowcnt when 0 then 'Passed' when -1 then cast('Error'as char(6)) else 'Failed' end, ': ' , cast (rowcnt as char(10)), ': minutes run - ', datediff(minute, @fileRunStartTime, getdate()))
		from #rowcount

		print @print

		delete #PostProcess where @cursorDataSetname = DataSetName and @cursorQueryName = queryname
	END

exec dbo.spr_SendEmailResults @RunID, @db;


GO

USE [msdb]
GO


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Automated_Testing', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'XEPUALVIW0027\Valentyn', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Verification]    Script Date: 6/21/2019 10:53:51 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Verification', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec dbo.spr_postprocessing ''TSQL2012'',''D:\Scripts_Folder''', 
		@database_name=N'TSQL2012', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
