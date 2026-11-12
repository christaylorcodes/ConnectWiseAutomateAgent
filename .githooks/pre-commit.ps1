#requires -Version 7.0
# Started by the pre-commit hook. Runs the same quick check used during development:
# PSScriptAnalyzer on source/ and the Pester suite (Live and Integration tests excluded),
# with the pinned modules in output/RequiredModules when they are there.

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $projectRoot 'Scripts' 'Invoke-QuickTest.ps1') -IncludeAnalyzer
exit $LASTEXITCODE
