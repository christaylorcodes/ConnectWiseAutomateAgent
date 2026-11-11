# Local test script - run this before pushing to catch issues early
param(
    [switch]$SkipBuild,
    [switch]$SkipTests,
    [switch]$SkipAnalyze,

    [string]$FunctionName,

    [switch]$Quick,
    [switch]$DualMode
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$quickTestScript = Join-Path $ProjectRoot 'Scripts' 'Invoke-QuickTest.ps1'
$buildScript = Join-Path $ProjectRoot 'build.ps1'

# Quick mode: skip build and delegate to Invoke-QuickTest.ps1
if ($Quick) {
    if ($FunctionName) {
        Write-Host "`n[QUICK] Running targeted test for: $FunctionName" -ForegroundColor Yellow
        & $quickTestScript -FunctionName $FunctionName -IncludeAnalyzer:(-not $SkipAnalyze)
        exit $LASTEXITCODE
    }

    # Quick without function name: run all tests directly (no build, no coverage)
    Write-Host "`n[QUICK] Running all tests (no build, no coverage)..." -ForegroundColor Yellow
    & $quickTestScript -IncludeAnalyzer:(-not $SkipAnalyze)
    exit $LASTEXITCODE
}

# Dual mode: delegate to Invoke-AllTests.ps1 (Module + BuiltModule test modes)
if ($DualMode) {
    Write-Host "`n[DUAL MODE] Running Module + BuiltModule test modes..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot 'Invoke-AllTests.ps1')
    exit $LASTEXITCODE
}

# build.ps1 throws on failure (InvokeBuild) rather than setting an exit code, so
# treat both a throw and a non-zero exit code as failure.
function Invoke-BuildStep {
    param([string[]]$Tasks)
    $global:LASTEXITCODE = 0
    try {
        # Send build output to the host: anything left in the pipeline would become part of
        # this function's return value and make the pass/fail check below always truthy.
        & $buildScript -Tasks $Tasks | Out-Host
    }
    catch {
        Write-Host $_ -ForegroundColor Red
        return $false
    }
    return [bool]($LASTEXITCODE -eq 0)
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host 'LOCAL PRE-PUSH VALIDATION' -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$steps = @(
    if (-not $SkipBuild) { 'build' }
    if (-not $SkipAnalyze) { 'analyze' }
    if (-not $SkipTests) { 'test' }
)
$stepCount = $steps.Count
$currentStep = 0

# build.ps1 adds output/ paths to PSModulePath; don't leak that into the caller's session
$savedPSModulePath = $env:PSModulePath
try {
    # 1. BUILD
    if (-not $SkipBuild) {
        $currentStep++
        Write-Host "[$currentStep/$stepCount] Building module..." -ForegroundColor Yellow
        if (-not (Invoke-BuildStep -Tasks build)) {
            Write-Host 'BUILD FAILED' -ForegroundColor Red
            exit 1  # finally still restores PSModulePath
        }
        Write-Host "BUILD PASSED`n" -ForegroundColor Green
    }

    # 2. PSScriptAnalyzer
    if (-not $SkipAnalyze) {
        $currentStep++
        Write-Host "[$currentStep/$stepCount] Running PSScriptAnalyzer..." -ForegroundColor Yellow

        $requiredModules = Join-Path $ProjectRoot 'output' 'RequiredModules'
        if (Test-Path $requiredModules) {
            $env:PSModulePath = $requiredModules + [IO.Path]::PathSeparator + $env:PSModulePath
        }
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        Write-Host "  PSScriptAnalyzer $((Get-Module PSScriptAnalyzer).Version)" -ForegroundColor DarkGray

        $settingsFile = Join-Path $ProjectRoot '.PSScriptAnalyzerSettings.psd1'
        $analyzeParams = @{}
        if (Test-Path $settingsFile) {
            $analyzeParams['Settings'] = $settingsFile
        }

        # Module source: errors AND warnings reported, errors fail.
        # Tooling (Scripts/, Templates/, .build/): errors fail, warnings are not
        # shown (these are standalone scripts that legitimately use Write-Host, etc.).
        # Analyze .ps1/.psm1 only; .psd1 excluded due to PSScriptAnalyzer NullRef bug.
        $sourceFiles = Get-ChildItem -Path (Join-Path $ProjectRoot 'source') -Include '*.ps1', '*.psm1' -Recurse -File
        $toolingFiles = 'Scripts', 'Templates', '.build' |
            ForEach-Object { Join-Path $ProjectRoot $_ } |
            Where-Object { Test-Path $_ } |
            ForEach-Object { Get-ChildItem -Path $_ -Include '*.ps1', '*.psm1' -Recurse -File }

        $results = @($sourceFiles | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName @analyzeParams })
        $results += @($toolingFiles | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName -Severity Error })

        if ($results) {
            $results | Format-Table -AutoSize
            $errors = @($results | Where-Object Severity -EQ 'Error')

            if ($errors) {
                Write-Host "PSScriptAnalyzer found $($errors.Count) error(s)" -ForegroundColor Red
                exit 1  # finally still restores PSModulePath
            }
            Write-Host "PSScriptAnalyzer warnings found (but no errors)`n" -ForegroundColor Yellow
        }
        else {
            Write-Host "PSScriptAnalyzer PASSED - no issues found`n" -ForegroundColor Green
        }
    }

    # 3. TESTS
    if (-not $SkipTests) {
        $currentStep++
        Write-Host "[$currentStep/$stepCount] Running Pester tests..." -ForegroundColor Yellow

        if ($FunctionName) {
            Write-Host "Targeted test for: $FunctionName" -ForegroundColor Cyan
            & $quickTestScript -FunctionName $FunctionName
            $passed = ($LASTEXITCODE -eq 0)
        }
        else {
            $passed = Invoke-BuildStep -Tasks test
        }

        if (-not $passed) {
            Write-Host 'TESTS FAILED' -ForegroundColor Red
            exit 1  # finally still restores PSModulePath
        }
        Write-Host "TESTS PASSED`n" -ForegroundColor Green
    }

    Write-Host '========================================' -ForegroundColor Green
    Write-Host 'ALL LOCAL CHECKS PASSED!' -ForegroundColor Green
    Write-Host "========================================`n" -ForegroundColor Green
    Write-Host "Ready to push to GitHub`n"
}
finally {
    $env:PSModulePath = $savedPSModulePath
}

exit 0
