# ==============================================================================
# Troubleshooting-QuickDiagnostic.ps1
#
# All-in-one diagnostic script for the ConnectWise Automate agent. Gathers
# agent configuration, health status, server connectivity, port tests, recent
# errors, and proxy settings into a single summary report.
#
# Usage:
#   1. Run this script elevated (Administrator) on the target machine.
#   2. Review the on-screen report to identify issues.
#   3. Optionally redirect output to a file for remote review:
#        powershell -File Troubleshooting-QuickDiagnostic.ps1 > C:\Temp\CWAA-Diag.txt
#
# What this script checks:
#   - Agent installation and registration (ID, server, location, last check-in)
#   - Service health (LTService, LTSvcMon running status)
#   - Server reachability (agent.aspx endpoint and server version)
#   - Required TCP port connectivity (70, 80, 443, 8002, TrayPort)
#   - Recent agent errors (last 5 entries from LTErrors.txt)
#   - Proxy configuration (enabled, URL, username)
#
# Requirements:
#   - Windows PowerShell 3.0 or later
#   - Administrator privileges (for full registry and service access)
# ==============================================================================

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
}
catch {
    # WARNING: Invoke-Expression executes downloaded code. See security note above.
    # This fallback is ONLY for systems where the PowerShell Gallery is unavailable.
    # The URL is pinned to a specific release tag — it will not change after publication.
    $URI = "https://github.com/christaylorcodes/ConnectWiseAutomateAgent/releases/download/v$ModuleVersion/ConnectWiseAutomateAgent.psm1"
    (New-Object Net.WebClient).DownloadString($URI) | Invoke-Expression
}

# --- Diagnostic Banner -------------------------------------------------------

$diagnosticTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Host ''
Write-Host '=====================================================================' -ForegroundColor Cyan
Write-Host '  ConnectWise Automate Agent - Quick Diagnostic Report' -ForegroundColor Cyan
Write-Host "  Generated: $diagnosticTimestamp" -ForegroundColor Cyan
Write-Host "  Computer:  $env:COMPUTERNAME" -ForegroundColor Cyan
Write-Host '=====================================================================' -ForegroundColor Cyan
Write-Host ''

# Track summary findings for the final report
$summaryFindings = @()

# --- Step 1: Agent Information ------------------------------------------------

Write-Host '--- Agent Information ---' -ForegroundColor Yellow
$agentInfo = $null
try {
    $agentInfo = Get-CWAAInfo -ErrorAction Stop
}
catch {
    Write-Host "  ERROR: Unable to read agent configuration. The agent may not be installed." -ForegroundColor Red
    Write-Host "  Detail: $($_.Exception.Message)" -ForegroundColor Red
    $summaryFindings += 'FAIL: Agent configuration not readable'
}

if ($agentInfo) {
    $agentId = $agentInfo | Select-Object -ExpandProperty 'ID' -ErrorAction SilentlyContinue
    $agentServer = ($agentInfo | Select-Object -ExpandProperty 'Server' -ErrorAction SilentlyContinue) -join ', '
    $agentLocationId = $agentInfo | Select-Object -ExpandProperty 'LocationID' -ErrorAction SilentlyContinue
    $lastSuccessStatus = $agentInfo | Select-Object -ExpandProperty 'LastSuccessStatus' -ErrorAction SilentlyContinue
    $heartbeatLastSent = $agentInfo | Select-Object -ExpandProperty 'HeartbeatLastSent' -ErrorAction SilentlyContinue

    Write-Host "  Agent ID:       $agentId"
    Write-Host "  Server:         $agentServer"
    Write-Host "  Location ID:    $agentLocationId"
    Write-Host "  Last Check-in:  $lastSuccessStatus"
    Write-Host "  Last Heartbeat: $heartbeatLastSent"

    if ($agentId -ge 1) {
        $summaryFindings += 'OK: Agent is installed and registered'
    }
    else {
        $summaryFindings += 'WARN: Agent is installed but has not registered (ID < 1)'
    }
}
else {
    Write-Host '  No agent information available.' -ForegroundColor DarkGray
}

Write-Host ''

# --- Step 2: Health Check -----------------------------------------------------

Write-Host '--- Health Status ---' -ForegroundColor Yellow
try {
    $healthResult = Test-CWAAHealth -ErrorAction Stop
    Write-Host "  Agent Installed:   $($healthResult.AgentInstalled)"
    Write-Host "  Services Running:  $($healthResult.ServicesRunning)"
    Write-Host "  Last Contact:      $($healthResult.LastContact)"
    Write-Host "  Last Heartbeat:    $($healthResult.LastHeartbeat)"
    Write-Host "  Server Address:    $($healthResult.ServerAddress)"

    if ($healthResult.Healthy) {
        Write-Host "  Overall Healthy:   $($healthResult.Healthy)" -ForegroundColor Green
        $summaryFindings += 'OK: Agent is healthy'
    }
    else {
        Write-Host "  Overall Healthy:   $($healthResult.Healthy)" -ForegroundColor Red
        $summaryFindings += 'FAIL: Agent is NOT healthy'
    }
}
catch {
    Write-Host "  ERROR: Health check failed. Detail: $($_.Exception.Message)" -ForegroundColor Red
    $summaryFindings += 'FAIL: Health check could not complete'
}

Write-Host ''

# --- Step 3: Server Connectivity ----------------------------------------------

