use msdbbkup_azg1lulsql01d
 
declare @jobnamestr varchar(max) ='%Support_lululemon_28435_LululemonPCR592912_ClearFutureOrgOpeningDates%'
 
DECLARE
    @JobName     NVARCHAR(256),
    @StepID      INT,
    @StepName    NVARCHAR(256),
    @Subsystem   NVARCHAR(40),
    @Command     NVARCHAR(MAX),
    @PrintChunk  NVARCHAR(4000),
    @Pos         INT,
    @ChunkSize   INT = 4000;
DECLARE job_cursor CURSOR FAST_FORWARD FOR
    SELECT
        j.name,
        js.step_id,
        js.step_name,
        js.subsystem,
        js.command
    FROM dbo.sysjobs        j
    INNER JOIN dbo.sysjobsteps js ON j.job_id = js.job_id
    -- *** Filter here as needed ***
     WHERE j.name LIKE @jobnamestr
    ORDER BY j.name, js.step_id;
OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @JobName, @StepID, @StepName, @Subsystem, @Command;
WHILE @@FETCH_STATUS = 0
BEGIN
    PRINT REPLICATE('=', 70);
    PRINT 'Job      : ' + @JobName;
    PRINT 'Step     : ' + CAST(@StepID AS VARCHAR) + ' - ' + @StepName;
    PRINT 'Subsystem: ' + @Subsystem;
    PRINT REPLICATE('-', 70);
    -- PRINT only handles 4000 chars at a time, so chunk it
    SET @Pos = 1;
    WHILE @Pos <= LEN(@Command)
    BEGIN
        SET @PrintChunk = SUBSTRING(@Command, @Pos, @ChunkSize);
        PRINT @PrintChunk;
        SET @Pos = @Pos + @ChunkSize;
    END
    PRINT '';  -- blank line between jobs
    FETCH NEXT FROM job_cursor INTO @JobName, @StepID, @StepName, @Subsystem, @Command;
END
CLOSE job_cursor;
DEALLOCATE job_cursor;