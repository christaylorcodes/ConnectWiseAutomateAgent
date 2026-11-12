<#
.SYNOPSIS
    Runs the full test suite against both module loading methods in separate processes.

.DESCRIPTION
    Executes the entire Pester test suite twice — once in Module mode (standard
    Import-Module from source manifest) and once in BuiltModule mode (Import-Module
    from the compiled ModuleBuilder output). Each mode runs in its own pwsh process
    to prevent .NET state leakage (SSL callbacks, compiled types, etc.).

    The module is rebuilt automatically before the BuiltModule run.

.PARAMETER ExcludeTag
    Pester tags to exclude. Defaults to 'Live'.

.PARAMETER TestPath
    Path to test files. Defaults to the Tests directory containing this script.

.PARAMETER SkipBuild
    Skip the module rebuild before the BuiltModule mode run.

.EXAMPLE
    .\Tests\Invoke-AllTests.ps1
    Runs both modes, excluding Live tests.

.EXAMPLE
    .\Tests\Invoke-AllTests.ps1 -ExcludeTag 'Live','Slow'
    Runs both modes, excluding Live and Slow tagged tests.

.EXAMPLE
    .\Tests\Invoke-AllTests.ps1 -SkipBuild
    Runs both modes without rebuilding the module first.

.NOTES
    Exit code is non-zero if any test fails in either mode.
#>
[CmdletBinding()]
param(
    [string[]]$ExcludeTag = @('Live'),
    [string]$TestPath,
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $TestPath) {
    $TestPath = $PSScriptRoot
}

# --- Locate pwsh / powershell executables ---
$pwshExe = if ($PSVersionTable.PSEdition -eq 'Core') {
    (Get-Process -Id $PID).Path
} else {
    # Running in Windows PowerShell — prefer pwsh if available, else use self
    $found = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($found) { $found.Source } else { (Get-Process -Id $PID).Path }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ConnectWiseAutomateAgent — Dual-Mode Test Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PowerShell: $pwshExe" -ForegroundColor Gray
Write-Host "  Test path:  $TestPath" -ForegroundColor Gray
Write-Host "  Exclude:    $($ExcludeTag -join ', ')" -ForegroundColor Gray
Write-Host ""

# --- Build exclude tag argument ---
$excludeTagArg = ($ExcludeTag | ForEach-Object { "'$_'" }) -join ','

# --- Helper: run Pester in a child process ---
function Invoke-PesterInProcess {
    [CmdletBinding()]
    param(
        [string]$Mode,
        [string]$Label
    )

    Write-Host "`n----------------------------------------" -ForegroundColor Yellow
    Write-Host "  $Label" -ForegroundColor Yellow
    Write-Host "----------------------------------------" -ForegroundColor Yellow

    # Both modes use the pinned Pester in output/RequiredModules when it is there, the same
    # one the build uses, rather than whichever version the machine has installed.
    $requiredModules = Join-Path $RepoRoot 'output' | Join-Path -ChildPath 'RequiredModules'
    $pesterCommand = @"
`$env:CWAA_TEST_LOAD_METHOD = '$Mode'
if (Test-Path -LiteralPath '$($requiredModules -replace "'","''")') { `$env:PSModulePath = '$($requiredModules -replace "'","''")' + [IO.Path]::PathSeparator + `$env:PSModulePath }
`$config = New-PesterConfiguration
`$config.Run.Path = '$($TestPath -replace "'","''")'
`$config.Filter.ExcludeTag = @($excludeTagArg)
`$config.Output.Verbosity = 'Detailed'
`$config.Run.Exit = `$true
Invoke-Pester -Configuration `$config
"@

    & $pwshExe -NoProfile -NonInteractive -Command $pesterCommand | Out-Host
    return $LASTEXITCODE
}

# ============================================
# Mode 1: Module (standard Import-Module from source)
# ============================================
$moduleExitCode = Invoke-PesterInProcess -Mode 'Module' -Label 'Mode 1/2: Module Import (Source)'

# ============================================
# Rebuild module before BuiltModule mode
# ============================================
if (-not $SkipBuild) {
    Write-Host "`n  Rebuilding module (Sampler/ModuleBuilder)..." -ForegroundColor Gray
    $buildScript = Join-Path $RepoRoot 'build.ps1'
    # A failed build must fail the run: testing the previous build output would report on
    # code that is no longer in source/. build.ps1 throws on failure (InvokeBuild).
    if (-not (Test-Path $buildScript)) {
        Write-Host "  ERROR: Build script not found at '$buildScript'" -ForegroundColor Red
        exit 1
    }
    $global:LASTEXITCODE = 0
    try { & $buildScript -Tasks build | Out-Host }
    catch {
        Write-Host "  ERROR: Build failed: $_" -ForegroundColor Red
        exit 1
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Build exited with code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Build completed." -ForegroundColor Green
}

# ============================================
# Mode 2: BuiltModule (compiled ModuleBuilder output)
# ============================================
$builtModuleExitCode = Invoke-PesterInProcess -Mode 'BuiltModule' -Label 'Mode 2/2: Built Module (Compiled Output)'

# ============================================
# Summary
# ============================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$moduleStatus = if ($moduleExitCode -eq 0) { 'PASS' } else { 'FAIL' }
$builtModuleStatus = if ($builtModuleExitCode -eq 0) { 'PASS' } else { 'FAIL' }
$moduleColor = if ($moduleExitCode -eq 0) { 'Green' } else { 'Red' }
$builtModuleColor = if ($builtModuleExitCode -eq 0) { 'Green' } else { 'Red' }

Write-Host "  Module mode:      " -NoNewline; Write-Host $moduleStatus -ForegroundColor $moduleColor
Write-Host "  BuiltModule mode: " -NoNewline; Write-Host $builtModuleStatus -ForegroundColor $builtModuleColor
Write-Host ""

# Exit with non-zero if either mode failed
$finalExitCode = if ($moduleExitCode -ne 0 -or $builtModuleExitCode -ne 0) { 1 } else { 0 }

if ($finalExitCode -eq 0) {
    Write-Host "  All tests passed in both modes." -ForegroundColor Green
} else {
    Write-Host "  One or more modes had failures." -ForegroundColor Red
}

Write-Host ""
exit $finalExitCode
