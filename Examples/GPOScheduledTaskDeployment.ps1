# ==============================================================================
# GPOScheduledTaskDeployment.ps1
#
# Deploys the ConnectWise Automate agent via a GPO-delivered scheduled task.
# This is the recommended approach for mass deployment across a domain.
#
# How it works:
#   1. A GPO creates a scheduled task on domain machines that calls this script
#      with -Server, -LocationID, and -InstallerToken parameters.
#   2. This script installs the agent if missing (or repairs if misconfigured).
#   3. It then registers a recurring health check task (Register-CWAAHealthCheckTask)
#      that runs Repair-CWAA every 6 hours to keep the agent connected.
#   4. On subsequent GPO runs, the script updates the health check task if the
#      InstallerToken has changed (supports monthly token rotation).
#
# GPO Setup:
#   Computer Configuration > Preferences > Control Panel Settings >
#   Scheduled Tasks > New > Scheduled Task (At least Windows 7)
#
#   General tab:
#     - Action: Create or Update
#     - When running the task, use the following user account: NT AUTHORITY\SYSTEM
#     - Run whether user is logged on or not
#     - Run with highest privileges
#
#   Triggers tab:
#     - At startup, with a 5-minute delay to allow network readiness
#
#   Actions tab:
#     - Start a program
#     - Program/script: C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe
#     - Add arguments:
#       -ExecutionPolicy Bypass -NoProfile -File "\\domain.local\NETLOGON\Deploy-CWAAAgent.ps1" -Server "automate.example.com" -LocationID 1 -InstallerToken "YourToken"
#
#   Conditions tab:
#     - Start only if the following network connection is available: Any connection
#
# Token rotation:
#   When you generate a new InstallerToken each month, update only the
#   -InstallerToken value in the GPO scheduled task arguments. On the next GPO
#   refresh (or reboot), this script detects the token change and updates the
#   recurring health check task automatically.
#
# What Repair-CWAA does (called by the health check task every 6 hours):
#   - Agent healthy and checking in        -> no action
#   - Agent hasn't checked in for 2+ hours -> restarts services, waits up to
#                                             2 minutes for recovery
#   - Still offline after 120+ hours       -> full reinstall via Redo-CWAA
#   - Agent config unreadable              -> uninstall and reinstall
#   - Agent pointing at wrong server       -> reinstall with correct server
#   - Agent not installed at all           -> fresh install from parameters
#
# Requirements:
#   - Windows PowerShell 3.0 or later
#   - SYSTEM context (GPO scheduled tasks run as SYSTEM)
#   - Network access to the Automate server and PowerShell Gallery (or the
#     single-file fallback URL)
#
# Security considerations:
#   - Store this script on a secured NETLOGON or SYSVOL share with restricted
#     write permissions. Anyone who can modify this script can run code as
#     SYSTEM on every domain machine.
#   - InstallerToken is visible in the scheduled task arguments. Restrict GPO
#     read access and NETLOGON permissions to Domain Computers and Domain
#     Admins only.
#   - Consider using GPO Item-Level Targeting to limit which OUs or groups
#     receive the task.
# ==============================================================================

[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$Server,

    [Parameter(Mandatory = $true)]
    [int]$LocationID,

    [Parameter(Mandatory = $true)]
    [string]$InstallerToken,

    [int]$HealthCheckIntervalHours = 6,

    [string]$TaskName = 'CWAAHealthCheck'
)

$ErrorActionPreference = 'Stop'

# --- Logging -----------------------------------------------------------------

# Log to file since GPO scheduled tasks have no interactive console.
$LogFile = "$env:windir\Temp\CWAA-GPODeploy.log"

function Write-Log {
    param ([string]$Message)
    $entry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $LogFile -Value $entry -ErrorAction SilentlyContinue
}

Write-Log '--- CWAA GPO deployment script started ---'

# --- Kill Duplicate Processes ------------------------------------------------

