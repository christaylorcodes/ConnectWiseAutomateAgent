<#
.SYNOPSIS
    Fast targeted test runner for AI agent closed-loop development.

.DESCRIPTION
    Runs Pester tests for a specific function, test file, or the full suite
    without the overhead of the full build pipeline. Designed for rapid
    write-test-fix-retest cycles.

    Does NOT build the single-file distribution or compute code coverage.
    For full validation, use Tests/test-local.ps1.

.PARAMETER FunctionName
    Name of the function to test. Uses Pester's FullName filter to match
    tests across all test files (e.g., -FunctionName Install-CWAA matches
    all Describe/Context/It blocks containing 'Install-CWAA').

.PARAMETER TestFile
    Run a specific test file by short name or full path.
    Short names: Module, DataReaders, Commands, ServiceOps, CrossCutting,
    PrivateHelpers, Installation, Documentation, Security, CrossVersion, Live.

.PARAMETER IncludeAnalyzer
    Also run PSScriptAnalyzer on the function source file (with -FunctionName)
    or the entire module directory (without -FunctionName).

.PARAMETER OutputFormat
    'Human' for colored console output with clear PASS/FAIL markers (default).
    'Structured' for JSON output that AI agents can parse.

.PARAMETER ExcludeTag
    Pester tags to exclude. Defaults to 'Live'.

.EXAMPLE
    .\Scripts\Invoke-QuickTest.ps1 -FunctionName Install-CWAA
    Quick-test a single function across all test files.

.EXAMPLE
    .\Scripts\Invoke-QuickTest.ps1 -FunctionName Install-CWAA -IncludeAnalyzer -OutputFormat Structured
    Quick-test with lint check, JSON output for AI parsing.

.EXAMPLE
    .\Scripts\Invoke-QuickTest.ps1 -TestFile Installation
    Run only the installation mocked test suite.

.EXAMPLE
    .\Scripts\Invoke-QuickTest.ps1
    Run all tests without build or coverage overhead.
