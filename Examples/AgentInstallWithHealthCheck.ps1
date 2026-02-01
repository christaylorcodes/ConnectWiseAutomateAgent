# ==============================================================================
# AgentInstallWithHealthCheck.ps1
#
# Installs the ConnectWise Automate agent and registers a recurring scheduled
# task that automatically monitors agent health and repairs it when needed.
#
# Usage:
#   1. Fill in $InstallParameters below with your Automate server details.
#   2. Run this script elevated (Administrator) on target machines.
#   3. The agent installs, then a scheduled task is created that runs every
#      6 hours as SYSTEM to check agent health and self-heal if necessary.
#
# What the health check does (Repair-CWAA):
#   - If the agent hasn't checked in for 2+ hours  -> restarts services
#   - If offline for 120+ hours after restart       -> reinstalls the agent
#   - If no agent is found and Server/LocationID    -> performs a fresh install
#     were provided
#
# Requirements:
#   - Windows PowerShell 3.0 or later
#   - Administrator privileges (for agent install and scheduled task creation)
#   - Internet access to the Automate server and PowerShell Gallery (or use
#     the single-file fallback)
# ==============================================================================

# --- Configuration -----------------------------------------------------------

$InstallParameters = @{
    Server         = 'automate.example.com'
    LocationID     = 1
    InstallerToken = 'YourGeneratedInstallerToken'
}
# ^^ This info is sensitive -- take precautions to secure it ^^

$HealthCheckIntervalHours = 6   # How often the health check runs (default: 6)
$TaskName = 'CWAAHealthCheck'   # Scheduled task name (default: CWAAHealthCheck)

# --- Module Loading ----------------------------------------------------------

# SECURITY WARNING: The fallback method below uses Invoke-Expression to load
# code downloaded from the internet at runtime. This is convenient but carries
# inherent risk -- a compromised source or man-in-the-middle attack could
# execute arbitrary code on this machine.
#
# RECOMMENDED: Use Install-Module from the PowerShell Gallery instead:
#   Install-Module 'ConnectWiseAutomateAgent' -Scope AllUsers
#
# The Invoke-Expression fallback is provided ONLY for systems where the
# PowerShell Gallery is unavailable (e.g., PS 2.0, restricted networks).

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
try {
    $Module = 'ConnectWiseAutomateAgent'
    try { Update-Module $Module -ErrorAction Stop }
    catch { Install-Module $Module -Force -Scope AllUsers -SkipPublisherCheck }

    Get-Module $Module -ListAvailable |
        Sort-Object Version -Descending |
        Select-Object -First 1 |
        Import-Module *>$null
}
catch {
    # WARNING: Invoke-Expression executes downloaded code. See security note above.
    # This fallback is ONLY for systems where the PowerShell Gallery is unavailable.
    $URI = 'https://raw.githubusercontent.com/christaylorcodes/ConnectWiseAutomateAgent/main/ConnectWiseAutomateAgent.ps1'
    (New-Object Net.WebClient).DownloadString($URI) | Invoke-Expression
}

# --- Step 1: Install the Agent -----------------------------------------------

Write-Host 'Installing the ConnectWise Automate agent...' -ForegroundColor Cyan

# Redo-CWAA removes any existing agent before installing fresh.
# Use Install-CWAA instead if you know no agent is present.
Redo-CWAA @InstallParameters

# Verify installation
$agentInfo = Get-CWAAInfo -ErrorAction SilentlyContinue
if ($agentInfo -and ($agentInfo | Select-Object -ExpandProperty 'ID' -ErrorAction SilentlyContinue) -ge 1) {
    Write-Host "Agent installed. ID: $($agentInfo.ID), Location: $($agentInfo.LocationID)" -ForegroundColor Green
}
else {
    Write-Warning 'Agent may not have registered yet. The health check task will monitor and repair if needed.'
}

# --- Step 2: Register the Health Check Scheduled Task -------------------------

Write-Host "`nRegistering health check scheduled task..." -ForegroundColor Cyan

$taskParameters = @{
    InstallerToken = $InstallParameters.InstallerToken
    Server         = $InstallParameters.Server
    LocationID     = $InstallParameters.LocationID
    TaskName       = $TaskName
    IntervalHours  = $HealthCheckIntervalHours
    Force          = $true
}
Register-CWAAHealthCheckTask @taskParameters

Write-Host "`nSetup complete." -ForegroundColor Green
Write-Host "  Agent: Installed and running"
Write-Host "  Health check: '$TaskName' runs every $HealthCheckIntervalHours hours as SYSTEM"
Write-Host "  Event log: Application log, source 'ConnectWiseAutomateAgent'"

# --- Optional: Verify Health Now ----------------------------------------------

# Uncomment the lines below to run an immediate health check after install:
#
# Write-Host "`nRunning initial health check..." -ForegroundColor Cyan
# Test-CWAAHealth | Format-List
