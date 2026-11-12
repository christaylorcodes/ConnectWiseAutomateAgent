#requires -Version 7.6

<#
.SYNOPSIS
    Fast targeted test runner for AI agent closed-loop development.

.DESCRIPTION
    Runs Pester tests for a specific function, test file, or the full suite
    without the overhead of the full build pipeline. Designed for rapid
    write-test-fix-retest cycles.

    Always tests the module from source/ (never a possibly stale build in
    output/). Does NOT build the module or compute code coverage.
    For full validation, use Tests/test-local.ps1.

    Uses the pinned modules in output/RequiredModules when present
    (run './build.ps1 -ResolveDependency -Tasks noop' once to populate it).

.PARAMETER FunctionName
    Name of the function to test. Uses Pester's FullName filter to match
    tests across all test files (e.g., -FunctionName Install-CWAA matches
    all Describe/Context/It blocks containing 'Install-CWAA').

.PARAMETER TestFile
    Run a specific test file by short name or full path.
    Short names: Module, DataReaders, Commands, ServiceOps, CrossCutting,
    PrivateHelpers, Installation, Scripting, Documentation, Security,
    CrossVersion, Live.

.PARAMETER IncludeAnalyzer
    Also run PSScriptAnalyzer on the function source file (with -FunctionName)
    or the entire source directory (without -FunctionName).

.PARAMETER OutputFormat
    'Human' for colored console output with clear PASS/FAIL markers (default).
    'Structured' for JSON output that AI agents can parse. JSON is always
    emitted in Structured mode, including when the run itself errors.

.PARAMETER ExcludeTag
    Pester tags to exclude. Defaults to 'Live' and 'Integration' (same as
    build.yaml).

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

    [string[]]$ExcludeTag = @('Live', 'Integration')
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$TestsPath = Join-Path $ProjectRoot 'Tests'
$SourcePath = Join-Path $ProjectRoot 'source'

# --- Short name mapping for test files ---

$testFileMap = @{
    'Module'         = 'ConnectWiseAutomateAgent.Module.Tests.ps1'
    'DataReaders'    = 'ConnectWiseAutomateAgent.Mocked.DataReaders.Tests.ps1'
    'Commands'       = 'ConnectWiseAutomateAgent.Mocked.Commands.Tests.ps1'
    'ServiceOps'     = 'ConnectWiseAutomateAgent.Mocked.ServiceOps.Tests.ps1'
    'CrossCutting'   = 'ConnectWiseAutomateAgent.Mocked.CrossCutting.Tests.ps1'
    'PrivateHelpers' = 'ConnectWiseAutomateAgent.Mocked.PrivateHelpers.Tests.ps1'
    'Installation'   = 'ConnectWiseAutomateAgent.Mocked.Installation.Tests.ps1'
    'Scripting'      = 'ConnectWiseAutomateAgent.Mocked.Scripting.Tests.ps1'
    'Documentation'  = 'ConnectWiseAutomateAgent.Documentation.Tests.ps1'
    'Security'       = 'ConnectWiseAutomateAgent.Security.Tests.ps1'
    'CrossVersion'   = 'ConnectWiseAutomateAgent.CrossVersion.Tests.ps1'
    'Live'           = 'ConnectWiseAutomateAgent.Live.Tests.ps1'
}

function ConvertTo-RelativePath([string]$Path) {
    if (-not $Path) { return 'unknown' }
    $Path -replace [regex]::Escape($ProjectRoot + [IO.Path]::DirectorySeparatorChar), ''
}

