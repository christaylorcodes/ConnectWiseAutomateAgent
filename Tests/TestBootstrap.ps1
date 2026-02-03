<#
.SYNOPSIS
    Shared module loading bootstrap for ConnectWiseAutomateAgent tests.

.DESCRIPTION
    Loads the module using one of two methods based on the CWAA_TEST_LOAD_METHOD
    environment variable:

    - Module (default): Import-Module from source/ConnectWiseAutomateAgent.psd1
      Development source — dot-sources individual .ps1 files at import time.

    - BuiltModule: Import-Module from the compiled output built by ModuleBuilder.
      Tests the artifact that ships to PSGallery and GitHub Releases.

    Call this from BeforeAll in each test file. For discovery-time flags (Context -Skip),
    check $env:CWAA_TEST_LOAD_METHOD directly in BeforeDiscovery instead.

.EXAMPLE
    BeforeDiscovery {
        $script:IsBuiltModuleMode = ($env:CWAA_TEST_LOAD_METHOD -eq 'BuiltModule')
    }
    BeforeAll {
        $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
    }

.OUTPUTS
    Hashtable with keys: LoadMethod, ModuleName, ModulePath, BuiltModulePath, IsLoaded
#>
[CmdletBinding()]
param()

$ModuleName = 'ConnectWiseAutomateAgent'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ModulePsd1 = Join-Path $RepoRoot "source\$ModuleName.psd1"

# Find the built module manifest (latest version directory under output/)
$BuiltModulePsd1 = Get-ChildItem -Path (Join-Path $RepoRoot "output\$ModuleName\*\$ModuleName.psd1") -ErrorAction SilentlyContinue |
    Sort-Object { [version](Split-Path (Split-Path $_.FullName -Parent) -Leaf) } -Descending |
    Select-Object -First 1

$LoadMethod = if ($env:CWAA_TEST_LOAD_METHOD -eq 'BuiltModule') { 'BuiltModule' } else { 'Module' }

# Remove any existing module
Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force

if ($LoadMethod -eq 'BuiltModule') {
    # BuiltModule mode: Import-Module from the compiled output.
    # This validates the ModuleBuilder-compiled .psm1 and manifest with explicit exports.
    if (-not $BuiltModulePsd1) {
        throw "Built module not found in 'output/$ModuleName/'. Run './build.ps1 -Tasks build' first."
    }

    Import-Module $BuiltModulePsd1.FullName -Force -ErrorAction Stop

    Write-Verbose "TestBootstrap: Imported built module from '$($BuiltModulePsd1.FullName)'"

    return @{
        LoadMethod      = 'BuiltModule'
        ModuleName      = $ModuleName
        ModulePath      = $BuiltModulePsd1.FullName
        BuiltModulePath = $BuiltModulePsd1.FullName
        IsLoaded        = $true
    }
}
else {
    # Module mode: standard Import-Module from source manifest
    if (-not (Test-Path $ModulePsd1)) {
        throw "Module manifest not found at '$ModulePsd1'."
    }

    Import-Module $ModulePsd1 -Force -ErrorAction Stop

    Write-Verbose "TestBootstrap: Imported module '$ModuleName' from manifest"

    return @{
        LoadMethod      = 'Module'
        ModuleName      = $ModuleName
        ModulePath      = $ModulePsd1
        BuiltModulePath = if ($BuiltModulePsd1) { $BuiltModulePsd1.FullName } else { $null }
        IsLoaded        = $true
    }
}
