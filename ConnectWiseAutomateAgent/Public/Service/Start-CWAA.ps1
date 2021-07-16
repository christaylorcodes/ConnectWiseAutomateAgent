Function Start-CWAA {
    [CmdletBinding(SupportsShouldProcess=$True)]
    [Alias('Start-LTService')]
    Param()

    Begin{
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"
        #Identify processes that are using the tray port
        [array]$processes = @()
        $Port = (Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False|Select-Object -Expand TrayPort -EA 0)
        if (-not ($Port)) {$Port = "42000"}
        $startedSvcCount=0
    }

    Process{
        If (-not (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
            If ($WhatIfPreference -ne $True) {
                Write-Error "ERROR: Line $(LINENUM): Services NOT Found $($Error[0])"
                return
            } Else {
                Write-Error "What If: Line $(LINENUM): Stopping: Services NOT Found"
                return
            }
        }
        Try{
            If((('LTService') | Get-Service -EA 0 | Where-Object {$_.Status -eq 'Stopped'} | Measure-Object | Select-Object -Expand Count) -gt 0) {
                Try {$netstat=& "$env:windir\system32\netstat.exe" -a -o -n 2>'' | Select-String -Pattern " .*[0-9\.]+:$($Port).*[0-9\.]+:[0-9]+ .*?([0-9]+)" -EA 0}
                Catch {Write-Output "Error calling netstat.exe."; $netstat=$null}
                Foreach ($line in $netstat){
                    $processes += ($line -split ' {4,}')[-1]
                }
                $processes = $processes | Where-Object {$_ -gt 0 -and $_ -match '^\d+$'}| Sort-Object | Get-Unique
                If ($processes) {
                    Foreach ($proc in $processes){
                        Write-Output "Process ID:$proc is using port $Port. Killing process."
                        Try{Stop-Process -ID $proc -Force -Verbose -EA Stop}
                        Catch {
                            Write-Warning "WARNING: Line $(LINENUM): There was an issue killing the following process: $proc"
                            Write-Warning "WARNING: Line $(LINENUM): This generally means that a 'protected application' is using this port."
                            $newPort = [int]$port + 1
                            if($newPort -gt 42009) {$newPort = 42000}
                            Write-Warning "WARNING: Line $(LINENUM): Setting tray port to $newPort."
                            New-ItemProperty -Path "HKLM:\Software\Labtech\Service" -Name TrayPort -PropertyType String -Value $newPort -Force -WhatIf:$False -Confirm:$False | Out-Null
                        }
                    }
                }
            }
            If ($PSCmdlet.ShouldProcess("LTService, LTSvcMon", "Start Service")) {
                @('LTService','LTSvcMon') | ForEach-Object {
                    If (Get-Service $_ -EA 0) {
                        Set-Service $_ -StartupType Automatic -EA 0 -Confirm:$False -WhatIf:$False
                        $Null=& "$env:windir\system32\sc.exe" start "$($_)" 2>''
                        $startedSvcCount++
                        Write-Debug "Line $(LINENUM): Executed Start Service for $($_)"
                    }
                }
            }
        }

        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was an error starting the LabTech services. $($Error[0])"
            return
        }
    }

    End{
        If ($WhatIfPreference -ne $True) {
            If ($?){
                $svcnotRunning = ('LTService') | Get-Service -EA 0 | Where-Object {$_.Status -ne 'Running'} | Measure-Object | Select-Object -Expand Count
                If ($svcnotRunning -gt 0 -and $startedSvcCount -eq 2) {
                    $timeout = new-timespan -Minutes 1
                    $sw = [diagnostics.stopwatch]::StartNew()
                    Write-Host -NoNewline "Waiting for Services to Start."
                    Do {
                        Write-Host -NoNewline '.'
                        Start-Sleep 2
                        $svcnotRunning = ('LTService') | Get-Service -EA 0 | Where-Object {$_.Status -ne 'Running'} | Measure-Object | Select-Object -Expand Count
                    } Until ($sw.elapsed -gt $timeout -or $svcnotRunning -eq 0)
                    Write-Host ""
                    $sw.Stop()
                }
                If ($svcnotRunning -eq 0) {
                    Write-Output "Services Started successfully."
                    $Null=Invoke-CWAACommand 'Send Status' -EA 0 -Confirm:$False
                } ElseIf ($startedSvcCount -gt 0) {
                    Write-Output "Service Start was issued but LTService has not reached Running state."
                } Else {
                    Write-Output "Service Start was not issued."
                }
            }
            Else{
                $($Error[0])
            }
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}
