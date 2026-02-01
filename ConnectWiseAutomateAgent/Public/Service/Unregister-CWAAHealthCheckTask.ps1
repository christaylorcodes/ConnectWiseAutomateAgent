function Unregister-CWAAHealthCheckTask {
    <#
    .SYNOPSIS
        Removes the ConnectWise Automate agent health check scheduled task.
    .DESCRIPTION
        Deletes the Windows scheduled task created by Register-CWAAHealthCheckTask.
        If the task does not exist, writes a warning and returns gracefully.
    .PARAMETER TaskName
        Name of the scheduled task to remove. Default: 'CWAAHealthCheck'.
    .EXAMPLE
        Unregister-CWAAHealthCheckTask
        Removes the default CWAAHealthCheck scheduled task.
    .EXAMPLE
        Unregister-CWAAHealthCheckTask -TaskName 'MyHealthCheck'
        Removes a custom-named health check task.
    .NOTES
        Author: Chris Taylor
        Alias: Unregister-LTHealthCheckTask
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Unregister-LTHealthCheckTask')]
    Param(
        [string]$TaskName = 'CWAAHealthCheck'
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        $removed = $False

        # Check if the task exists
        $taskExists = $False
        Try {
            $Null = schtasks /QUERY /TN $TaskName 2>$Null
            if ($LASTEXITCODE -eq 0) {
                $taskExists = $True
            }
        }
        Catch { Write-Debug "Task '$TaskName' query failed: $($_.Exception.Message)" }

        if (-not $taskExists) {
            Write-Warning "Scheduled task '$TaskName' does not exist."
            [PSCustomObject]@{
                TaskName = $TaskName
                Removed  = $False
            }
            return
        }

        if ($PSCmdlet.ShouldProcess("Scheduled Task '$TaskName'", 'Remove health check task')) {
            Try {
                $schtasksOutput = schtasks /DELETE /TN $TaskName /F 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "schtasks returned exit code $LASTEXITCODE. Output: $schtasksOutput"
                }
                $removed = $True
                Write-Output "Scheduled task '$TaskName' has been removed."
                Write-CWAAEventLog -EventId 4030 -EntryType Information -Message "Scheduled task '$TaskName' removed."
            }
            Catch {
                Write-Error "Failed to remove scheduled task '$TaskName'. Error: $($_.Exception.Message)"
                Write-CWAAEventLog -EventId 4032 -EntryType Error -Message "Failed to remove scheduled task '$TaskName'. Error: $($_.Exception.Message)"
            }
        }

        [PSCustomObject]@{
            TaskName = $TaskName
            Removed  = $removed
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
