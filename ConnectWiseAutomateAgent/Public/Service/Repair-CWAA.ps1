function Repair-CWAA {
    <#
    .SYNOPSIS
        Performs escalating remediation of the ConnectWise Automate agent.
    .DESCRIPTION
        Checks the health of the installed Automate agent and takes corrective action
        using an escalating strategy:

        1. If the agent is installed and healthy — no action taken.
        2. If the agent is installed but has not checked in within HoursRestart — restarts
           services and waits up to 2 minutes for the agent to recover.
        3. If the agent is still not checking in after HoursReinstall — reinstalls the agent
           using Redo-CWAA.
        4. If the agent configuration is unreadable — uninstalls and reinstalls.
        5. If the installed agent points to the wrong server — reinstalls with the correct server.
        6. If the agent is not installed — performs a fresh install from provided parameters
           or from backup settings.

        All remediation actions are logged to the Windows Event Log (Application log,
        source ConnectWiseAutomateAgent) for visibility in unattended scheduled task runs.

        Designed to be called periodically via Register-CWAAHealthCheckTask or any
        external scheduler.
    .PARAMETER Server
        The ConnectWise Automate server URL for fresh installs or server mismatch correction.
        Required when using the Install parameter set.
    .PARAMETER LocationID
        The LocationID for fresh agent installs. Required with the Install parameter set.
    .PARAMETER InstallerToken
        An installer token for authenticated agent deployment. Required for both parameter sets.
    .PARAMETER HoursRestart
        Hours since last check-in before a service restart is attempted. Expressed as a
        negative number (e.g., -2 means 2 hours ago). Default: -2.
    .PARAMETER HoursReinstall
        Hours since last check-in before a full reinstall is attempted. Expressed as a
        negative number (e.g., -120 means 120 hours / 5 days ago). Default: -120.
    .EXAMPLE
        Repair-CWAA -InstallerToken 'abc123def456'
        Checks the installed agent and repairs if needed (Checkup mode).
    .EXAMPLE
        Repair-CWAA -Server 'https://automate.domain.com' -LocationID 42 -InstallerToken 'token'
        Checks agent health. If the agent is missing or pointed at the wrong server,
        installs or reinstalls with the specified settings.
    .EXAMPLE
        Repair-CWAA -InstallerToken 'token' -HoursRestart -4 -HoursReinstall -240
        Uses custom thresholds: restart after 4 hours offline, reinstall after 10 days.
    .NOTES
        Author: Chris Taylor
        Alias: Repair-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Repair-LTService')]
    Param(
        [Parameter(ParameterSetName = 'Install', Mandatory = $True)]
        [ValidateScript({
            if ($_ -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$') { $true }
            else { throw "Server address '$_' is not valid. Expected format: https://automate.domain.com" }
        })]
        [string]$Server,

        [Parameter(ParameterSetName = 'Install', Mandatory = $True)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$LocationID,

        [Parameter(ParameterSetName = 'Install', Mandatory = $True)]
        [Parameter(ParameterSetName = 'Checkup', Mandatory = $True)]
        [ValidatePattern('(?s:^[0-9a-z]+$)')]
        [string]$InstallerToken,

        [int]$HoursRestart = -2,

        [int]$HoursReinstall = -120
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"

        # Kill duplicate Repair-CWAA processes to prevent overlapping remediation
        # Uses CIM for reliable command-line matching (Get-Process cannot filter by arguments)
        if ($PSCmdlet.ShouldProcess('Duplicate Repair-CWAA processes', 'Terminate')) {
            Try {
                Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
                    $_.Name -eq 'powershell.exe' -and
                    $_.CommandLine -match 'Repair-CWAA' -and
                    $_.ProcessId -ne $PID
                } | ForEach-Object {
                    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                }
            }
            Catch {
                Write-Debug "Unable to check for duplicate processes: $($_.Exception.Message)"
            }
        }
    }

    Process {
        $actionTaken = 'None'
        $success = $True
        $resultMessage = ''

        # Determine if the agent service is installed
        $agentServiceExists = [bool](Get-Service 'LTService' -ErrorAction SilentlyContinue)

        if ($agentServiceExists) {
            #region Agent is installed — check health and remediate

            # Verify we can read agent configuration
            $agentInfo = $Null
            Try {
                $agentInfo = Get-CWAAInfo -EA Stop -Verbose:$False -WhatIf:$False -Confirm:$False
            }
            Catch {
                # Agent config is unreadable — uninstall so we can reinstall cleanly
                Write-Warning "Unable to read agent configuration. Uninstalling for clean reinstall."
                Write-CWAAEventLog -EventId 4009 -EntryType Warning -Message "Agent configuration unreadable. Uninstalling for clean reinstall. Error: $($_.Exception.Message)"

                $backupSettings = Get-CWAAInfoBackup -EA 0
                Try {
                    Get-Process 'Agent_Uninstall' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                    if ($PSCmdlet.ShouldProcess('LTService', 'Uninstall agent with unreadable config')) {
                        Uninstall-CWAA -Force -Server ($backupSettings.Server[0])
                    }
                }
                Catch {
                    Write-Error "Failed to uninstall agent with unreadable config. Error: $($_.Exception.Message)"
                    Write-CWAAEventLog -EventId 4009 -EntryType Error -Message "Failed to uninstall agent with unreadable config. Error: $($_.Exception.Message)"
                }
                $resultMessage = 'Uninstalled agent with unreadable config. Restart machine and run again.'
                $actionTaken = 'Uninstall'
                $success = $False

                [PSCustomObject]@{
                    ActionTaken = $actionTaken
                    Success     = $success
                    Message     = $resultMessage
                }
                return
            }

            # If Server parameter was provided, check that it matches the installed agent
            if ($Server) {
                $currentServers = ($agentInfo | Select-Object -Expand 'Server' -EA 0)
                $cleanExpectedServer = $Server -replace 'https?://', '' -replace '/$', ''
                $serverMatches = $False
                foreach ($currentServer in $currentServers) {
                    $cleanCurrent = $currentServer -replace 'https?://', '' -replace '/$', ''
                    if ($cleanCurrent -eq $cleanExpectedServer) {
                        $serverMatches = $True
                        break
                    }
                }

                if (-not $serverMatches) {
                    Write-Warning "Wrong install server ($($currentServers -join ', ')). Expected '$Server'. Reinstalling."
                    Write-CWAAEventLog -EventId 4004 -EntryType Warning -Message "Server mismatch detected. Installed: $($currentServers -join ', '). Expected: $Server. Reinstalling."

                    if ($PSCmdlet.ShouldProcess('LTService', "Reinstall agent for server mismatch (current: $($currentServers -join ', '), expected: $Server)")) {
                        Clear-CWAAInstallerArtifacts
                        Try {
                            Redo-CWAA -Server $Server -LocationID $LocationID -InstallerToken $InstallerToken
                            $actionTaken = 'Reinstall'
                            $resultMessage = "Reinstalled agent to correct server: $Server"
                            Write-CWAAEventLog -EventId 4004 -EntryType Information -Message $resultMessage
                        }
                        Catch {
                            $actionTaken = 'Reinstall'
                            $success = $False
                            $resultMessage = "Failed to reinstall agent for server mismatch. Error: $($_.Exception.Message)"
                            Write-Error $resultMessage
                            Write-CWAAEventLog -EventId 4009 -EntryType Error -Message $resultMessage
                        }
                    }

                    [PSCustomObject]@{
                        ActionTaken = $actionTaken
                        Success     = $success
                        Message     = $resultMessage
                    }
                    return
                }
            }

            # Get last contact timestamp (try LastSuccessStatus, fall back to HeartbeatLastReceived)
            $lastContact = $Null
            Try {
                [datetime]$lastContact = $agentInfo.LastSuccessStatus
            }
            Catch {
                Try {
                    [datetime]$lastContact = $agentInfo.HeartbeatLastReceived
                }
                Catch {
                    # No valid contact timestamp — treat as very old
                    [datetime]$lastContact = (Get-Date).AddYears(-1)
                }
            }

            # Get last heartbeat timestamp
            $lastHeartbeat = $Null
            Try {
                [datetime]$lastHeartbeat = $agentInfo.HeartbeatLastSent
            }
            Catch {
                [datetime]$lastHeartbeat = (Get-Date).AddYears(-1)
            }

            Write-Verbose "Last check-in: $lastContact"
            Write-Verbose "Last heartbeat: $lastHeartbeat"

            # Determine the server address for connectivity checks
            $activeServer = $Null
            if ($Server) {
                $activeServer = $Server
            }
            else {
                Try { $activeServer = ($agentInfo | Select-Object -Expand 'Server' -EA 0)[0] }
                Catch {
                    Try { $activeServer = (Get-CWAAInfoBackup -EA 0).Server[0] }
                    Catch { Write-Debug "Unable to retrieve server from backup settings: $($_.Exception.Message)" }
                }
            }

            # Check if the agent is offline beyond the restart threshold
            $restartThreshold = (Get-Date).AddHours($HoursRestart)
            $reinstallThreshold = (Get-Date).AddHours($HoursReinstall)

            if ($lastContact -lt $restartThreshold -or $lastHeartbeat -lt $restartThreshold) {
                Write-Verbose "Agent has NOT checked in within the last $([Math]::Abs($HoursRestart)) hour(s)."
                Write-CWAAEventLog -EventId 4001 -EntryType Warning -Message "Agent offline. Last contact: $lastContact. Last heartbeat: $lastHeartbeat. Threshold: $([Math]::Abs($HoursRestart)) hours."

                # Verify the server is reachable before attempting remediation
                if ($activeServer) {
                    $serverAvailable = Test-CWAAServerConnectivity -Server $activeServer -Quiet
                    if (-not $serverAvailable) {
                        $resultMessage = "Server '$activeServer' is not reachable. Cannot remediate."
                        Write-Error $resultMessage
                        Write-CWAAEventLog -EventId 4008 -EntryType Error -Message $resultMessage
                        [PSCustomObject]@{
                            ActionTaken = 'None'
                            Success     = $False
                            Message     = $resultMessage
                        }
                        return
                    }
                }

                # Step 1: Restart services
                if ($PSCmdlet.ShouldProcess('LTService, LTSvcMon', 'Restart services to recover agent check-in')) {
                    Write-Verbose 'Restarting Automate agent services.'
                    Restart-CWAA

                    # Wait up to 2 minutes for the agent to check in after restart
                    Write-Verbose 'Waiting for agent check-in after restart.'
                    $waitStart = Get-Date
                    while ($lastContact -lt $restartThreshold -and $waitStart.AddMinutes(2) -gt (Get-Date)) {
                        Start-Sleep -Seconds 2
                        Try {
                            [datetime]$lastContact = (Get-CWAAInfo -EA Stop -Verbose:$False -WhatIf:$False -Confirm:$False).LastSuccessStatus
                        }
                        Catch {
                            Write-Debug "Unable to re-read LastSuccessStatus during wait loop: $($_.Exception.Message)"
                        }
                    }
                }

                # Did the restart fix it?
                if ($lastContact -ge $restartThreshold) {
                    $actionTaken = 'Restart'
                    $resultMessage = "Services restarted. Agent recovered. Last contact: $lastContact"
                    Write-Verbose $resultMessage
                    Write-CWAAEventLog -EventId 4001 -EntryType Information -Message $resultMessage
                }
                # Step 2: Reinstall if still offline beyond reinstall threshold
                elseif ($lastContact -lt $reinstallThreshold) {
                    Write-Verbose "Agent still not connecting after restart. Offline beyond $([Math]::Abs($HoursReinstall))-hour threshold. Reinstalling."
                    Write-CWAAEventLog -EventId 4002 -EntryType Warning -Message "Agent still offline after restart. Last contact: $lastContact. Attempting reinstall."

                    if ($PSCmdlet.ShouldProcess('LTService', 'Reinstall agent after failed restart recovery')) {
                        Clear-CWAAInstallerArtifacts
                        Try {
                            if ($InstallerToken -and $Server -and $LocationID) {
                                Redo-CWAA -Server $Server -LocationID $LocationID -InstallerToken $InstallerToken -Hide
                            }
                            else {
                                Redo-CWAA -Hide -InstallerToken $InstallerToken
                            }
                            $actionTaken = 'Reinstall'
                            $resultMessage = 'Agent reinstalled after extended offline period.'
                            Write-CWAAEventLog -EventId 4002 -EntryType Information -Message $resultMessage
                        }
                        Catch {
                            $actionTaken = 'Reinstall'
                            $success = $False
                            $resultMessage = "Agent reinstall failed. Error: $($_.Exception.Message)"
                            Write-Error $resultMessage
                            Write-CWAAEventLog -EventId 4009 -EntryType Error -Message $resultMessage
                        }
                    }
                }
                else {
                    # Restart was attempted but agent hasn't recovered yet. Not yet at reinstall threshold.
                    $actionTaken = 'Restart'
                    $success = $True
                    $resultMessage = "Services restarted. Agent has not recovered yet but is within reinstall threshold ($([Math]::Abs($HoursReinstall)) hours)."
                    Write-Verbose $resultMessage
                }
            }
            else {
                # Agent is healthy
                $resultMessage = "Agent is healthy. Last contact: $lastContact. Last heartbeat: $lastHeartbeat."
                Write-Verbose $resultMessage
                Write-CWAAEventLog -EventId 4000 -EntryType Information -Message $resultMessage
            }

            #endregion
        }
        else {
            #region Agent is NOT installed — attempt install

            Write-Verbose 'Agent service not found. Attempting installation.'
            Write-CWAAEventLog -EventId 4003 -EntryType Warning -Message 'Agent not installed. Attempting installation.'

            Try {
                if ($Server -and $LocationID -and $InstallerToken) {
                    # Full install parameters provided
                    if ($PSCmdlet.ShouldProcess('LTService', "Install agent (Server: $Server, LocationID: $LocationID)")) {
                        Write-Verbose "Installing agent with provided parameters (Server: $Server, LocationID: $LocationID)."
                        Clear-CWAAInstallerArtifacts
                        Redo-CWAA -Server $Server -LocationID $LocationID -InstallerToken $InstallerToken
                        $actionTaken = 'Install'
                        $resultMessage = "Fresh agent install completed (Server: $Server, LocationID: $LocationID)."
                        Write-CWAAEventLog -EventId 4003 -EntryType Information -Message $resultMessage
                    }
                }
                else {
                    # Try to recover from existing settings or backup
                    $settings = $Null
                    $hasBackup = $False
                    Try {
                        $settings = Get-CWAAInfo -EA Stop -Verbose:$False -WhatIf:$False -Confirm:$False
                        $hasBackup = $True
                    }
                    Catch {
                        $settings = Get-CWAAInfoBackup -EA 0
                        $hasBackup = $False
                    }

                    if ($settings) {
                        if ($hasBackup) {
                            Write-Verbose 'Backing up current settings before reinstall.'
                            New-CWAABackup -ErrorAction SilentlyContinue
                        }
                        $reinstallServer = ($settings | Select-Object -Expand 'Server' -EA 0)[0]
                        $reinstallLocationID = $settings | Select-Object -Expand 'LocationID' -EA 0

                        if ($PSCmdlet.ShouldProcess('LTService', "Reinstall from backup settings (Server: $reinstallServer)")) {
                            Write-Verbose "Reinstalling agent from backup settings (Server: $reinstallServer)."
                            Clear-CWAAInstallerArtifacts
                            Redo-CWAA -Server $reinstallServer -LocationID $reinstallLocationID -Hide -InstallerToken $InstallerToken
                            $actionTaken = 'Install'
                            $resultMessage = "Agent reinstalled from backup settings (Server: $reinstallServer)."
                            Write-CWAAEventLog -EventId 4003 -EntryType Information -Message $resultMessage
                        }
                    }
                    else {
                        $success = $False
                        $resultMessage = 'Unable to find install settings. Provide -Server, -LocationID, and -InstallerToken parameters.'
                        Write-Error $resultMessage
                        Write-CWAAEventLog -EventId 4009 -EntryType Error -Message $resultMessage
                    }
                }
            }
            Catch {
                $actionTaken = 'Install'
                $success = $False
                $resultMessage = "Agent installation failed. Error: $($_.Exception.Message)"
                Write-Error $resultMessage
                Write-CWAAEventLog -EventId 4009 -EntryType Error -Message $resultMessage
            }

            #endregion
        }

        [PSCustomObject]@{
            ActionTaken = $actionTaken
            Success     = $success
            Message     = $resultMessage
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
