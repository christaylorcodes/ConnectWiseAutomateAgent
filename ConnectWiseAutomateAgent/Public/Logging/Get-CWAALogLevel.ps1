function Get-CWAALogLevel {
    <#
    .SYNOPSIS
        Retrieves the current logging level for the ConnectWise Automate Agent.
    .DESCRIPTION
        Checks the agent's registry settings to determine the current logging verbosity level.
        The ConnectWise Automate Agent supports two logging levels: Normal (value 1) for standard
        operations, and Verbose (value 1000) for detailed diagnostic logging.

        The logging level is stored in the registry at HKLM:\SOFTWARE\LabTech\Service\Settings
        under the "Debuging" value.
    .EXAMPLE
        Get-CWAALogLevel
        Returns the current logging level (Normal or Verbose).
    .EXAMPLE
        Get-CWAALogLevel
        Set-CWAALogLevel -Level Verbose
        Get-CWAALogLevel
        Typical troubleshooting workflow: check level, enable verbose, verify the change.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTLogging
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTLogging')]
    Param ()

    Process {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        Try {
            # "Debuging" is the vendor's original spelling in the registry -- not a typo in this code.
            $logLevel = Get-CWAASettings | Select-Object -Expand Debuging -EA 0

            if ($logLevel -eq 1000) {
                Write-Output 'Current logging level: Verbose'
            }
            elseif ($Null -eq $logLevel -or $logLevel -eq 1) {
                # Fresh installs may not have the Debuging value yet; treat as Normal
                Write-Output 'Current logging level: Normal'
            }
            else {
                Write-Error "Unknown logging level value '$logLevel' in registry."
            }
        }
        Catch {
            Write-Error "Failed to read logging level from registry. Error: $($_.Exception.Message)"
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
