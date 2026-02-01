function Get-CWAAError {
    <#
    .SYNOPSIS
        Reads the ConnectWise Automate Agent error log into structured objects.
    .DESCRIPTION
        Parses the LTErrors.txt file from the agent install directory into objects with
        ServiceVersion, Timestamp, and Message properties. This enables filtering, sorting,
        and pipeline operations on agent error log entries.

        The log file location is determined from Get-CWAAInfo; if unavailable, falls back
        to the default install path at C:\Windows\LTSVC.
    .EXAMPLE
        Get-CWAAError | Where-Object {$_.Timestamp -gt (Get-Date).AddHours(-24)}
        Returns all agent errors from the last 24 hours.
    .EXAMPLE
        Get-CWAAError | Out-GridView
        Opens the error log in a sortable, searchable grid view window.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTErrors
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTErrors')]
    Param()

    Begin {
        $BasePath = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand BasePath -EA 0
        if (-not $BasePath) { $BasePath = $Script:CWAAInstallPath }
    }

    Process {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $logFilePath = "$BasePath\LTErrors.txt"

        if (-not (Test-Path -Path $logFilePath)) {
            Write-Error "Unable to find agent error log at '$logFilePath'."
            return
        }

        Try {
            $errors = Get-Content $logFilePath
            $errors = $errors -join ' ' -split '::: '

            foreach ($line in $errors) {
                $items = $line -split "`t" -replace ' - ', ''
                if ($items[1]) {
                    [PSCustomObject]@{
                        ServiceVersion = $items[0]
                        Timestamp      = $(Try { [datetime]::Parse($items[1]) } Catch { $null })
                        Message        = $items[2]
                    }
                }
            }
        }
        Catch {
            Write-Error "Failed to read agent error log at '$logFilePath'. Error: $($_.Exception.Message)"
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
