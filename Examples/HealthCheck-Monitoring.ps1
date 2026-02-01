# ==============================================================================
# HealthCheck-Monitoring.ps1
#
# Demonstrates the full lifecycle of the ConnectWise Automate agent health check
# system: registering a scheduled task, running an immediate health assessment,
# inspecting the scheduled task, and unregistering it when no longer needed.
#
# Usage:
#   1. Fill in the configuration variables below.
#   2. Run this script elevated (Administrator) on the target machine.
#   3. The script registers a health check task, runs an immediate health test,
#      and shows the task status.
#
# What the health check task does (Repair-CWAA):
#   - Agent healthy and checking in        -> no action
#   - Agent hasn't checked in for 2+ hours -> restarts services, waits up to
#                                             2 minutes for recovery
#   - Still offline after 120+ hours       -> full reinstall via Redo-CWAA
#   - Agent config unreadable              -> uninstall and reinstall
#   - Agent pointing at wrong server       -> reinstall with correct server
#   - Agent not installed at all           -> fresh install from parameters
#
# Two registration modes:
#   - Checkup mode: Only InstallerToken is required. The task monitors and
#     repairs the existing agent but cannot perform a fresh install if the agent
#     is completely missing.
#   - Install mode: Server, LocationID, and InstallerToken are provided. The
#     task can install the agent from scratch if it is removed.
#
# Requirements:
#   - Windows PowerShell 3.0 or later
#   - Administrator privileges (for scheduled task creation and service access)
# ==============================================================================

# --- Configuration -----------------------------------------------------------

$InstallerToken        = 'YourGeneratedInstallerToken'
$Server                = 'automate.example.com'       # Only needed for Install mode
$LocationID            = 1                             # Only needed for Install mode
$TaskName              = 'CWAAHealthCheck'             # Scheduled task name
$HealthCheckInterval   = 6                             # Hours between health checks

# ^^ Fill in the InstallerToken at minimum. Server and LocationID are needed
#    only if you want the health check to be able to install a missing agent. ^^

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

# --- Step 1: Register the Health Check Task -----------------------------------

# Install mode: provides Server and LocationID so the task can install a missing
# agent from scratch. This is the recommended mode for deployment scripts.

Write-Host '--- Registering Health Check Task (Install Mode) ---' -ForegroundColor Cyan

$taskParameters = @{
    InstallerToken = $InstallerToken
    Server         = $Server
    LocationID     = $LocationID
    TaskName       = $TaskName
    IntervalHours  = $HealthCheckInterval
    Force          = $true
}

