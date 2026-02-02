function Test-CWAAHealth {
    <#
    .SYNOPSIS
        Performs a read-only health assessment of the ConnectWise Automate agent.
    .DESCRIPTION
        Checks the overall health of the installed Automate agent without taking any
        remediation action. Returns a status object with details about the agent's
        installation state, service status, last check-in times, and server connectivity.

        This function never modifies the agent, services, or registry. It is safe to call
        at any time for monitoring or diagnostic purposes.

        Health assessment criteria:
        - Agent is installed (LTService exists)
        - Services are running (LTService and LTSvcMon)
        - Agent has checked in recently (LastSuccessStatus or HeartbeatLastSent within threshold)
        - Server is reachable (optional, tested when Server param is provided or auto-discovered)

        The Healthy property is True only when the agent is installed, services are running,
        and LastContact is not null.
    .PARAMETER Server
        An Automate server URL to validate against the installed agent's configured server.
        If provided, the ServerMatch property indicates whether the installed agent points
        to this server. If omitted, ServerMatch is null.
    .PARAMETER TestServerConnectivity
        When specified, tests whether the agent's server is reachable via the agent.aspx
        endpoint. Adds a brief network call. The ServerReachable property is null when
        this switch is not used.
    .EXAMPLE
        Test-CWAAHealth
        Returns a health status object for the installed agent.
    .EXAMPLE
        Test-CWAAHealth -Server 'https://automate.domain.com' -TestServerConnectivity
        Checks agent health, validates the server address matches, and tests server connectivity.
    .EXAMPLE
        if ((Test-CWAAHealth).Healthy) { Write-Output 'Agent is healthy' }
        Uses the Healthy boolean for conditional logic.
    .EXAMPLE
        Get-CWAAInfo | Test-CWAAHealth
        Pipes the installed agent's Server property into Test-CWAAHealth via pipeline.
    .NOTES
        Author: Chris Taylor
        Alias: Test-LTHealth
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Test-LTHealth')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$Server,

        [switch]$TestServerConnectivity
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        # Defaults — populated progressively as checks succeed
        $agentInstalled = $False
        $servicesRunning = $False
        $lastContact = $Null
        $lastHeartbeat = $Null
        $serverAddress = $Null
        $serverMatch = $Null
        $serverReachable = $Null
        $healthy = $False

        # Check if the agent service exists
        $ltService = Get-Service 'LTService' -ErrorAction SilentlyContinue
        if ($ltService) {
            $agentInstalled = $True

            # Check if both services are running
            $ltSvcMon = Get-Service 'LTSvcMon' -ErrorAction SilentlyContinue
            $servicesRunning = (
                $ltService.Status -eq 'Running' -and
                $ltSvcMon -and $ltSvcMon.Status -eq 'Running'
            )

            # Read agent configuration from registry
            $agentInfo = $Null
            Try {
                $agentInfo = Get-CWAAInfo -EA Stop -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
            }
            Catch {
                Write-Verbose "Unable to read agent info from registry: $($_.Exception.Message)"
            }

            if ($agentInfo) {
                # Extract server address
                $serverAddress = ($agentInfo | Select-Object -Expand 'Server' -EA 0) -join '|'

                # Parse last contact timestamp
                Try {
                    [datetime]$lastContact = $agentInfo.LastSuccessStatus
                }
                Catch {
                    Write-Verbose 'LastSuccessStatus not available or not a valid datetime.'
                }

                # Parse last heartbeat timestamp
                Try {
                    [datetime]$lastHeartbeat = $agentInfo.HeartbeatLastSent
                }
                Catch {
                    Write-Verbose 'HeartbeatLastSent not available or not a valid datetime.'
                }

                # If a Server was provided, check if any matches the installed configuration.
                # Server is string[] to handle Get-CWAAInfo pipeline output (which returns Server as an array).
                if ($Server) {
                    $installedServers = @($agentInfo | Select-Object -Expand 'Server' -EA 0)
                    $cleanProvided = @($Server | ForEach-Object { $_ -replace 'https?://', '' -replace '/$', '' })
                    $serverMatch = $False
                    foreach ($installedServer in $installedServers) {
                        $cleanInstalled = $installedServer -replace 'https?://', '' -replace '/$', ''
                        if ($cleanProvided -contains $cleanInstalled) {
                            $serverMatch = $True
                            break
                        }
                    }
                }

                # Optionally test server connectivity
                if ($TestServerConnectivity) {
                    $serversToTest = @($agentInfo | Select-Object -Expand 'Server' -EA 0)
                    if ($serversToTest) {
                        $serverReachable = Test-CWAAServerConnectivity -Server $serversToTest[0] -Quiet
                    }
                    else {
                        $serverReachable = $False
                    }
                }
            }

            # Overall health: installed, running, and has a recent contact timestamp
            $healthy = $agentInstalled -and $servicesRunning -and ($Null -ne $lastContact)
        }

        [PSCustomObject]@{
            AgentInstalled  = $agentInstalled
            ServicesRunning = $servicesRunning
            LastContact     = $lastContact
            LastHeartbeat   = $lastHeartbeat
            ServerAddress   = $serverAddress
            ServerMatch     = $serverMatch
            ServerReachable = $serverReachable
            Healthy         = $healthy
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
