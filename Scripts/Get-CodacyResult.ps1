#requires -Version 7.0
<#
.SYNOPSIS
    Shows why Codacy passed or failed a pull request.

.DESCRIPTION
    The Codacy check on GitHub only says "action required". This reads the detail from Codacy's
    public API (no token needed for a public repository) and prints it:

    - each analysis step that ended in an error, for the pull request, its head commit and its
      base commit, with the tool's own error text
    - the new issues Codacy counts against the pull request

    A pull request also fails when the BASE commit could not be analysed, because Codacy then has
    nothing to compare against. That is fixed on the target branch, not in the pull request.

.PARAMETER PullRequest
    The pull request number. Defaults to the pull request of the current branch (needs gh).

.PARAMETER Repository
    Owner/name on GitHub.

.EXAMPLE
    ./Scripts/Get-CodacyResult.ps1

.EXAMPLE
    ./Scripts/Get-CodacyResult.ps1 -PullRequest 14
#>
[CmdletBinding()]
param(
    [int]$PullRequest,
    [string]$Repository = 'christaylorcodes/ConnectWiseAutomateAgent'
)

$ErrorActionPreference = 'Stop'

if (-not $PullRequest) {
    $PullRequest = [int](gh pr view --json number --jq '.number')
    if (-not $PullRequest) { throw 'No pull request found for the current branch. Pass -PullRequest.' }
}

$owner, $name = $Repository -split '/', 2
$api = "https://app.codacy.com/api/v3/analysis/organizations/gh/$owner/repositories/$name"

function Get-CodacyData {
    param([string]$Path)
    Invoke-RestMethod -Uri "$api/$Path" -Headers @{ Accept = 'application/json' } -UserAgent 'Get-CodacyResult'
}

function Get-FailedStep {
    param([string]$Scope, [string]$Path)
    foreach ($step in (Get-CodacyData -Path $Path).data.steps) {
        if ($step.status -ne 'error') { continue }
        [pscustomobject]@{
            Scope  = $Scope
            Step   = $step.title
            Detail = if ($step.stackTrace) { $step.stackTrace.Trim() } else { '(Codacy gives no detail for this step)' }
        }
    }
}

$pullRequestLog = (Get-CodacyData -Path "pull-requests/$PullRequest/logs").data
$headSha = $pullRequestLog.headCommitSha
$baseSha = $pullRequestLog.commonAncestorCommitSha

$failedSteps = @(
    Get-FailedStep -Scope 'pull request' -Path "pull-requests/$PullRequest/logs"
    Get-FailedStep -Scope "head commit $($headSha.Substring(0, 7))" -Path "commits/$headSha/logs"
    Get-FailedStep -Scope "base commit $($baseSha.Substring(0, 7))" -Path "commits/$baseSha/logs"
)
$issues = @((Get-CodacyData -Path "pull-requests/$PullRequest/issues?status=new&limit=100").data)
$quality = (Get-CodacyData -Path "commits/$headSha").quality

Write-Output "Codacy result for pull request #$PullRequest ($Repository)"
Write-Output "Head commit: $($quality.newIssues) new issues, $($quality.fixedIssues) fixed, up to standards: $($quality.isUpToStandards)"

if ($failedSteps.Count -eq 0) { Write-Output 'Analysis steps: none failed' }
foreach ($failedStep in $failedSteps) {
    Write-Output ''
    Write-Output "FAILED STEP [$($failedStep.Scope)] $($failedStep.Step)"
    Write-Output $failedStep.Detail
}

if ($issues.Count -gt 0) {
    Write-Output ''
    Write-Output "NEW ISSUES ($($issues.Count))"
    foreach ($issue in $issues) {
        $info = $issue.commitIssue
        Write-Output "$($info.filePath):$($info.lineNumber)  [$($info.patternInfo.id)]  $($info.message)"
    }
}

if ($failedSteps.Count -gt 0 -or $issues.Count -gt 0) { exit 1 }
