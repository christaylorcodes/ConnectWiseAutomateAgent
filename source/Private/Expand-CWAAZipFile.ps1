function Expand-CWAAZipFile {
    <#
    .SYNOPSIS
        Extracts a ZIP file on any supported PowerShell version.
    .DESCRIPTION
        Install-CWAA receives the agent installer as a ZIP from current Automate servers.
        Expand-Archive only exists from PowerShell 5.0, and the agent has to be installable
        on Windows 7 and Server 2008 R2 as shipped (PowerShell 2.0), so this uses
        Expand-Archive when it is available and the Windows shell's own ZIP support otherwise.

        Existing files in the destination are overwritten. A failure is a terminating error.
    .PARAMETER Path
        The ZIP file to extract. The shell only treats a file as a ZIP when its name ends in .zip.
    .PARAMETER DestinationPath
        The folder to extract into. It is created if it does not exist.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$Path,

        [Parameter(Mandatory = $True)]
        [string]$DestinationPath
    )

    # Called through the command object, so nothing here names a cmdlet that PowerShell 2.0 lacks
    $expandArchiveCommand = Get-Command -Name 'Expand-Archive' -ErrorAction SilentlyContinue
    if ($expandArchiveCommand) {
        & $expandArchiveCommand $Path -DestinationPath $DestinationPath -Force -ErrorAction Stop
        return
    }

    Write-Debug 'Expand-Archive is not available (PowerShell before 5.0). Extracting with the Windows shell.'
    if (-not (Test-Path -Path $DestinationPath -PathType Container)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $shell = New-Object -ComObject Shell.Application
    $zipFolder = $shell.NameSpace("$Path")
    if (-not $zipFolder) {
        Throw "Unable to open '$Path' as a ZIP file."
    }
    $destinationFolder = $shell.NameSpace("$DestinationPath")
    # The shell item's Path ends in the real file name; its Name can lose the extension.
    $expectedNames = @($zipFolder.Items() | ForEach-Object { Split-Path -Path $_.Path -Leaf })

    # 4 = no progress dialog, 16 = answer "Yes to All" (overwrite). The copy can return before
    # the files are written, so wait until every top-level item has appeared.
    $destinationFolder.CopyHere($zipFolder.Items(), 20)
    $deadline = (Get-Date).AddSeconds(120)
    Do {
        $missingNames = @($expectedNames | Where-Object { -not (Test-Path -Path (Join-Path $DestinationPath $_)) })
        if ($missingNames.Count -gt 0) { Start-Sleep -Milliseconds 500 }
    } While ($missingNames.Count -gt 0 -and (Get-Date) -lt $deadline)
    if ($missingNames.Count -gt 0) {
        Throw "Extracting '$Path' did not produce: $($missingNames -join ', ')."
    }
}
