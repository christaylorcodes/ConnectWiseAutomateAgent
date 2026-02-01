param(
    [switch]$BuildDocs
)

$ModuleName = 'ConnectWiseAutomateAgent'
$PathRoot = '.'
$Initialize = 'Initialize-CWAA'
$FileName = "$($ModuleName).ps1"
$FullPath = Join-Path $PathRoot $FileName
$ModulePath = Join-Path $PathRoot $ModuleName
$ManifestPath = Join-Path $ModulePath "$ModuleName.psd1"

Try {
    # Read version and prerelease tag from manifest
    $version = $null
    $prerelease = $null
    if (Test-Path $ManifestPath) {
        $manifest = Import-PowerShellDataFile $ManifestPath -ErrorAction SilentlyContinue
        if ($manifest) {
            $version = $manifest.ModuleVersion
            $prerelease = $manifest.PrivateData.PSData.Prerelease
        }
    }
    $fullVersion = if ($prerelease) { "$version-$prerelease" } else { $version }

    # Build header
    $header = @"
# $ModuleName $fullVersion
# Single-file distribution - built $(Get-Date -Format 'yyyy-MM-dd')
# https://github.com/christaylorcodes/ConnectWiseAutomateAgent

"@

    # Concatenate all .ps1 files from the module directory
    $sourceFiles = Get-ChildItem (Join-Path $PathRoot $ModuleName) -Filter '*.ps1' -Recurse
    if (-not $sourceFiles) {
        Write-Error "No .ps1 files found in $ModulePath"
        return
    }

    $content = $sourceFiles | ForEach-Object {
        (Get-Content $_.FullName | Where-Object { $_ })
    }

    # Write header, content, and initialization call
    $header | Out-File $FullPath -Force -Encoding UTF8
    $content | Out-File $FullPath -Append -Encoding UTF8
    $Initialize | Out-File $FullPath -Append -Encoding UTF8

    # Validate output
    if (-not (Test-Path $FullPath)) {
        Write-Error "Build failed: output file was not created."
        return
    }

    $outputSize = (Get-Item $FullPath).Length
    if ($outputSize -eq 0) {
        Write-Error "Build failed: output file is empty."
        return
    }

    $lineCount = (Get-Content $FullPath | Measure-Object).Count
    Write-Output "Build successful: $FullPath ($lineCount lines, $([math]::Round($outputSize / 1KB, 1)) KB)"

    # Version consistency check: verify manifest version matches CHANGELOG latest entry
    $changelogPath = Join-Path $PathRoot 'CHANGELOG.md'
    if (Test-Path $changelogPath) {
        $changelogContent = Get-Content $changelogPath -Raw
        # Match the first version heading: ## [1.0.0] or ## [1.0.0-alpha001]
        if ($changelogContent -match '## \[([^\]]+)\]') {
            $changelogVersion = $Matches[1]
            if ($changelogVersion -ne $fullVersion) {
                Write-Warning "Version mismatch: manifest says '$fullVersion' but CHANGELOG.md latest entry is '$changelogVersion'. Update CHANGELOG.md before release."
            }
            else {
                Write-Output "Version consistency check passed: $fullVersion"
            }
        }
        else {
            Write-Warning 'CHANGELOG.md found but no version heading detected.'
        }
    }
    else {
        Write-Warning 'CHANGELOG.md not found. Consider creating one for release tracking.'
    }

    # Optionally build documentation
    if ($BuildDocs) {
        Write-Output 'Building documentation...'
        $docBuildScript = Join-Path $PSScriptRoot 'Build-Documentation.ps1'
        if (Test-Path $docBuildScript) {
            & $docBuildScript -UpdateExisting
        }
        else {
            Write-Warning "Documentation build script not found: $docBuildScript"
        }
    }
}
Catch {
    Write-Error "Build failed. $_"
}
