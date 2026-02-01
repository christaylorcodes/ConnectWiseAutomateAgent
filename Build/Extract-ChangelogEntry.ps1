<#
.SYNOPSIS
    Extracts a version's release notes from CHANGELOG.md.

.DESCRIPTION
    Parses a Keep a Changelog formatted CHANGELOG.md and extracts the content
    for a specific version heading. Returns the markdown content between the
    target version heading and the next version heading (or end of file).

    Used by the CI/CD workflow to populate GitHub Release descriptions.

.PARAMETER Version
    The version string to extract (e.g., '1.0.0-alpha001', '1.0.0').
    Must match a heading in the format ## [Version] in CHANGELOG.md.

.PARAMETER ChangelogPath
    Path to the CHANGELOG.md file. Defaults to CHANGELOG.md in the repository root.

.PARAMETER OutputPath
    If specified, writes the extracted content to this file instead of stdout.
    Used by CI to pass release notes to gh release create via --notes-file.

.EXAMPLE
    ./Extract-ChangelogEntry.ps1 -Version '1.0.0-alpha001'
    Outputs the release notes for version 1.0.0-alpha001 to stdout.

.EXAMPLE
    ./Extract-ChangelogEntry.ps1 -Version '1.0.0' -OutputPath 'release-notes.md'
    Writes release notes to release-notes.md for use in CI.

.LINK
    https://keepachangelog.com/en/1.1.0/

.NOTES
    Exit codes:
      0 - Success
      1 - CHANGELOG.md not found
      2 - Version heading not found or empty in CHANGELOG.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]$Version,

    [string]$ChangelogPath,

    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$RepoRoot = Split-Path $ScriptRoot -Parent

if (-not $ChangelogPath) {
    $ChangelogPath = Join-Path $RepoRoot 'CHANGELOG.md'
}

# ─── Validate CHANGELOG exists ────────────────────────────────────────────
if (-not (Test-Path $ChangelogPath)) {
    Write-Error "CHANGELOG.md not found at '$ChangelogPath'. Cannot extract release notes."
    exit 1
}

# ─── Read and parse ───────────────────────────────────────────────────────
$changelogLines = Get-Content $ChangelogPath

# Find the line index of the target version heading: ## [1.0.0-alpha001] - 2026-01-31
$escapedVersion = [regex]::Escape($Version)
$targetPattern = "^## \[$escapedVersion\]"
$startIndex = -1

for ($i = 0; $i -lt $changelogLines.Count; $i++) {
    if ($changelogLines[$i] -match $targetPattern) {
        $startIndex = $i
        break
    }
}

if ($startIndex -eq -1) {
    Write-Error "Version '$Version' not found in CHANGELOG.md. Expected a heading like '## [$Version] - YYYY-MM-DD'."
    exit 2
}

# Find the next version heading (## [...]) or end of file
$endIndex = $changelogLines.Count
for ($i = $startIndex + 1; $i -lt $changelogLines.Count; $i++) {
    if ($changelogLines[$i] -match '^## \[') {
        $endIndex = $i
        break
    }
}

# Extract lines between headings (exclusive of both), trim leading/trailing blank lines
$contentLines = $changelogLines[($startIndex + 1)..($endIndex - 1)]
$content = ($contentLines -join "`n").Trim()

if (-not $content) {
    Write-Error "Version '$Version' heading found but has no content in CHANGELOG.md."
    exit 2
}

# ─── Output ───────────────────────────────────────────────────────────────
if ($OutputPath) {
    $content | Out-File -FilePath $OutputPath -Encoding UTF8 -Force
    Write-Host "Release notes for v$Version written to: $OutputPath"
}
else {
    Write-Output $content
}
