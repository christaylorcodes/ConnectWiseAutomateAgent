# Frequently Asked Questions

## Installation & Deployment

### What authentication method should I use?

Use **InstallerToken** whenever possible. It is scoped, revocable, and more secure than the server-wide `ServerPassword`. Generate tokens in the Automate console.

```powershell
Install-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

`ServerPassword` is supported for backward compatibility with older Automate servers and existing scripts. See [Security Model](Security.md#authentication-installertoken-vs-serverpassword) for details.

### Does the module work on Windows Server Core?

Yes. PowerShell 3.0+ is available on all Server Core editions. The module has no GUI dependencies.

### How do I deploy agents via GPO?

Use the [GPOScheduledTaskDeployment.ps1](../Examples/GPOScheduledTaskDeployment.ps1) example script. It creates a Group Policy scheduled task that runs the installation on target machines.

### Can I deploy with Intune, SCCM, or another RMM tool?

Yes. Any tool that can execute a PowerShell script with administrator privileges can deploy the agent. The key command is:

```powershell
Install-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

For environments without PowerShell Gallery access, use the single-file version:

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/christaylorcodes/ConnectWiseAutomateAgent/main/ConnectWiseAutomateAgent.ps1' | Invoke-Expression
Install-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

### What PowerShell versions are supported?

| Version | Support Level |
| --- | --- |
| PowerShell 2.0 | Limited (no module manifest support, use single-file mode) |
| PowerShell 3.0 - 5.1 | Full support |
| PowerShell 7+ | Full support |

The module is tested on PowerShell 5.1 and 7+.

---

## Configuration

### How do I set up a proxy for the agent?

```powershell
# Auto-detect from system settings (IE/WinHTTP)
Set-CWAAProxy -DetectProxy

# Or set manually
Set-CWAAProxy -ProxyServerURL 'proxy.example.com:8080'

# With authentication
Set-CWAAProxy -ProxyServerURL 'proxy.example.com:8080' -ProxyUsername 'user' -ProxyPassword (ConvertTo-SecureString 'pass' -AsPlainText -Force)
```

See [ProxyConfiguration.ps1](../Examples/ProxyConfiguration.ps1) for a complete walkthrough.

### How do I set up automated health checks?

One command registers a Windows scheduled task that runs `Repair-CWAA` on a schedule:

```powershell
Register-CWAAHealthCheckTask -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

This creates a task that checks agent health every 60 minutes and applies escalating remediation (restart, then reinstall) as needed. See [HealthCheck-Monitoring.ps1](../Examples/HealthCheck-Monitoring.ps1) for details.

### Does 32-bit vs 64-bit matter?

Yes. The Automate agent is a 32-bit application, but its registry keys are accessible from both 32-bit and 64-bit PowerShell (with different paths due to WOW64 redirection). The module handles this automatically:

- **Module mode:** Emits a warning if imported in 32-bit PowerShell on a 64-bit OS. Re-import in 64-bit PowerShell.
- **Single-file mode:** Automatically relaunches under 64-bit PowerShell.

Always use 64-bit PowerShell when possible. See [Troubleshooting](Troubleshooting.md#wow64--32-bit-vs-64-bit-mismatches) for details.

---

## Backward Compatibility

### Can I still use the old LT function names?

Yes. All 32 legacy `LT` aliases are preserved and will not be removed:

```powershell
# These are identical:
Install-CWAA -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1
Install-LTService -Server 'automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

List all aliases: `Get-Alias -Definition *-CWAA*`

### Will my existing scripts break after upgrading?

No, with one exception: `Redo-CWAA` (aliased as `Redo-LTService`) changed `-LocationID` from `[string]` to `[int]`. If you pass `''` (empty string) where `$null` is intended, it may now fail. See [Migration Guide](Migration.md#breaking-changes) for details.

---

## Troubleshooting

### Where are the agent logs?

| Log | Location | Access |
| --- | --- | --- |
| Agent errors | `C:\Windows\LTSVC\errors.txt` | `Get-CWAAError` |
| Probe errors | `C:\Windows\LTSVC\Probes\*.txt` | `Get-CWAAProbeError` |
| Module events | Windows Application Event Log | `Get-WinEvent -FilterHashtable @{ LogName='Application'; ProviderName='ConnectWiseAutomateAgent' }` |

### How do I check if the agent is healthy?

```powershell
Test-CWAAHealth
```

For a more thorough check including server connectivity:

```powershell
Test-CWAAHealth -TestServerConnectivity
```

### How do I force the agent to check in?

```powershell
Invoke-CWAACommand -Command 'Send Status'
```

Other useful commands: `'Send Inventory'`, `'Send Drives'`, `'Send Procs'`. See `Get-Help Invoke-CWAACommand` for the full list.

---

## Module Usage

### What does the single-file version do differently?

Functionally identical — all the same functions are available. The difference is packaging:

- **Module (Install-Module):** Installed to the module path, imported with `Import-Module`, supports `Get-Help`, auto-updates via `Update-Module`.
- **Single-file (.ps1):** All functions concatenated into one file, loaded via `Invoke-Expression`. Used when the PowerShell Gallery is unavailable. `Initialize-CWAA` is appended at the end of the file.

Prefer `Install-Module` whenever possible.

### How do I update the module?

```powershell
Update-Module ConnectWiseAutomateAgent
```

For prerelease builds:

```powershell
Update-Module ConnectWiseAutomateAgent -AllowPrerelease
```

### Can I use this in a CI/CD pipeline?

Yes. The module is published on the PowerShell Gallery and can be installed non-interactively:

```powershell
Install-Module ConnectWiseAutomateAgent -Force -Scope AllUsers -AllowPrerelease
```

Note that most functions require administrator privileges and a Windows target. Functions that read agent state (`Get-CWAAInfo`, `Test-CWAAHealth`) are most useful in CI/CD for validation steps.

### What is the `-Force` parameter doing?

It varies by function. See [Common Parameters](CommonParameters.md#-force) for the full breakdown. In general, it overrides safety checks (existing installation detection, probe agent protection, existing scheduled tasks).
