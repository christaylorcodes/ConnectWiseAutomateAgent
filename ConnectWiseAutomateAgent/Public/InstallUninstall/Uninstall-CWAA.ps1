function Uninstall-CWAA {
    <#
    .SYNOPSIS
        Completely uninstalls the ConnectWise Automate Agent from the local computer.
    .DESCRIPTION
        Performs a comprehensive removal of the ConnectWise Automate Agent from a Windows computer.
        This function is more thorough than a standard MSI uninstall, as it also removes residual
        files, registry keys, and services that may not be cleaned up by the normal uninstall process.

        The uninstall process performs the following operations:
        1. Downloads official uninstaller files (Agent_Uninstall.msi and Agent_Uninstall.exe) from the server
        2. Optionally creates a backup of the current agent installation (if -Backup is specified)
        3. Stops all running agent services (LTService, LTSvcMon, LabVNC)
        4. Terminates any running agent processes
        5. Unregisters the wodVPN.dll component
        6. Runs the MSI uninstaller (Agent_Uninstall.msi)
        7. Runs the agent uninstaller executable (Agent_Uninstall.exe)
        8. Removes agent Windows services
        9. Removes all agent files from the installation directory
        10. Removes all agent-related registry keys (over 30 different registry locations)
        11. Verifies the uninstall was successful

        Probe Agent Protection: By default, this function will refuse to uninstall probe agents to
        prevent accidental removal of critical infrastructure. Use -Force to override this protection.
    .PARAMETER Server
        One or more ConnectWise Automate server URLs to download uninstaller files from.
        If not specified, reads the server URL from the agent's current registry configuration.
        If that fails, prompts interactively for a server URL.
        Example: https://automate.domain.com
    .PARAMETER Backup
        Creates a complete backup of the agent installation before uninstalling by calling New-CWAABackup.
    .PARAMETER Force
        Forces uninstallation even when a probe agent is detected. Use with extreme caution,
        as probe agents are typically critical infrastructure components.
    .EXAMPLE
        Uninstall-CWAA
        Uninstalls the agent using the server URL from the agent's registry settings.
    .EXAMPLE
        Uninstall-CWAA -Backup
        Creates a backup of the agent installation before uninstalling.
    .EXAMPLE
        Uninstall-CWAA -Server "https://automate.company.com"
        Uninstalls using the specified server URL to download uninstaller files.
    .EXAMPLE
        Uninstall-CWAA -Server "https://primary.company.com","https://backup.company.com"
        Provides multiple server URLs with fallback. Tries each until uninstaller files download successfully.
    .EXAMPLE
        Uninstall-CWAA -Force
        Forces uninstallation even if a probe agent is detected.
    .EXAMPLE
        Uninstall-CWAA -WhatIf
        Simulates the uninstall process without making any actual changes.
    .NOTES
        Author: Chris Taylor
        Alias: Uninstall-LTService
        Requires: Administrator privileges
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Uninstall-LTService')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [AllowNull()]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Backup,
        [switch]$Force,
        [switch]$SkipCertificateCheck
    )

    Begin {
        Write-Debug "Starting $($myInvocation.InvocationName)"

        # Lazy initialization of SSL/TLS, WebClient, and proxy configuration.
        # Only runs once per session, skips immediately on subsequent calls.
        $Null = Initialize-CWAANetworking -SkipCertificateCheck:$SkipCertificateCheck

        if (-not ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent() | Select-Object -Expand groups -EA 0) -match 'S-1-5-32-544'))) {
            Throw "Needs to be ran as Administrator"
        }

        $serviceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
        if ($serviceInfo -and ($serviceInfo | Select-Object -Expand Probe -EA 0) -eq '1') {
            if ($Force -eq $True) {
                Write-Output 'Probe Agent Detected. UnInstall Forced.'
            }
            else {
                Write-Error -Exception [System.OperationCanceledException]"Probe Agent Detected. UnInstall Denied." -ErrorAction Stop
            }
        }

        if ($Backup) {
            if ($PSCmdlet.ShouldProcess('LTService', 'Backup Current Service Settings')) {
                New-CWAABackup
            }
        }

        $BasePath = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand BasePath -EA 0
        if (-not $BasePath) { $BasePath = $Script:CWAAInstallPath }

        New-PSDrive HKU Registry HKEY_USERS -ErrorAction SilentlyContinue -WhatIf:$False -Confirm:$False -Debug:$False | Out-Null
        $regs = @( 'Registry::HKEY_LOCAL_MACHINE\Software\LabTechMSP',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\LabTech\Service',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\LabTech\LabVNC',
            'Registry::HKEY_LOCAL_MACHINE\Software\Wow6432Node\LabTech\Service',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Managed\\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\D1003A85576B76D45A1AF09A0FC87FAC\InstallProperties',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{3426921d-9ad5-4237-9145-f15dee7e3004}',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Appmgmt\{40bf8c82-ed0d-4f66-b73e-58a3d7ab6582}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Dependencies\{3426921d-9ad5-4237-9145-f15dee7e3004}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Dependencies\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{09DF1DCA-C076-498A-8370-AD6F878B6C6A}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{15DD3BF6-5A11-4407-8399-A19AC10C65D0}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{3C198C98-0E27-40E4-972C-FDC656EC30D7}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{459C65ED-AA9C-4CF1-9A24-7685505F919A}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{7BE3886B-0C12-4D87-AC0B-09A5CE4E6BD6}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{7E092B5C-795B-46BC-886A-DFFBBBC9A117}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{9D101D9C-18CC-4E78-8D78-389E48478FCA}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{B0B8CDD6-8AAA-4426-82E9-9455140124A1}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{B1B00A43-7A54-4A0F-B35D-B4334811FAA4}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{BBC521C8-2792-43FE-9C91-CCA7E8ACBCC9}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{C59A1D54-8CD7-4795-AEDD-F6F6E2DE1FE7}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_CURRENT_USER\SOFTWARE\LabTech\Service',
            'Registry::HKEY_CURRENT_USER\SOFTWARE\LabTech\LabVNC',
            'Registry::HKEY_CURRENT_USER\Software\Microsoft\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'HKU:\*\Software\Microsoft\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F'
        )

        if ($WhatIfPreference -ne $True) {
            Remove-Item 'Uninstall.exe', 'Uninstall.exe.config' -ErrorAction SilentlyContinue -Force -Confirm:$False
            New-Item "$Script:CWAAInstallerTempPath\Installer" -type directory -ErrorAction SilentlyContinue | Out-Null
        }

        $uninstallArguments = "/x ""$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi"" /qn"
    }

    Process {
        if (-not $Server) {
            $Server = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand 'Server' -EA 0
        }
        if (-not $Server) {
            $Server = Read-Host -Prompt 'Provide the URL to your Automate server (https://automate.domain.com):'
        }

        # Resolve the first reachable server and its advertised version
        $serverResult = Resolve-CWAAServer -Server $Server
        if (-not $serverResult) { return }
        $serverUrl = $serverResult.ServerUrl

        Try {
            # Download the uninstall MSI (same URL for all server versions)
            $installer = "$serverUrl/LabTech/Service/LabTechRemoteAgent.msi"
            $installerTest = [System.Net.WebRequest]::Create($installer)
            if (($Script:LTProxy.Enabled) -eq $True) {
                Write-Debug "Proxy Configuration Needed. Applying Proxy Settings to request."
                $installerTest.Proxy = $Script:LTWebProxy
            }
            $installerTest.KeepAlive = $False
            $installerTest.ProtocolVersion = '1.0'
            $installerResult = $installerTest.GetResponse()
            $installerTest.Abort()
            if ($installerResult.StatusCode -ne 200) {
                Write-Warning "Unable to download Agent_Uninstall.msi from server $serverUrl."
                return
            }

            if ($PSCmdlet.ShouldProcess("$installer", 'DownloadFile')) {
                Write-Debug "Downloading Agent_Uninstall.msi from $installer"
                $Script:LTServiceNetWebClient.DownloadFile($installer, "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi")
                if (-not (Test-CWAADownloadIntegrity -FilePath "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi" -FileName 'Agent_Uninstall.msi')) {
                    return
                }
                $AlternateServer = $serverUrl
            }

            # Download the uninstall EXE (same URI for all versions)
            $uninstaller = "$serverUrl/LabTech/Service/LabUninstall.exe"
            $uninstallerTest = [System.Net.WebRequest]::Create($uninstaller)
            if (($Script:LTProxy.Enabled) -eq $True) {
                Write-Debug "Proxy Configuration Needed. Applying Proxy Settings to request."
                $uninstallerTest.Proxy = $Script:LTWebProxy
            }
            $uninstallerTest.KeepAlive = $False
            $uninstallerTest.ProtocolVersion = '1.0'
            $uninstallerResult = $uninstallerTest.GetResponse()
            $uninstallerTest.Abort()
            if ($uninstallerResult.StatusCode -ne 200) {
                Write-Warning "Unable to download Agent_Uninstall from server."
                return
            }

            if ($PSCmdlet.ShouldProcess("$uninstaller", 'DownloadFile')) {
                Write-Debug "Downloading Agent_Uninstall.exe from $uninstaller"
                $Script:LTServiceNetWebClient.DownloadFile($uninstaller, "${env:windir}\temp\Agent_Uninstall.exe")
                # Uninstall EXE is smaller than MSI — use 80 KB threshold
                if (-not (Test-CWAADownloadIntegrity -FilePath "${env:windir}\temp\Agent_Uninstall.exe" -FileName 'Agent_Uninstall.exe' -MinimumSizeKB 80)) {
                    return
                }
            }

            if ($WhatIfPreference -eq $True) {
                $GoodServer = $serverUrl
            }
            Elseif ((Test-Path "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi") -and (Test-Path "${env:windir}\temp\Agent_Uninstall.exe")) {
                $GoodServer = $serverUrl
                Write-Verbose "Successfully downloaded files from $serverUrl."
            }
            else {
                Write-Warning "Error encountered downloading from $serverUrl. Uninstall file(s) could not be received."
            }
        }
        Catch {
            Write-Warning "Error encountered downloading from $serverUrl."
        }
    }

    End {
        if ($GoodServer -match 'https?://.+' -or $AlternateServer -match 'https?://.+') {
            Try {
                Write-Output 'Starting Uninstall.'

                Try { Stop-CWAA -ErrorAction SilentlyContinue } Catch { Write-Debug "Stop-CWAA encountered an error: $_" }

                # Kill all running processes from %ltsvcdir%
                if (Test-Path $BasePath) {
                    $Executables = (Get-ChildItem $BasePath -Filter *.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -Expand FullName)
                    if ($Executables) {
                        Write-Verbose "Terminating Automate agent processes from $BasePath if found running: $(($Executables) -replace [Regex]::Escape($BasePath),'' -replace '^\\','')"
                        Get-Process | Where-Object { $Executables -contains $_.Path } | ForEach-Object {
                            Write-Debug "Terminating Process $($_.ProcessName)"
                            $_ | Stop-Process -Force -ErrorAction SilentlyContinue
                        }
                        Get-ChildItem $BasePath -Filter labvnc.exe -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction 0
                    }

                    if ($PSCmdlet.ShouldProcess("$BasePath\wodVPN.dll", 'Unregister DLL')) {
                        Write-Debug "Executing Command ""regsvr32.exe /u $BasePath\wodVPN.dll /s"""
                        Try { & "$env:windir\system32\regsvr32.exe" /u "$BasePath\wodVPN.dll" /s 2>'' }
                        Catch { Write-Output 'Error calling regsvr32.exe.' }
                    }
                }

                if ($PSCmdlet.ShouldProcess("msiexec.exe $uninstallArguments", 'Execute MSI Uninstall')) {
                    if (Test-Path "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi") {
                        Write-Verbose 'Launching MSI Uninstall.'
                        Write-Debug "Executing Command ""msiexec.exe $uninstallArguments"""
                        Start-Process -Wait -FilePath "$env:windir\system32\msiexec.exe" -ArgumentList $uninstallArguments -WorkingDirectory $env:TEMP
                        Start-Sleep -Seconds 5
                    }
                    else {
                        Write-Verbose "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi was not found."
                    }
                }

                if ($PSCmdlet.ShouldProcess("${env:windir}\temp\Agent_Uninstall.exe", 'Execute Agent Uninstall')) {
                    if (Test-Path "${env:windir}\temp\Agent_Uninstall.exe") {
                        # Remove previously extracted SFX files to prevent UnRAR overwrite prompts
                        Remove-Item "$env:TEMP\Uninstall.exe", "$env:TEMP\Uninstall.exe.config" -ErrorAction SilentlyContinue -Force -Confirm:$False
                        Write-Verbose 'Launching Agent Uninstaller'
                        Write-Debug "Executing Command ""${env:windir}\temp\Agent_Uninstall.exe"""
                        Start-Process -Wait -FilePath "${env:windir}\temp\Agent_Uninstall.exe" -WorkingDirectory $env:TEMP
                        Start-Sleep -Seconds 5
                    }
                    else {
                        Write-Verbose "${env:windir}\temp\Agent_Uninstall.exe was not found."
                    }
                }

                Write-Verbose 'Removing Services if found.'
                @('LTService', 'LTSvcMon', 'LabVNC') | ForEach-Object {
                    if (Get-Service $_ -EA 0) {
                        if ($PSCmdlet.ShouldProcess($_, 'Remove Service')) {
                            Write-Debug "Removing Service: $_"
                            Try {
                                & "$env:windir\system32\sc.exe" delete "$_" 2>''
                                if ($LASTEXITCODE -ne 0) {
                                    Write-Warning "sc.exe delete returned exit code $LASTEXITCODE for service '$_'."
                                }
                            }
                            Catch { Write-Output 'Error calling sc.exe.' }
                        }
                    }
                }

                Write-Verbose 'Cleaning Files remaining if found.'
                # Depth-first removal to get as much removed as possible if complete removal fails
                @($BasePath, "${env:windir}\temp\_ltupdate") | ForEach-Object {
                    if (Test-Path $_ -EA 0) {
                        Remove-CWAAFolderRecursive -Path $_
                    }
                }

                Write-Verbose 'Removing agent installation msi file.'
                if ($PSCmdlet.ShouldProcess('Agent_Uninstall.msi', 'Remove File')) {
                    $MsiPath = "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi"
                    $tries = 0
                    Try {
                        Do {
                            $MsiExists = Test-Path $MsiPath
                            Start-Sleep -Seconds 10
                            Remove-Item $MsiPath -ErrorAction SilentlyContinue
                            $tries++
                        }
                        While ($MsiExists -and $tries -lt 4)
                    }
                    Catch {
                        Write-Verbose "Unable to remove Agent_Uninstall.msi: $($_.Exception.Message)"
                    }
                }

                Write-Verbose 'Cleaning Registry Keys if found.'
                # Depth First Value Removal, then Key Removal
                Foreach ($reg in $regs) {
                    if (Test-Path $reg -EA 0) {
                        Write-Debug "Found Registry Key: $reg"
                        if ($PSCmdlet.ShouldProcess($reg, 'Remove Registry Key')) {
                            Try {
                                Get-ChildItem -Path $reg -Recurse -Force -ErrorAction SilentlyContinue | Sort-Object { $_.name.length } -Descending | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                                Remove-Item -Recurse -Force -Path $reg -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                            }
                            Catch { Write-Debug "Error removing registry key '$reg': $($_.Exception.Message)" }
                        }
                    }
                }
            }

            Catch {
                Write-CWAAEventLog -EventId 1012 -EntryType Error -Message "Agent uninstall failed. Error: $($_.Exception.Message)"
                Write-Error "There was an error during the uninstall process. $($_.Exception.Message)" -ErrorAction Stop
            }

            if ($WhatIfPreference -ne $True) {
                # Post Uninstall Check
                If ((Test-Path $Script:CWAAInstallPath) -or (Test-Path "${env:windir}\temp\_ltupdate") -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)) {
                    Start-Sleep -Seconds 10
                }
                If ((Test-Path $Script:CWAAInstallPath) -or (Test-Path "${env:windir}\temp\_ltupdate") -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)) {
                    Write-Error "Remnants of previous install still detected after uninstall attempt. Please reboot and try again."
                    Write-CWAAEventLog -EventId 1011 -EntryType Warning -Message 'Remnants of previous install detected after uninstall. Reboot recommended.'
                }
                else {
                    Write-Output 'Automate agent has been successfully uninstalled.'
                    Write-CWAAEventLog -EventId 1010 -EntryType Information -Message 'Agent uninstalled successfully.'
                }
            }
        }
        Elseif ($WhatIfPreference -ne $True) {
            Write-Error "No valid server was reached to use for the uninstall." -ErrorAction Stop
        }
        Write-Debug "Exiting $($myInvocation.InvocationName)"
    }
}
