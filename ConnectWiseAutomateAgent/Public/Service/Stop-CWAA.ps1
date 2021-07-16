Function Stop-CWAA{
    [CmdletBinding(SupportsShouldProcess=$True)]
    [Alias('Stop-LTService')]
    Param()

    Begin{
        Clear-Variable sw,timeout,svcRun -EA 0 -WhatIf:$False -Confirm:$False -Verbose:$False #Clearing Variables for use
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"
    }

    Process{
        if (-not (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
            If ($WhatIfPreference -ne $True) {
                Write-Error "ERROR: Line $(LINENUM): Services NOT Found $($Error[0])"
                return
            } Else {
                Write-Error "What If: Line $(LINENUM): Stopping: Services NOT Found"
                return
            }
        }
        If ($PSCmdlet.ShouldProcess("LTService, LTSvcMon", "Stop-Service")) {
            $Null=Invoke-CWAACommand ('Kill VNC','Kill Trays') -EA 0 -WhatIf:$False -Confirm:$False
            Write-Verbose "Stopping Labtech Services"
            Try{
                ('LTService','LTSvcMon') | Foreach-Object {
                    Try {$Null=& "$env:windir\system32\sc.exe" stop "$($_)" 2>''}
                    Catch {Write-Output "Error calling sc.exe."}
                }
                $timeout = new-timespan -Minutes 1
                $sw = [diagnostics.stopwatch]::StartNew()
                Write-Host -NoNewline "Waiting for Services to Stop."
                Do {
                    Write-Host -NoNewline '.'
                    Start-Sleep 2
                    $svcRun = ('LTService','LTSvcMon') | Get-Service -EA 0 | Where-Object {$_.Status -ne 'Stopped'} | Measure-Object | Select-Object -Expand Count
                } Until ($sw.elapsed -gt $timeout -or $svcRun -eq 0)
                Write-Host ""
                $sw.Stop()
                if ($svcRun -gt 0) {
                    Write-Verbose "Services did not stop. Terminating Processes after $(([int32]$sw.Elapsed.TotalSeconds).ToString()) seconds."
                }
                Get-Process | Where-Object {@('LTTray','LTSVC','LTSvcMon') -contains $_.ProcessName } | Stop-Process -Force -ErrorAction Stop -Whatif:$False -Confirm:$False
            }

            Catch{
                Write-Error "ERROR: Line $(LINENUM): There was an error stopping the LabTech processes. $($Error[0])"
                return
            }
        }
    }

    End{
        If ($WhatIfPreference -ne $True) {
            If ($?) {
                If((('LTService','LTSvcMon') | Get-Service -EA 0 | Where-Object {$_.Status -ne 'Stopped'} | Measure-Object | Select-Object -Expand Count) -eq 0){
                    Write-Output "Services Stopped successfully."
                } Else {
                    Write-Warning "WARNING: Line $(LINENUM): Services have not stopped completely."
                }
            } Else {$Error[0]}
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}
