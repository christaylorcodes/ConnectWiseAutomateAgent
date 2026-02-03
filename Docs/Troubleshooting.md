# Troubleshooting Guide

Symptom-based reference for diagnosing and resolving ConnectWise Automate agent issues. Each section starts with the symptom, lists diagnostic commands, and provides resolution steps.

For a quick all-in-one diagnostic, run the [Troubleshooting-QuickDiagnostic.ps1](../Examples/Troubleshooting-QuickDiagnostic.ps1) example script.

---

## Quick Diagnostic

Run this one-liner for a snapshot of agent health:

```powershell
Get-CWAAInfo | Format-List ID, Server, LocationID, LastSuccessStatus, LastContact, LastHeartbeat
```

For a more thorough assessment:

```powershell
Test-CWAAHealth -TestServerConnectivity | Format-List
```

---

## Agent Not Appearing in Automate Console

The agent is installed but does not show up or appears offline in the Automate server.

### Diagnose

```powershell
# Is the agent installed?
Get-CWAAInfo | Format-List ID, Server, LocationID

# Are services running?
Get-Service LTService, LTSvcMon -ErrorAction SilentlyContinue | Format-Table Name, Status

# Can the agent reach the server?
Test-CWAAServerConnectivity | Format-List

# Are the required ports open?
Test-CWAAPort -Server 'automate.example.com' | Format-Table
```

### Common Causes

- **Services not running:** `Restart-CWAA`
- **Wrong server URL:** Check `(Get-CWAAInfo).Server` against your expected URL
- **Firewall blocking ports:** TCP 70, 80, 443, 8002 must be open to the server. Run `Test-CWAAPort` to verify.
- **Agent not registered:** If `ID` is empty, the agent never completed registration. Run `Redo-CWAA` to reinstall.

### Resolution

```powershell
# Restart services
Restart-CWAA

# If services won't stay running, reinstall
Redo-CWAA -Server 'automate.example.com' -LocationID 1 -InstallerToken 'MyToken'
```

---

## Agent Services Keep Stopping

`LTService` or `LTSvcMon` repeatedly stop after being started.

### Diagnose

```powershell
# Check current service state
Get-Service LTService, LTSvcMon | Format-Table Name, Status, StartType

# Check recent agent errors
Get-CWAAError -Days 1 | Select-Object -First 10

# Check probe errors
Get-CWAAProbeError -Days 1 | Select-Object -First 10

# Check Windows Event Log for module events
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'ConnectWiseAutomateAgent' } -MaxEvents 20 -ErrorAction SilentlyContinue | Format-Table TimeCreated, Id, Message -Wrap
```

### Common Causes

- **Corrupt installation:** Files missing or damaged in `C:\Windows\LTSVC`
- **Registry corruption:** Agent configuration values missing or invalid
- **Conflicting software:** Security software blocking agent processes

### Resolution

```powershell
# Try restart first
Restart-CWAA

# If it keeps failing, repair (escalating remediation)
Repair-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

---

## Agent Offline / Not Checking In

The agent appears in the Automate console but shows as offline.

### Diagnose

```powershell
# When did the agent last check in?
$info = Get-CWAAInfo
Write-Host "Last Contact:   $($info.LastContact)"
Write-Host "Last Heartbeat: $($info.LastHeartbeat)"
Write-Host "Last Success:   $($info.LastSuccessStatus)"

# Full health assessment
Test-CWAAHealth -TestServerConnectivity
```

### Interpreting Health Check Results

| Property | Healthy Value | Meaning |
| --- | --- | --- |
| `AgentInstalled` | `True` | LTService service exists |
| `ServicesRunning` | `True` | LTService and LTSvcMon are running |
| `LastContactRecent` | `True` | LastContact within the threshold |
| `ServerReachable` | `True` | HTTPS connection to server succeeded |

### Resolution

```powershell
# If services are running but not checking in — force a status update
Invoke-CWAACommand -Command 'Send Status'

