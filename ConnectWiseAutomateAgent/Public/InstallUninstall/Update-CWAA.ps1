function Update-CWAA {
    <#
    .SYNOPSIS
        Manually updates the ConnectWise Automate Agent to a specified version.
    .DESCRIPTION
        Downloads and applies an agent update from the ConnectWise Automate server. The function
        reads the current server configuration from the agent's registry settings, downloads the
        appropriate update package, extracts it, and runs the updater.

        If no version is specified, the function uses the version advertised by the server.
        The function validates that the requested version is higher than the currently installed
        version and not higher than the server version before proceeding.

        The update process:
        1. Reads current agent settings and server information
        2. Downloads the LabtechUpdate.exe for the target version
        3. Stops agent services
        4. Extracts and runs the update
        5. Restarts agent services
    .PARAMETER Version
        The target agent version to update to.
        Example: 120.240
        If omitted, the version advertised by the server will be used.
    .EXAMPLE
        Update-CWAA -Version 120.240
        Updates the agent to the specific version requested.
    .EXAMPLE
        Update-CWAA
        Updates the agent to the current version advertised by the server.
    .NOTES
        Author: Darren White
        Alias: Update-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Update-LTService')]
    Param(
        [parameter(Position = 0)]
        [AllowNull()]
        [string]$Version,
        [switch]$SkipCertificateCheck
    )

    Begin {
        Write-Debug "Starting $($myInvocation.InvocationName)"

        # Lazy initialization of SSL/TLS, WebClient, and proxy configuration.
        # Only runs once per session, skips immediately on subsequent calls.
        $Null = Initialize-CWAANetworking -SkipCertificateCheck:$SkipCertificateCheck

        $Settings = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False
        $updaterPath = [System.Environment]::ExpandEnvironmentVariables('%windir%\temp\_LTUpdate')
        $extractArguments = @("/o""$updaterPath""", '/y')
        $updaterArguments = @("""$updaterPath\Update.ini""")
    }

    Process {
        if (-not $Server) {
            if ($Settings) {
                $Server = $Settings | Select-Object -Expand 'Server' -EA 0
            }
        }

        # Resolve the first reachable server and its advertised version
        if (-not $Server) { return }
        $serverResult = Resolve-CWAAServer -Server $Server
        if ($serverResult) {
            $GoodServer = $serverResult.ServerUrl
            $serverVersion = $serverResult.ServerVersion
        }

        if ($GoodServer) {
            # Determine the target version and build the update download URL
            if ($Version -match '[1-9][0-9]{2}\.[0-9]{1,3}') {
                $updater = "$GoodServer/Labtech/Updates/LabtechUpdate_$Version.zip"
            }
            Elseif ([System.Version]$serverVersion -ge [System.Version]'105.001') {
                $Version = $serverVersion
                Write-Verbose "Using detected version ($Version) from server: $GoodServer."
                $updater = "$GoodServer/Labtech/Updates/LabtechUpdate_$Version.zip"
            }

            # Kill all running processes from $updaterPath before cleanup
            if (Test-Path $updaterPath) {
                $Executables = (Get-ChildItem $updaterPath -Filter *.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -Expand FullName)
                if ($Executables) {
                    Write-Verbose "Terminating Automate agent processes from $updaterPath if found running: $(($Executables) -replace [Regex]::Escape($updaterPath),'' -replace '^\\','')"
                    Get-Process | Where-Object { $Executables -contains $_.Path } | ForEach-Object {
                        Write-Debug "Terminating Process $($_.ProcessName)"
                        $_ | Stop-Process -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            # Remove stale updater directory using depth-first removal
            Remove-CWAAFolderRecursive -Path $updaterPath

            Try {
                if (-not (Test-Path -PathType Container -Path $updaterPath)) {
                    New-Item $updaterPath -type directory -ErrorAction SilentlyContinue | Out-Null
                }
                $updaterTest = [System.Net.WebRequest]::Create($updater)
                if (($Script:LTProxy.Enabled) -eq $True) {
                    Write-Debug "Proxy Configuration Needed. Applying Proxy Settings to request."
                    $updaterTest.Proxy = $Script:LTWebProxy
                }
                $updaterTest.KeepAlive = $False
                $updaterTest.ProtocolVersion = '1.0'
                $updaterResult = $updaterTest.GetResponse()
                $updaterTest.Abort()
                if ($updaterResult.StatusCode -ne 200) {
                    Write-Warning "Unable to download LabtechUpdate.exe version $Version from server $GoodServer."
                    $GoodServer = $null
                }
                else {
                    if ($PSCmdlet.ShouldProcess($updater, 'DownloadFile')) {
                        Write-Debug "Downloading LabtechUpdate.exe from $updater"
                        $Script:LTServiceNetWebClient.DownloadFile($updater, "$updaterPath\LabtechUpdate.exe")
                        if (-not (Test-CWAADownloadIntegrity -FilePath "$updaterPath\LabtechUpdate.exe" -FileName 'LabtechUpdate.exe')) {
                            $GoodServer = $null
                        }
                    }

                    if ($GoodServer) {
                        if ($WhatIfPreference -ne $True -and -not (Test-Path "$updaterPath\LabtechUpdate.exe")) {
                            Write-Warning "Error encountered downloading from $GoodServer. No update file was received."
                            $GoodServer = $null
                        }
                        else {
                            Write-Verbose "LabtechUpdate.exe downloaded successfully from server $GoodServer."
                        }
                    }
                }
            }
            Catch {
                Write-Warning "Error encountered downloading $updater."
                $GoodServer = $null
            }
        }
    }

    End {
        $detectedVersion = $Settings | Select-Object -Expand 'Version' -EA 0
        if ($Null -eq $detectedVersion) {
            Write-Error "No existing installation was found." -ErrorAction Stop
            Return
        }
        if ([System.Version]$detectedVersion -ge [System.Version]$Version) {
            Write-Warning "Installed version detected ($detectedVersion) is higher than or equal to the requested version ($Version)."
            Return
        }
        if (-not $GoodServer) {
            Write-Warning "No valid server was detected."
            Return
        }
        if ([System.Version]$serverVersion -gt [System.Version]$Version) {
            Write-Warning "Server version detected ($serverVersion) is higher than the requested version ($Version)."
            Return
        }

        Try {
            Stop-CWAA
        }
        Catch {
            Write-Error "There was an error stopping the services. $_"
            Write-CWAAEventLog -EventId 1032 -EntryType Error -Message "Agent update failed - unable to stop services. Error: $($_.Exception.Message)"
            Return
        }

        Write-Output "Updating Agent with the following information: Server $GoodServer, Version $Version"
        Try {
            if ($PSCmdlet.ShouldProcess("LabtechUpdate.exe $extractArguments", 'Extracting update files')) {
                if (Test-Path "$updaterPath\LabtechUpdate.exe") {
                    Write-Verbose 'Launching LabtechUpdate Self-Extractor.'
                    Write-Debug "Executing Command ""LabtechUpdate.exe $extractArguments"""
                    Try {
                        Push-Location $updaterPath
                        & "$updaterPath\LabtechUpdate.exe" $extractArguments 2>''
                        Pop-Location
                    }
                    Catch { Write-Output 'Error calling LabtechUpdate.exe.' }
                    Start-Sleep -Seconds 5
                }
                else {
                    Write-Verbose "$updaterPath\LabtechUpdate.exe was not found."
                }
            }

            if ($PSCmdlet.ShouldProcess("Update.exe $updaterArguments", 'Launching Updater')) {
                if (Test-Path "$updaterPath\Update.exe") {
                    Write-Verbose 'Launching Labtech Updater'
                    Write-Debug "Executing Command ""Update.exe $updaterArguments"""
                    Try { & "$updaterPath\Update.exe" $updaterArguments 2>'' }
                    Catch { Write-Output 'Error calling Update.exe.' }
                    Start-Sleep -Seconds 5
                }
                else {
                    Write-Verbose "$updaterPath\Update.exe was not found."
                }
            }
        }
        Catch {
            Write-Error "There was an error during the update process. $_" -ErrorAction Continue
            Write-CWAAEventLog -EventId 1032 -EntryType Error -Message "Agent update process failed. Error: $($_.Exception.Message)"
        }

        Try {
            Start-CWAA
        }
        Catch {
            Write-Error "There was an error starting the services. $_"
            Write-CWAAEventLog -EventId 1032 -EntryType Error -Message "Agent update completed but services failed to start. Error: $($_.Exception.Message)"
            Return
        }

        Write-CWAAEventLog -EventId 1030 -EntryType Information -Message "Agent updated successfully to version $Version."
        Write-Debug "Exiting $($myInvocation.InvocationName)"
    }
}
