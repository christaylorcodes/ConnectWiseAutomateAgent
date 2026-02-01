# Common Parameters Reference

Parameters shared across multiple ConnectWiseAutomateAgent functions. This reference documents how each parameter behaves, its validation rules, and which functions accept it.

For PowerShell's built-in common parameters (`-Verbose`, `-Debug`, `-ErrorAction`, etc.), see [about_CommonParameters](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters).

---

## -Server

Specifies one or more ConnectWise Automate server URLs. The module tries each server in order and uses the first one that responds with a valid version string.

| Detail | Value |
| --- | --- |
| **Type** | `[string[]]` |
| **Required** | Yes (on most functions) |
| **Pipeline** | `ValueFromPipelineByPropertyName` |
| **Validation** | Regex: `$Script:CWAAServerValidationRegex` |

Bare hostnames (e.g., `automate.example.com`) are automatically normalized with an `https://` prefix. The server is validated by downloading the version response from `/LabTech/Agent.aspx`. Invalid formats produce a warning and are skipped.

On `Uninstall-CWAA`, the `-Server` parameter is `[AllowNull()]` because the server URL can be read from the installed agent's registry if not explicitly provided.

### Functions that accept -Server

| Function | Mandatory | Notes |
| --- | --- | --- |
| `Install-CWAA` | Yes | Downloads installer from this server |
| `Uninstall-CWAA` | No | Falls back to registry; downloads uninstaller |
| `Update-CWAA` | Yes | Downloads updated installer |
| `Redo-CWAA` | Yes | Passed through to Install-CWAA |
| `Repair-CWAA` | No | Used for reinstall; falls back to agent config |
| `Test-CWAAPort` | Yes | Tests port connectivity to this server |
| `Test-CWAAServerConnectivity` | No | Auto-discovers from agent config if omitted |
| `Test-CWAAHealth` | No | Passed to Test-CWAAServerConnectivity if `-TestServerConnectivity` |
| `Register-CWAAHealthCheckTask` | Yes | Stored in scheduled task for recurring health checks |

---

## -LocationID

Specifies the Automate location (site) to assign the agent to during installation.

| Detail | Value |
| --- | --- |
| **Type** | `[int]` |
| **Required** | No |
| **Pipeline** | `ValueFromPipelineByPropertyName` |
| **Validation** | `[ValidateRange(1, [int]::MaxValue)]` on some functions |

**Breaking change in 1.0.0:** `Redo-CWAA` changed `-LocationID` from `[string]` to `[int]`. Scripts passing string values like `'5'` instead of `5` may need updating. See [Migration Guide](Migration.md) for details.

### Functions that accept -LocationID

| Function | Notes |
| --- | --- |
| `Install-CWAA` | Passed as MSI property `LOCATION=` |
| `Redo-CWAA` | Passed through to Install-CWAA |
| `Repair-CWAA` | Used for reinstall if escalation required |
| `Register-CWAAHealthCheckTask` | Stored in scheduled task arguments |

---

## -InstallerToken

The modern, preferred authentication method for agent deployment. An alphanumeric token generated in the Automate console.

| Detail | Value |
| --- | --- |
| **Type** | `[string]` |
| **Required** | No (but recommended) |
| **Parameter Set** | `installertoken` |
| **Validation** | `[ValidatePattern('(?s:^[0-9a-z]+$)')]` — lowercase alphanumeric only |

When provided, the installer is downloaded via `Deployment.aspx?InstallerToken=<token>`. This is more secure than `-ServerPassword` because the token is scoped and revocable.

### Functions that accept -InstallerToken

| Function | Notes |
| --- | --- |
| `Install-CWAA` | Primary installation parameter |
| `Redo-CWAA` | Passed through to Install-CWAA |
| `Repair-CWAA` | Used for reinstall if escalation required |
| `Register-CWAAHealthCheckTask` | Stored in scheduled task arguments |

---

## -ServerPassword

The legacy authentication method for agent deployment. A server-level password configured in the Automate console.

| Detail | Value |
| --- | --- |
| **Type** | `[string]` |
| **Required** | No |
| **Parameter Set** | `deployment` |
| **Alias** | `Password` |

When provided, the password is passed as an MSI property during installation. **Use `-InstallerToken` instead whenever possible.** `InstallerToken` is scoped, revocable, and does not expose a server-wide credential. See [Security Model](Security.md#authentication-installertoken-vs-serverpassword) for details.

### Functions that accept -ServerPassword

| Function | Notes |
| --- | --- |
| `Install-CWAA` | Passed as MSI property `SERVERPASS=` |
| `Redo-CWAA` | Passed through to Install-CWAA |

---

## -Force

Overrides safety checks. **The specific behavior varies by function.**

| Detail | Value |
| --- | --- |
| **Type** | `[switch]` |
| **Required** | No |
| **Default** | `$False` |

### Behavior by function

| Function | What -Force does |
| --- | --- |
| `Install-CWAA` | Skips the "agent already installed" check and .NET prerequisite validation |
| `Uninstall-CWAA` | Allows uninstall even when the probe agent is detected (normally blocked to prevent accidental probe removal) |
| `Redo-CWAA` | Passed through to Install-CWAA |
| `Repair-CWAA` | Passed through to Install-CWAA during reinstall escalation |
| `ConvertFrom-CWAASecurity` | Attempts alternate decryption keys if the primary key fails |
| `Register-CWAAHealthCheckTask` | Recreates the scheduled task unconditionally, even if one already exists |

---

## -SkipCertificateCheck

Disables all SSL certificate validation for the current PowerShell session.

| Detail | Value |
| --- | --- |
| **Type** | `[switch]` |
| **Required** | No |
| **Default** | `$False` |
| **Scope** | Session-wide (affects ALL HTTPS connections) |

Sets the `SkipAll` flag on the compiled C# `ServerCertificateValidationCallback` class, bypassing the graduated trust model entirely. This is necessary when connecting to servers with self-signed certificates where the hostname matches but the CA is not trusted.

**Warning:** This affects all HTTPS connections in the PowerShell session, not just Automate operations. Use only when the graduated SSL trust model (which auto-bypasses IP addresses and tolerates name mismatches) is insufficient. See [Security Model](Security.md#ssl-certificate-validation) for the full trust hierarchy.

### Functions that accept -SkipCertificateCheck

| Function | Notes |
| --- | --- |
| `Install-CWAA` | Passed to Initialize-CWAANetworking |
| `Uninstall-CWAA` | Passed to Initialize-CWAANetworking |
| `Update-CWAA` | Passed to Initialize-CWAANetworking |
| `Set-CWAAProxy` | Passed to Initialize-CWAANetworking |

---

## -Backup

Creates a backup of the agent's registry configuration before performing a destructive operation.

| Detail | Value |
| --- | --- |
| **Type** | `[switch]` |
| **Required** | No |
| **Default** | `$False` |

Calls `New-CWAABackup` internally, which copies the agent's registry keys to `HKLM:\SOFTWARE\LabTechBackup\Service` and exports configuration files to `C:\Windows\LTSVC\Backup\`.

### Functions that accept -Backup

| Function | Notes |
| --- | --- |
| `Uninstall-CWAA` | Backs up before removing the agent |