# If server unreachable — check network/firewall
Test-CWAAPort -Server 'automate.example.com'

# If nothing works — full reinstall
Redo-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

---

## Installation Fails

`Install-CWAA` or `Redo-CWAA` fails during agent deployment.

### Diagnose

```powershell
# Run installation with verbose output for full diagnostics
Install-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1 -Verbose -Debug

# Check if a previous installation exists
Get-CWAAInfo -ErrorAction SilentlyContinue

# Check installer temp directory
Get-ChildItem "$env:windir\Temp\LabTech" -ErrorAction SilentlyContinue
```

### Common Causes

| Symptom | Cause | Fix |
| --- | --- | --- |
| "Needs to be ran as Administrator" | Not elevated | Run PowerShell as Administrator |
| "Agent already installed" | Existing agent present | Use `-Force` or `Uninstall-CWAA` first |
| Download integrity check failed | Corrupt/incomplete download | Check network, proxy, and firewall. Retry. |
| "Unable to download" | Server unreachable | Verify server URL, check `Test-CWAAServerConnectivity` |
| MSI execution failed | .NET 3.5 missing or MSI conflict | Check `Add-WindowsFeature NET-Framework-Core` or use `-SkipDotNet` |
| Server version warning | Server below v200.197 | Update the Automate server (security concern) |

### Resolution

```powershell
# Clean up failed installation artifacts, then retry
Uninstall-CWAA -Server 'automate.example.com' -Force
Install-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

---

## TrayPort Conflicts

The agent cannot bind to its local communication port (default: 42000).

### Diagnose

```powershell
# Check which TrayPort the agent is configured for
Get-CWAAInfo | Select-Object -ExpandProperty TrayPort

# Test if ports 42000-42009 are available
Test-CWAAPort | Format-Table
```

### About TrayPort

The Automate agent uses a local TCP port (42000-42009) for communication between the `LTService` service and the system tray icon. During installation, `Install-CWAA` automatically scans ports 42000-42009 and picks the first available one.

### Resolution

If another application is occupying the TrayPort:

```powershell
# Find what is using the port
netstat -ano | Select-String ':42000'

# Reinstall with a specific port
Redo-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1 -TrayPort 42001
```

---

## Proxy Issues

The agent cannot communicate through a network proxy.

### Diagnose

```powershell
# View current proxy configuration
Get-CWAAProxy | Format-List

# Test server connectivity (will use configured proxy)
Test-CWAAServerConnectivity
```

See [ProxyConfiguration.ps1](../Examples/ProxyConfiguration.ps1) for a step-by-step proxy setup walkthrough.

### Common Causes

- **No proxy configured:** Agent uses direct connection but network requires proxy
- **Wrong proxy URL:** Typo or outdated proxy address
- **Credential issue:** Proxy requires authentication but credentials are missing or expired

### Resolution

```powershell
# Auto-detect system proxy (reads from IE/WinHTTP settings)
Set-CWAAProxy -DetectProxy

# Or set manually
Set-CWAAProxy -ProxyServerURL 'proxy.example.com:8080' -ProxyUsername 'user' -ProxyPassword (ConvertTo-SecureString 'pass' -AsPlainText -Force)

# Clear proxy if misconfigured
Set-CWAAProxy -ResetProxy
```

---

## WOW64 / 32-bit vs 64-bit Mismatches

Agent registry keys or files are missing or inconsistent between 32-bit and 64-bit views.

### Background

On 64-bit Windows, 32-bit PowerShell sees a different registry view (`HKLM:\SOFTWARE\Wow6432Node\LabTech\Service`) than 64-bit PowerShell (`HKLM:\SOFTWARE\LabTech\Service`). The Automate agent is a 32-bit application that writes to the WOW64 node.

### Diagnose

```powershell
# Check which PowerShell architecture you are running
[IntPtr]::Size  # 4 = 32-bit, 8 = 64-bit

