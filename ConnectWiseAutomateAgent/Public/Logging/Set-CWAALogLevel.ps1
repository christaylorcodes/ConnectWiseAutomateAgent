function Set-CWAALogLevel {
    <#
    .SYNOPSIS
        Sets the logging level for the ConnectWise Automate Agent.
    .DESCRIPTION
        Configures the agent's logging verbosity by updating the registry and restarting the
        agent services. Supports Normal (standard) and Verbose (detailed diagnostic) levels.

        The function stops the agent service, writes the new logging level to the registry at
        HKLM:\SOFTWARE\LabTech\Service\Settings under the "Debuging" value, then restarts the
        agent service. After applying the change, it outputs the current logging level.
    .PARAMETER Level
        The desired logging level. Valid values are 'Normal' (default) and 'Verbose'.
        Normal sets registry value 1; Verbose sets registry value 1000.
    .EXAMPLE
        Set-CWAALogLevel -Level Verbose
        Enables verbose diagnostic logging on the agent.
    .EXAMPLE
        Set-CWAALogLevel -Level Normal
        Returns the agent to standard logging.
    .EXAMPLE
        Set-CWAALogLevel -Level Verbose -WhatIf
        Shows what changes would be made without applying them.
    .NOTES
        Author: Chris Taylor
        Alias: Set-LTLogging
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Set-LTLogging')]
    Param (
        [ValidateSet('Normal', 'Verbose')]
        $Level = 'Normal'
    )

    Process {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        Try {
            # "Debuging" is the vendor's original spelling in the registry -- not a typo in this code.
            $registryPath = "$Script:CWAARegistrySettings"
            $registryName = 'Debuging'

            if ($Level -eq 'Normal') {
                $registryValue = 1
            }
            else {
                $registryValue = 1000
            }

            if ($PSCmdlet.ShouldProcess("$registryPath\$registryName", "Set logging level to $Level (value: $registryValue)")) {
                Stop-CWAA
                Set-ItemProperty $registryPath -Name $registryName -Value $registryValue
                Start-CWAA
            }

            Get-CWAALogLevel
            Write-CWAAEventLog -EventId 3030 -EntryType Information -Message "Agent log level set to $Level."
        }
        Catch {
            Write-CWAAEventLog -EventId 3032 -EntryType Error -Message "Failed to set agent log level to '$Level'. Error: $($_.Exception.Message)"
            Write-Error "Failed to set logging level to '$Level'. Error: $($_.Exception.Message)" -ErrorAction Stop
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
