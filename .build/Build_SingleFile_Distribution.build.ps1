# Synopsis: Build the standalone single-file .ps1 distribution for GitHub Releases.
# This task takes the compiled .psm1 from ModuleBuilder output and produces a
# standalone ConnectWiseAutomateAgent.ps1 that can be executed directly.

task Build_SingleFile_Distribution {
    $moduleName = 'ConnectWiseAutomateAgent'
    $outputBase = Join-Path $OutputDirectory $moduleName

    # Find the built module (latest version directory)
    $builtManifest = Get-ChildItem -Path "$outputBase\*\$moduleName.psd1" -ErrorAction SilentlyContinue |
        Sort-Object { [version](Split-Path (Split-Path $_.FullName -Parent) -Leaf) } -Descending |
        Select-Object -First 1

    if (-not $builtManifest) {
        throw "Built module manifest not found in $outputBase. Run Build_ModuleOutput_ModuleBuilder first."
    }

    $versionDir = Split-Path $builtManifest.FullName -Parent
    $builtPsm1 = Join-Path $versionDir "$moduleName.psm1"

    if (-not (Test-Path $builtPsm1)) {
        throw "Built .psm1 not found at $builtPsm1"
    }

    # Read version from built manifest
    $manifest = Import-PowerShellDataFile $builtManifest.FullName
    $version = $manifest.ModuleVersion
    $prerelease = $manifest.PrivateData.PSData.Prerelease
    $fullVersion = if ($prerelease) { "$version-$prerelease" } else { $version }

    # Build header
    $header = @"
# $moduleName $fullVersion
# Single-file distribution - built $(Get-Date -Format 'yyyy-MM-dd')
# https://github.com/christaylorcodes/ConnectWiseAutomateAgent

"@

    # Write single-file output.
    # Strip Export-ModuleMember because the .ps1 is dot-sourced or IEX'd outside
    # a module context where that cmdlet is not valid.
    $singleFilePath = Join-Path $OutputDirectory "$moduleName.ps1"
    $header | Out-File $singleFilePath -Force -Encoding UTF8
    Get-Content $builtPsm1 |
        Where-Object { $_ -notmatch '^\s*Export-ModuleMember\b' } |
        Out-File $singleFilePath -Append -Encoding UTF8

    $lineCount = (Get-Content $singleFilePath | Measure-Object).Count
    $size = (Get-Item $singleFilePath).Length
    Write-Build Green "Single-file built: $singleFilePath ($lineCount lines, $([math]::Round($size / 1KB, 1)) KB)"
}
