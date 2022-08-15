function Uninstall-CWAA {
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Uninstall-LTService')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [AllowNull()]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Backup,
        [switch]$Force
    )

    Begin {
        Clear-Variable Executables, BasePath, reg, regs, installer, installerTest, installerResult, LTSI, uninstaller, uninstallerTest, uninstallerResult, xarg, Svr, SVer, SvrVer, SvrVerCheck, GoodServer, AlternateServer, Item -EA 0 -WhatIf:$False -Confirm:$False #Clearing Variables for use
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"

        if (-not ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent() | Select-Object -Expand groups -EA 0) -match 'S-1-5-32-544'))) {
            Throw "Line $(LINENUM): Needs to be ran as Administrator"
        }

        $LTSI = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
        if (($LTSI) -and ($LTSI | Select-Object -Expand Probe -EA 0) -eq '1') {
            if ($Force -eq $True) {
                Write-Output 'Probe Agent Detected. UnInstall Forced.'
            }
            else {
                Write-Error -Exception [System.OperationCanceledException]"Line $(LINENUM): Probe Agent Detected. UnInstall Denied." -ErrorAction Stop
            }
        }

        if ($Backup) {
            if ( $PSCmdlet.ShouldProcess('LTService', 'Backup Current Service Settings') ) {
                New-CWAABackup
            }
        }

        $BasePath = $(Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand BasePath -EA 0)
        if (-not ($BasePath)) { $BasePath = "$env:windir\LTSVC" }

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
            #Cleanup previous uninstallers
            Remove-Item 'Uninstall.exe', 'Uninstall.exe.config' -ErrorAction SilentlyContinue -Force -Confirm:$False
            New-Item "$env:windir\temp\LabTech\Installer" -type directory -ErrorAction SilentlyContinue | Out-Null
        }

        $xarg = "/x ""$($env:windir)\temp\LabTech\Installer\Agent_Uninstall.msi"" /qn"
    }

    Process {
        if (-not ($Server)) {
            $Server = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand 'Server' -EA 0
        }
        if (-not ($Server)) {
            $Server = Read-Host -Prompt 'Provide the URL to your LabTech server (https://lt.domain.com):'
        }
        $Server = ForEach ($Svr in $Server) { if ($Svr -notmatch 'https?://.+') { "https://$($Svr)" }; $Svr }
        ForEach ($Svr in $Server) {
            if (-not ($GoodServer)) {
                if ($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$') {
                    Try {
                        if ($Svr -notmatch 'https?://.+') { $Svr = "http://$($Svr)" }
                        $SvrVerCheck = "$($Svr)/Labtech/Agent.aspx"
                        Write-Debug "Line $(LINENUM): Testing Server Response and Version: $SvrVerCheck"
                        $SvrVer = $Script:LTServiceNetWebClient.DownloadString($SvrVerCheck)

                        Write-Debug "Line $(LINENUM): Raw Response: $SvrVer"
                        $SVer = $SvrVer | Select-String -Pattern '(?<=[|]{6})[0-9]{1,3}\.[0-9]{1,3}' | ForEach-Object { $_.matches } | Select-Object -Expand value -EA 0
                        if ($Null -eq ($SVer)) {
                            Write-Verbose "Unable to test version response from $($Svr)."
                            Continue
                        }
                        $installer = "$($Svr)/LabTech/Service/LabTechRemoteAgent.msi"
                        $installerTest = [System.Net.WebRequest]::Create($installer)
                        if (($Script:LTProxy.Enabled) -eq $True) {
                            Write-Debug "Line $(LINENUM): Proxy Configuration Needed. Applying Proxy Settings to request."
                            $installerTest.Proxy = $Script:LTWebProxy
                        }
                        $installerTest.KeepAlive = $False
                        $installerTest.ProtocolVersion = '1.0'
                        $installerResult = $installerTest.GetResponse()
                        $installerTest.Abort()
                        if ($installerResult.StatusCode -ne 200) {
                            Write-Warning "WARNING: Line $(LINENUM): Unable to download Agent_Uninstall.msi from server $($Svr)."
                            Continue
                        }
                        else {
                            if ($PSCmdlet.ShouldProcess("$installer", 'DownloadFile')) {
                                Write-Debug "Line $(LINENUM): Downloading Agent_Uninstall.msi from $installer"
                                $Script:LTServiceNetWebClient.DownloadFile($installer, "$env:windir\temp\LabTech\Installer\Agent_Uninstall.msi")
                                if ((Test-Path "$env:windir\temp\LabTech\Installer\Agent_Uninstall.msi")) {
                                    if (!((Get-Item "$env:windir\temp\LabTech\Installer\Agent_Uninstall.msi" -EA 0).length / 1KB -gt 1234)) {
                                        Write-Warning "WARNING: Line $(LINENUM): Agent_Uninstall.msi size is below normal. Removing suspected corrupt file."
                                        Remove-Item "$env:windir\temp\LabTech\Installer\Agent_Uninstall.msi" -ErrorAction SilentlyContinue -Force -Confirm:$False
                                        Continue
                                    }
                                    else {
                                        $AlternateServer = $Svr
                                    }
                                }
                            }
                        }

                        #Using $SVer results gathered above.
                        if ([System.Version]$SVer -ge [System.Version]'110.374') {
                            #New Style Download Link starting with LT11 Patch 13 - The Agent Uninstaller URI has changed.
                            $uninstaller = "$($Svr)/LabTech/Service/LabUninstall.exe"
                        }
                        else {
                            #Original Uninstaller URL
                            $uninstaller = "$($Svr)/LabTech/Service/LabUninstall.exe"
                        }
                        $uninstallerTest = [System.Net.WebRequest]::Create($uninstaller)
                        if (($Script:LTProxy.Enabled) -eq $True) {
                            Write-Debug "Line $(LINENUM): Proxy Configuration Needed. Applying Proxy Settings to request."
                            $uninstallerTest.Proxy = $Script:LTWebProxy
                        }
                        $uninstallerTest.KeepAlive = $False
                        $uninstallerTest.ProtocolVersion = '1.0'
                        $uninstallerResult = $uninstallerTest.GetResponse()
                        $uninstallerTest.Abort()
                        if ($uninstallerResult.StatusCode -ne 200) {
                            Write-Warning "WARNING: Line $(LINENUM): Unable to download Agent_Uninstall from server."
                            Continue
                        }
                        else {
                            #Download Agent_Uninstall.exe
                            if ($PSCmdlet.ShouldProcess("$uninstaller", 'DownloadFile')) {
                                Write-Debug "Line $(LINENUM): Downloading Agent_Uninstall.exe from $uninstaller"
                                $Script:LTServiceNetWebClient.DownloadFile($uninstaller, "$($env:windir)\temp\Agent_Uninstall.exe")
                                if ((Test-Path "$($env:windir)\temp\Agent_Uninstall.exe") -and !((Get-Item "$($env:windir)\temp\Agent_Uninstall.exe" -EA 0).length / 1KB -gt 80)) {
                                    Write-Warning "WARNING: Line $(LINENUM): Agent_Uninstall.exe size is below normal. Removing suspected corrupt file."
                                    Remove-Item "$($env:windir)\temp\Agent_Uninstall.exe" -ErrorAction SilentlyContinue -Force -Confirm:$False
                                    Continue
                                }
                            }
                        }
                        if ($WhatIfPreference -eq $True) {
                            $GoodServer = $Svr
                        }
                        Elseif ((Test-Path "$env:windir\temp\LabTech\Installer\Agent_Uninstall.msi") -and (Test-Path "$($env:windir)\temp\Agent_Uninstall.exe")) {
                            $GoodServer = $Svr
                            Write-Verbose "Successfully downloaded files from $($Svr)."
                        }
                        else {
                            Write-Warning "WARNING: Line $(LINENUM): Error encountered downloading from $($Svr). Uninstall file(s) could not be received."
                            Continue
                        }
                    }
                    Catch {
                        Write-Warning "WARNING: Line $(LINENUM): Error encountered downloading from $($Svr)."
                        Continue
                    }
                }
                else {
                    Write-Verbose "Server address $($Svr) is not formatted correctly. Example: https://lt.domain.com"
                }
            }
            else {
                Write-Debug "Line $(LINENUM): Server $($GoodServer) has been selected."
                Write-Verbose "Server has already been selected - Skipping $($Svr)."
            }
        }
    }

    End {
        if ($GoodServer -match 'https?://.+' -or $AlternateServer -match 'https?://.+') {
            Try {
                Write-Output 'Starting Uninstall.'

                Try { Stop-CWAA -ErrorAction SilentlyContinue } Catch {}

                #Kill all running processes from %ltsvcdir%
                if (Test-Path $BasePath) {
                    $Executables = (Get-ChildItem $BasePath -Filter *.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -Expand FullName)
                    if ($Executables) {
                        Write-Verbose "Terminating LabTech Processes from $($BasePath) if found running: $(($Executables) -replace [Regex]::Escape($BasePath),'' -replace '^\\','')"
                        Get-Process | Where-Object { $Executables -contains $_.Path } | ForEach-Object {
                            Write-Debug "Line $(LINENUM): Terminating Process $($_.ProcessName)"
                            $($_) | Stop-Process -Force -ErrorAction SilentlyContinue
                        }
                        Get-ChildItem $BasePath -Filter labvnc.exe -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction 0
                    }

                    if ($PSCmdlet.ShouldProcess("$($BasePath)\wodVPN.dll", 'Unregister DLL')) {
                        #Unregister DLL
                        Write-Debug "Line $(LINENUM): Executing Command ""regsvr32.exe /u $($BasePath)\wodVPN.dll /s"""
                        Try { & "$env:windir\system32\regsvr32.exe" /u "$($BasePath)\wodVPN.dll" /s 2>'' }
                        Catch { Write-Output 'Error calling regsvr32.exe.' }
                    }
                }

                if ($PSCmdlet.ShouldProcess("msiexec.exe $($xarg)", 'Execute MSI Uninstall')) {
                    if ((Test-Path "$($env:windir)\temp\LabTech\Installer\Agent_Uninstall.msi")) {
                        #Run MSI uninstaller for current installation
                        Write-Verbose 'Launching MSI Uninstall.'
                        Write-Debug "Line $(LINENUM): Executing Command ""msiexec.exe $($xarg)"""
                        Start-Process -Wait -FilePath "$env:windir\system32\msiexec.exe" -ArgumentList $xarg -WorkingDirectory $env:TEMP
                        Start-Sleep -Seconds 5
                    }
                    else {
                        Write-Verbose "WARNING: $($env:windir)\temp\LabTech\Installer\Agent_Uninstall.msi was not found."
                    }
                }

                if ($PSCmdlet.ShouldProcess("$($env:windir)\temp\Agent_Uninstall.exe", 'Execute Agent Uninstall')) {
                    if ((Test-Path "$($env:windir)\temp\Agent_Uninstall.exe")) {
                        #Run Agent_Uninstall.exe
                        Write-Verbose 'Launching Agent Uninstaller'
                        Write-Debug "Line $(LINENUM): Executing Command ""$($env:windir)\temp\Agent_Uninstall.exe"""
                        Start-Process -Wait -FilePath "$($env:windir)\temp\Agent_Uninstall.exe" -WorkingDirectory $env:TEMP
                        Start-Sleep -Seconds 5
                    }
                    else {
                        Write-Verbose "WARNING: $($env:windir)\temp\Agent_Uninstall.exe was not found."
                    }
                }

                Write-Verbose 'Removing Services if found.'
                #Remove Services
                @('LTService', 'LTSvcMon', 'LabVNC') | ForEach-Object {
                    if (Get-Service $_ -EA 0) {
                        if ( $PSCmdlet.ShouldProcess("$($_)", 'Remove Service') ) {
                            Write-Debug "Line $(LINENUM): Removing Service: $($_)"
                            Try { & "$env:windir\system32\sc.exe" delete "$($_)" 2>'' }
                            Catch { Write-Output 'Error calling sc.exe.' }
                        }
                    }
                }

                Write-Verbose 'Cleaning Files remaining if found.'
                #Remove %ltsvcdir% - Depth First Removal, First by purging files, then Removing Folders, to get as much removed as possible if complete removal fails
                @($BasePath, "$($env:windir)\temp\_ltupdate", "$($env:windir)\temp\_ltupdate") | ForEach-Object {
                    if ((Test-Path "$($_)" -EA 0)) {
                        if ( $PSCmdlet.ShouldProcess("$($_)", 'Remove Folder') ) {
                            Write-Debug "Line $(LINENUM): Removing Folder: $($_)"
                            Try {
                                Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { ($_.psiscontainer) } | ForEach-Object { Get-ChildItem -Path "$($_.FullName)" -EA 0 | Where-Object { -not ($_.psiscontainer) } | Remove-Item -Force -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False }
                                Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { ($_.psiscontainer) } | Sort-Object { $_.fullname.length } -Descending | Remove-Item -Force -ErrorAction SilentlyContinue -Recurse -Confirm:$False -WhatIf:$False
                                Remove-Item -Recurse -Force -Path $_ -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                            }
                            Catch {}
                        }
                    }
                }
                Write-Verbose 'Removing agent installation msi file'
                if ($PSCmdlet.ShouldProcess('Agent_Uninstall.msi', 'Remove File')) {
                    $MsiPath = "$env:windir\temp\LabTech\Installer\Agent_Uninstall.msi"
                    try {
                        do {
                            $MsiExists = Test-Path $MsiPath 
                            Start-Sleep -Seconds 10
                            Remove-Item $MsiPath -ErrorAction SilentlyContinue
                            $tries++
                        }
                        while (-not $MsiExists -or $tries -gt 4)
                    }
                    catch {
                        Write-Verbose ('Unable to remove Agent_Uninstall.msi' -f $_.Exception.Message)
                    }
                }
                

                Write-Verbose 'Cleaning Registry Keys if found.'
                #Remove all registry keys - Depth First Value Removal, then Key Removal, to get as much removed as possible if complete removal fails
                Foreach ($reg in $regs) {
                    if ((Test-Path "$($reg)" -EA 0)) {
                        Write-Debug "Line $(LINENUM): Found Registry Key: $($reg)"
                        if ( $PSCmdlet.ShouldProcess("$($Reg)", 'Remove Registry Key') ) {
                            Try {
                                Get-ChildItem -Path $reg -Recurse -Force -ErrorAction SilentlyContinue | Sort-Object { $_.name.length } -Descending | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                                Remove-Item -Recurse -Force -Path $reg -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                            }
                            Catch {}
                        }
                    }
                }
            }

            Catch {
                Write-Error "ERROR: Line $(LINENUM): There was an error during the uninstall process. $($_.Exception.Message)" -ErrorAction Stop
            }

            if ($WhatIfPreference -ne $True) {
                if ($?) {
                    #Post Uninstall Check
                    If ((Test-Path "$env:windir\ltsvc") -or (Test-Path "$env:windir\temp\_ltupdate") -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)) {
                        Start-Sleep -Seconds 10
                    }
                    If ((Test-Path "$env:windir\ltsvc") -or (Test-Path "$env:windir\temp\_ltupdate") -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)) {
                        Write-Error "ERROR: Line $(LINENUM): Remnants of previous install still detected after uninstall attempt. Please reboot and try again."
                    }
                    else {
                        Write-Output 'LabTech has been successfully uninstalled.'
                    }
                }
                else {
                    $($Error[0])
                }
            }
        }
        Elseif ($WhatIfPreference -ne $True) {
            Write-Error "ERROR: Line $(LINENUM): No valid server was reached to use for the uninstall." -ErrorAction Stop
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}
