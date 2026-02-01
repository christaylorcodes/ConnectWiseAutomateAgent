function Reset-CWAA {
    <#
    .SYNOPSIS
        Removes local agent identity settings to force re-registration.
    .DESCRIPTION
        Removes some of the agent's local settings: ID, MAC, and/or LocationID. The function
        stops the services, removes the specified registry values, then restarts the services.
        Resetting all three values forces the agent to check in as a new agent. If MAC filtering
        is enabled on the server, the agent should check back in with the same ID.

        This function is useful for resolving duplicate agent entries. If no switches are
        specified, all three values (ID, Location, MAC) are reset.

        Probe agents are protected from reset unless the -Force switch is used.
    .PARAMETER ID
        Resets the AgentID of the computer.
    .PARAMETER Location
        Resets the LocationID of the computer.
    .PARAMETER MAC
        Resets the MAC address of the computer.
    .PARAMETER Force
        Forces the reset operation on an agent detected as a probe.
    .PARAMETER NoWait
        Skips the post-reset health check that waits for the agent to re-register.
    .EXAMPLE
        Reset-CWAA
        Resets the ID, MAC, and LocationID on the agent, then waits for re-registration.
    .EXAMPLE
        Reset-CWAA -ID
        Resets only the AgentID of the agent.
    .EXAMPLE
        Reset-CWAA -Force -NoWait
        Resets all values on a probe agent without waiting for re-registration.
    .NOTES
        Author: Chris Taylor
        Alias: Reset-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Reset-LTService')]
    Param(
        [switch]$ID,
        [switch]$Location,
        [switch]$MAC,
        [switch]$Force,
        [switch]$NoWait
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"

        if (-not $PSBoundParameters.ContainsKey('ID') -and -not $PSBoundParameters.ContainsKey('Location') -and -not $PSBoundParameters.ContainsKey('MAC')) {
            $ID = $True
            $Location = $True
            $MAC = $True
        }

        $serviceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
        if ($serviceInfo -and ($serviceInfo | Select-Object -Expand Probe -EA 0) -eq '1') {
            if ($Force) {
                Write-Output 'Probe Agent Detected. Reset Forced.'
            }
            else {
                if ($WhatIfPreference -ne $True) {
                    Write-Error -Exception [System.OperationCanceledException]"Probe Agent Detected. Reset Denied." -ErrorAction Stop
                }
                else {
                    Write-Error -Exception [System.OperationCanceledException]"What If: Probe Agent Detected. Reset Denied." -ErrorAction Stop
                }
            }
        }
        Write-Output "OLD ID: $($serviceInfo | Select-Object -Expand ID -EA 0) LocationID: $($serviceInfo | Select-Object -Expand LocationID -EA 0) MAC: $($serviceInfo | Select-Object -Expand MAC -EA 0)"
    }

    Process {
        if (-not (Get-Service $Script:CWAAServiceNames -ErrorAction SilentlyContinue)) {
            if ($WhatIfPreference -ne $True) {
                Write-Error "Automate agent services NOT Found."
                return
            }
            else {
                Write-Error "What If: Stopping: Automate agent services NOT Found."
                return
            }
        }

        Try {
            if ($ID -or $Location -or $MAC) {
                Stop-CWAA
                if ($ID) {
                    Write-Output '.Removing ID'
                    Remove-ItemProperty -Name ID -Path $Script:CWAARegistryRoot -ErrorAction SilentlyContinue
                }
                if ($Location) {
                    Write-Output '.Removing LocationID'
                    Remove-ItemProperty -Name LocationID -Path $Script:CWAARegistryRoot -ErrorAction SilentlyContinue
                }
                if ($MAC) {
                    Write-Output '.Removing MAC'
                    Remove-ItemProperty -Name MAC -Path $Script:CWAARegistryRoot -ErrorAction SilentlyContinue
                }
                Start-CWAA
            }
        }
        Catch {
            Write-CWAAEventLog -EventId 3002 -EntryType Error -Message "Agent reset failed. Error: $($_.Exception.Message)"
            Write-Error "There was an error during the reset process. $_" -ErrorAction Stop
        }
    }

    End {
        if (-not $NoWait -and $PSCmdlet.ShouldProcess('LTService', 'Discover new settings after Service Start')) {
            $timeout = New-TimeSpan -Minutes 1
            $stopwatch = [Diagnostics.Stopwatch]::StartNew()
            $serviceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
            Write-Verbose 'Waiting for agent to register...'
            while (
                (-not ($serviceInfo | Select-Object -Expand ID -EA 0) -or
                 -not ($serviceInfo | Select-Object -Expand LocationID -EA 0) -or
                 -not ($serviceInfo | Select-Object -Expand MAC -EA 0)) -and
                $stopwatch.Elapsed -lt $timeout
            ) {
                Start-Sleep 2
                $serviceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
            }
            Write-Verbose 'Agent registration wait complete.'
            $serviceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
            Write-Output "NEW ID: $($serviceInfo | Select-Object -Expand ID -EA 0) LocationID: $($serviceInfo | Select-Object -Expand LocationID -EA 0) MAC: $($serviceInfo | Select-Object -Expand MAC -EA 0)"
            Write-CWAAEventLog -EventId 3000 -EntryType Information -Message "Agent reset successfully. New ID: $($serviceInfo | Select-Object -Expand ID -EA 0), LocationID: $($serviceInfo | Select-Object -Expand LocationID -EA 0)"
        }
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
