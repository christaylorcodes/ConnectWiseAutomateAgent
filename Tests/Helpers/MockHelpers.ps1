<#
.SYNOPSIS
    Shared mock data factories for ConnectWiseAutomateAgent Pester tests.

.DESCRIPTION
    Provides reusable functions that create commonly-needed mock data objects.
    These helpers return PSCustomObjects that tests use as mock return values,
    reducing duplication of inline mock data across test files.

    Mock wiring (Mock CommandName { ... }) stays inline in each test since
    the mock setup varies per test scenario.

.NOTES
    Dot-source this file in BeforeAll blocks:
        . "$PSScriptRoot\Helpers\MockHelpers.ps1"
#>

function New-MockAgentInfo {
    <#
    .SYNOPSIS
        Creates a PSCustomObject matching the shape of Get-CWAAInfo output.
    #>
    param(
        [string]$ID = '12345',
        [string[]]$Server = @('automate.example.com'),
        [string]$LocationID = '1',
        [string]$BasePath = 'C:\Windows\LTSVC',
        [string]$Version = '230.105',
        [string]$LastSuccessStatus,
        [string]$HeartbeatLastSent,
        [string]$HeartbeatLastReceived,
        [string]$TrayPort,
        [string]$ServerPassword,
        [string]$Password,
        [string]$Probe,
        [string]$MAC
    )

    $obj = [PSCustomObject]@{
        ID              = $ID
        Server          = $Server
        LocationID      = $LocationID
        BasePath        = $BasePath
        Version         = $Version
    }

    if ($LastSuccessStatus)     { $obj | Add-Member -NotePropertyName 'LastSuccessStatus'     -NotePropertyValue $LastSuccessStatus }
    if ($HeartbeatLastSent)     { $obj | Add-Member -NotePropertyName 'HeartbeatLastSent'     -NotePropertyValue $HeartbeatLastSent }
    if ($HeartbeatLastReceived) { $obj | Add-Member -NotePropertyName 'HeartbeatLastReceived' -NotePropertyValue $HeartbeatLastReceived }
    if ($TrayPort)              { $obj | Add-Member -NotePropertyName 'TrayPort'              -NotePropertyValue $TrayPort }
    if ($ServerPassword)        { $obj | Add-Member -NotePropertyName 'ServerPassword'        -NotePropertyValue $ServerPassword }
    if ($Password)              { $obj | Add-Member -NotePropertyName 'Password'              -NotePropertyValue $Password }
    if ($Probe)                 { $obj | Add-Member -NotePropertyName 'Probe'                 -NotePropertyValue $Probe }
    if ($MAC)                   { $obj | Add-Member -NotePropertyName 'MAC'                   -NotePropertyValue $MAC }

    return $obj
}

function New-MockRunningService {
    <#
    .SYNOPSIS
        Creates a PSCustomObject matching a Windows service object.
    #>
    param(
        [string]$Name = 'LTService',
        [string]$Status = 'Running'
    )

    return [PSCustomObject]@{
        Name   = $Name
        Status = $Status
    }
}

function New-MockRegistryEntry {
    <#
    .SYNOPSIS
        Creates a PSCustomObject matching Get-ItemProperty output with PS provider properties.
    #>
    param(
        [hashtable]$Properties = @{},
        [switch]$IncludePSProperties
    )

    $obj = [PSCustomObject]$Properties

    if ($IncludePSProperties) {
        $obj | Add-Member -NotePropertyName 'PSPath'       -NotePropertyValue 'fake'
        $obj | Add-Member -NotePropertyName 'PSParentPath' -NotePropertyValue 'fake'
        $obj | Add-Member -NotePropertyName 'PSChildName'  -NotePropertyValue 'fake'
        $obj | Add-Member -NotePropertyName 'PSDrive'      -NotePropertyValue 'fake'
        $obj | Add-Member -NotePropertyName 'PSProvider'   -NotePropertyValue 'fake'
    }

    return $obj
}
