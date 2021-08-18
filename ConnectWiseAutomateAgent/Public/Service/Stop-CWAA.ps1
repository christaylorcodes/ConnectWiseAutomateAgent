function Stop-CWAA {
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Stop-LTService')]
    Param()

    Begin {
        Clear-Variable sw, timeout, svcRun -EA 0 -WhatIf:$False -Confirm:$False -Verbose:$False #Clearing Variables for use
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"
    }

    Process {
        if (-not (Get-Service 'LTService', 'LTSvcMon' -ErrorAction SilentlyContinue)) {
            if ($WhatIfPreference -ne $True) {
                Write-Error "ERROR: Line $(LINENUM): Services NOT Found $($Error[0])"
                return
            }
            else {
                Write-Error "What If: Line $(LINENUM): Stopping: Services NOT Found"
                return
            }
        }
        if ($PSCmdlet.ShouldProcess('LTService, LTSvcMon', 'Stop-Service')) {
            $Null = Invoke-CWAACommand ('Kill VNC', 'Kill Trays') -EA 0 -WhatIf:$False -Confirm:$False
            Write-Verbose 'Stopping Labtech Services'
            Try {
                ('LTService', 'LTSvcMon') | ForEach-Object {
                    Try { $Null = & "$env:windir\system32\sc.exe" stop "$($_)" 2>'' }
                    Catch { Write-Output 'Error calling sc.exe.' }
                }
                $timeout = New-TimeSpan -Minutes 1
                $sw = [diagnostics.stopwatch]::StartNew()
                Write-Host -NoNewline 'Waiting for Services to Stop.'
                Do {
                    Write-Host -NoNewline '.'
                    Start-Sleep 2
                    $svcRun = ('LTService', 'LTSvcMon') | Get-Service -EA 0 | Where-Object { $_.Status -ne 'Stopped' } | Measure-Object | Select-Object -Expand Count
                } Until ($sw.elapsed -gt $timeout -or $svcRun -eq 0)
                Write-Host ''
                $sw.Stop()
                if ($svcRun -gt 0) {
                    Write-Verbose "Services did not stop. Terminating Processes after $(([int32]$sw.Elapsed.TotalSeconds).ToString()) seconds."
                }
                Get-Process | Where-Object { @('LTTray', 'LTSVC', 'LTSvcMon') -contains $_.ProcessName } | Stop-Process -Force -ErrorAction Stop -WhatIf:$False -Confirm:$False
            }

            Catch {
                Write-Error "ERROR: Line $(LINENUM): There was an error stopping the LabTech processes. $($Error[0])"
                return
            }
        }
    }

    End {
        if ($WhatIfPreference -ne $True) {
            if ($?) {
                If ((('LTService', 'LTSvcMon') | Get-Service -EA 0 | Where-Object { $_.Status -ne 'Stopped' } | Measure-Object | Select-Object -Expand Count) -eq 0) {
                    Write-Output 'Services Stopped successfully.'
                }
                else {
                    Write-Warning "WARNING: Line $(LINENUM): Services have not stopped completely."
                }
            }
            else { $Error[0] }
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}
