<#
.SYNOPSIS
    Publishes the ConnectWiseAutomateAgent module to the PowerShell Gallery.

.DESCRIPTION
    Validates the module manifest, displays version and prerelease information,
    and publishes the module to the PowerShell Gallery using Publish-Module.

    Supports a dry-run mode via -WhatIf that validates the manifest and shows
    what would be published without actually calling Publish-Module.

.PARAMETER NuGetApiKey
    The API key for authenticating with the PowerShell Gallery.

.PARAMETER Force
    Bypasses NuGet dependency validation during publish. Use for CI/CD pipelines
    or when you've already validated dependencies separately.

.EXAMPLE
    ./Publish-CWAAModule.ps1 -NuGetApiKey 'your-api-key-here'
    Publishes the module to the PowerShell Gallery.

.EXAMPLE
    ./Publish-CWAAModule.ps1 -NuGetApiKey 'your-api-key-here' -WhatIf
    Validates the manifest and shows what would be published without publishing.

.EXAMPLE
    ./Publish-CWAAModule.ps1 -NuGetApiKey 'your-api-key-here' -Force
    Publishes with NuGet dependency validation bypassed (CI/CD use).

.LINK
    https://www.powershellgallery.com/packages/ConnectWiseAutomateAgent

.NOTES
    Requires PowerShell 5.0+ and the PowerShellGet module.
    The NuGetApiKey can be generated at https://www.powershellgallery.com/account/apikeys
#>
#Requires -Version 5.0
#Requires -Module PowerShellGet

[CmdletBinding(SupportsShouldProcess = $True)]
param(
    [Parameter(Mandatory = $True)]
    [string]$NuGetApiKey,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$ModuleName = 'ConnectWiseAutomateAgent'
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$RepoRoot = Split-Path $ScriptRoot -Parent
$ModulePath = Join-Path $RepoRoot $ModuleName
$ManifestPath = Join-Path $ModulePath "$ModuleName.psd1"

# ─── Validate manifest exists ───────────────────────────────────────────────
if (-not (Test-Path $ManifestPath)) {
    throw "Module manifest not found: $ManifestPath"
}

# ─── Read version info from manifest ────────────────────────────────────────
$manifestData = Import-PowerShellDataFile $ManifestPath
$moduleVersion = $manifestData.ModuleVersion
$prereleaseTag = $manifestData.PrivateData.PSData.Prerelease
$isPrerelease = [bool]$prereleaseTag
$fullVersion = if ($isPrerelease) { "$moduleVersion-$prereleaseTag" } else { $moduleVersion }

# ─── Validate manifest with Test-ModuleManifest ─────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MODULE MANIFEST VALIDATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

try {
    Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop | Out-Null
    Write-Host "Manifest validation passed." -ForegroundColor Green
}
catch {
    throw "Manifest validation failed. Error: $($_.Exception.Message)"
}

# ─── Verify module imports cleanly ────────────────────────────────────────
Write-Host "`nImport test..." -ForegroundColor Cyan
Get-Module $ModuleName | Remove-Module -Force -ErrorAction SilentlyContinue
try {
    Import-Module $ModulePath -Force -ErrorAction Stop -WarningAction SilentlyContinue
    $loadedModule = Get-Module $ModuleName
    if (-not $loadedModule) { throw 'Module did not load.' }
    Write-Host "Import test passed ($($loadedModule.ExportedFunctions.Count) functions exported)." -ForegroundColor Green
    Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue -WhatIf:$False
}
catch {
    throw "Module failed to import cleanly. Fix errors before publishing. Error: $($_.Exception.Message)"
}

# ─── Check for existing version on gallery ────────────────────────────────
try {
    $galleryModule = Find-Module -Name $ModuleName -RequiredVersion $moduleVersion -AllowPrerelease -ErrorAction SilentlyContinue
    if ($galleryModule) {
        Write-Warning "Version $fullVersion already exists on the PowerShell Gallery. Publish will likely fail."
    }
}
catch {
    # Gallery lookup failed — not fatal, continue with publish attempt
    Write-Host "Could not check gallery for existing version (this is non-fatal)." -ForegroundColor Gray
}

# ─── Display publish summary ────────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PUBLISH SUMMARY" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Module:       $ModuleName" -ForegroundColor Gray
Write-Host "Version:      $fullVersion" -ForegroundColor Gray
Write-Host "Prerelease:   $isPrerelease" -ForegroundColor $(if ($isPrerelease) { 'Yellow' } else { 'Gray' })
Write-Host "Author:       $($manifestData.Author)" -ForegroundColor Gray
Write-Host "Description:  $($manifestData.Description)" -ForegroundColor Gray
Write-Host "Source:       $ModulePath" -ForegroundColor Gray

if ($isPrerelease) {
    Write-Host "`n--- Prerelease Install Instructions ---" -ForegroundColor Yellow
    Write-Host "Install-Module -Name $ModuleName -AllowPrerelease" -ForegroundColor White
    Write-Host "Install-Module -Name $ModuleName -RequiredVersion $fullVersion -AllowPrerelease" -ForegroundColor White
}
else {
    Write-Host "`n--- Install Instructions ---" -ForegroundColor Green
    Write-Host "Install-Module -Name $ModuleName" -ForegroundColor White
    Write-Host "Install-Module -Name $ModuleName -RequiredVersion $moduleVersion" -ForegroundColor White
}

# ─── Publish or dry-run ─────────────────────────────────────────────────────
if ($PSCmdlet.ShouldProcess("$ModuleName $fullVersion", 'Publish to PowerShell Gallery')) {
    Write-Host "`nPublishing $ModuleName $fullVersion to PowerShell Gallery..." -ForegroundColor Yellow

    $publishParams = @{
        Path        = $ModulePath
        NuGetApiKey = $NuGetApiKey
        ErrorAction = 'Stop'
    }
    if ($Force) { $publishParams['Force'] = $True }

    try {
        Publish-Module @publishParams
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "PUBLISH SUCCESSFUL" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Published: $ModuleName $fullVersion" -ForegroundColor Gray
        Write-Host "Gallery:   https://www.powershellgallery.com/packages/$ModuleName" -ForegroundColor Gray
    }
    catch {
        Write-Error "Publish failed for $ModuleName $fullVersion. Error: $($_.Exception.Message)"
    }
}
else {
    Write-Host "`n========================================" -ForegroundColor Yellow
    Write-Host "DRY RUN - NO CHANGES MADE" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "Manifest validation: Passed" -ForegroundColor Green
    Write-Host "Would publish:       $ModuleName $fullVersion" -ForegroundColor Gray
    Write-Host "To:                  PowerShell Gallery" -ForegroundColor Gray
}