function Write-QuickTestResult {
    param(
        [bool]$Success,
        [string]$Summary,
        $Results,
        [array]$FailedTests = @(),
        [array]$AnalyzerErrors = @(),
        [array]$AnalyzerWarnings = @(),
        [string]$Label = 'Tests'
    )

    $duration = if ($Results) { '{0:N2}s' -f $Results.Duration.TotalSeconds } else { '0s' }
    $pester = Get-Module Pester | Select-Object -First 1

    if ($OutputFormat -eq 'Structured') {
        [ordered]@{
            success          = $Success
            totalTests       = if ($Results) { $Results.TotalCount } else { 0 }
            passed           = if ($Results) { $Results.PassedCount } else { 0 }
            failed           = if ($Results) { $Results.FailedCount } else { 0 }
            skipped          = if ($Results) { $Results.SkippedCount } else { 0 }
            duration         = $duration
            moduleSource     = 'source'
            pesterVersion    = if ($pester) { "$($pester.Version)" } else { $null }
            failedTests      = @($FailedTests)
            analyzerErrors   = @($AnalyzerErrors)
            analyzerWarnings = @($AnalyzerWarnings)
            summary          = $Summary
        } | ConvertTo-Json -Depth 5
        return
    }

    Write-Host ''
    Write-Host "=== QUICK TEST: $Label (source module, Pester $($pester.Version)) ===" -ForegroundColor Cyan

    if ($FailedTests.Count -gt 0) {
        Write-Host ''
        Write-Host 'FAILED TESTS:' -ForegroundColor Red
        foreach ($ft in $FailedTests) {
            Write-Host "  FAILED  $($ft.name)" -ForegroundColor Red
            Write-Host "    ERROR: $($ft.error)" -ForegroundColor Yellow
            Write-Host "    FILE:  $($ft.file):$($ft.line)" -ForegroundColor Gray
        }
    }

    if ($AnalyzerErrors.Count -gt 0) {
        Write-Host ''
        Write-Host 'ANALYZER ERRORS:' -ForegroundColor Red
        foreach ($ae in $AnalyzerErrors) {
            Write-Host "  [$($ae.rule)] $($ae.message)" -ForegroundColor Red
            Write-Host "    FILE: $($ae.file):$($ae.line)" -ForegroundColor Gray
        }
    }
    if ($AnalyzerWarnings.Count -gt 0) {
        Write-Host ''
        Write-Host 'ANALYZER WARNINGS:' -ForegroundColor Yellow
        foreach ($aw in $AnalyzerWarnings) {
            Write-Host "  [$($aw.rule)] $($aw.message)" -ForegroundColor Yellow
            Write-Host "    FILE: $($aw.file):$($aw.line)" -ForegroundColor Gray
        }
    }

    Write-Host ''
    $color = if ($Success) { 'Green' } else { 'Red' }
    Write-Host "=== RESULT: $Summary ($duration) ===" -ForegroundColor $color
    Write-Host ''
}

# Save process state so nothing leaks into the caller's session
$savedPSModulePath = $env:PSModulePath
$savedLoadMethod = $env:CWAA_TEST_LOAD_METHOD
$label = if ($FunctionName) { $FunctionName } elseif ($TestFile) { $TestFile } else { 'All Tests' }
$success = $false

