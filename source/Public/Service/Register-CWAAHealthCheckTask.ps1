function Register-CWAAHealthCheckTask {
    <#
    .SYNOPSIS
        Creates or updates a scheduled task for periodic ConnectWise Automate agent health checks.
    .DESCRIPTION
        Creates a Windows scheduled task that runs Repair-CWAA at a configurable interval
        (default every 6 hours) to monitor agent health and automatically remediate issues.

        The task runs as SYSTEM with highest privileges, includes a random delay equal to the
        interval to stagger execution across multiple machines, and has a 1-hour execution timeout.

        If the task already exists and the InstallerToken has changed, the task is recreated
        with the new token. Use -Force to recreate unconditionally.

        A backup of the current agent configuration is created before task registration
        via New-CWAABackup.
    .PARAMETER InstallerToken
        The installer token for authenticated agent deployment. Embedded in the scheduled
        task action for use by Repair-CWAA.
    .PARAMETER Server
        Optional server URL. When provided, the scheduled task passes this to Repair-CWAA
        in Install mode (with Server, LocationID, and InstallerToken).
    .PARAMETER LocationID
        Optional location ID. Required when Server is provided.
    .PARAMETER TaskName
        Name of the scheduled task. Default: 'CWAAHealthCheck'.
    .PARAMETER IntervalHours
        Hours between health check runs. Default: 6.
    .PARAMETER Force
        Force recreation of the task even if it already exists with the same token.
    .EXAMPLE
        Register-CWAAHealthCheckTask -InstallerToken 'abc123def456'
        Creates a task that runs Repair-CWAA in Checkup mode every 6 hours.
    .EXAMPLE
        Register-CWAAHealthCheckTask -InstallerToken 'token' -Server 'https://automate.domain.com' -LocationID 42
        Creates a task that runs Repair-CWAA in Install mode (can install fresh if agent is missing).
    .EXAMPLE
        Register-CWAAHealthCheckTask -InstallerToken 'token' -IntervalHours 12 -TaskName 'MyHealthCheck'
        Creates a custom-named task running every 12 hours.
    .EXAMPLE
        Get-CWAAInfo | Register-CWAAHealthCheckTask -InstallerToken 'token'
        Uses Server and LocationID from the installed agent via pipeline to register a health check task.
    .NOTES
        Author: Chris Taylor
        Alias: Register-LTHealthCheckTask
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Register-LTHealthCheckTask')]
    Param(
        [Parameter(Mandatory = $True)]
        [ValidatePattern('(?s:^[0-9a-z]+$)')]
        [string]$InstallerToken,

        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidatePattern('^[a-zA-Z0-9\.\-\:\/]+$')]
        [string[]]$Server,

        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [int]$LocationID,

        [ValidatePattern('^[\w\-\. ]+$')]
        [string]$TaskName = 'CWAAHealthCheck',

        [ValidateRange(1, 168)]
        [int]$IntervalHours = 6,

        [switch]$Force
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        $created = $False
        $updated = $False

        # Check if the task already exists
        $existingTaskXml = $Null
        Try {
            [xml]$existingTaskXml = schtasks /QUERY /XML /TN $TaskName 2>$Null
        }
        Catch { Write-Debug "Task '$TaskName' not found or query failed: $($_.Exception.Message)" }

        # If the task exists and the token hasn't changed, skip recreation unless -Force
        if ($existingTaskXml -and -not $Force) {
            if ($existingTaskXml.Task.Actions.Exec.Arguments -match [regex]::Escape($InstallerToken)) {
                Write-Verbose "Scheduled task '$TaskName' already exists with the same InstallerToken. Use -Force to recreate."
                [PSCustomObject]@{
                    TaskName = $TaskName
                    Created  = $False
                    Updated  = $False
                }
                return
            }
            $updated = $True
        }

        if ($PSCmdlet.ShouldProcess("Scheduled Task '$TaskName'", 'Create health check task')) {
            # Back up agent settings before creating/updating the task
            Write-Verbose 'Backing up agent configuration.'
            New-CWAABackup -ErrorAction SilentlyContinue

            # Build the PowerShell command for the scheduled task action
            # Use Install mode if Server and LocationID are provided, otherwise Checkup mode
            if ($Server -and $LocationID) {
                # Build a proper PowerShell array literal for the Server argument.
                # Handles both single-server and multi-server arrays from Get-CWAAInfo pipeline.
                $serverArgument = ($Server | ForEach-Object { "'$_'" }) -join ','
                $repairCommand = "Import-Module ConnectWiseAutomateAgent; Repair-CWAA -Server $serverArgument -LocationID $LocationID -InstallerToken '$InstallerToken'"
            }
            else {
                $repairCommand = "Import-Module ConnectWiseAutomateAgent; Repair-CWAA -InstallerToken '$InstallerToken'"
            }

            # XML-escape special characters in the command for the task definition
            $escapedCommand = $repairCommand -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'

            # Delete existing task if present
            Try {
                $Null = schtasks /DELETE /TN $TaskName /F 2>&1
            }
            Catch { Write-Debug "Failed to delete existing task '$TaskName': $($_.Exception.Message)" }

            # Build the task XML definition
            # Runs as SYSTEM (S-1-5-18) with highest privileges
            # Repeats every $IntervalHours hours with randomized delay for staggering
            $intervalIso = "PT${IntervalHours}H"
            $startBoundary = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'

            [xml]$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
        <Description>ConnectWise Automate agent health check and automatic remediation.</Description>
        <URI>\$TaskName</URI>
    </RegistrationInfo>
    <Principals>
        <Principal id="Author">
            <UserId>S-1-5-18</UserId>
            <RunLevel>HighestAvailable</RunLevel>
        </Principal>
    </Principals>
    <Settings>
        <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
        <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
        <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
        <IdleSettings>
            <Duration>PT10M</Duration>
            <WaitTimeout>PT1H</WaitTimeout>
            <StopOnIdleEnd>false</StopOnIdleEnd>
            <RestartOnIdle>false</RestartOnIdle>
        </IdleSettings>
        <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    </Settings>
    <Triggers>
        <TimeTrigger>
            <StartBoundary>$startBoundary</StartBoundary>
            <Repetition>
                <Interval>$intervalIso</Interval>
                <Duration>P7300D</Duration>
                <StopAtDurationEnd>true</StopAtDurationEnd>
            </Repetition>
            <RandomDelay>$intervalIso</RandomDelay>
        </TimeTrigger>
    </Triggers>
    <Actions Context="Author">
        <Exec>
            <Command>C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe</Command>
            <Arguments>-NoProfile -WindowStyle Hidden -Command "$escapedCommand"</Arguments>
        </Exec>
    </Actions>
</Task>
"@

            $taskFilePath = "$env:TEMP\CWAAHealthCheckTask.xml"
            Try {
                $taskXml.Save($taskFilePath)

                $schtasksOutput = schtasks /CREATE /TN $TaskName /XML $taskFilePath /RU SYSTEM 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "schtasks returned exit code $LASTEXITCODE. Output: $schtasksOutput"
                }

                $created = -not $updated
                $resultMessage = if ($updated) { "Scheduled task '$TaskName' updated." } else { "Scheduled task '$TaskName' created." }
                Write-Output $resultMessage
                Write-CWAAEventLog -EventId 4020 -EntryType Information -Message "$resultMessage Interval: every $IntervalHours hours."
            }
            Catch {
                Write-Error "Failed to create scheduled task '$TaskName'. Error: $($_.Exception.Message)"
                Write-CWAAEventLog -EventId 4022 -EntryType Error -Message "Failed to create scheduled task '$TaskName'. Error: $($_.Exception.Message)"
            }
            Finally {
                # Clean up the temporary XML file
                Remove-Item -Path $taskFilePath -Force -ErrorAction SilentlyContinue
            }
        }

        [PSCustomObject]@{
            TaskName = $TaskName
            Created  = $created
            Updated  = $updated
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