# Discover the server from agent config or backup for connectivity and port tests
$discoveredServer = $null
if ($agentInfo) {
    $discoveredServer = ($agentInfo | Select-Object -ExpandProperty 'Server' -ErrorAction SilentlyContinue) | Select-Object -First 1
}
if (-not $discoveredServer) {
    try {
        $discoveredServer = (Get-CWAAInfoBackup -ErrorAction SilentlyContinue | Select-Object -ExpandProperty 'Server' -ErrorAction SilentlyContinue) | Select-Object -First 1
    }
    catch { }
}

Write-Host '--- Server Connectivity ---' -ForegroundColor Yellow
if ($discoveredServer) {
    try {
        $connectivityResult = Test-CWAAServerConnectivity -Server $discoveredServer -ErrorAction Stop
        Write-Host "  Server:        $($connectivityResult.Server)"
        if ($connectivityResult.Available) {
            Write-Host "  Available:     $($connectivityResult.Available)" -ForegroundColor Green
            Write-Host "  Version:       $($connectivityResult.Version)"
            $summaryFindings += "OK: Server '$discoveredServer' is reachable"
        }
        else {
            Write-Host "  Available:     $($connectivityResult.Available)" -ForegroundColor Red
            Write-Host "  Error:         $($connectivityResult.ErrorMessage)" -ForegroundColor Red
            $summaryFindings += "FAIL: Server '$discoveredServer' is NOT reachable"
        }
    }
    catch {
        Write-Host "  ERROR: Connectivity test failed. Detail: $($_.Exception.Message)" -ForegroundColor Red
        $summaryFindings += 'FAIL: Server connectivity test could not complete'
    }
}
else {
    Write-Host '  No server could be discovered from agent config or backup.' -ForegroundColor DarkGray
    Write-Host '  Skipping connectivity test.' -ForegroundColor DarkGray
    $summaryFindings += 'SKIP: No server discovered for connectivity test'
}

Write-Host ''

# --- Step 4: Port Test --------------------------------------------------------

Write-Host '--- Port Connectivity ---' -ForegroundColor Yellow
if ($discoveredServer) {
    try {
        Test-CWAAPort -Server $discoveredServer -ErrorAction SilentlyContinue
        $summaryFindings += 'INFO: Port test completed (review details above)'
    }
    catch {
        Write-Host "  ERROR: Port test failed. Detail: $($_.Exception.Message)" -ForegroundColor Red
        $summaryFindings += 'FAIL: Port test could not complete'
    }
}
else {
    Write-Host '  No server discovered. Skipping port test.' -ForegroundColor DarkGray
    $summaryFindings += 'SKIP: No server discovered for port test'
}

Write-Host ''

# --- Step 5: Recent Errors ----------------------------------------------------

Write-Host '--- Recent Agent Errors (last 5) ---' -ForegroundColor Yellow
try {
    $recentErrors = Get-CWAAError -ErrorAction Stop |
        Sort-Object Timestamp -Descending |
        Select-Object -First 5

    if ($recentErrors) {
        foreach ($errorEntry in $recentErrors) {
            $timestampDisplay = if ($errorEntry.Timestamp) { $errorEntry.Timestamp.ToString('yyyy-MM-dd HH:mm:ss') } else { '(unknown)' }
            Write-Host "  [$timestampDisplay] $($errorEntry.Message)" -ForegroundColor DarkGray
        }
        $summaryFindings += "INFO: $(@($recentErrors).Count) recent error(s) found in agent log"
    }
    else {
        Write-Host '  No errors found in agent log.' -ForegroundColor Green
        $summaryFindings += 'OK: No errors in agent log'
    }
}
catch {
    Write-Host "  Unable to read error log. Detail: $($_.Exception.Message)" -ForegroundColor DarkGray
    $summaryFindings += 'SKIP: Could not read agent error log'
}

Write-Host ''

# --- Step 6: Proxy Configuration ----------------------------------------------

Write-Host '--- Proxy Configuration ---' -ForegroundColor Yellow
try {
    $proxyConfig = Get-CWAAProxy -ErrorAction SilentlyContinue
    if ($proxyConfig) {
        Write-Host "  Enabled:        $($proxyConfig.Enabled)"
        Write-Host "  Proxy URL:      $($proxyConfig.ProxyServerURL)"
        Write-Host "  Proxy Username: $($proxyConfig.ProxyUsername)"
        if ($proxyConfig.Enabled) {
            $summaryFindings += "INFO: Proxy is enabled ($($proxyConfig.ProxyServerURL))"
        }
        else {
            $summaryFindings += 'OK: No proxy configured'
        }
    }
    else {
        Write-Host '  No proxy information available.' -ForegroundColor DarkGray
        $summaryFindings += 'OK: No proxy configured'
    }
}
catch {
    Write-Host "  Unable to read proxy settings. Detail: $($_.Exception.Message)" -ForegroundColor DarkGray
    $summaryFindings += 'SKIP: Could not read proxy settings'
}

Write-Host ''

# --- Summary Report -----------------------------------------------------------

Write-Host '=====================================================================' -ForegroundColor Cyan
Write-Host '  Summary' -ForegroundColor Cyan
Write-Host '=====================================================================' -ForegroundColor Cyan
foreach ($finding in $summaryFindings) {
    if ($finding -match '^OK:') {
        Write-Host "  $finding" -ForegroundColor Green
    }
    elseif ($finding -match '^FAIL:') {
        Write-Host "  $finding" -ForegroundColor Red
    }
    elseif ($finding -match '^WARN:') {
        Write-Host "  $finding" -ForegroundColor Yellow
    }
    else {
        Write-Host "  $finding" -ForegroundColor DarkGray
    }
}
Write-Host ''
Write-Host "Diagnostic complete. Generated at $diagnosticTimestamp on $env:COMPUTERNAME." -ForegroundColor Cyan