try {
    $registerResult = Register-CWAAHealthCheckTask @taskParameters -ErrorAction Stop
    if ($registerResult.Created) {
        Write-Host "  Task '$TaskName' created successfully." -ForegroundColor Green
    }
    elseif ($registerResult.Updated) {
        Write-Host "  Task '$TaskName' updated (token or settings changed)." -ForegroundColor Yellow
    }
    else {
        Write-Host "  Task '$TaskName' already exists with the same configuration." -ForegroundColor DarkGray
    }
}
catch {
    Write-Host "  ERROR: Failed to register health check task." -ForegroundColor Red
    Write-Host "  Detail: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ''

# --- Alternative: Checkup Mode (Example) -------------------------------------

# Checkup mode: only InstallerToken is required. The task monitors the existing
# agent and can restart or reinstall it, but cannot perform a fresh install if
# the agent is completely removed. Uncomment to use instead of Install mode.

# Write-Host '--- Registering Health Check Task (Checkup Mode) ---' -ForegroundColor Cyan
#
# $checkupParameters = @{
#     InstallerToken = $InstallerToken
#     TaskName       = $TaskName
#     IntervalHours  = $HealthCheckInterval
# }
#
# try {
#     Register-CWAAHealthCheckTask @checkupParameters -ErrorAction Stop
#     Write-Host "  Task '$TaskName' registered in Checkup mode." -ForegroundColor Green
# }
# catch {
#     Write-Host "  ERROR: Failed to register task. Detail: $($_.Exception.Message)" -ForegroundColor Red
# }

# --- Step 2: Run an Immediate Health Test -------------------------------------

Write-Host '--- Running Immediate Health Check ---' -ForegroundColor Cyan

try {
    $healthResult = Test-CWAAHealth -TestServerConnectivity -ErrorAction Stop

    Write-Host "  Agent Installed:   $($healthResult.AgentInstalled)"
    Write-Host "  Services Running:  $($healthResult.ServicesRunning)"
    Write-Host "  Last Contact:      $($healthResult.LastContact)"
    Write-Host "  Last Heartbeat:    $($healthResult.LastHeartbeat)"
    Write-Host "  Server Address:    $($healthResult.ServerAddress)"
    Write-Host "  Server Reachable:  $($healthResult.ServerReachable)"

    if ($healthResult.Healthy) {
        Write-Host "  Overall Healthy:   True" -ForegroundColor Green
    }
    else {
        Write-Host "  Overall Healthy:   False" -ForegroundColor Red
        Write-Host ''
        Write-Host '  The health check task will automatically remediate issues on its next run.' -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ERROR: Health check failed. Detail: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ''

# --- Step 3: Verify the Scheduled Task Exists ---------------------------------

Write-Host '--- Verifying Scheduled Task ---' -ForegroundColor Cyan

$taskExists = $false
try {
    $null = schtasks /QUERY /TN $TaskName 2>$null
    if ($LASTEXITCODE -eq 0) {
        $taskExists = $true
    }
}
catch { }

if ($taskExists) {
    Write-Host "  Scheduled task '$TaskName' is registered." -ForegroundColor Green

    # Display task details using schtasks verbose output
    try {
        $taskInfo = schtasks /QUERY /TN $TaskName /V /FO LIST 2>$null
        $nextRunLine = $taskInfo | Select-String -Pattern 'Next Run Time' | Select-Object -First 1
        $statusLine = $taskInfo | Select-String -Pattern '^Status' | Select-Object -First 1
        $lastRunLine = $taskInfo | Select-String -Pattern 'Last Run Time' | Select-Object -First 1

        if ($statusLine) { Write-Host "  $($statusLine.Line.Trim())" }
        if ($lastRunLine) { Write-Host "  $($lastRunLine.Line.Trim())" }
        if ($nextRunLine) { Write-Host "  $($nextRunLine.Line.Trim())" }
    }
    catch {
        Write-Host '  (Unable to retrieve task details.)' -ForegroundColor DarkGray
    }
}
else {
    Write-Host "  Scheduled task '$TaskName' was NOT found." -ForegroundColor Red
    Write-Host '  Registration may have failed. Check the error output above.' -ForegroundColor Yellow
}

Write-Host ''

# --- Step 4: Unregister the Task (Example - Uncomment to Use) ----------------

# Uncomment the block below to remove the health check scheduled task. This
# stops automatic monitoring and remediation. The agent itself is not affected.

# Write-Host '--- Unregistering Health Check Task ---' -ForegroundColor Cyan
#
# try {
#     $unregisterResult = Unregister-CWAAHealthCheckTask -TaskName $TaskName -ErrorAction Stop
#     if ($unregisterResult.Removed) {
#         Write-Host "  Task '$TaskName' has been removed." -ForegroundColor Green
#     }
#     else {
#         Write-Host "  Task '$TaskName' was not found or could not be removed." -ForegroundColor Yellow
#     }
# }
# catch {
#     Write-Host "  ERROR: Failed to unregister task. Detail: $($_.Exception.Message)" -ForegroundColor Red
# }
#
# # Verify removal
# $taskStillExists = $false
# try {
#     $null = schtasks /QUERY /TN $TaskName 2>$null
#     if ($LASTEXITCODE -eq 0) { $taskStillExists = $true }
# }
# catch { }
#
# if ($taskStillExists) {
#     Write-Host "  WARNING: Task '$TaskName' still exists after unregister attempt." -ForegroundColor Red
# }
# else {
#     Write-Host "  Confirmed: Task '$TaskName' no longer exists." -ForegroundColor Green
# }

# --- Summary ------------------------------------------------------------------

Write-Host '--- Summary ---' -ForegroundColor Cyan
Write-Host "  Health check task: '$TaskName'"
Write-Host "  Interval: Every $HealthCheckInterval hours"
Write-Host "  Mode: Install (can reinstall from Server/LocationID/InstallerToken)"
Write-Host ''
Write-Host 'The health check task runs as SYSTEM and logs to the Windows Event Log' -ForegroundColor DarkGray
Write-Host '(Application log, source ConnectWiseAutomateAgent).' -ForegroundColor DarkGray
Write-Host 'To remove the task, uncomment the unregister section at the end of this script.' -ForegroundColor DarkGray
