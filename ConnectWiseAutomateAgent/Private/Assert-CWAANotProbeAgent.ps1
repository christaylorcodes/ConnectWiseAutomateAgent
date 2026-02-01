function Assert-CWAANotProbeAgent {
    <#
    .SYNOPSIS
        Blocks operations on probe agents unless -Force is specified.
    .DESCRIPTION
        Checks the agent info object to determine if the current machine is a probe agent.
        If it is and -Force is not set, writes a terminating error to prevent accidental
        removal of critical infrastructure. If -Force is set, writes a warning message and
        allows continuation.

        The ActionName parameter produces contextual messages like
        "Probe Agent Detected. UnInstall Denied." or "Probe Agent Detected. Reset Forced."

        This consolidates the duplicated probe agent protection check found in
        Uninstall-CWAA, Redo-CWAA, and Reset-CWAA.
    .PARAMETER ServiceInfo
        The agent info object from Get-CWAAInfo. If null or missing the Probe property,
        the check is skipped silently.
    .PARAMETER ActionName
        The name of the operation for error/output messages. Used directly in the message
        string, e.g., 'UnInstall', 'Re-Install', 'Reset'.
    .PARAMETER Force
        When set, allows the operation to proceed on a probe agent with an output message
        instead of a terminating error.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    Param(
        [Parameter()]
        [AllowNull()]
        $ServiceInfo,

        [Parameter(Mandatory = $True)]
        [string]$ActionName,

        [switch]$Force
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        if ($ServiceInfo -and ($ServiceInfo | Select-Object -Expand Probe -EA 0) -eq '1') {
            if ($Force) {
                Write-Output "Probe Agent Detected. $ActionName Forced."
            }
            else {
                if ($WhatIfPreference -ne $True) {
                    Write-Error -Exception ([System.OperationCanceledException]"Probe Agent Detected. $ActionName Denied.") -ErrorAction Stop
                }
                else {
                    Write-Error -Exception ([System.OperationCanceledException]"What If: Probe Agent Detected. $ActionName Denied.") -ErrorAction Stop
                }
            }
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
