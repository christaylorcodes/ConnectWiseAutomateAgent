# ==============================================================================
# ProxyConfiguration.ps1
#
# Demonstrates how to view, configure, and clear proxy settings for the
# ConnectWise Automate agent using the CWAA module.
#
# Usage:
#   1. Run this script elevated (Administrator) on the target machine.
#   2. The script displays the current proxy settings, then shows example
#      commands for setting and clearing proxy configuration.
#   3. To actually apply proxy changes, uncomment the relevant section below
#      and fill in your proxy details.
#
# What this script covers:
#   - Viewing current proxy settings with Get-CWAAProxy
#   - Setting a proxy with URL, username, and password via Set-CWAAProxy
#   - Auto-detecting system proxy settings with Set-CWAAProxy -DetectProxy
#   - Clearing proxy settings with Set-CWAAProxy -ResetProxy
#   - Verifying proxy changes after applying them
#
# How proxy settings work in the Automate agent:
#   - Proxy URL, username, and password are stored encrypted in the agent's
#     registry settings under HKLM:\SOFTWARE\LabTech\Service\Settings.
#   - When Set-CWAAProxy detects a change, it stops the agent services, writes
#     the new values, and restarts the services automatically.
#   - Get-CWAAProxy reads and decrypts the stored values for display.
#
# Requirements:
#   - Windows PowerShell 3.0 or later
#   - Administrator privileges (for registry and service access)
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

# --- Step 1: View Current Proxy Settings --------------------------------------

Write-Host '--- Current Proxy Settings ---' -ForegroundColor Cyan

$currentProxy = $null
try {
    $currentProxy = Get-CWAAProxy -ErrorAction Stop
}
catch {
    Write-Host "Unable to read proxy settings. The agent may not be installed." -ForegroundColor Red
    Write-Host "Detail: $($_.Exception.Message)" -ForegroundColor Red
}

if ($currentProxy) {
    Write-Host "  Enabled:   $($currentProxy.Enabled)"
    Write-Host "  Proxy URL: $($currentProxy.ProxyServerURL)"
    Write-Host "  Username:  $($currentProxy.ProxyUsername)"

    if ($currentProxy.Enabled) {
        Write-Host "`nA proxy is currently configured." -ForegroundColor Yellow
    }
    else {
        Write-Host "`nNo proxy is currently configured." -ForegroundColor Green
    }
}
else {
    Write-Host '  No proxy information available.' -ForegroundColor DarkGray
}

Write-Host ''

# --- Step 2: Set Proxy (Example - Uncomment to Use) --------------------------

# To configure a proxy with authentication, uncomment and fill in the block
# below with your proxy server details.
#
# IMPORTANT: ProxyPassword must be passed as a SecureString. The example below
# converts a plain text password for simplicity. In production, consider using
# Read-Host -AsSecureString or a credential store for the password.

# Write-Host '--- Setting Proxy ---' -ForegroundColor Cyan
#
# $ProxyUrl      = 'proxy.example.com:8080'
# $ProxyUser     = 'DOMAIN\proxyuser'
# $ProxyPass     = ConvertTo-SecureString 'YourProxyPassword' -AsPlainText -Force
#
# try {
#     Set-CWAAProxy -ProxyServerURL $ProxyUrl -ProxyUsername $ProxyUser -ProxyPassword $ProxyPass -ErrorAction Stop
#     Write-Host "Proxy set to '$ProxyUrl' with user '$ProxyUser'." -ForegroundColor Green
# }
# catch {
#     Write-Host "Failed to set proxy. Detail: $($_.Exception.Message)" -ForegroundColor Red
# }

# --- Step 3: Set Proxy Without Authentication (Example) -----------------------

# To configure a proxy that does not require credentials:

# Write-Host '--- Setting Proxy (No Auth) ---' -ForegroundColor Cyan
#
# try {
#     Set-CWAAProxy -ProxyServerURL 'proxy.example.com:8080' -ErrorAction Stop
#     Write-Host 'Proxy set successfully (no authentication).' -ForegroundColor Green
# }
# catch {
#     Write-Host "Failed to set proxy. Detail: $($_.Exception.Message)" -ForegroundColor Red
# }

# --- Step 4: Auto-Detect System Proxy (Example) ------------------------------

# DetectProxy reads the system proxy settings (IE/WinHTTP) and applies them to
# the Automate agent. This is useful in environments where proxy settings are
# pushed via GPO.

# Write-Host '--- Auto-Detecting System Proxy ---' -ForegroundColor Cyan
#
# try {
#     Set-CWAAProxy -DetectProxy -ErrorAction Stop
#     Write-Host 'System proxy detection complete.' -ForegroundColor Green
# }
# catch {
#     Write-Host "Failed to detect proxy. Detail: $($_.Exception.Message)" -ForegroundColor Red
# }

# --- Step 5: Clear / Reset Proxy (Example) ------------------------------------

# ResetProxy removes all proxy settings from the agent. The agent will connect
# directly to the Automate server without a proxy.

# Write-Host '--- Clearing Proxy Settings ---' -ForegroundColor Cyan
#
# try {
#     Set-CWAAProxy -ResetProxy -ErrorAction Stop
#     Write-Host 'Proxy settings cleared.' -ForegroundColor Green
# }
# catch {
#     Write-Host "Failed to clear proxy. Detail: $($_.Exception.Message)" -ForegroundColor Red
# }

# --- Step 6: Verify Proxy After Changes ---------------------------------------

# After making proxy changes (uncomment one of the sections above), uncomment
# this verification step to confirm the new settings took effect.

# Write-Host ''
# Write-Host '--- Verifying Proxy Settings ---' -ForegroundColor Cyan
#
# try {
#     $updatedProxy = Get-CWAAProxy -ErrorAction Stop
#     Write-Host "  Enabled:   $($updatedProxy.Enabled)"
#     Write-Host "  Proxy URL: $($updatedProxy.ProxyServerURL)"
#     Write-Host "  Username:  $($updatedProxy.ProxyUsername)"
#
#     if ($updatedProxy.Enabled) {
#         Write-Host "`nProxy is now active." -ForegroundColor Green
#     }
#     else {
#         Write-Host "`nProxy is not active (direct connection)." -ForegroundColor Green
#     }
# }
# catch {
#     Write-Host "Unable to verify proxy settings. Detail: $($_.Exception.Message)" -ForegroundColor Red
# }

Write-Host '--- Proxy Configuration Script Complete ---' -ForegroundColor Cyan
Write-Host ''
Write-Host 'To apply proxy changes, edit this script and uncomment the relevant section.' -ForegroundColor DarkGray
Write-Host 'After changes, use Get-CWAAProxy to verify the new settings.' -ForegroundColor DarkGray
