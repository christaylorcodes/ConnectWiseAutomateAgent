<#
.SYNOPSIS
    Template for ConnectWise Automate deployed scripts using the ScriptHelper functions.

.DESCRIPTION
    Copy this template as a starting point for new Automate scripts. It demonstrates
    the recommended pattern for scripts deployed via ConnectWise Automate using the
    ConnectWiseAutomateAgent module's Scripting helpers.

    Output Format:  Status=<Success|Failed|Error>|Result=<message>|LogPath=<path>|Data=<data>
    Module:         ConnectWiseAutomateAgent

.PARAMETER Service
    Example parameter — the name of a Windows service to check.

.NOTES
    Version:        1.0
    Author:         <Name>
    Creation Date:  <Date>
    Purpose/Change: Initial script development
    Deployment:     ConnectWise Automate

.EXAMPLE
    .\ScriptHelper-AutomateTemplate.ps1 -Service 'LTService'
#>
[CmdletBinding()]
Param(
    [string]$Service = 'LTService'
)

#region-[Declarations]----------------------------------------------------------

#requires -version 5

$ErrorActionPreference = 'Stop'
[version]$ScriptVersion = '1.0.0'

# ConnectWise Automate template variables (replaced at runtime by the Automate agent)
# $ComputerPassword = '%ComputerPassword%'
# $LocationID       = '%LocationID%'
# $ClientID         = '%clientid%'
# $ComputerID       = '%Computerid%'

#endregion Declarations

#region-[Initializations]-------------------------------------------------------

# TLS Security Protocol
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# Load module
Import-Module ConnectWiseAutomateAgent -ErrorAction Stop

#endregion Initializations

#region-[Functions]-------------------------------------------------------------

function Invoke-MainLogic {
    [CmdletBinding()]
    param()

    # Create output object and initialize logging
    $output = New-CWAAScriptOutput
    $output.LogPath = Initialize-CWAAScriptLog -LogName 'ServiceCheck'

    Write-CWAAScriptLog -Message "Script v$ScriptVersion started" -LogPath $output.LogPath
    Write-CWAAScriptLog -Message "Checking service: $Service" -LogPath $output.LogPath

    # --- Your script logic here ---

    $svc = Get-Service $Service -ErrorAction SilentlyContinue

    if (-not $svc) {
        $output.Status = 'Error'
        $output.Result = "Service '$Service' not found"
        Write-CWAAScriptLog -Message $output.Result -Level ERROR -LogPath $output.LogPath
        return $output.ToString()
    }

    $message = "$Service is $($svc.Status)"
    $output.Result = $message

    if ($svc.Status -ne 'Running') {
        $output.Status = 'Failed'
        Write-CWAAScriptLog -Message $message -Level WARNING -LogPath $output.LogPath
    }
    else {
        Write-CWAAScriptLog -Message $message -LogPath $output.LogPath
    }

    # Optional: return structured data for Automate EDFs/variables
    $output.Data = "ServiceName=$Service,ServiceStatus=$($svc.Status)"

    Write-CWAAScriptLog -Message 'Script completed' -LogPath $output.LogPath
    $output.ToString()
}

#endregion Functions

#region-[Execution]-------------------------------------------------------------

try {
    Invoke-MainLogic -ErrorAction Stop
}
catch {
    # Fallback error output if something fails before the output object is created
    (New-CWAAScriptOutput -Status 'Error' -Result $_.Exception.Message).ToString()
}

#endregion Execution