#>
[CmdletBinding(DefaultParameterSetName = 'All')]
param(
    [Parameter(ParameterSetName = 'ByFunction', Position = 0)]
    [string]$FunctionName,

    [Parameter(ParameterSetName = 'ByTestFile', Position = 0)]
    [string]$TestFile,

    [switch]$IncludeAnalyzer,

    [ValidateSet('Human', 'Structured')]
    [string]$OutputFormat = 'Human',

    [string[]]$ExcludeTag = @('Live')
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TestsPath = Join-Path $ProjectRoot 'Tests'
$SourcePath = Join-Path $ProjectRoot 'ConnectWiseAutomateAgent'

# --- Short name mapping for test files ---

$testFileMap = @{
    'Module'         = 'ConnectWiseAutomateAgent.Module.Tests.ps1'
    'DataReaders'    = 'ConnectWiseAutomateAgent.Mocked.DataReaders.Tests.ps1'
    'Commands'       = 'ConnectWiseAutomateAgent.Mocked.Commands.Tests.ps1'
    'ServiceOps'     = 'ConnectWiseAutomateAgent.Mocked.ServiceOps.Tests.ps1'
    'CrossCutting'   = 'ConnectWiseAutomateAgent.Mocked.CrossCutting.Tests.ps1'
    'PrivateHelpers' = 'ConnectWiseAutomateAgent.Mocked.PrivateHelpers.Tests.ps1'
    'Installation'   = 'ConnectWiseAutomateAgent.Mocked.Installation.Tests.ps1'
    'Documentation'  = 'ConnectWiseAutomateAgent.Documentation.Tests.ps1'
    'Security'       = 'ConnectWiseAutomateAgent.Security.Tests.ps1'
    'CrossVersion'   = 'ConnectWiseAutomateAgent.CrossVersion.Tests.ps1'
    'Live'           = 'ConnectWiseAutomateAgent.Live.Tests.ps1'
}

# --- Resolve test path and filter ---

$testFilePath = $TestsPath
$fullNameFilter = $null

if ($PSCmdlet.ParameterSetName -eq 'ByFunction') {
    # Run all test files but filter to tests matching the function name
    $fullNameFilter = "*$FunctionName*"
}
elseif ($PSCmdlet.ParameterSetName -eq 'ByTestFile') {
    # Resolve short name or use as-is
    if ($testFileMap.ContainsKey($TestFile)) {
        $testFilePath = Join-Path $TestsPath $testFileMap[$TestFile]
    }
    elseif (Test-Path $TestFile) {
        $testFilePath = $TestFile
    }
    else {
        $msg = "ERROR: Test file '$TestFile' not found. Valid short names: $($testFileMap.Keys -join ', ')"
        if ($OutputFormat -eq 'Structured') {
            @{
                success          = $false
                totalTests       = 0
                passed           = 0
                failed           = 0
                skipped          = 0
                duration         = '0s'
                failedTests      = @()
                analyzerErrors   = @()
                analyzerWarnings = @()
                summary          = $msg
            } | ConvertTo-Json -Depth 5
        }
        else {
            Write-Host $msg -ForegroundColor Red
        }
        exit 1
    }
}

# --- Run Pester ---

$config = New-PesterConfiguration
$config.Run.Path = $testFilePath
$config.Run.PassThru = $true
$config.CodeCoverage.Enabled = $false
$config.TestResult.Enabled = $false

if ($ExcludeTag) {
    $config.Filter.ExcludeTag = $ExcludeTag
}

if ($fullNameFilter) {
    $config.Filter.FullName = $fullNameFilter
}

if ($OutputFormat -eq 'Structured') {
    $config.Output.Verbosity = 'None'
}
else {
    $config.Output.Verbosity = 'Detailed'
}

$results = Invoke-Pester -Configuration $config

# --- Optional analyzer ---

$analyzerErrors = @()
$analyzerWarnings = @()

if ($IncludeAnalyzer) {
    $settingsFile = Join-Path $ProjectRoot '.PSScriptAnalyzerSettings.psd1'
    $analyzePath = $null

    if ($FunctionName) {
        # Search recursively for the specific function source file
        $sourceFiles = @(Get-ChildItem -Path $SourcePath -Filter "$FunctionName.ps1" -Recurse -File)
        if ($sourceFiles.Count -gt 0) {
            $analyzePath = $sourceFiles[0].FullName
        }
    }
    else {
        # Analyze entire module directory
        $analyzePath = $SourcePath
    }

    if ($analyzePath) {
        $analyzeParams = @{ Path = $analyzePath; Recurse = $true }
        if (Test-Path $settingsFile) {
            $analyzeParams['Settings'] = $settingsFile
        }

        $analyzeResults = Invoke-ScriptAnalyzer @analyzeParams

        if ($analyzeResults) {
            $analyzerErrors = @($analyzeResults | Where-Object Severity -eq 'Error' | ForEach-Object {
                @{
                    rule    = $_.RuleName
                    message = $_.Message
                    line    = $_.Line
                    file    = $_.ScriptName
                }
            })
            $analyzerWarnings = @($analyzeResults | Where-Object Severity -eq 'Warning' | ForEach-Object {
                @{
                    rule    = $_.RuleName
                    message = $_.Message
                    line    = $_.Line
                    file    = $_.ScriptName
                }
            })
        }
    }
}

# --- Build output ---

$failedTests = @()
if ($results.FailedCount -gt 0) {
    $failedTests = @($results.Failed | ForEach-Object {
        $relativePath = if ($_.ScriptBlock.File) {
            $_.ScriptBlock.File -replace [regex]::Escape($ProjectRoot + [IO.Path]::DirectorySeparatorChar), ''
        } else { 'unknown' }
        @{
            name  = $_.Name
            block = $_.Path -join ' > '
            error = $_.ErrorRecord.DisplayErrorMessage
            file  = $relativePath
            line  = if ($_.ScriptBlock.StartPosition) { $_.ScriptBlock.StartPosition.StartLine } else { 0 }
        }
    })
}

$totalDuration = '{0:N2}s' -f $results.Duration.TotalSeconds

$success = ($results.FailedCount -eq 0) -and ($analyzerErrors.Count -eq 0)
$summaryParts = @()
if ($results.PassedCount -gt 0) { $summaryParts += "$($results.PassedCount) passed" }
if ($results.FailedCount -gt 0) { $summaryParts += "$($results.FailedCount) failed" }
if ($results.SkippedCount -gt 0) { $summaryParts += "$($results.SkippedCount) skipped" }
$summaryText = if ($success) { "PASSED ($($summaryParts -join ', '))" } else { "FAILED ($($summaryParts -join ', '))" }

# --- Output ---

if ($OutputFormat -eq 'Structured') {
    $output = @{
        success          = $success
        totalTests       = $results.TotalCount
        passed           = $results.PassedCount
        failed           = $results.FailedCount
        skipped          = $results.SkippedCount
        duration         = $totalDuration
        failedTests      = $failedTests
        analyzerErrors   = $analyzerErrors
        analyzerWarnings = $analyzerWarnings
        summary          = $summaryText
    }
    $output | ConvertTo-Json -Depth 5
}
else {
    # Human-readable output
    $label = if ($FunctionName) { $FunctionName }
             elseif ($TestFile) { $TestFile }
             else { 'All Tests' }
    Write-Host ""
    Write-Host "=== QUICK TEST: $label ===" -ForegroundColor Cyan

    # Failed test details
    if ($results.FailedCount -gt 0) {
        Write-Host ""
        Write-Host "FAILED TESTS:" -ForegroundColor Red
        foreach ($ft in $failedTests) {
            Write-Host "  FAILED  $($ft.name)" -ForegroundColor Red
            Write-Host "    ERROR: $($ft.error)" -ForegroundColor Yellow
            Write-Host "    FILE:  $($ft.file):$($ft.line)" -ForegroundColor Gray
        }
    }

    # Analyzer results
    if ($analyzerErrors.Count -gt 0) {
        Write-Host ""
        Write-Host "ANALYZER ERRORS:" -ForegroundColor Red
        foreach ($ae in $analyzerErrors) {
            Write-Host "  [$($ae.rule)] $($ae.message)" -ForegroundColor Red
            Write-Host "    FILE: $($ae.file):$($ae.line)" -ForegroundColor Gray
        }
    }
    if ($analyzerWarnings.Count -gt 0) {
        Write-Host ""
        Write-Host "ANALYZER WARNINGS:" -ForegroundColor Yellow
        foreach ($aw in $analyzerWarnings) {
            Write-Host "  [$($aw.rule)] $($aw.message)" -ForegroundColor Yellow
            Write-Host "    FILE: $($aw.file):$($aw.line)" -ForegroundColor Gray
        }
    }

    # Summary
    Write-Host ""
    $color = if ($success) { 'Green' } else { 'Red' }
    Write-Host "=== RESULT: $summaryText ($totalDuration) ===" -ForegroundColor $color
    Write-Host ""
}

# --- Exit code ---

if (-not $success) { exit 1 }
exit 0
