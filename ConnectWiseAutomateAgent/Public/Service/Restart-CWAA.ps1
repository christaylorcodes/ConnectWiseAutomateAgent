Function Restart-CWAA {
    [CmdletBinding(SupportsShouldProcess=$True)]
    [Alias('Restart-LTService')]
    Param()

    Begin{
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"
    }

    Process{
        if (-not (Get-Service 'LTService','LTSvcMon' -ErrorAction SilentlyContinue)) {
            If ($WhatIfPreference -ne $True) {
                Write-Error "ERROR: Line $(LINENUM): Services NOT Found $($Error[0])"
                return
            } Else {
                Write-Error "What-If: Line $(LINENUM): Stopping: Services NOT Found"
                return
            }
        }
        Try{
            Stop-CWAA
        }
        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was an error stopping the services. $($Error[0])"
            return
        }

        Try{
            Start-CWAA
        }
        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was an error starting the services. $($Error[0])"
            return
        }
    }

    End{
        If ($WhatIfPreference -ne $True) {
            If ($?) {Write-Output "Services Restarted successfully."}
            Else {$Error[0]}
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}
