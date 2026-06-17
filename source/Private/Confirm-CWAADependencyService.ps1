function Confirm-CWAADependencyService {
    <#
    .SYNOPSIS
        Ensures the OS services the Automate agent depends on are Automatic and Running.
    .DESCRIPTION
        Iterates the services named in $Script:CWAADependencyServiceNames (winmgmt/WMI by
        default) and makes sure each is set to Automatic startup and is Running. The agent
        relies on WMI for inventory, scripting, and check-in, and this module's own
        Get-CimInstance calls fail silently when winmgmt is disabled, so this runs before
        install, repair, and service start.

        For each dependency service:
          - If the service is not present, it is skipped (logged via Write-Debug).
          - Startup type is set to Automatic unconditionally. This is done without reading
            the current StartMode (which would require Win32_Service via WMI, the very
            service that may be down) and is idempotent.
          - If the service is not Running, a start is attempted via Start-Service (which
            resolves dependencies such as RpcSs), falling back to sc.exe start. The function
            then polls up to $Script:CWAAServiceWaitTimeoutSec for the Running state.

        Remediation outcomes are written to the Windows Event Log (EventIds 2030-2032).
        Honors -WhatIf via ShouldProcess; under -WhatIf no changes are made.
    .PARAMETER ServiceName
        One or more service names to ensure. Defaults to $Script:CWAADependencyServiceNames.
        Exposed primarily for testing.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter()]
        [string[]]$ServiceName = $Script:CWAADependencyServiceNames
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        foreach ($name in $ServiceName) {
            $service = Get-Service $name -ErrorAction SilentlyContinue
            if (-not $service) {
                Write-Debug "Dependency service '$name' not found. Skipping."
                continue
            }

            Try {
                # Force Automatic startup. Set unconditionally; reading the current start mode
                # reliably needs WMI, which may be the disabled service we are repairing.
                if ($PSCmdlet.ShouldProcess($name, 'Set service startup type to Automatic')) {
                    Set-Service $name -StartupType Automatic -EA 0 -Confirm:$False -WhatIf:$False
                }

                # Start the service if it is not already running.
                $service = Get-Service $name -ErrorAction SilentlyContinue
                if ($service -and $service.Status -ne 'Running') {
                    if ($PSCmdlet.ShouldProcess($name, 'Start service')) {
                        Write-Verbose "Dependency service '$name' is $($service.Status). Starting."
                        Try {
                            Start-Service $name -ErrorAction Stop -WhatIf:$False -Confirm:$False
                        }
                        Catch {
                            # Fall back to sc.exe, consistent with the rest of the module.
                            Write-Debug "Start-Service failed for '$name' ($($_.Exception.Message)). Falling back to sc.exe."
                            $Null = & "$env:windir\system32\sc.exe" start "$name" 2>''
                        }

                        # GetNewClosure bakes the loop-local $name into the scriptblock so it
                        # resolves correctly when Wait-CWAACondition invokes it from its own scope.
                        $running = Wait-CWAACondition -Condition {
                            (Get-Service $name -EA 0 | Select-Object -Expand Status -EA 0) -eq 'Running'
                        }.GetNewClosure() -TimeoutSeconds $Script:CWAAServiceWaitTimeoutSec -IntervalSeconds 2 -Activity "Dependency service '$name' starting"

                        if ($running) {
                            Write-Verbose "Dependency service '$name' is Running."
                            Write-CWAAEventLog -EventId 2030 -EntryType Information -Message "Dependency service '$name' set to Automatic and started."
                        }
                        else {
                            Write-Warning "Dependency service '$name' did not reach the Running state."
                            Write-CWAAEventLog -EventId 2031 -EntryType Warning -Message "Dependency service '$name' was set to Automatic but did not reach the Running state."
                        }
                    }
                }
                else {
                    Write-Debug "Dependency service '$name' is already Running."
                }
            }
            Catch {
                Write-Warning "Failed to ensure dependency service '$name'. $($_.Exception.Message)"
                Write-CWAAEventLog -EventId 2032 -EntryType Error -Message "Failed to ensure dependency service '$name'. Error: $($_.Exception.Message)"
            }
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
