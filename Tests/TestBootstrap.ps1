<#
.SYNOPSIS
    Shared module loading bootstrap for ConnectWiseAutomateAgent tests.

.DESCRIPTION
    Loads the module using one of two methods based on the CWAA_TEST_LOAD_METHOD
    environment variable:

    - Module (default): Import-Module ConnectWiseAutomateAgent.psd1
      Standard PSGallery loading path.

    - SingleFile: Load ConnectWiseAutomateAgent.ps1 into a dynamic module via New-Module.
      Tests the concatenated single-file build used by systems without gallery access.
      The dynamic module wrapper preserves InModuleScope and Get-Module compatibility.

    Call this from BeforeAll in each test file. For discovery-time flags (Context -Skip),
    check $env:CWAA_TEST_LOAD_METHOD directly in BeforeDiscovery instead.

.EXAMPLE
    BeforeDiscovery {
        $script:IsSingleFileMode = ($env:CWAA_TEST_LOAD_METHOD -eq 'SingleFile')
    }
    BeforeAll {
        $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
    }

.OUTPUTS
    Hashtable with keys: LoadMethod, ModuleName, ModulePath, SingleFilePath, IsLoaded
#>
[CmdletBinding()]
param()

$ModuleName = 'ConnectWiseAutomateAgent'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ModulePsd1 = Join-Path $RepoRoot "$ModuleName\$ModuleName.psd1"
$SingleFilePath = Join-Path $RepoRoot "$ModuleName.ps1"

$LoadMethod = if ($env:CWAA_TEST_LOAD_METHOD -eq 'SingleFile') { 'SingleFile' } else { 'Module' }

# Remove any existing module (standard or dynamic)
Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force

if ($LoadMethod -eq 'SingleFile') {
    # SingleFile mode: load concatenated .ps1 into a dynamic module.
    # This validates the build output while preserving InModuleScope compatibility.
    if (-not (Test-Path $SingleFilePath)) {
        throw "Single-file build not found at '$SingleFilePath'. Run Build\SingleFileBuild.ps1 first."
    }

    $singleFileContent = Get-Content $SingleFilePath -Raw -ErrorAction Stop

    # Append Export-ModuleMember so [Alias()] attributes on functions are exported.
    # Without this, dynamic modules don't export aliases from function attributes.
    $singleFileContent += "`nExport-ModuleMember -Function * -Alias *"

    New-Module -Name $ModuleName -ScriptBlock ([ScriptBlock]::Create($singleFileContent)) |
        Import-Module -Force -ErrorAction Stop

    Write-Verbose "TestBootstrap: Loaded single-file into dynamic module '$ModuleName'"

    return @{
        LoadMethod     = 'SingleFile'
        ModuleName     = $ModuleName
        ModulePath     = $SingleFilePath
        SingleFilePath = $SingleFilePath
        IsLoaded       = $true
    }
}
else {
    # Module mode: standard Import-Module from manifest
    if (-not (Test-Path $ModulePsd1)) {
        throw "Module manifest not found at '$ModulePsd1'."
    }

    Import-Module $ModulePsd1 -Force -ErrorAction Stop

    Write-Verbose "TestBootstrap: Imported module '$ModuleName' from manifest"

    return @{
        LoadMethod     = 'Module'
        ModuleName     = $ModuleName
        ModulePath     = $ModulePsd1
        SingleFilePath = $SingleFilePath
        IsLoaded       = $true
    }
}