try {
    # Prefer pinned dependencies from output/RequiredModules
    $requiredModulesPath = Join-Path $ProjectRoot 'output' 'RequiredModules'
    if (Test-Path $requiredModulesPath) {
        $env:PSModulePath = $requiredModulesPath + [IO.Path]::PathSeparator + $env:PSModulePath
    }

    # Pester 3.4 ships with Windows PowerShell's module path; make sure we get 5+
    if (-not (Get-Module Pester | Where-Object { $_.Version -ge [version]'5.0' })) {
        Get-Module Pester | Remove-Module -Force
        Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
    }

    # Always test source/ (TestBootstrap.ps1 loads source unless this is 'BuiltModule')
    $env:CWAA_TEST_LOAD_METHOD = 'Module'

    # --- Resolve test path and filter ---
    $testFilePath = $TestsPath
    $fullNameFilter = $null

    if ($PSCmdlet.ParameterSetName -eq 'ByFunction') {
        # Run all test files but filter to tests matching the function name
        $fullNameFilter = "*$FunctionName*"
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'ByTestFile') {
        if ($testFileMap.ContainsKey($TestFile)) {
            $testFilePath = Join-Path $TestsPath $testFileMap[$TestFile]
        }
        elseif (Test-Path $TestFile) {
            $testFilePath = $TestFile
        }
        else {
            throw "Test file '$TestFile' not found. Valid short names: $($testFileMap.Keys -join ', ')"
        }

        # Explicitly targeting the Live suite: don't filter it out by default
        if ($TestFile -eq 'Live' -and -not $PSBoundParameters.ContainsKey('ExcludeTag')) {
            $ExcludeTag = @()
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
    $config.Output.Verbosity = if ($OutputFormat -eq 'Structured') { 'None' } else { 'Detailed' }

    $results = if ($OutputFormat -eq 'Structured') {
        # Keep stdout parseable: warnings/host output from code under test would precede the JSON.
        # Redirection (not preference changes) so tests that capture these streams still work.
        Invoke-Pester -Configuration $config 2>$null 3>$null 4>$null 5>$null 6>$null
    }
    else {
        Invoke-Pester -Configuration $config
    }

    # --- Optional analyzer ---
    $analyzerErrors = @()
    $analyzerWarnings = @()

    if ($IncludeAnalyzer) {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        $settingsFile = Join-Path $ProjectRoot '.PSScriptAnalyzerSettings.psd1'
        $analyzeParams = @{}
        if (Test-Path $settingsFile) {
            $analyzeParams['Settings'] = $settingsFile
        }

        # Analyze .ps1/.psm1 only; .psd1 excluded due to PSScriptAnalyzer NullRef bug
        $files = if ($FunctionName) {
            @(Get-ChildItem -Path $SourcePath -Filter "$FunctionName.ps1" -Recurse -File | Select-Object -First 1)
        }
        else {
            @(Get-ChildItem -Path $SourcePath -Include '*.ps1', '*.psm1' -Recurse -File)
        }

        $analyzeResults = $files | ForEach-Object { Invoke-ScriptAnalyzer -Path $_.FullName @analyzeParams }

        $toEntry = {
            @{
                rule    = $_.RuleName
                message = $_.Message
                line    = $_.Line
                file    = ConvertTo-RelativePath $_.ScriptPath
            }
        }
        $analyzerErrors = @($analyzeResults | Where-Object Severity -EQ 'Error' | ForEach-Object $toEntry)
        $analyzerWarnings = @($analyzeResults | Where-Object Severity -EQ 'Warning' | ForEach-Object $toEntry)
    }

    # --- Evaluate ---
    $failedTests = @($results.Failed | ForEach-Object {
            @{
                name  = $_.Name
                block = $_.Path -join ' > '
                error = (@($_.ErrorRecord) | ForEach-Object { $_.Exception.Message }) -join '; '
                file  = ConvertTo-RelativePath $_.ScriptBlock.File
                line  = if ($_.ScriptBlock.StartPosition) { $_.ScriptBlock.StartPosition.StartLine } else { 0 }
            }
        })

    # Failed BeforeAll/AfterAll blocks and containers that failed to load aren't in .Failed
    foreach ($block in @($results.FailedBlocks)) {
        $failedTests += @{
            name  = '(block setup/teardown failed)'
            block = $block.Path -join ' > '
            error = (@($block.ErrorRecord) | ForEach-Object { $_.Exception.Message }) -join '; '
            file  = ConvertTo-RelativePath $block.ScriptBlock.File
            line  = if ($block.ScriptBlock.StartPosition) { $block.ScriptBlock.StartPosition.StartLine } else { 0 }
        }
    }
    foreach ($container in @($results.FailedContainers)) {
        $failedTests += @{
            name  = '(container failed to run)'
            block = ''
            error = ($container.ErrorRecord | ForEach-Object { $_.DisplayErrorMessage }) -join '; '
            file  = ConvertTo-RelativePath "$($container.Item)"
            line  = 0
        }
    }

    # Success requires a passing run that actually executed tests
    $success = ($results.Result -eq 'Passed') -and ($results.TotalCount -gt 0) -and ($analyzerErrors.Count -eq 0)

    $summaryParts = @()
    if ($results.PassedCount -gt 0) { $summaryParts += "$($results.PassedCount) passed" }
    if ($results.FailedCount -gt 0) { $summaryParts += "$($results.FailedCount) failed" }
    if ($results.SkippedCount -gt 0) { $summaryParts += "$($results.SkippedCount) skipped" }
    if ($results.FailedBlocksCount -gt 0) { $summaryParts += "$($results.FailedBlocksCount) block(s) failed" }
    if ($results.FailedContainersCount -gt 0) { $summaryParts += "$($results.FailedContainersCount) container(s) failed" }
    if ($results.TotalCount -eq 0) { $summaryParts += 'no tests ran' }
    if ($analyzerErrors.Count -gt 0) { $summaryParts += "$($analyzerErrors.Count) analyzer error(s)" }
    $summaryText = "$(if ($success) { 'PASSED' } else { 'FAILED' }) ($($summaryParts -join ', '))"

    Write-QuickTestResult -Success $success -Summary $summaryText -Results $results -Label $label `
        -FailedTests $failedTests -AnalyzerErrors $analyzerErrors -AnalyzerWarnings $analyzerWarnings
}
catch {
    $success = $false
    Write-QuickTestResult -Success $false -Summary "ERROR: $($_.Exception.Message)" -Label $label
}
finally {
    $env:PSModulePath = $savedPSModulePath
    $env:CWAA_TEST_LOAD_METHOD = $savedLoadMethod
}

if (-not $success) { exit 1 }
exit 0
