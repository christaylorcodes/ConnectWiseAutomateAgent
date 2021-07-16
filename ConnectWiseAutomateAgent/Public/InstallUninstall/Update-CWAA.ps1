Function Update-CWAA{
    [CmdletBinding(SupportsShouldProcess=$True)]
    [Alias('Update-LTService')]
    Param(
        [parameter(Position=0)]
        [AllowNull()]
        [string]$Version
    )

    Begin{
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"
        Clear-Variable Svr, GoodServer, Settings -EA 0 -WhatIf:$False -Confirm:$False #Clearing Variables for use
        $Settings = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False
        $updaterPath = [System.Environment]::ExpandEnvironmentVariables("%windir%\temp\_LTUpdate")
        $xarg=@("/o""$updaterPath""","/y")
        $uarg=@("""$updaterPath\Update.ini""")
    }

    Process{
        if (-not ($Server)){
            If ($Settings){
                $Server = $Settings|Select-Object -Expand 'Server' -EA 0
            }
        }

        $Server=ForEach ($Svr in $Server) {If ($Svr -notmatch 'https?://.+') {"https://$($Svr)"}; $Svr}
        Foreach ($Svr in $Server) {
            If (-not ($GoodServer)) {
                If ($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$') {
                    If ($Svr -notmatch 'https?://.+') {$Svr = "http://$($Svr)"}
                    Try {
                        $SvrVerCheck = "$($Svr)/Labtech/Agent.aspx"
                        Write-Debug "Line $(LINENUM): Testing Server Response and Version: $SvrVerCheck"
                        $SvrVer = $Script:LTServiceNetWebClient.DownloadString($SvrVerCheck)
                        Write-Debug "Line $(LINENUM): Raw Response: $SvrVer"
                        $SVer = $SvrVer|select-string -pattern '(?<=[|]{6})[0-9]{1,3}\.[0-9]{1,3}'|ForEach-Object {$_.matches}|Select-Object -Expand value -EA 0
                        If ($Null -eq ($SVer)) {
                            Write-Verbose "Unable to test version response from $($Svr)."
                            Continue
                        }
                        If ($Version -match '[1-9][0-9]{2}\.[0-9]{1,3}') {
                            $updater = "$($Svr)/Labtech/Updates/LabtechUpdate_$($Version).zip"
                        } ElseIf ([System.Version]$SVer -ge [System.Version]'105.001') {
                            $Version = $SVer
                            Write-Verbose "Using detected version ($Version) from server: $($Svr)."
                            $updater = "$($Svr)/Labtech/Updates/LabtechUpdate_$($Version).zip"
                        }

                        #Kill all running processes from $updaterPath
                        if (Test-Path $updaterPath){
                            $Executables = (Get-ChildItem $updaterPath -Filter *.exe -Recurse -ErrorAction SilentlyContinue|Select-Object -Expand FullName)
                            if ($Executables) {
                                Write-Verbose "Terminating LabTech Processes from $($updaterPath) if found running: $(($Executables) -replace [Regex]::Escape($updaterPath),'' -replace '^\\','')"
                                Get-Process | Where-Object {$Executables -contains $_.Path } | ForEach-Object {
                                    Write-Debug "Line $(LINENUM): Terminating Process $($_.ProcessName)"
                                    $($_) | Stop-Process -Force -ErrorAction SilentlyContinue
                                }
                            }
                        }

                        #Remove $updaterPath - Depth First Removal, First by purging files, then Removing Folders, to get as much removed as possible if complete removal fails
                        @("$updaterPath") | foreach-object {
                            If ((Test-Path "$($_)" -EA 0)) {
                                If ( $PSCmdlet.ShouldProcess("$($_)","Remove Folder") ) {
                                    Write-Debug "Line $(LINENUM): Removing Folder: $($_)"
                                    Try {
                                        Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { ($_.psiscontainer) } | foreach-object { Get-ChildItem -Path "$($_.FullName)" -EA 0 | Where-Object { -not ($_.psiscontainer) } | Remove-Item -Force -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False }
                                        Get-ChildItem -Path $_ -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { ($_.psiscontainer) } | Sort-Object { $_.fullname.length } -Descending | Remove-Item -Force -ErrorAction SilentlyContinue -Recurse -Confirm:$False -WhatIf:$False
                                        Remove-Item -Recurse -Force -Path $_ -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                                    } Catch {}
                                }
                            }
                        }

                        Try {
                            If (-not (Test-Path -PathType Container -Path "$updaterPath" )){
                                New-Item "$updaterPath" -type directory -ErrorAction SilentlyContinue | Out-Null
                            }
                            $updaterTest = [System.Net.WebRequest]::Create($updater)
                            If (($Script:LTProxy.Enabled) -eq $True) {
                                Write-Debug "Line $(LINENUM): Proxy Configuration Needed. Applying Proxy Settings to request."
                                $updaterTest.Proxy=$Script:LTWebProxy
                            }
                            $updaterTest.KeepAlive=$False
                            $updaterTest.ProtocolVersion = '1.0'
                            $updaterResult = $updaterTest.GetResponse()
                            $updaterTest.Abort()
                            If ($updaterResult.StatusCode -ne 200) {
                                Write-Warning "WARNING: Line $(LINENUM): Unable to download LabtechUpdate.exe version $Version from server $($Svr)."
                                Continue
                            } Else {
                                If ( $PSCmdlet.ShouldProcess($updater, "DownloadFile") ) {
                                    Write-Debug "Line $(LINENUM): Downloading LabtechUpdate.exe from $updater"
                                    $Script:LTServiceNetWebClient.DownloadFile($updater,"$updaterPath\LabtechUpdate.exe")
                                    If((Test-Path "$updaterPath\LabtechUpdate.exe") -and  !((Get-Item "$updaterPath\LabtechUpdate.exe" -EA 0).length/1KB -gt 1234)) {
                                        Write-Warning "WARNING: Line $(LINENUM): LabtechUpdate.exe size is below normal. Removing suspected corrupt file."
                                        Remove-Item "$updaterPath\LabtechUpdate.exe" -ErrorAction SilentlyContinue -Force -Confirm:$False
                                        Continue
                                    }
                                }

                                If ($WhatIfPreference -eq $True) {
                                    $GoodServer = $Svr
                                } ElseIf (Test-Path "$updaterPath\LabtechUpdate.exe") {
                                    $GoodServer = $Svr
                                    Write-Verbose "LabtechUpdate.exe downloaded successfully from server $($Svr)."
                                } Else {
                                    Write-Warning "WARNING: Line $(LINENUM): Error encountered downloading from $($Svr). No update file was received."
                                    Continue
                                }
                            }
                        }
                        Catch {
                            Write-Warning "WARNING: Line $(LINENUM): Error encountered downloading $updater."
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
        $detectedVersion = $Settings|Select-Object -Expand 'Version' -EA 0
        If ($Null -eq $detectedVersion){
            Write-Error "ERROR: Line $(LINENUM): No existing installation was found." -ErrorAction Stop
            Return
        }
        If ([System.Version]$detectedVersion -ge [System.Version]$Version) {
            Write-Warning "WARNING: Line $(LINENUM): Installed version detected ($detectedVersion) is higher than or equal to the requested version ($Version)."
            Return
        }
        If (-not ($GoodServer)) {
            Write-Warning "WARNING: Line $(LINENUM): No valid server was detected."
            Return
        }
        If ([System.Version]$SVer -gt [System.Version]$Version) {
            Write-Warning "WARNING: Line $(LINENUM): Server version detected ($SVer) is higher than the requested version ($Version)."
            Return
        }

        Try{
            Stop-CWAA
        }
        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was an error stopping the services. $($Error[0])"
            Return
        }

        Write-Output "Updating Agent with the following information: Server $($GoodServer), Version $Version"
        Try{
            If ($PSCmdlet.ShouldProcess("LabtechUpdate.exe $($xarg)", "Extracting update files")) {
                If ((Test-Path "$updaterPath\LabtechUpdate.exe")) {
                    #Extract Update Files
                    Write-Verbose "Launching LabtechUpdate Self-Extractor."
                    Write-Debug "Line $(LINENUM): Executing Command ""LabtechUpdate.exe $($xarg)"""
                    Try {
                        Push-Location $updaterPath
                        & "$updaterPath\LabtechUpdate.exe" $($xarg) 2>''
                        Pop-Location
                    }
                    Catch {Write-Output "Error calling LabtechUpdate.exe."}
                    Start-Sleep -Seconds 5
                } Else {
                    Write-Verbose "WARNING: $updaterPath\LabtechUpdate.exe was not found."
                }
            }

            If ($PSCmdlet.ShouldProcess("Update.exe $($uarg)", "Launching Updater")) {
                If ((Test-Path "$updaterPath\Update.exe")) {
                    #Extract Update Files
                    Write-Verbose "Launching Labtech Updater"
                    Write-Debug "Line $(LINENUM): Executing Command ""Update.exe $($uarg)"""
                    Try {& "$updaterPath\Update.exe" $($uarg) 2>''}
                    Catch {Write-Output "Error calling Update.exe."}
                    Start-Sleep -Seconds 5
                } Else {
                    Write-Verbose "WARNING: $updaterPath\Update.exe was not found."
                }
            }

        }

        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was an error during the update process $($Error[0])" -ErrorAction Continue
        }

        Try{
            Start-CWAA
        }
        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was an error starting the services. $($Error[0])"
            Return
        }

        If ($WhatIfPreference -ne $True) {
            If ($?) {}
            Else {$Error[0]}
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}