# Check if WOW64 is active
$env:PROCESSOR_ARCHITEW6432  # Non-empty = running 32-bit on 64-bit OS
```

### Module Behavior

- **Module mode:** If imported in 32-bit PowerShell on a 64-bit OS, the module emits a warning. Re-import in 64-bit PowerShell.
- **Direct download mode (.psm1):** The script automatically relaunches under the native 64-bit PowerShell host via `Initialize-CWAA`.

### Resolution

Always run ConnectWiseAutomateAgent from a 64-bit PowerShell session:

```powershell
# Launch 64-bit PowerShell explicitly
%SystemRoot%\SysNative\WindowsPowerShell\v1.0\powershell.exe
```

---

## Certificate Errors During Install/Update

SSL/TLS errors when downloading the agent installer or communicating with the server.

### Diagnose

```powershell
# Test basic HTTPS connectivity
Test-CWAAServerConnectivity -Server 'automate.example.com'

# Try with verbose output to see SSL callback details
Install-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1 -Verbose -Debug
```

### About the SSL Trust Model

The module uses a graduated trust model (see [Security Model](Security.md#ssl-certificate-validation)):

1. IP addresses — auto-bypass (always works)
2. Hostname name mismatches — tolerated
3. Chain/trust errors — **blocked by default**

### Resolution

If you get certificate errors with a hostname URL and a self-signed certificate:

```powershell
# Use -SkipCertificateCheck to bypass all validation for this session
Install-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1 -SkipCertificateCheck
```

Or connect by IP address (auto-bypassed):

```powershell
Install-CWAA -Server '10.0.0.50' -InstallerToken 'MyToken' -LocationID 1
```

---

## Advanced Diagnostics

### Increase Log Verbosity

```powershell
# Set agent log level to Verbose (1 = Normal, 2 = Verbose)
Set-CWAALogLevel -Level 2

# After reproducing the issue, read the detailed logs
Get-CWAAError -Days 1

# Reset to normal verbosity
Set-CWAALogLevel -Level 1
```

### Read Structured Errors

```powershell
# Agent errors (from C:\Windows\LTSVC\errors.txt)
Get-CWAAError -Days 7 | Format-Table Time, Source, Message -Wrap

# Probe errors (from C:\Windows\LTSVC\Probes\*.txt)
Get-CWAAProbeError -Days 7
```

### Compare Current vs Backup Settings

```powershell
# Current agent config
$current = Get-CWAAInfo

# Last backed-up config (from before uninstall/reset)
$backup = Get-CWAAInfoBackup

# Compare key fields
'Server', 'LocationID', 'ID', 'Password' | ForEach-Object {
    [PSCustomObject]@{
        Property = $_
        Current  = $current.$_
        Backup   = $backup.$_
        Match    = $current.$_ -eq $backup.$_
    }
} | Format-Table
```

### Audit Event Log

```powershell
# All module events
Get-WinEvent -FilterHashtable @{
    LogName      = 'Application'
    ProviderName = 'ConnectWiseAutomateAgent'
} -MaxEvents 50 -ErrorAction SilentlyContinue | Format-Table TimeCreated, Id, LevelDisplayName, Message -Wrap

# Filter by category (see event ID ranges)
# 1000-1039: Installation
# 2000-2029: Service Control
# 3000-3069: Configuration
# 4000-4039: Health/Monitoring
```

---

## Automated Remediation

### One-Time Repair

```powershell
Repair-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

`Repair-CWAA` assesses health and escalates: restart services, then reinstall if the agent has been offline beyond the threshold.

### Scheduled Health Checks

```powershell
# Register a recurring health check (runs every 60 minutes by default)
Register-CWAAHealthCheckTask -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1

# Check task status
Get-ScheduledTask -TaskName 'CWAA Health Check' -ErrorAction SilentlyContinue

# Remove when no longer needed
Unregister-CWAAHealthCheckTask
```

See [HealthCheck-Monitoring.ps1](../Examples/HealthCheck-Monitoring.ps1) for a complete walkthrough.
