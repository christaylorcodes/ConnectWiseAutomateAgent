# ==============================================================================
# PipelineUsage.ps1
#
# Demonstrates PowerShell pipeline patterns with ConnectWiseAutomateAgent
# functions. Shows how to chain commands, use pipeline input, filter results,
# and combine with Invoke-Command for multi-machine operations.
#
# Usage:
#   1. Uncomment and adapt the examples below for your environment.
#   2. Multi-machine examples require PowerShell Remoting (WinRM) configured
#      on the target machines.
#   3. All examples assume the module is already imported.
#
# Requirements:
#   - Windows PowerShell 3.0 or later
#   - Administrator privileges (for most operations)
#   - PowerShell Remoting (for Invoke-Command examples)
# ==============================================================================

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

# ==============================================================================
# EXAMPLES
# ==============================================================================

# --- Example 1: Basic Pipeline — Select Specific Properties ------------------
#
# Get-CWAAInfo returns a PSCustomObject with many properties. Use
# Select-Object to extract just what you need.

# Get-CWAAInfo | Select-Object ID, Server, LocationID, LastSuccessStatus, LastContact

# --- Example 2: Health Check to Conditional Action ---------------------------
#
# Test-CWAAHealth returns a structured object. Use its properties to
# decide what action to take.

# $health = Test-CWAAHealth
# if ($health.AgentInstalled -and -not $health.ServicesRunning) {
#     Write-Host "Agent installed but services stopped. Restarting..."
#     Restart-CWAA
# }
# elseif (-not $health.AgentInstalled) {
#     Write-Host "Agent not installed."
# }
# else {
#     Write-Host "Agent healthy."
# }

# --- Example 3: Filter Agent Errors by Pattern ------------------------------
#
# Get-CWAAError returns structured error entries. Use Where-Object to
# filter for specific error types.

# Get-CWAAError -Days 7 | Where-Object { $_.Message -match 'heartbeat|timeout|connection' }

# --- Example 4: Multi-Machine Agent Inventory --------------------------------
#
# Use Invoke-Command to gather agent information from multiple machines.
# Requires PowerShell Remoting (WinRM) on all targets.

# $computers = 'PC-001', 'PC-002', 'PC-003'
#
# $inventory = Invoke-Command -ComputerName $computers -ScriptBlock {
#     Import-Module ConnectWiseAutomateAgent -ErrorAction SilentlyContinue
#     Get-CWAAInfo | Select-Object @{N='Computer'; E={$env:COMPUTERNAME}}, ID, Server, LocationID, LastSuccessStatus
# } -ErrorAction SilentlyContinue
#
# $inventory | Sort-Object Computer | Format-Table -AutoSize

# --- Example 5: Export Agent Inventory to CSV --------------------------------
#
# Combine Invoke-Command with Export-Csv for reporting.

# $computers = (Get-ADComputer -Filter * -SearchBase 'OU=Workstations,DC=example,DC=com').Name
#
# Invoke-Command -ComputerName $computers -ScriptBlock {
#     Import-Module ConnectWiseAutomateAgent -ErrorAction SilentlyContinue
#     Get-CWAAInfo
# } -ErrorAction SilentlyContinue |
#     Select-Object PSComputerName, ID, Server, LocationID, LastContact, LastSuccessStatus |
#     Export-Csv 'AgentInventory.csv' -NoTypeInformation
#
# Write-Host "Exported inventory for $($computers.Count) machines to AgentInventory.csv"

# --- Example 6: Fleet Health Assessment --------------------------------------
#
# Check health across multiple machines and filter for unhealthy agents.

# $computers = 'PC-001', 'PC-002', 'PC-003'
#
# $results = Invoke-Command -ComputerName $computers -ScriptBlock {
#     Import-Module ConnectWiseAutomateAgent -ErrorAction SilentlyContinue
#     Test-CWAAHealth
# } -ErrorAction SilentlyContinue
#
# Write-Host "`n--- Unhealthy Agents ---"
# $results | Where-Object { -not $_.Healthy } |
#     Format-Table PSComputerName, AgentInstalled, ServicesRunning, LastContactRecent -AutoSize
#
# Write-Host "--- Summary ---"
# Write-Host "Total: $($results.Count)  Healthy: $(($results | Where-Object Healthy).Count)  Unhealthy: $(($results | Where-Object { -not $_.Healthy }).Count)"

