function Write-CWAAEventLog {
    <#
    .SYNOPSIS
        Writes an entry to the Windows Event Log for ConnectWise Automate Agent operations.
    .DESCRIPTION
        Centralized event log writer for the ConnectWiseAutomateAgent module. Writes to the
        Application event log under the source defined by $Script:CWAAEventLogSource.

        On first call, registers the event source if it does not already exist (requires
        administrator privileges for registration). If the source cannot be registered or
        the write fails for any reason, the error is written to Write-Debug and the function
        returns silently. This ensures event logging never disrupts the calling function.

        Event ID ranges by category:
          1000-1039  Installation (Install, Uninstall, Redo, Update)
          2000-2029  Service Control (Start, Stop, Restart)
          3000-3069  Configuration (Reset, Backup, Proxy, LogLevel, AddRemove)
          4000-4039  Health/Monitoring (Repair, Register/Unregister task)
    .NOTES
        Version: 0.1.5.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$Message,

        [Parameter(Mandatory = $True)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$EntryType,

        [Parameter(Mandatory = $True)]
        [int]$EventId
    )

    Try {
        # Register the event source if it does not exist yet.
        # This requires administrator privileges the first time.
        if (-not [System.Diagnostics.EventLog]::SourceExists($Script:CWAAEventLogSource)) {
            New-EventLog -LogName $Script:CWAAEventLogName -Source $Script:CWAAEventLogSource -ErrorAction Stop
            Write-Debug "Write-CWAAEventLog: Registered event source '$($Script:CWAAEventLogSource)' in '$($Script:CWAAEventLogName)' log."
        }

        Write-EventLog -LogName $Script:CWAAEventLogName `
            -Source $Script:CWAAEventLogSource `
            -EventId $EventId `
            -EntryType $EntryType `
            -Message $Message `
            -ErrorAction Stop

        Write-Debug "Write-CWAAEventLog: Wrote EventId $EventId ($EntryType) to '$($Script:CWAAEventLogName)' log."
    }
    Catch {
        # Best-effort: never disrupt the calling function if event logging fails.
        Write-Debug "Write-CWAAEventLog: Failed to write event log entry. Error: $($_.Exception.Message)"
    }
}
