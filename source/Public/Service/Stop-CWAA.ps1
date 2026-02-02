function Stop-CWAA {
    <#
    .SYNOPSIS
        Stops the ConnectWise Automate agent services.
    .DESCRIPTION
        Verifies that the Automate agent services (LTService, LTSvcMon) are present, then
        attempts to stop them gracefully via sc.exe. Waits up to one minute for the
        services to reach a Stopped state. If they do not stop in time, remaining
        Automate agent processes (LTTray, LTSVC, LTSvcMon) are forcefully terminated.
    .EXAMPLE
        Stop-CWAA
        Stops the ConnectWise Automate agent services.
    .EXAMPLE
        Stop-CWAA -WhatIf
        Shows what would happen without actually stopping the services.
    .NOTES
        Author: Chris Taylor
        Alias: Stop-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Stop-LTService')]
    Param()

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        if (-not (Test-CWAAServiceExists -WriteErrorOnMissing)) { return }
        if ($PSCmdlet.ShouldProcess('LTService, LTSvcMon', 'Stop-Service')) {
            $Null = Invoke-CWAACommand ('Kill VNC', 'Kill Trays') -EA 0 -WhatIf:$False -Confirm:$False
            Write-Verbose 'Stopping Automate agent services.'
            Try {
                $Script:CWAAServiceNames | ForEach-Object {
                    Try {
                        $Null = & "$env:windir\system32\sc.exe" stop "$($_)" 2>''
                        if ($LASTEXITCODE -ne 0) {
                            Write-Warning "sc.exe stop returned exit code $LASTEXITCODE for service '$_'."
                        }
                    }
                    Catch { Write-Debug "Failed to call sc.exe stop for service $_." }
                }
                $servicesStopped = Wait-CWAACondition -Condition {
                    $count = $Script:CWAAServiceNames | Get-Service -EA 0 | Where-Object { $_.Status -ne 'Stopped' } | Measure-Object | Select-Object -Expand Count
                    $count -eq 0
                } -TimeoutSeconds $Script:CWAAServiceWaitTimeoutSec -IntervalSeconds 2 -Activity 'Services stopping'
                if (-not $servicesStopped) {
                    Write-Verbose 'Services did not stop in time. Terminating processes.'
                }
                Get-Process | Where-Object { $Script:CWAAAgentProcessNames -contains $_.ProcessName } | Stop-Process -Force -ErrorAction Stop -WhatIf:$False -Confirm:$False

                # Verify final state and report
                $remainingCount = $Script:CWAAServiceNames | Get-Service -EA 0 | Where-Object { $_.Status -ne 'Stopped' } | Measure-Object | Select-Object -Expand Count
                if ($remainingCount -eq 0) {
                    Write-Output 'Services stopped successfully.'
                    Write-CWAAEventLog -EventId 2010 -EntryType Information -Message 'Agent services stopped successfully.'
                }
                else {
                    Write-Warning 'Services have not stopped completely.'
                    Write-CWAAEventLog -EventId 2011 -EntryType Warning -Message 'Agent services did not stop completely.'
                }
            }
            Catch {
                Write-Error "There was an error stopping the Automate agent processes. $_"
                Write-CWAAEventLog -EventId 2012 -EntryType Error -Message "Agent service stop failed. Error: $($_.Exception.Message)"
            }
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