# --- Example 7: Backup Then Uninstall Pipeline -------------------------------
#
# Chain operations sequentially for a safe removal workflow.

# $serverUrl = 'https://automate.example.com'
#
# Write-Host 'Creating backup...'
# New-CWAABackup
#
# Write-Host 'Verifying backup...'
# $backup = Get-CWAAInfoBackup
# if ($backup.Server) {
#     Write-Host "Backup verified (Server: $($backup.Server), ID: $($backup.ID))"
#     Write-Host 'Proceeding with uninstall...'
#     Uninstall-CWAA -Server $serverUrl
# }
# else {
#     Write-Host 'Backup failed — aborting uninstall.' -ForegroundColor Red
# }

# --- Example 8: ForEach-Object with Splatting --------------------------------
#
# Deploy agents to multiple locations using splatting for clean parameter passing.

# $deployments = @(
#     @{ Server = 'https://automate.example.com'; LocationID = 1; InstallerToken = 'TokenForSiteA' }
#     @{ Server = 'https://automate.example.com'; LocationID = 2; InstallerToken = 'TokenForSiteB' }
#     @{ Server = 'https://automate.example.com'; LocationID = 3; InstallerToken = 'TokenForSiteC' }
# )
#
# $deployments | ForEach-Object {
#     $params = $_
#     Write-Host "Deploying to LocationID $($params.LocationID)..."
#     Install-CWAA @params
# }

# --- Example 9: Compare Current Settings to Backup --------------------------
#
# Use calculated properties to build a comparison report.

# $current = Get-CWAAInfo
# $backup  = Get-CWAAInfoBackup
#
# 'Server', 'LocationID', 'ID', 'Version' | ForEach-Object {
#     [PSCustomObject]@{
#         Property = $_
#         Current  = $current.$_
#         Backup   = $backup.$_
#         Match    = $current.$_ -eq $backup.$_
#     }
# } | Format-Table -AutoSize

# --- Example 10: Encrypt Multiple Values via Pipeline -------------------------
#
# ConvertTo-CWAASecurity accepts pipeline input, so you can encrypt an array
# of strings in one expression. ConvertFrom-CWAASecurity also supports pipeline,
# enabling a full round-trip chain.

# 'Password1', 'Secret2', 'Token3' | ConvertTo-CWAASecurity
#
# # Round-trip: encrypt then decrypt in a single pipeline
# 'Password1', 'Secret2', 'Token3' | ConvertTo-CWAASecurity | ConvertFrom-CWAASecurity

# --- Example 11: Pipe Agent Info to Repair ------------------------------------
#
# Get-CWAAInfo returns an object with a Server property. Repair-CWAA accepts
# Server via ValueFromPipelineByPropertyName, enabling direct piping.

# Get-CWAAInfo | Repair-CWAA -InstallerToken 'abc123def456' -LocationID 42

# --- Example 12: Rename Agent from Pipeline -----------------------------------
#
# Rename-CWAAAddRemove accepts the Name parameter from pipeline input.

# 'My Managed Agent' | Rename-CWAAAddRemove

# --- Example 13: Test Server Connectivity from Agent Config -------------------
#
# Test-CWAAServerConnectivity accepts Server via ValueFromPipelineByPropertyName.
# Pipe the installed agent's info to verify its configured server is reachable.

# Get-CWAAInfo | Test-CWAAServerConnectivity

# --- Example 14: Test Required Ports from Agent Config ------------------------
#
# Test-CWAAPort accepts Server and TrayPort via ValueFromPipelineByPropertyName.
# Pipe agent info to test all required ports using the agent's own configuration.

# Get-CWAAInfo | Test-CWAAPort

# --- Example 15: Set Log Level from Pipeline -----------------------------------
#
# Set-CWAALogLevel accepts Level via ValueFromPipeline.
# Useful for scripted toggle or conditional log level changes.

# 'Verbose' | Set-CWAALogLevel

# --- Example 16: Register Health Check from Agent Config ----------------------
#
# Register-CWAAHealthCheckTask accepts Server and LocationID via
# ValueFromPipelineByPropertyName. Pipe agent info to register a health check
# task using the agent's current server and location.

# Get-CWAAInfo | Register-CWAAHealthCheckTask -InstallerToken 'abc123def456'