# Prevent overlapping runs if GPO fires while a previous run is still going.
Get-CimInstance Win32_Process | Where-Object {
    $_.Name -eq 'powershell.exe' -and
    $_.CommandLine -match 'GPOScheduledTaskDeployment|Deploy-CWAAAgent' -and
    $_.ProcessId -ne $PID
} | ForEach-Object {
    Write-Log "Killing duplicate process $($_.ProcessId)."
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

# --- Module Loading ----------------------------------------------------------

# SECURITY NOTE: Version locking
#
# Production scripts should pin to a specific module version. This prevents
# untested updates from rolling out to endpoints and mitigates supply-chain
# risk. Update $ModuleVersion deliberately after validating new releases.
#
# The Invoke-Expression fallback downloads and executes code at runtime.
# It is provided ONLY for systems where the PowerShell Gallery is unavailable
# (e.g., PS 2.0, restricted networks). The fallback URL is version-locked to
# a GitHub Release so the code is immutable after publication.
#
# PREFERRED: Use Install-Module from the PowerShell Gallery instead:
#   Install-Module 'ConnectWiseAutomateAgent' -RequiredVersion '1.0.0'

$Module = 'ConnectWiseAutomateAgent'
$ModuleVersion = '1.0.0'  # Pin to a tested version — update after validating new releases

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
try {
    $installed = Get-Module $Module -ListAvailable |
        Where-Object { $_.Version -eq $ModuleVersion }
    if (-not $installed) {
        Install-Module $Module -RequiredVersion $ModuleVersion -Force -Scope AllUsers
    }
    Import-Module $Module -RequiredVersion $ModuleVersion *>$null

    Write-Log "Module '$Module' v$ModuleVersion loaded."
}
catch {
    Write-Log 'PowerShell Gallery unavailable. Falling back to version-locked single-file download.'
    # WARNING: Invoke-Expression executes downloaded code. See security note above.
    # This fallback is ONLY for systems where the PowerShell Gallery is unavailable.
    # The URL is pinned to a specific release tag — it will not change after publication.
    $URI = "https://github.com/christaylorcodes/ConnectWiseAutomateAgent/releases/download/v$ModuleVersion/ConnectWiseAutomateAgent.ps1"
    (New-Object Net.WebClient).DownloadString($URI) | Invoke-Expression
}

# --- Install or Repair the Agent ---------------------------------------------

$installParameters = @{
    Server         = $Server
    LocationID     = $LocationID
    InstallerToken = $InstallerToken
}

$agentInfo = Get-CWAAInfo -ErrorAction SilentlyContinue
$agentId = $agentInfo | Select-Object -ExpandProperty 'ID' -ErrorAction SilentlyContinue

if ($agentInfo -and $agentId -ge 1) {
    # Agent is installed. Check if it's pointed at the correct server.
    $currentServers = ($agentInfo.'Server Address' -split '\|') | Where-Object { $_ }
    if ($currentServers -notcontains $Server) {
        Write-Log "Agent installed but pointed at wrong server ($($currentServers -join ', ')). Reinstalling."
        Redo-CWAA @installParameters
        Write-Log 'Reinstall completed.'
    }
    else {
        Write-Log "Agent already installed. ID: $agentId, Server: $($currentServers -join ', '). Skipping install."
    }
}
else {
    # Agent not installed or not registered. Install fresh.
    Write-Log 'Agent not detected. Installing...'
    try {
        # Redo-CWAA removes leftover files from partial/corrupted installs before
        # installing fresh -- safer than Install-CWAA for mass deployment.
        Redo-CWAA @installParameters
        Write-Log 'Installation completed.'
    }
    catch {
        Write-Log "ERROR: Installation failed. Error: $($_.Exception.Message)"
        exit 1
    }

    # Verify
    $agentInfo = Get-CWAAInfo -ErrorAction SilentlyContinue
    $agentId = $agentInfo | Select-Object -ExpandProperty 'ID' -ErrorAction SilentlyContinue
    if ($agentId -ge 1) {
        Write-Log "Agent registered. ID: $agentId, Location: $($agentInfo.LocationID)"
    }
    else {
        Write-Log 'WARNING: Agent installed but has not registered yet. Health check task will monitor.'
    }
}

# --- Register / Update Health Check Task -------------------------------------

# Register-CWAAHealthCheckTask creates a recurring scheduled task that runs
# Repair-CWAA every $HealthCheckIntervalHours. If the task already exists and
# the InstallerToken matches, it's left alone. If the token has changed (monthly
# rotation), the task is automatically recreated with the new token.

Write-Log 'Ensuring health check task is registered...'
try {
    New-CWAABackup -ErrorAction SilentlyContinue

    $taskParameters = @{
        InstallerToken = $InstallerToken
        Server         = $Server
        LocationID     = $LocationID
        TaskName       = $TaskName
        IntervalHours  = $HealthCheckIntervalHours
    }
    Register-CWAAHealthCheckTask @taskParameters

    Write-Log "Health check task '$TaskName' is active (runs every $HealthCheckIntervalHours hours)."
}
catch {
    Write-Log "WARNING: Failed to register health check task. Error: $($_.Exception.Message)"
}

Write-Log '--- CWAA GPO deployment script finished ---'
exit 0
