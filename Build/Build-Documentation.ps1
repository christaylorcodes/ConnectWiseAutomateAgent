<#
.SYNOPSIS
    Generates markdown documentation and MAML help for ConnectWiseAutomateAgent using PlatyPS.

.DESCRIPTION
    This script generates markdown help files for all exported functions
    in the ConnectWiseAutomateAgent module using PlatyPS, then compiles
    them into MAML XML for Get-Help support.

.PARAMETER OutputPath
    The path where markdown documentation will be generated. Defaults to 'Docs\Help'.

.PARAMETER UpdateExisting
    If specified, updates existing markdown files rather than regenerating.

.EXAMPLE
    ./Build-Documentation.ps1
    Generates fresh documentation in Docs/Help/

.EXAMPLE
    ./Build-Documentation.ps1 -UpdateExisting
    Updates existing documentation files with any changes from code.
#>
[CmdletBinding()]
param(
    [string]$OutputPath,

    [switch]$UpdateExisting
)

$ErrorActionPreference = 'Stop'

$ModuleName = 'ConnectWiseAutomateAgent'
$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$RepoRoot = Split-Path $ScriptRoot -Parent
if (-not $OutputPath) { $OutputPath = Join-Path (Join-Path $RepoRoot 'Docs') 'Help' }
$ModulePath = Join-Path (Join-Path $RepoRoot $ModuleName) "$ModuleName.psd1"
$EnUsPath = Join-Path (Join-Path $RepoRoot $ModuleName) 'en-US'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "PLATYPS DOCUMENTATION GENERATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Ensure platyPS is available
if (-not (Get-Module -ListAvailable -Name platyPS)) {
    Write-Host "Installing platyPS module..." -ForegroundColor Yellow
    Install-Module -Name platyPS -Force -Scope CurrentUser
}

Import-Module platyPS -Force

# Remove any existing module from session
Get-Module $ModuleName | Remove-Module -Force -ErrorAction SilentlyContinue

# Import the source module
# Note: Initialize-CWAA runs on import and may produce non-terminating errors
# on dev machines without the Automate agent installed (registry keys not found).
# This is expected and safe to suppress.
Write-Host "Importing module from: $ModulePath" -ForegroundColor Gray
Import-Module $ModulePath -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

# Validate the module actually loaded
$module = Get-Module $ModuleName
if (-not $module) {
    Write-Error "Failed to import module $ModuleName from $ModulePath"
    return
}

Write-Host "Module loaded: $($module.Name) v$($module.Version)" -ForegroundColor Green
Write-Host "Exported functions: $($module.ExportedFunctions.Count)" -ForegroundColor Gray

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    Write-Host "Creating output directory: $OutputPath" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

if ($UpdateExisting -and (Get-ChildItem $OutputPath -Filter '*.md' -ErrorAction SilentlyContinue)) {
    Write-Host "`nUpdating existing documentation..." -ForegroundColor Yellow
    Update-MarkdownHelpModule -Path $OutputPath -RefreshModulePage -AlphabeticParamsOrder
}
else {
    Write-Host "`nGenerating new documentation..." -ForegroundColor Yellow

    # Generate markdown for each function
    $params = @{
        Module                = $ModuleName
        OutputFolder          = $OutputPath
        AlphabeticParamsOrder = $true
        WithModulePage        = $true
        ExcludeDontShow       = $true
        Encoding              = [System.Text.Encoding]::UTF8
    }

    New-MarkdownHelp @params -Force
}

# Count generated markdown files
$docFiles = Get-ChildItem $OutputPath -Filter '*.md'

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "MARKDOWN DOCUMENTATION GENERATED" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Output: $OutputPath" -ForegroundColor Gray
Write-Host "Files:  $($docFiles.Count) markdown files" -ForegroundColor Gray

# List generated files
Write-Host "`nGenerated files:" -ForegroundColor Cyan
$docFiles | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor Gray
}

# --- Post-process: rewrite the module page with categorized layout ---
# PlatyPS generates a flat alphabetical list. This rewrites it as categorized
# tables with enhanced descriptions for better readability.
# When adding a new function, add it to the appropriate category below.

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MODULE PAGE ENHANCEMENT" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$modulePagePath = Join-Path $OutputPath "$ModuleName.md"

