Function Install-CWAA {
    [CmdletBinding(SupportsShouldProcess=$True,DefaultParameterSetName = 'deployment')]
    [Alias('Install-LTService')]
    Param(
        [Parameter(ParameterSetName = 'deployment')]
        [Parameter(ParameterSetName = 'installertoken')]
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory=$True)]
        [string[]]$Server,
        [Parameter(ParameterSetName = 'deployment')]
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [Alias("Password")]
        [SecureString]$ServerPassword,
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
        [switch]$NoWait
    )

    Begin{
        Clear-Variable DotNET,OSVersion,PasswordArg,Result,logpath,logfile,curlog,installer,installerTest,installerResult,GoodServer,GoodTrayPort,TestTrayPort,Svr,SVer,SvrVer,SvrVerCheck,iarg,timeout,sw,tmpLTSI -EA 0 -WhatIf:$False -Confirm:$False #Clearing Variables for use
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"

        If (!($Force)) {
            If (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue) {
                If ($WhatIfPreference -ne $True) {
                    Write-Error "ERROR: Line $(LINENUM): Services are already installed." -ErrorAction Stop
                } Else {
                    Write-Error "ERROR: Line $(LINENUM): What if: Stopping: Services are already installed." -ErrorAction Stop
                }
            }
        }

        If (-not ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()|Select-Object -Expand groups -EA 0) -match 'S-1-5-32-544'))) {
            Throw "Needs to be ran as Administrator"
        }

        If (!$SkipDotNet){
            $DotNET = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse -EA 0 | Get-ItemProperty -name Version,Release -EA 0 | Where-Object { $_.PSChildName -match '^(?!S)\p{L}'} | Select-Object -ExpandProperty Version -EA 0
            If (-not ($DotNet -like '3.5.*')){
                Write-Output ".NET Framework 3.5 installation needed."
                #Install-WindowsFeature Net-Framework-Core
                $OSVersion = [System.Environment]::OSVersion.Version

                If ([version]$OSVersion -gt [version]'6.2'){
                    Try{
                        If ( $PSCmdlet.ShouldProcess('NetFx3', 'Enable-WindowsOptionalFeature') ) {
                            $Install = Get-WindowsOptionalFeature -Online -FeatureName 'NetFx3'
                            If (!($Install.State -eq 'EnablePending')) {
                                $Install = Enable-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -All -NoRestart
                            }
                            If ($Install.RestartNeeded -or $Install.State -eq 'EnablePending') {
                                Write-Output ".NET Framework 3.5 installed but a reboot is needed."
                            }
                        }
                    }
                    Catch{
                        Write-Error "ERROR: Line $(LINENUM): .NET 3.5 install failed." -ErrorAction Continue
                        If (!($Force)) { Write-Error ("Line $(LINENUM):",$Install) -ErrorAction Stop }
                    }
                }
                ElseIf ([version]$OSVersion -gt [version]'6.1'){
                    If ( $PSCmdlet.ShouldProcess("NetFx3", "Add Windows Feature") ) {
                        Try {$Result=& "${env:windir}\system32\Dism.exe" /English /NoRestart /Online /Enable-Feature /FeatureName:NetFx3 2>''}
                        Catch {Write-Output "Error calling Dism.exe."; $Result=$Null}
                        Try {$Result=& "${env:windir}\system32\Dism.exe" /English /Online /Get-FeatureInfo /FeatureName:NetFx3 2>''}
                        Catch {Write-Output "Error calling Dism.exe."; $Result=$Null}
                        If ($Result -contains 'State : Enabled'){
                            Write-Warning "WARNING: Line $(LINENUM): .Net Framework 3.5 has been installed and enabled."
                        } ElseIf ($Result -contains 'State : Enable Pending'){
                            Write-Warning "WARNING: Line $(LINENUM): .Net Framework 3.5 installed but a reboot is needed."
                        } Else {
                            Write-Error "ERROR: Line $(LINENUM): .NET Framework 3.5 install failed." -ErrorAction Continue
                            If (!($Force)) { Write-Error ("ERROR: Line $(LINENUM):",$Result) -ErrorAction Stop }
                        }
                    }
                }

                $DotNET = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -recurse | Get-ItemProperty -name Version -EA 0 | Where-Object{ $_.PSChildName -match '^(?!S)\p{L}'} | Select-Object -ExpandProperty Version
            }

            If (-not ($DotNet -like '3.5.*')){
                If (($Force)) {
                    If ($DotNet -match '(?m)^[2-4].\d'){
                        Write-Error "ERROR: Line $(LINENUM): .NET 3.5 is not detected and could not be installed." -ErrorAction Continue
                    } Else {
                        Write-Error "ERROR: Line $(LINENUM): .NET 2.0 or greater is not detected and could not be installed." -ErrorAction Stop
                    }
                } Else {
                    Write-Error "ERROR: Line $(LINENUM): .NET 3.5 is not detected and could not be installed." -ErrorAction Stop
                }
            }
        }

        $InstallBase="${env:windir}\Temp\LabTech"
        $InstallMSI='Agent_Install.msi'
        $logfile = "LTAgentInstall"
        $curlog = "$($InstallBase)\$($logfile).log"
        If (-not (Test-Path -PathType Container -Path "$InstallBase\Installer" )){
            New-Item "$InstallBase\Installer" -type directory -ErrorAction SilentlyContinue | Out-Null
        }
        If ((Test-Path -PathType Leaf -Path $($curlog))){
            If ($PSCmdlet.ShouldProcess("$($curlog)","Rotate existing log file")){
                Get-Item -LiteralPath $curlog -EA 0 | Where-Object {$_} | Foreach-Object {
                    Rename-Item -Path $($_|Select-Object -Expand FullName -EA 0) -NewName "$($logfile)-$(Get-Date $($_|Select-Object -Expand LastWriteTime -EA 0) -Format 'yyyyMMddHHmmss').log" -Force -Confirm:$False -WhatIf:$False
                    Remove-Item -Path $($_|Select-Object -Expand FullName -EA 0) -Force -EA 0 -Confirm:$False -WhatIf:$False
                }
            }
        }
    }
    Process{
        If (-not ($LocationID -or $PSCmdlet.ParameterSetName -eq 'installertoken')){
            $LocationID = "1"
        }
        If (-not ($TrayPort) -or -not ($TrayPort -ge 1 -and $TrayPort -le 65535)){
            $TrayPort = "42000"
        }
        $Server=ForEach ($Svr in $Server) {If ($Svr -notmatch 'https?://.+') {"https://$($Svr)"}; $Svr}
        ForEach ($Svr in $Server) {
            If (-not ($GoodServer)) {
                If ($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$') {
                    If ($Svr -notmatch 'https?://.+') {$Svr = "http://$($Svr)"}
                    Try {
                        If ($PSCmdlet.ParameterSetName -eq 'installertoken') {
                            Write-Debug "Line $(LINENUM): Skipping Server Version Check. Using Installer Token for download."
                            $installer = "$($Svr)/LabTech/Deployment.aspx?InstallerToken=$InstallerToken"
                        } Else {
                            $SvrVerCheck = "$($Svr)/LabTech/Agent.aspx"
                            Write-Debug "Line $(LINENUM): Testing Server Response and Version: $SvrVerCheck"
                            $SvrVer = $Script:LTServiceNetWebClient.DownloadString($SvrVerCheck)
                            Write-Debug "Line $(LINENUM): Raw Response: $SvrVer"
                            $SVer = $SvrVer|select-string -pattern '(?<=[|]{6})[0-9]{1,3}\.[0-9]{1,3}'|ForEach-Object {$_.matches}|Select-Object -Expand value -EA 0
                            If ($Null -eq $SVer) {
                                Write-Verbose "Unable to test version response from $($Svr)."
                                Continue
                            }
                            If ([System.Version]$SVer -ge [System.Version]'110.374') {
                                #New Style Download Link starting with LT11 Patch 13 - Direct Location Targeting is no longer available
                                $installer = "$($Svr)/LabTech/Deployment.aspx?Probe=1&installType=msi&MSILocations=1"
                            } Else {
                                #Original URL
                                Write-Warning 'Update your damn server!'
                                $installer = "$($Svr)/LabTech/Deployment.aspx?Probe=1&installType=msi&MSILocations=$LocationID"
                            }

                            # Vuln test June 10, 2020: ConnectWise Automate API Vulnerability - Only test if version is below known minimum.
                            Try{
                                If ([System.Version]$SVer -lt [System.Version]'200.197' -or !$ServerPassword) {
                                    $HTTP_Request = [System.Net.WebRequest]::Create("$($Svr)/LabTech/Deployment.aspx")
                                    If ($HTTP_Request.GetResponse().StatusCode -eq 'OK') {
                                        $Message = @('Your server is vulnerable!!')
                                        $Message += 'https://docs.connectwise.com/ConnectWise_Automate/ConnectWise_Automate_Supportability_Statements/Supportability_Statement%3A_ConnectWise_Automate_Mitigation_Steps'
                                        Write-Warning $($Message | Out-String)
                                    }
                                }
                            }
                            Catch {
                                If (!$ServerPassword) {
                                    Write-Error 'Anonymous downloads are not allowed. ServerPassword or InstallerToken may be needed.'
                                    Continue
                                }
                            }
                            If ($ServerPassword) { $installer = "$($Svr)/LabTech/Service/LabTechRemoteAgent.msi" }
                        }

                        If ( $PSCmdlet.ShouldProcess($installer, "DownloadFile") ) {
                            Write-Debug "Line $(LINENUM): Downloading $InstallMSI from $installer"
                            $Script:LTServiceNetWebClient.DownloadFile($installer,"$InstallBase\Installer\$InstallMSI")
                            If((Test-Path "$InstallBase\Installer\$InstallMSI") -and  !((Get-Item "$InstallBase\Installer\$InstallMSI" -EA 0).length/1KB -gt 1234)) {
                                Write-Warning "WARNING: Line $(LINENUM): $InstallMSI size is below normal. Removing suspected corrupt file."
                                Remove-Item "$InstallBase\Installer\$InstallMSI" -ErrorAction SilentlyContinue -Force -Confirm:$False
                                Continue
                            }
                        }

                        If ($WhatIfPreference -eq $True) {
                            $GoodServer = $Svr
                        } ElseIf (Test-Path "$InstallBase\Installer\$InstallMSI") {
                            $GoodServer = $Svr
                            Write-Verbose "$InstallMSI downloaded successfully from server $($Svr)."
                        } Else {
                            Write-Warning "WARNING: Line $(LINENUM): Error encountered downloading from $($Svr). No installation file was received."
                            Continue
                        }
                    }
                    Catch {
                        Write-Warning "WARNING: Line $(LINENUM): Error encountered downloading from $($Svr)."
                        Continue
                    }
                } Else {
                    Write-Warning "WARNING: Line $(LINENUM): Server address $($Svr) is not formatted correctly. Example: https://lt.domain.com"
                }
            } Else {
                Write-Debug "Line $(LINENUM): Server $($GoodServer) has been selected."
                Write-Verbose "Server has already been selected - Skipping $($Svr)."
            }
        }
    }
    End{
        If ($GoodServer) {

            If ( $WhatIfPreference -eq $True -and (Get-PSCallStack)[1].Command -eq 'Redo-LTService' ) {
                Write-Debug "Line $(LINENUM): Skipping Preinstall Check: Called by Redo-LTService and ""-WhatIf=`$True"""
            } Else {
                If ((Test-Path "${env:windir}\ltsvc" -EA 0) -or (Test-Path "${env:windir}\temp\_ltupdate" -EA 0) -or (Test-Path registry::HKLM\Software\LabTech\Service -EA 0) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service -EA 0)){
                    Write-Warning "WARNING: Line $(LINENUM): Previous installation detected. Calling Uninstall-LTService"
                    Uninstall-LTService -Server $GoodServer -Force
                    Start-Sleep 10
                }
            }

            If ($WhatIfPreference -ne $True) {
                $GoodTrayPort=$Null;
                $TestTrayPort=$TrayPort;
                For ($i=0; $i -le 10; $i++) {
                    If (-not ($GoodTrayPort)) {
                        If (-not (Test-LTPorts -TrayPort $TestTrayPort -Quiet)){
                            $TestTrayPort++;
                            If ($TestTrayPort -gt 42009) {$TestTrayPort=42000}
                        } Else {
                            $GoodTrayPort=$TestTrayPort
                        }
                    }
                }
                If ($GoodTrayPort -and $GoodTrayPort -ne $TrayPort -and $GoodTrayPort -ge 1 -and $GoodTrayPort -le 65535) {
                    Write-Verbose "TrayPort $($TrayPort) is in use. Changing TrayPort to $($GoodTrayPort)"
                    $TrayPort=$GoodTrayPort
                }
                Write-Output "Starting Install."
            }

            #Build parameter string
            $iarg =(@(
                "/i `"$InstallBase\Installer\$InstallMSI`"",
                "SERVERADDRESS=$GoodServer",
                $(If ($ServerPassword -and $ServerPassword -match '.') {"SERVERPASS=""$ServerPassword"""} Else {""}),
                $(If ($LocationID -and $LocationID -match '^\d+$') {"LOCATION=$LocationID"} Else {""}),
                $(If ($TrayPort -and $TrayPort -ne 42000) {"SERVICEPORT=$TrayPort"} Else {""}),
                "/qn",
                "/l ""$InstallBase\$logfile.log""") | Where-Object {$_}) -join ' '

            Try{
                If ( $PSCmdlet.ShouldProcess("msiexec.exe $($iarg)", "Execute Install") ) {
                    $InstallAttempt=0
                    Do {
                        If ($InstallAttempt -gt 0 ) {
                            Write-Warning "WARNING: Line $(LINENUM): Service Failed to Install. Retrying in 30 seconds." -WarningAction 'Continue'
                            $timeout = new-timespan -Seconds 30
                            $sw = [diagnostics.stopwatch]::StartNew()
                            Do {
                                Start-Sleep 5
                                $svcRun = ('LTService') | Get-Service -EA 0 | Measure-Object | Select-Object -Expand Count
                            } Until ($sw.elapsed -gt $timeout -or $svcRun -eq 1)
                            $sw.Stop()
                        }
                        $InstallAttempt++
                        $svcRun = ('LTService') | Get-Service -EA 0 | Measure-Object | Select-Object -Expand Count
                        If ($svcRun -eq 0) {
                            Write-Verbose "Launching Installation Process: msiexec.exe $(($iarg -join ''))"
                            Start-Process -Wait -FilePath "${env:windir}\system32\msiexec.exe" -ArgumentList $iarg -WorkingDirectory $env:TEMP
                            Start-Sleep 5
                        }
                        $svcRun = ('LTService') | Get-Service -EA 0 | Measure-Object | Select-Object -Expand Count
                    } Until ($InstallAttempt -ge 3 -or $svcRun -eq 1)
                    If ($svcRun -eq 0) {
                        Write-Error "ERROR: Line $(LINENUM): LTService was not installed. Installation failed."
                        Return
                    }
                }
                If (($Script:LTProxy.Enabled) -eq $True) {
                    Write-Verbose "Proxy Configuration Needed. Applying Proxy Settings to Agent Installation."
                    If ( $PSCmdlet.ShouldProcess($Script:LTProxy.ProxyServerURL, "Configure Agent Proxy") ) {
                        $svcRun = ('LTService') | Get-Service -EA 0 | Where-Object {$_.Status -eq 'Running'} | Measure-Object | Select-Object -Expand Count
                        If ($svcRun -ne 0) {
                            $timeout = new-timespan -Minutes 2
                            $sw = [diagnostics.stopwatch]::StartNew()
                            Write-Host -NoNewline "Waiting for Service to Start."
                            Do {
                                Write-Host -NoNewline '.'
                                Start-Sleep 2
                                $svcRun = ('LTService') | Get-Service -EA 0 | Where-Object {$_.Status -eq 'Running'} | Measure-Object | Select-Object -Expand Count
                            } Until ($sw.elapsed -gt $timeout -or $svcRun -eq 1)
                            Write-Host ""
                            $sw.Stop()
                            If ($svcRun -eq 1) {
                                Write-Debug "Line $(LINENUM): LTService Initial Startup Successful."
                            } Else {
                                Write-Debug "Line $(LINENUM): LTService Initial Startup failed to complete within expected period."
                            }
                        }
                        Set-LTProxy -ProxyServerURL $Script:LTProxy.ProxyServerURL -ProxyUsername $Script:LTProxy.ProxyUsername -ProxyPassword $Script:LTProxy.ProxyPassword -Confirm:$False -WhatIf:$False
                    }
                } Else {
                    Write-Verbose "No Proxy Configuration has been specified - Continuing."
                }
                If (!($NoWait) -and $PSCmdlet.ShouldProcess("LTService","Monitor For Successful Agent Registration") ) {
                    $timeout = new-timespan -Minutes 3
                    $sw = [diagnostics.stopwatch]::StartNew()
                    Write-Host -NoNewline "Waiting for agent to register."
                    Do {
                        Write-Host -NoNewline '.'
                        Start-Sleep 5
                        $tmpLTSI = (Get-LTServiceInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False|Select-Object -Expand 'ID' -EA 0)
                    } Until ($sw.elapsed -gt $timeout -or $tmpLTSI -ge 1)
                    Write-Host ""
                    $sw.Stop()
                    Write-Verbose "Completed wait for LabTech Installation after $(([int32]$sw.Elapsed.TotalSeconds).ToString()) seconds."
                    $Null=Get-LTProxy -ErrorAction Continue
                }
                If ($Hide) {Hide-LTAddRemove}
            }

            Catch{
                Write-Error "ERROR: Line $(LINENUM): There was an error during the install process. $($Error[0])"
                Return
            }

            If ($WhatIfPreference -ne $True) {
                #Cleanup Install files
                Remove-Item "$InstallBase\Installer\$InstallMSI" -ErrorAction SilentlyContinue -Force -Confirm:$False
                @($curlog,"${env:windir}\LTSvc\Install.log") | Foreach-Object {
                    If ((Test-Path -PathType Leaf -LiteralPath $($_))) {
                        $logcontents=Get-Content -Path $_
                        $logcontents=$logcontents -replace '(?<=PreInstallPass:[^\r\n]+? (?:result|value)): [^\r\n]+',': <REDACTED>'
                        If ($logcontents) {Set-Content -Path $_ -Value $logcontents -Force -Confirm:$False}
                    }
                }

                $tmpLTSI = Get-LTServiceInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
                If (($tmpLTSI)) {
                    If (($tmpLTSI|Select-Object -Expand 'ID' -EA 0) -ge 1) {
                        Write-Output "LabTech has been installed successfully. Agent ID: $($tmpLTSI|Select-Object -Expand 'ID' -EA 0) LocationID: $($tmpLTSI|Select-Object -Expand 'LocationID' -EA 0)"
                    } ElseIf (!($NoWait)) {
                        Write-Error "ERROR: Line $(LINENUM): LabTech installation completed but Agent failed to register within expected period." -ErrorAction Continue
                    } Else {
                        Write-Warning "WARNING: Line $(LINENUM): LabTech installation completed but Agent did not yet register." -WarningAction Continue
                    }
                } Else {
                    If (($Error)) {
                        Write-Error "ERROR: Line $(LINENUM): There was an error installing LabTech. Check the log, $InstallBase\$logfile.log $($Error[0])"
                        Return
                    } ElseIf (!($NoWait)) {
                        Write-Error "ERROR: Line $(LINENUM): There was an error installing LabTech. Check the log, $InstallBase\$logfile.log"
                        Return
                    } Else {
                        Write-Warning "WARNING: Line $(LINENUM): LabTech installation may not have succeeded." -WarningAction Continue
                    }
                }
            }
            If (($Rename) -and $Rename -notmatch 'False'){ Rename-LTAddRemove -Name $Rename }
        } ElseIf ( $WhatIfPreference -ne $True ) {
            Write-Error "ERROR: Line $(LINENUM): No valid server was reached to use for the install."
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}