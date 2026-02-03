function Test-CWAAServiceExists {
    <#
    .SYNOPSIS
        Tests whether the Automate agent services are installed on the local computer.
    .DESCRIPTION
        Checks for the existence of the LTService and LTSvcMon services using the
        centralized $Script:CWAAServiceNames constant. Returns $true if at least one
        service is found, $false otherwise.

        When -WriteErrorOnMissing is specified, writes a WhatIf-aware error message
        if the services are not found. This consolidates the duplicated service existence
        check pattern found in Start-CWAA, Stop-CWAA, Restart-CWAA, and Reset-CWAA.
    .PARAMETER WriteErrorOnMissing
        When specified, writes a Write-Error message if the services are not found.
        The error message is WhatIf-aware (includes 'What If:' prefix when
        $WhatIfPreference is $true in the caller's scope).
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    Param(
        [switch]$WriteErrorOnMissing
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        $services = Get-Service $Script:CWAAServiceNames -ErrorAction SilentlyContinue
        if ($services) {
            return $true
        }

        if ($WriteErrorOnMissing) {
            $prefix = if ($WhatIfPreference) { 'What If: ' } else { '' }
            Write-Error "${prefix}Services NOT Found."
        }
        return $false
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
