#requires -Version 7.6

<#
.SYNOPSIS
    Generates markdown command help with Microsoft.PowerShell.PlatyPS.

.DESCRIPTION
    Writes one markdown file per exported command plus a module page, using
    Microsoft.PowerShell.PlatyPS (1.x).

    Comment-based help in source/ is the single source of truth. The markdown is
    generated reference documentation for GitHub or a docs site, so the module's
    folder is regenerated from scratch on every run: don't hand-edit it, edit the
    comment-based help instead. (Regenerating is also required for correctness:
    Update-MarkdownCommandHelp in PlatyPS 1.0.3 is not idempotent and appends a
    duplicate OUTPUTS section on every run.)

    No MAML is generated: Get-Help already works from comment-based help in the
    built module.

    Every command file is validated with Test-MarkdownCommandHelp, and remaining
    '{{ ... }}' placeholders (gaps in comment-based help) are listed.

    Normally run by './build.ps1 -Tasks docs', which builds the module first and
    runs this script in a separate pwsh process (PlatyPS and powershell-yaml load
    conflicting YamlDotNet assemblies, so they must not share a session).

.PARAMETER ModulePath
    Path to the module manifest to document (normally the built module in output/).

.PARAMETER OutputPath
    Root help folder. Files are written to <OutputPath>/<ModuleName>/.
    Defaults to docs/help.

.PARAMETER Locale
    Help locale written into the markdown metadata. Defaults to en-US.

.EXAMPLE
    ./build.ps1 -Tasks docs

    Builds the module and regenerates docs/help/<ModuleName>/*.md.

.EXAMPLE
    ./Scripts/Update-MarkdownHelp.ps1 -ModulePath ./output/MyModule/1.2.0/MyModule.psd1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ModulePath,

    [Parameter()]
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'docs' 'help'),

    [Parameter()]
    [string]$Locale = 'en-US'
)

$ErrorActionPreference = 'Stop'

Import-Module -Name Microsoft.PowerShell.PlatyPS -ErrorAction Stop
$platyPS = Get-Module -Name Microsoft.PowerShell.PlatyPS
Write-Host "Using Microsoft.PowerShell.PlatyPS $($platyPS.Version)" -ForegroundColor DarkGray

$module = Import-Module -Name $ModulePath -Force -PassThru -ErrorAction Stop
$moduleFolder = Join-Path $OutputPath $module.Name

# Regenerate from scratch (see DESCRIPTION)
if (Test-Path -LiteralPath $moduleFolder) {
    Get-ChildItem -LiteralPath $moduleFolder -Filter '*.md' -File | Remove-Item -Force
}

$newParams = @{
    ModuleInfo     = $module
    OutputFolder   = $OutputPath   # PlatyPS writes to <OutputFolder>/<ModuleName>/
    WithModulePage = $true
    Locale         = $Locale
    HelpVersion    = "$($module.Version)"
    Force          = $true
}
if ($module.HelpInfoUri) { $newParams.HelpInfoUri = $module.HelpInfoUri }

$files = @(New-MarkdownCommandHelp @newParams)

# Tidy:
# - .LINK entries without a title render as "[](url)"
# - PlatyPS 1.0.3 leaves the ALIASES section as a placeholder; fill it from the module's exports
$aliasesByCommand = @{}
foreach ($alias in $module.ExportedAliases.Values) {
    $aliasesByCommand[$alias.ResolvedCommandName] += @($alias.Name)
}
foreach ($file in Get-ChildItem -LiteralPath $moduleFolder -Filter '*.md' -File) {
    $content = [IO.File]::ReadAllText($file.FullName)
    $fixed = [regex]::Replace($content, '(?m)^- \[\]\((https?://[^)]+)\)', '- [Online Version]($1)')
    $aliasText = if ($aliasesByCommand[$file.BaseName]) {
        "This cmdlet has the following aliases:`n`n" + (($aliasesByCommand[$file.BaseName] | Sort-Object | ForEach-Object { "- $_" }) -join "`n")
    } else {
        'This cmdlet has no aliases.'
    }
    $fixed = [regex]::Replace($fixed, '(?m)^This cmdlet has the following aliases,\r?\n\s*\{\{Insert list of aliases\}\}', $aliasText.Replace('$', '$$'))
    if ($fixed -ne $content) {
        [IO.File]::WriteAllText($file.FullName, $fixed, [Text.UTF8Encoding]::new($false))
    }
}

# Validate. Note: PlatyPS 1.0.3's -LiteralPath parameter sets return nothing, so use -Path.
$commandFiles = @(Get-ChildItem -LiteralPath $moduleFolder -Filter '*.md' -File | Where-Object BaseName -NE $module.Name)
$invalid = @($commandFiles | Where-Object { (Test-MarkdownCommandHelp -Path $_.FullName) -ne $true })
if ($invalid.Count -gt 0) {
    throw "Invalid markdown help: $($invalid.Name -join ', '). Run Test-MarkdownCommandHelp -DetailView on them."
}

# Functions and cmdlets only: aliases are in ExportedCommands but get no help file
$expected = $module.ExportedFunctions.Count + $module.ExportedCmdlets.Count
if ($commandFiles.Count -ne $expected) {
    throw "Expected $expected command help file(s) for $($module.Name), found $($commandFiles.Count)."
}

# Report placeholders left for a human to fill in (in comment-based help)
$placeholders = @(Get-ChildItem -LiteralPath $moduleFolder -Filter '*.md' -File |
        Select-String -Pattern '\{\{.*?\}\}' |
        ForEach-Object { '{0}:{1}: {2}' -f $_.Filename, $_.LineNumber, $_.Matches[0].Value })

Write-Host "Generated $($files.Count) markdown file(s) for $($module.Name) $($module.Version) in '$moduleFolder'" -ForegroundColor Green
if ($placeholders.Count -gt 0) {
    Write-Host "  $($placeholders.Count) placeholder(s) - fill these in via comment-based help:" -ForegroundColor Yellow
    $placeholders | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
}
