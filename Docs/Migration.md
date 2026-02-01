# Migration Guide: 0.1.4.0 to 1.0.0

## Quick Start

**Your existing scripts will keep working.** All 32 legacy `LT` aliases are preserved in 1.0.0. No function was removed from the public API. Upgrade the module and your existing scripts will run without changes:

```powershell
Update-Module ConnectWiseAutomateAgent -AllowPrerelease
```

Read on if you want to adopt the new naming, use the new features, or need to handle the one breaking change.

---

## What Changed

### Module Prefix: LT to CWAA

Every public function was renamed from `Verb-LT*` to `Verb-CWAA*`. All original names remain as aliases.

### Complete Function-to-Alias Mapping

| CWAA Function (1.0.0) | LT Alias (legacy) | Category |
| --- | --- | --- |
| `Install-CWAA` | `Install-LTService` | Install & Lifecycle |
| `Uninstall-CWAA` | `Uninstall-LTService` | Install & Lifecycle |
| `Update-CWAA` | `Update-LTService` | Install & Lifecycle |
| `Redo-CWAA` | `Redo-LTService`, `Reinstall-CWAA`, `Reinstall-LTService` | Install & Lifecycle |
| `Start-CWAA` | `Start-LTService` | Service Control |
| `Stop-CWAA` | `Stop-LTService` | Service Control |
| `Restart-CWAA` | `Restart-LTService` | Service Control |
| `Repair-CWAA` | `Repair-LTService` | Service Control (new) |
| `Test-CWAAHealth` | `Test-LTHealth` | Health & Connectivity (new) |
| `Test-CWAAPort` | `Test-LTPorts` | Health & Connectivity |
| `Test-CWAAServerConnectivity` | `Test-LTServerConnectivity` | Health & Connectivity (new) |
| `Register-CWAAHealthCheckTask` | `Register-LTHealthCheckTask` | Scheduled Monitoring (new) |
| `Unregister-CWAAHealthCheckTask` | `Unregister-LTHealthCheckTask` | Scheduled Monitoring (new) |
| `Get-CWAAInfo` | `Get-LTServiceInfo` | Settings & Backup |
| `Get-CWAAInfoBackup` | `Get-LTServiceInfoBackup` | Settings & Backup |
| `Get-CWAASettings` | `Get-LTServiceSettings` | Settings & Backup |
| `New-CWAABackup` | `New-LTServiceBackup` | Settings & Backup |
| `Reset-CWAA` | `Reset-LTService` | Settings & Backup |
| `Get-CWAAError` | `Get-LTErrors` | Logging & Diagnostics |
| `Get-CWAAProbeError` | `Get-LTProbeErrors` | Logging & Diagnostics |
| `Get-CWAALogLevel` | `Get-LTLogging` | Logging & Diagnostics |
| `Set-CWAALogLevel` | `Set-LTLogging` | Logging & Diagnostics |
| `Get-CWAAProxy` | `Get-LTProxy` | Proxy |
| `Set-CWAAProxy` | `Set-LTProxy` | Proxy |
| `Hide-CWAAAddRemove` | `Hide-LTAddRemove` | Add/Remove Programs |
| `Show-CWAAAddRemove` | `Show-LTAddRemove` | Add/Remove Programs |
| `Rename-CWAAAddRemove` | `Rename-LTAddRemove` | Add/Remove Programs |
| `ConvertFrom-CWAASecurity` | `ConvertFrom-LTSecurity` | Security & Utilities |
| `ConvertTo-CWAASecurity` | `ConvertTo-LTSecurity` | Security & Utilities |
| `Invoke-CWAACommand` | `Invoke-LTServiceCommand` | Security & Utilities |

To list all available aliases in a running session:

```powershell
Get-Alias -Definition *-CWAA* | Format-Table Name, Definition
```

### New Functions in 1.0.0

Five new public functions (no legacy equivalents existed):

| Function | Purpose |
| --- | --- |
| `Test-CWAAHealth` | Read-only health assessment of the installed agent |
| `Repair-CWAA` | Escalating remediation (restart, reinstall) based on health status |
| `Test-CWAAServerConnectivity` | Tests HTTPS reachability of the Automate server |
| `Register-CWAAHealthCheckTask` | Creates a Windows scheduled task for recurring health checks |
| `Unregister-CWAAHealthCheckTask` | Removes the scheduled health check task |

### Removed Private Functions

Three internal functions were removed (not part of the public API — no script impact):

| Removed | Replacement |
| --- | --- |
| `Get-CurrentLineNumber` | Removed — no longer used |
| `Initialize-CWAAKeys` | Inlined into `Get-CWAAProxy` (only consumer) |
| `Initialize-CWAAModule` | Merged into `Initialize-CWAA` |

---

## Breaking Changes

### LocationID type on Redo-CWAA

`Redo-CWAA` changed `-LocationID` from `[string]` to `[int]`.

**Impact:** Scripts passing a string value will still work due to PowerShell's implicit type coercion (`'5'` becomes `5`). However, passing an empty string `''` where `$null` was intended will now fail validation.

```powershell
# Before (0.1.4.0) — worked with string
Redo-LTService -Server 'https://automate.example.com' -LocationID '5' -ServerPassword 'pwd'

# After (1.0.0) — use integer, and prefer InstallerToken
Redo-CWAA -Server 'https://automate.example.com' -LocationID 5 -InstallerToken 'MyToken'
```

---

## Authentication Migration

### ServerPassword (Legacy) to InstallerToken (Modern)

`InstallerToken` is the preferred authentication method in 1.0.0. It is scoped, revocable, and more secure than the server-wide `ServerPassword`. See [Security Model](Security.md#authentication-installertoken-vs-serverpassword) for details.

**Before (ServerPassword):**
```powershell
Install-LTService -Server 'https://automate.example.com' -ServerPassword 'LegacyPassword' -LocationID '5'
```

**After (InstallerToken):**
```powershell
Install-CWAA -Server 'https://automate.example.com' -InstallerToken 'abc123def456' -LocationID 5
```

Both methods are still supported. `ServerPassword` will not be removed, but `InstallerToken` should be preferred in all new scripts and documentation.

---

## Script Upgrade Examples

### Basic Installation

```powershell
# Before
Install-LTService -Server 'https://automate.example.com' -ServerPassword 'pwd' -LocationID '1'

# After
Install-CWAA -Server 'https://automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

### Reinstall

```powershell
# Before
Reinstall-LTService -Server 'https://automate.example.com' -ServerPassword 'pwd' -LocationID '1'

# After
Redo-CWAA -Server 'https://automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

### Health Check (new in 1.0.0)

```powershell
# No equivalent in 0.1.4.0
$health = Test-CWAAHealth
if (-not $health.Healthy) {
    Repair-CWAA -Server 'https://automate.example.com' -InstallerToken 'MyToken' -LocationID 1
}
```

### Automated Monitoring (new in 1.0.0)

```powershell
# No equivalent in 0.1.4.0
Register-CWAAHealthCheckTask -Server 'https://automate.example.com' -InstallerToken 'MyToken' -LocationID 1
```

---

## Deprecation Policy

There is **no planned deprecation** of the `LT` aliases. They are maintained indefinitely for backward compatibility. However, new documentation and examples use the `CWAA` prefix exclusively.
