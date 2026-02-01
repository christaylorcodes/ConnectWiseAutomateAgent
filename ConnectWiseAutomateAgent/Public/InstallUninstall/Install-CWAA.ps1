function Install-CWAA {
    <#
    .SYNOPSIS
        Installs the ConnectWise Automate Agent on the local computer.
    .DESCRIPTION
        Downloads and installs the ConnectWise Automate agent from the specified server URL.
        Supports authentication via InstallerToken (preferred) or ServerPassword. The function handles
        prerequisite checks for .NET Framework 3.5, MSI download with file integrity validation,
        proxy configuration, TrayPort conflict resolution, and post-install agent registration verification.

        If a previous installation is detected, the function will automatically call Uninstall-LTService
        before proceeding. The -Force parameter allows installation even when services are already present
        or when only .NET 4.0+ is available without 3.5.
    .PARAMETER Server
        One or more ConnectWise Automate server URLs to download the installer from.
        Example: https://automate.domain.com
        The function tries each server in order until a successful download occurs.
    .PARAMETER ServerPassword
        The server password that agents use to authenticate with the Automate server.
        Used for legacy deployment method. InstallerToken is preferred.
    .PARAMETER InstallerToken
        An installer token for authenticated agent deployment. This is the preferred
        authentication method over ServerPassword.
        See: https://forums.mspgeek.org/topic/5882-contribution-generate-agent-installertoken
    .PARAMETER LocationID
        The LocationID of the location the agent will be assigned to.
    .PARAMETER TrayPort
        The local port LTSvc.exe listens on for communication with LTTray processes.
        Defaults to 42000. If the port is in use, the function auto-selects the next available port.
    .PARAMETER Rename
        Renames the agent entry in Add/Remove Programs after installation by calling Rename-CWAAAddRemove.
    .PARAMETER Hide
        Hides the agent entry from Add/Remove Programs after installation by calling Hide-CWAAAddRemove.
    .PARAMETER SkipDotNet
        Skips .NET Framework 3.5 and 2.0 prerequisite checks. Use when .NET 4.0+ is already installed.
    .PARAMETER Force
        Disables safety checks including existing service detection and .NET version requirements.
    .PARAMETER NoWait
        Skips the post-install health check that waits for agent registration.
        The function exits immediately after the installer completes.
    .PARAMETER Credential
        A PSCredential object containing the server password for deployment authentication.
        The password is extracted and used as the ServerPassword. This is the preferred
        secure alternative to passing -ServerPassword as plain text.
    .PARAMETER SkipCertificateCheck
        Bypasses SSL/TLS certificate validation for server connections.
        Use in lab or test environments with self-signed certificates.
    .PARAMETER ShowProgress
        Displays a Write-Progress bar showing installation progress. Off by default
        to avoid interference with unattended execution (RMM tools, GPO scripts).
    .EXAMPLE
        Install-CWAA -Server https://automate.domain.com -InstallerToken 'GeneratedToken' -LocationID 42
        Installs the agent using an InstallerToken for authentication.
    .EXAMPLE
        Install-CWAA -Server https://automate.domain.com -ServerPassword 'encryptedpass' -LocationID 1
        Installs the agent using a legacy server password.
    .EXAMPLE
        Install-CWAA -Server https://automate.domain.com -InstallerToken 'token' -LocationID 42 -NoWait
        Installs the agent without waiting for registration to complete.
    .EXAMPLE
        Get-CWAAInfoBackup | Install-CWAA -InstallerToken 'GeneratedToken'
        Reinstalls the agent using Server and LocationID from a previous backup via pipeline.
    .NOTES
        Author: Chris Taylor
        Alias: Install-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True, DefaultParameterSetName = 'deployment')]
    [Alias('Install-LTService')]
    Param(
        [Parameter(ParameterSetName = 'deployment')]
        [Parameter(ParameterSetName = 'installertoken')]
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $True)]
        [ValidateScript({
            if ($_ -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$') { $true }
            else { throw "Server address '$_' is not valid. Expected format: https://automate.domain.com" }
        })]
        [string[]]$Server,
        [Parameter(ParameterSetName = 'deployment')]
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [Alias('Password')]
        [string]$ServerPassword,
        [Parameter(ParameterSetName = 'deployment')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,
        [Parameter(ParameterSetName = 'installertoken')]
        [ValidatePattern('(?s:^[0-9a-z]+$)')]
        [string]$InstallerToken,
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [int]$LocationID,
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [int]$TrayPort,
        [Parameter()]
        [AllowNull()]
        [string]$Rename,
        [switch]$Hide,
        [switch]$SkipDotNet,
        [switch]$Force,
        [switch]$NoWait,
        [switch]$SkipCertificateCheck,
        [switch]$ShowProgress
    )

    Begin {
        Write-Debug "Starting $($myInvocation.InvocationName)"

        # Snapshot error count so we can detect new errors from this function only,
        # rather than checking the global $Error collection which accumulates all session errors.
        $errorCountAtStart = $Error.Count

        # If a PSCredential was provided, extract the password for the deployment workflow.
        # This is the preferred secure alternative to passing -ServerPassword as plain text.
        if ($Credential) {
            $ServerPassword = $Credential.GetNetworkCredential().Password
        }

        # Lazy initialization of SSL/TLS, WebClient, and proxy configuration.
        # Only runs once per session, skips immediately on subsequent calls.
        $Null = Initialize-CWAANetworking -SkipCertificateCheck:$SkipCertificateCheck

        $progressId = 1
        $progressActivity = 'Installing ConnectWise Automate Agent'
        if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Checking prerequisites' -PercentComplete 11 }

        if (-not $Force) {
            if (Get-Service $Script:CWAAServiceNames -ErrorAction SilentlyContinue) {
                if ($WhatIfPreference -ne $True) {
                    Write-Error "Services are already installed." -ErrorAction Stop
                }
                else {
                    Write-Error "What if: Stopping: Services are already installed." -ErrorAction Stop
                }
            }
        }

        if (-not ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent() | Select-Object -Expand groups -EA 0) -match 'S-1-5-32-544'))) {
            Throw 'Needs to be ran as Administrator'
        }

        $Null = Test-CWAADotNetPrerequisite -SkipDotNet:$SkipDotNet -Force:$Force

        $InstallBase = $Script:CWAAInstallerTempPath
        $logfile = 'LTAgentInstall'
        $curlog = "$InstallBase\$logfile.log"
        if (-not (Test-Path -PathType Container -Path "$InstallBase\Installer")) {
            New-Item "$InstallBase\Installer" -type directory -ErrorAction SilentlyContinue | Out-Null
        }
        if (Test-Path -PathType Leaf -Path $curlog) {
            if ($PSCmdlet.ShouldProcess($curlog, 'Rotate existing log file')) {
                Get-Item -LiteralPath $curlog -EA 0 | Where-Object { $_ } | ForEach-Object {
                    Rename-Item -Path ($_ | Select-Object -Expand FullName -EA 0) -NewName "$logfile-$(Get-Date ($_ | Select-Object -Expand LastWriteTime -EA 0) -Format 'yyyyMMddHHmmss').log" -Force -Confirm:$False -WhatIf:$False
                    Remove-Item -Path ($_ | Select-Object -Expand FullName -EA 0) -Force -EA 0 -Confirm:$False -WhatIf:$False
                }
            }
        }
    }

    Process {
        # Escape double quotes in ServerPassword for MSI argument safety.
        # Placed in Process (not Begin) because ServerPassword may arrive via pipeline binding.
        if ($ServerPassword -match '"') { $ServerPassword = $ServerPassword.Replace('"', '""') }
        if (-not ($LocationID -or $PSCmdlet.ParameterSetName -eq 'installertoken')) {
            $LocationID = '1'
        }
        if (-not ($TrayPort) -or -not ($TrayPort -ge 1 -and $TrayPort -le 65535)) {
            $TrayPort = $Script:CWAATrayPortDefault
        }
        # Resolve the first reachable server and its advertised version
        if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Resolving server address' -PercentComplete 22 }
        $serverResult = Resolve-CWAAServer -Server $Server
        if ($serverResult) {
            $serverUrl = $serverResult.ServerUrl
            $serverVersion = $serverResult.ServerVersion
        }

        if ($serverResult) {
            $InstallMSI = 'Agent_Install.msi'

            # Server version detection and installer URL selection:
            # The download URL and installer format vary by server version and auth method.
            # - v240.331+: InstallerToken deployments use a ZIP containing MSI+MST (new format)
            # - v110.374+: Anonymous MSI download changed; direct location targeting removed (LT11 Patch 13)
            # - v200.197+: Fixed a critical API vulnerability (CVE, June 2020) that allowed
            #   unauthenticated access to Deployment.aspx. Servers below this version get a warning.
            # - Pre-110.374: Legacy deployment URL with per-location MSI targeting
            if ($PSCmdlet.ParameterSetName -eq 'installertoken') {
                $installer = "$serverUrl/LabTech/Deployment.aspx?InstallerToken=$InstallerToken"
                if ([System.Version]$serverVersion -ge [System.Version]$Script:CWAAVersionZipInstaller) {
                    Write-Debug "New MSI Installer Format Needed"
                    $InstallMSI = 'Agent_Install.zip'
                }
            }
            Elseif ($ServerPassword) {
                $installer = "$serverUrl/LabTech/Service/LabTechRemoteAgent.msi"
            }
            Elseif ([System.Version]$serverVersion -ge [System.Version]$Script:CWAAVersionAnonymousChange) {
                $installer = "$serverUrl/LabTech/Deployment.aspx?Probe=1&installType=msi&MSILocations=1"
            }
            else {
                Write-Warning 'The server version is not supported. Please update your Automate server.'
                $installer = "$serverUrl/LabTech/Deployment.aspx?Probe=1&installType=msi&MSILocations=$LocationID"
            }

            # Vulnerability test June 10, 2020: ConnectWise Automate API Vulnerability
            # Servers below v200.197 may allow unauthenticated access to Deployment.aspx
            if ([System.Version]$serverVersion -lt [System.Version]$Script:CWAAVersionVulnerabilityFix) {
                Try {
                    $HTTP_Request = [System.Net.WebRequest]::Create("$serverUrl/LabTech/Deployment.aspx")
                    if ($HTTP_Request.GetResponse().StatusCode -eq 'OK') {
                        $Message = @('Your server is vulnerable!!')
                        $Message += 'https://docs.connectwise.com/ConnectWise_Automate/ConnectWise_Automate_Supportability_Statements/Supportability_Statement%3A_ConnectWise_Automate_Mitigation_Steps'
                        Write-Warning ($Message | Out-String)
                    }
                }
                Catch {
                    if (-not $ServerPassword) {
                        Write-Error 'Anonymous downloads are not allowed. ServerPassword or InstallerToken may be needed.'
                    }
                }
            }

            if ($PSCmdlet.ShouldProcess($installer, 'DownloadFile')) {
                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Downloading agent installer' -PercentComplete 33 }
                Write-Debug "Downloading $InstallMSI from $installer"
                $Script:LTServiceNetWebClient.DownloadFile($installer, "$InstallBase\Installer\$InstallMSI")
                if (-not (Test-CWAADownloadIntegrity -FilePath "$InstallBase\Installer\$InstallMSI" -FileName $InstallMSI)) {
                    $serverResult = $null
                }
            }

            if ($serverResult) {
                if ($WhatIfPreference -eq $True) {
                    $GoodServer = $serverUrl
                }
                Elseif (Test-Path "$InstallBase\Installer\$InstallMSI") {
                    $GoodServer = $serverUrl
                    Write-Verbose "$InstallMSI downloaded successfully from server $serverUrl."
                    if (($PSCmdlet.ParameterSetName -eq 'installertoken') -and [System.Version]$serverVersion -ge [System.Version]$Script:CWAAVersionZipInstaller) {
                        Expand-Archive "$InstallBase\Installer\$InstallMSI" -DestinationPath "$InstallBase\Installer" -Force
                        Remove-Item "$InstallBase\Installer\$InstallMSI" -ErrorAction SilentlyContinue -Force -Confirm:$False
                        $InstallMSI = 'Agent_Install.msi'
                    }
                }
                else {
                    Write-Warning "Error encountered downloading from $serverUrl. No installation file was received."
                }
            }
        }
    }

    End {
        try {
            if ($GoodServer) {
                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Preparing installation environment' -PercentComplete 44 }

                if ($WhatIfPreference -eq $True -and (Get-PSCallStack)[1].Command -in @('Redo-CWAA', 'Redo-LTService', 'Reinstall-CWAA', 'Reinstall-LTService')) {
                    Write-Debug "Skipping Preinstall Check: Called by Redo-CWAA with -WhatIf"
                }
                else {
                    if ((Test-Path $Script:CWAAInstallPath -EA 0) -or (Test-Path "${env:windir}\temp\_ltupdate" -EA 0) -or (Test-Path registry::HKLM\Software\LabTech\Service -EA 0) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service -EA 0)) {
                        Write-Warning "Previous installation detected. Calling Uninstall-CWAA"
                        Uninstall-CWAA -Server $GoodServer -Force
                        Start-Sleep $Script:CWAAUninstallWaitSeconds
                    }
                }

                if ($WhatIfPreference -ne $True) {
                    if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Resolving TrayPort' -PercentComplete 55 }
                    # TrayPort conflict resolution: LTSvc.exe listens on a local TCP port (default 42000)
                    # for communication with LTTray.exe (system tray UI). The valid range is 42000-42009.
                    # If the requested port is occupied by another process, we scan sequentially through
                    # the range, wrapping from 42009 back to 42000, trying up to 10 alternatives.
                    $GoodTrayPort = $Null
                    $TestTrayPort = $TrayPort
                    For ($i = 0; $i -le 10; $i++) {
                        if (-not $GoodTrayPort) {
                            if (-not (Test-CWAAPort -TrayPort $TestTrayPort -Quiet)) {
                                $TestTrayPort++
                                if ($TestTrayPort -gt $Script:CWAATrayPortMax) { $TestTrayPort = $Script:CWAATrayPortMin }
                            }
                            else {
                                $GoodTrayPort = $TestTrayPort
                            }
                        }
                    }
                    if ($GoodTrayPort -and $GoodTrayPort -ne $TrayPort -and $GoodTrayPort -ge 1 -and $GoodTrayPort -le 65535) {
                        Write-Verbose "TrayPort $TrayPort is in use. Changing TrayPort to $GoodTrayPort"
                        $TrayPort = $GoodTrayPort
                    }
                    Write-Output 'Starting Install.'
                }

                # Build parameter string
                $installerArguments = ($(
                    "/i `"$InstallBase\Installer\$InstallMSI`""
                    "SERVERADDRESS=$GoodServer"
                    if (($PSCmdlet.ParameterSetName -eq 'installertoken') -and [System.Version]$serverVersion -ge [System.Version]$Script:CWAAVersionZipInstaller) { "TRANSFORMS=`"Agent_Install.mst`"" }
                    if ($ServerPassword -and $ServerPassword -match '.') { "SERVERPASS=`"$ServerPassword`"" }
                    if ($LocationID -and $LocationID -match '^\d+$') { "LOCATION=$LocationID" }
                    if ($TrayPort -and $TrayPort -ne $Script:CWAATrayPortDefault) { "SERVICEPORT=$TrayPort" }
                    "/qn"
                    "/l `"$InstallBase\$logfile.log`""
                ) | Where-Object { $_ }) -join ' '

                Try {
                    if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Running MSI installer' -PercentComplete 66 }
                    $installSuccess = Invoke-CWAAMsiInstaller -InstallerArguments $installerArguments
                    if (-not $installSuccess) { Return }

                    if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Waiting for services to start' -PercentComplete 77 }
                    if (($Script:LTProxy.Enabled) -eq $True) {
                        Write-Verbose 'Proxy Configuration Needed. Applying Proxy Settings to Agent Installation.'
                        if ($PSCmdlet.ShouldProcess($Script:LTProxy.ProxyServerURL, 'Configure Agent Proxy')) {
                            $serviceRunning = Wait-CWAACondition -Condition {
                                $count = ('LTService') | Get-Service -EA 0 | Where-Object { $_.Status -eq 'Running' } | Measure-Object | Select-Object -Expand Count
                                $count -eq 1
                            } -TimeoutSeconds $Script:CWAAServiceStartTimeoutSec -IntervalSeconds 2 -Activity 'LTService initial startup'
                            if ($serviceRunning) {
                                Write-Debug "LTService Initial Startup Successful."
                            }
                            else {
                                Write-Debug "LTService Initial Startup failed to complete within expected period."
                            }
                            Set-CWAAProxy -ProxyServerURL $Script:LTProxy.ProxyServerURL -ProxyUsername $Script:LTProxy.ProxyUsername -ProxyPassword $Script:LTProxy.ProxyPassword -Confirm:$False -WhatIf:$False
                        }
                    }
                    else {
                        Write-Verbose 'No Proxy Configuration has been specified - Continuing.'
                    }

                    if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Waiting for agent registration' -PercentComplete 88 }
                    if (-not $NoWait -and $PSCmdlet.ShouldProcess('LTService', 'Monitor For Successful Agent Registration')) {
                        $Null = Wait-CWAACondition -Condition {
                            $agentId = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand 'ID' -EA 0
                            $agentId -ge 1
                        } -TimeoutSeconds $Script:CWAARegistrationTimeoutSec -IntervalSeconds 5 -Activity 'Agent registration'
                        $Null = Get-CWAAProxy -ErrorAction Continue
                    }
                    if ($Hide) { Hide-CWAAAddRemove }
                }

                Catch {
                    Write-Error "There was an error during the install process. $_"
                    Write-CWAAEventLog -EventId 1002 -EntryType Error -Message "Agent installation failed. Error: $($_.Exception.Message)"
                    Return
                }

                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Completing installation' -PercentComplete 100 }
                if ($WhatIfPreference -ne $True) {
                    # Cleanup install files
                    Remove-Item "$InstallBase\Installer\$InstallMSI" -ErrorAction SilentlyContinue -Force -Confirm:$False
                    Remove-Item "$InstallBase\Installer\Agent_Install.mst" -ErrorAction SilentlyContinue -Force -Confirm:$False
                    @($curlog, "$Script:CWAAInstallPath\Install.log") | ForEach-Object {
                        if (Test-Path -PathType Leaf -LiteralPath $_) {
                            $logcontents = Get-Content -Path $_
                            $logcontents = $logcontents -replace '(?<=PreInstallPass:[^\r\n]+? (?:result|value)): [^\r\n]+', ': <REDACTED>'
                            if ($logcontents) { Set-Content -Path $_ -Value $logcontents -Force -Confirm:$False }
                        }
                    }

                    $tempServiceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
                    if ($tempServiceInfo) {
                        if (($tempServiceInfo | Select-Object -Expand 'ID' -EA 0) -ge 1) {
                            Write-Output "Automate agent has been installed successfully. Agent ID: $($tempServiceInfo | Select-Object -Expand 'ID' -EA 0) LocationID: $($tempServiceInfo | Select-Object -Expand 'LocationID' -EA 0)"
                            Write-CWAAEventLog -EventId 1000 -EntryType Information -Message "Agent installed successfully. Agent ID: $($tempServiceInfo | Select-Object -Expand 'ID' -EA 0), LocationID: $($tempServiceInfo | Select-Object -Expand 'LocationID' -EA 0)"
                        }
                        Elseif (-not $NoWait) {
                            Write-Error "Automate agent installation completed but agent failed to register within expected period." -ErrorAction Continue
                            Write-CWAAEventLog -EventId 1001 -EntryType Warning -Message "Agent installed but failed to register within expected period."
                        }
                        else {
                            Write-Warning "Automate agent installation completed but agent did not yet register." -WarningAction Continue
                        }
                    }
                    else {
                        if ($Error.Count -gt $errorCountAtStart -or (-not $NoWait)) {
                            Write-Error "There was an error installing Automate agent. Check the log, $InstallBase\$logfile.log"
                            Write-CWAAEventLog -EventId 1002 -EntryType Error -Message "Agent installation failed. Check log: $InstallBase\$logfile.log"
                            Return
                        }
                        else {
                            Write-Warning "Automate agent installation may not have succeeded." -WarningAction Continue
                        }
                    }
                }
                if ($Rename) { Rename-CWAAAddRemove -Name $Rename }
            }
            Elseif ($WhatIfPreference -ne $True) {
                Write-Error "No valid server was reached to use for the install."
            }
        }
        finally {
            if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Completed }
            Write-Debug "Exiting $($myInvocation.InvocationName)"
        }
    }
}
