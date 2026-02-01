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

# Quick mode: skip build and delegate to Invoke-QuickTest.ps1
if ($Quick) {
    $quickTestScript = Join-Path $ProjectRoot 'Scripts\Invoke-QuickTest.ps1'

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

# Dual mode: delegate to Invoke-AllTests.ps1
if ($DualMode) {
    Write-Host "`n[DUAL MODE] Running Module + SingleFile test modes..." -ForegroundColor Yellow
    $allTestsScript = Join-Path $PSScriptRoot 'Invoke-AllTests.ps1'
    & $allTestsScript
    exit $LASTEXITCODE
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "LOCAL PRE-PUSH VALIDATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$stepCount = 3
$currentStep = 0

# 1. BUILD
if (-not $SkipBuild) {
    $currentStep++
    Write-Host "[$currentStep/$stepCount] Building single-file distribution..." -ForegroundColor Yellow
    $buildScript = Join-Path $ProjectRoot 'Build\SingleFileBuild.ps1'

    if (Test-Path $buildScript) {
        & powershell -NoProfile -NonInteractive -File $buildScript
        if ($LASTEXITCODE -ne 0) {
            Write-Host "BUILD FAILED" -ForegroundColor Red
            exit 1
        }
        Write-Host "BUILD PASSED`n" -ForegroundColor Green
    }
    else {
        Write-Host "WARNING: Build script not found at '$buildScript', skipping build`n" -ForegroundColor Yellow
    }
}

# 2. PSScriptAnalyzer
if (-not $SkipAnalyze) {
    $currentStep++
    Write-Host "[$currentStep/$stepCount] Running PSScriptAnalyzer..." -ForegroundColor Yellow
    Import-Module PSScriptAnalyzer -ErrorAction Stop

    $sourcePath = Join-Path $ProjectRoot 'ConnectWiseAutomateAgent'
    $settingsFile = Join-Path $ProjectRoot '.PSScriptAnalyzerSettings.psd1'

    $analyzeParams = @{
        Path    = $sourcePath
        Recurse = $true
    }
    if (Test-Path $settingsFile) {
        $analyzeParams['Settings'] = $settingsFile
    }

    $results = Invoke-ScriptAnalyzer @analyzeParams

    if ($results) {
        $results | Format-Table -AutoSize
        $errors = @($results | Where-Object Severity -eq 'Error')

        if ($errors.Count -gt 0) {
            Write-Host "PSScriptAnalyzer found $($errors.Count) error(s)" -ForegroundColor Red
            exit 1
        }
        else {
            Write-Host "PSScriptAnalyzer warnings found (but no errors)`n" -ForegroundColor Yellow
        }
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
        $quickTestScript = Join-Path $ProjectRoot 'Scripts\Invoke-QuickTest.ps1'
        & $quickTestScript -FunctionName $FunctionName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "TESTS FAILED" -ForegroundColor Red
            exit 1
        }
    }
    else {
        $config = New-PesterConfiguration
        $config.Run.Path = $PSScriptRoot
        $config.Filter.ExcludeTag = @('Live')
        $config.Output.Verbosity = 'Detailed'
        $config.Run.Exit = $true
        Invoke-Pester -Configuration $config
        if ($LASTEXITCODE -ne 0) {
            Write-Host "TESTS FAILED" -ForegroundColor Red
            exit 1
        }
    }
    Write-Host "TESTS PASSED`n" -ForegroundColor Green
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "ALL LOCAL CHECKS PASSED!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green
Write-Host "Ready to push to GitHub`n"