# Category ordering for the module page
$categories = [ordered]@{
    'Install & Uninstall'     = @('Install-CWAA', 'Uninstall-CWAA', 'Update-CWAA', 'Redo-CWAA')
    'Service Management'      = @('Start-CWAA', 'Stop-CWAA', 'Restart-CWAA', 'Repair-CWAA')
    'Agent Settings & Backup' = @('Get-CWAAInfo', 'Get-CWAAInfoBackup', 'Get-CWAASettings', 'New-CWAABackup', 'Reset-CWAA')
    'Logging'                 = @('Get-CWAAError', 'Get-CWAAProbeError', 'Get-CWAALogLevel', 'Set-CWAALogLevel')
    'Proxy'                   = @('Get-CWAAProxy', 'Set-CWAAProxy')
    'Add/Remove Programs'     = @('Hide-CWAAAddRemove', 'Show-CWAAAddRemove', 'Rename-CWAAAddRemove')
    'Health & Monitoring'     = @('Test-CWAAHealth', 'Test-CWAAServerConnectivity', 'Register-CWAAHealthCheckTask', 'Unregister-CWAAHealthCheckTask')
    'Security & Utilities'    = @('ConvertFrom-CWAASecurity', 'ConvertTo-CWAASecurity', 'Invoke-CWAACommand', 'Test-CWAAPort')
}

# Read SYNOPSIS from each function's generated markdown.
# These come from the .SYNOPSIS in each function's comment-based help.
$synopses = @{}
foreach ($funcList in $categories.Values) {
    foreach ($funcName in $funcList) {
        $funcFile = Join-Path $OutputPath "$funcName.md"
        if (Test-Path $funcFile) {
            $funcContent = Get-Content $funcFile -Raw
            if ($funcContent -match '## SYNOPSIS\r?\n(.+)') {
                $synopses[$funcName] = $Matches[1].Trim()
            }
        }
    }
}

# Preserve YAML frontmatter from the PlatyPS-generated module page
$existingContent = Get-Content $modulePagePath -Raw
$frontmatter = ''
if ($existingContent -match '(?s)^(---.*?---)') {
    $frontmatter = $Matches[1]
}

# Build the enhanced module page
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine($frontmatter)
[void]$sb.AppendLine('')
[void]$sb.AppendLine("# $ModuleName Module")
[void]$sb.AppendLine('')
[void]$sb.AppendLine('PowerShell module for managing the ConnectWise Automate (formerly LabTech) Windows agent. Install, configure, troubleshoot, and manage the Automate agent on Windows systems.')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('> Every function below has a legacy `LT` alias (e.g., `Install-CWAA` = `Install-LTService`). Run `Get-Alias -Definition *-CWAA*` to see them all.')
[void]$sb.AppendLine('')

foreach ($categoryName in $categories.Keys) {
    [void]$sb.AppendLine("## $categoryName")
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| Function | Description |')
    [void]$sb.AppendLine('| --- | --- |')

    foreach ($funcName in $categories[$categoryName]) {
        $desc = if ($synopses.ContainsKey($funcName)) { $synopses[$funcName] } else { '' }
        [void]$sb.AppendLine("| [$funcName]($funcName.md) | $desc |")
    }

    [void]$sb.AppendLine('')
}

Set-Content -Path $modulePagePath -Value $sb.ToString().TrimEnd() -Encoding UTF8 -NoNewline

# Warn about any exported functions missing from the category map
$categorizedFunctions = $categories.Values | ForEach-Object { $_ }
$exportedFunctions = $module.ExportedFunctions.Keys
$uncategorized = $exportedFunctions | Where-Object { $_ -notin $categorizedFunctions }
if ($uncategorized) {
    Write-Host "`nWARNING: The following exported functions are not in the module page category map:" -ForegroundColor Yellow
    $uncategorized | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    Write-Host "Add them to the `$categories hashtable in Build-Documentation.ps1" -ForegroundColor Yellow
}
else {
    Write-Host "Module page rewritten with categorized layout ($($exportedFunctions.Count) functions)." -ForegroundColor Green
}

# Generate MAML XML help from markdown
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "MAML HELP GENERATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

if (-not (Test-Path $EnUsPath)) {
    Write-Host "Creating en-US directory: $EnUsPath" -ForegroundColor Gray
    New-Item -ItemType Directory -Path $EnUsPath -Force | Out-Null
}

Write-Host "Generating MAML XML from markdown..." -ForegroundColor Yellow
$mamlOutput = New-ExternalHelp -Path $OutputPath -OutputPath $EnUsPath -Force

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "DOCUMENTATION BUILD COMPLETE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Markdown: $OutputPath ($($docFiles.Count) files)" -ForegroundColor Gray
Write-Host "MAML:     $($mamlOutput.FullName)" -ForegroundColor Gray
