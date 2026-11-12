function Expand-CWAAZipFile {
    <#
    .SYNOPSIS
        Extracts a ZIP file on any supported PowerShell version.
    .DESCRIPTION
        Install-CWAA receives the agent installer as a ZIP from current Automate servers.
        Expand-Archive only exists from PowerShell 5.0, and the agent has to be installable
        on Windows 7 and Server 2008 R2 as shipped (PowerShell 2.0), so this tries, in order:

        1. Expand-Archive (PowerShell 5.0 and later).
        2. System.IO.Compression.ZipFile (.NET 4.5, so PowerShell 3.0 and 4.0). No user interface involved.
        3. The Windows shell's ZIP folder support (.NET 3.5 / PowerShell 2.0). This is the last resort:
           it is not present on Server Core, and it is a desktop component being driven from a script.

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

    # 1. Called through the command object, so nothing here names a cmdlet that PowerShell 2.0 lacks
    $expandArchiveCommand = Get-Command -Name 'Expand-Archive' -ErrorAction SilentlyContinue
    if ($expandArchiveCommand) {
        & $expandArchiveCommand $Path -DestinationPath $DestinationPath -Force -ErrorAction Stop
        return
    }

    if (-not (Test-Path -Path $DestinationPath -PathType Container)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }
    $destinationRoot = [System.IO.Path]::GetFullPath("$DestinationPath").TrimEnd('\') + '\'

    # 2. Only the assembly load is allowed to fail quietly; a bad archive must still be an error
    $zipFileAvailable = $False
    Try {
        Add-Type -AssemblyName 'System.IO.Compression.FileSystem' -ErrorAction Stop
        $zipFileAvailable = $True
    }
    Catch {
        Write-Debug "System.IO.Compression.ZipFile is not available (.NET before 4.5): $($_.Exception.Message)"
    }
    if ($zipFileAvailable) {
        $archive = [System.IO.Compression.ZipFile]::OpenRead("$Path")
        Try {
            foreach ($entry in $archive.Entries) {
                $targetPath = [System.IO.Path]::GetFullPath((Join-Path $destinationRoot $entry.FullName))
                if (-not $targetPath.StartsWith($destinationRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                    Throw "ZIP entry '$($entry.FullName)' would be written outside '$DestinationPath'."
                }
                if ($entry.FullName -match '[\\/]$') {
                    New-Item -Path $targetPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    continue
                }
                $targetFolder = Split-Path -Path $targetPath -Parent
                if (-not (Test-Path -Path $targetFolder -PathType Container)) {
                    New-Item -Path $targetFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
                }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targetPath, $True)
            }
        }
        Finally {
            $archive.Dispose()
        }
        return
    }

    # 3. Windows shell
    Write-Debug 'Extracting with the Windows shell.'
    $zipFolder = $Null
    Try {
        $shell = New-Object -ComObject Shell.Application -ErrorAction Stop
        $zipFolder = $shell.NameSpace("$Path")
    }
    Catch {
        Write-Debug "The Windows shell is not available: $($_.Exception.Message)"
    }
    if (-not $zipFolder) {
        Throw "Unable to open '$Path' as a ZIP file. Extracting it needs PowerShell 5.0, .NET 4.5, or the Windows shell, which Server Core does not have."
    }
    $destinationFolder = $shell.NameSpace("$DestinationPath")
    # The shell item's Path ends in the real file name; its Name can lose the extension.
    $expectedPaths = @($zipFolder.Items() | ForEach-Object { Join-Path $destinationRoot (Split-Path -Path $_.Path -Leaf) })

    # Remove what an earlier run left behind. Otherwise the shell asks whether to overwrite (with nobody
    # there to answer in a service session), and an old file would pass for a freshly extracted one.
    foreach ($expectedPath in $expectedPaths) {
        if (Test-Path -Path $expectedPath) { Remove-Item -Path $expectedPath -Recurse -Force -ErrorAction Stop }
    }

    # 4 = no progress dialog, 16 = answer "Yes to All". The copy can return before the files are
    # written, so wait until every top-level item exists and is no longer being written.
    $destinationFolder.CopyHere($zipFolder.Items(), 20)
    $deadline = (Get-Date).AddSeconds(120)
    Do {
        $pendingPaths = @($expectedPaths | Where-Object {
                if (-not (Test-Path -Path $_)) { return $True }
                if (Test-Path -Path $_ -PathType Container) { return $False }
                Try {
                    $stream = [System.IO.File]::Open($_, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
                    $stream.Close()
                    return $False
                }
                Catch { return $True }
            })
        if ($pendingPaths.Count -gt 0) { Start-Sleep -Milliseconds 500 }
    } While ($pendingPaths.Count -gt 0 -and (Get-Date) -lt $deadline)
    if ($pendingPaths.Count -gt 0) {
        Throw "Extracting '$Path' did not finish writing: $(($pendingPaths | ForEach-Object { Split-Path -Path $_ -Leaf }) -join ', ')."
    }
}
