# Security Model

How ConnectWiseAutomateAgent handles SSL certificates, credential encryption, and sensitive data in logs.

This module manages a privileged Windows agent — it requires administrator access and interacts with services, registry keys, and network downloads. The security design balances practical MSP deployment needs (self-signed certs, legacy encryption, restricted networks) with defense-in-depth principles.

---

## SSL Certificate Validation

### The Problem

Many MSP ConnectWise Automate servers use self-signed certificates, internal CA certificates, or certificates where the Common Name (CN) or Subject Alternative Name (SAN) doesn't match the hostname used to connect. A strict SSL policy would break most real-world deployments.

### Graduated Trust Model

Rather than bypassing all certificate validation (the legacy approach), the module registers a compiled C# callback with three tiers of graduated trust:

| Scenario | Behavior | Rationale |
| --- | --- | --- |
| **IP address target** | Auto-bypass | IP addresses cannot have properly signed certificates (no CA will issue a cert for an IP). This is always safe to bypass. |
| **Hostname name mismatch** | Tolerated | The certificate is from a trusted CA but the CN/SAN doesn't match the hostname. Common when servers are accessed by IP, CNAME, or internal hostname that differs from the cert. |
| **Chain/trust errors on hostname** | **Rejected** | The certificate is self-signed or from an untrusted CA on a hostname URL. This is the only case that blocks by default. |

The callback is compiled via `Add-Type` in `Initialize-CWAANetworking` (see [private function docs](Help/Private/Initialize-CWAANetworking.md)). Because compiled .NET types cannot be unloaded from an AppDomain, the callback persists for the lifetime of the PowerShell process — even across module re-imports.

### -SkipCertificateCheck (Full Bypass)

When the graduated model is insufficient (e.g., self-signed certificate on a hostname URL with no trusted chain), pass `-SkipCertificateCheck` to any networking function:

```powershell
Install-CWAA -Server 'automate.example.com' -LocationID 1 -InstallerToken 'MyToken' -SkipCertificateCheck
```

This sets `[ServerCertificateValidationCallback]::SkipAll = $True`, which bypasses all certificate validation for the remainder of the PowerShell session. A warning is emitted on first use.

**This affects ALL HTTPS connections in the session**, not just Automate operations. Use it only when necessary, and consider running the operation in an isolated PowerShell session.

Functions that accept `-SkipCertificateCheck`: `Install-CWAA`, `Uninstall-CWAA`, `Update-CWAA`, `Set-CWAAProxy`. See [Common Parameters](CommonParameters.md#-skipcertificatecheck) for the full reference.

### PowerShell 7+ Compatibility

On PowerShell 7+ (`.NET 6+`), `System.Net.ServicePointManager` triggers `SYSLIB0014` obsolescence warnings. The module wraps the C# source with `#pragma warning disable SYSLIB0014` to suppress these. `WebClient` and `WebProxy` are similarly deprecated but remain the only option compatible with PowerShell 3.0-5.1 (`.NET Framework`).

---

## Agent Credential Encryption (TripleDES)

### Why TripleDES?

The ConnectWise Automate agent stores several credentials in the Windows registry using TripleDES encryption with an MD5-derived key:

- `ServerPasswordString` — server authentication credential
- `PasswordString` — agent-specific credential (encrypted with `ServerPasswordString` as the key)
- Proxy credentials (`ProxyUsername`, `ProxyPassword`)

**This encryption scheme is required by the Automate agent for interoperability.** The module did not choose TripleDES — it matches the agent's format so it can read and write values the agent understands.

### How It Works

| Component | Value |
| --- | --- |
| **Algorithm** | TripleDES (168-bit key) |
| **Key derivation** | MD5 hash of the key string |
| **Initialization Vector** | Fixed 8-byte IV |
| **Encoding** | Base64 (input and output) |
| **Default key** | `'Thank you for using LabTech.'` |

The functions `ConvertFrom-CWAASecurity` (decrypt) and `ConvertTo-CWAASecurity` (encrypt) implement this scheme. Crypto objects are disposed in `Finally` blocks with a `Dispose()`/`Clear()` fallback for older .NET runtimes that don't support `Dispose()`.

### Usage

```powershell
# Decrypt a value from the agent's registry
$decrypted = ConvertFrom-CWAASecurity -InputString $encryptedRegistryValue

# Decrypt with a custom key (e.g., using the agent's ServerPassword as key)
$agentPassword = ConvertFrom-CWAASecurity -InputString $passwordString -Key $serverPassword

# Encrypt a value for writing back to the registry
$encrypted = ConvertTo-CWAASecurity -InputString 'plain text value'
```

If decryption fails with the provided key and `-Force` is enabled (default), `ConvertFrom-CWAASecurity` automatically tries alternate key values.

---

## Credential Redaction in Logs

The module never logs credential values in plain text. When debug or verbose output needs to reference a credential (for troubleshooting proxy changes, comparing server passwords, etc.), it uses a private helper function that produces a SHA256 hash prefix:

| Input | Output |
| --- | --- |
| Non-empty string | `[SHA256:a1b2c3d4]` (first 8 hex characters of the SHA256 hash) |
| Null or empty string | `[EMPTY]` |

This format logs that a credential is present and whether it changed between operations (same hash = same value), without exposing the actual content.

Example debug output:
```
Set-CWAAProxy: ProxyPassword changed from [SHA256:7f83b162] to [SHA256:ef2d127d]
```

---

## Authentication: InstallerToken vs ServerPassword

### InstallerToken (Recommended)

The modern authentication method for agent deployment. Tokens are generated in the Automate console and are:

- **Scoped** — can be limited to specific locations or clients
- **Revocable** — can be invalidated without changing server-wide settings
- **URL-based** — the installer is downloaded via `Deployment.aspx?InstallerToken=<token>`

```powershell
Install-CWAA -Server 'automate.example.com' -LocationID 1 -InstallerToken 'abc123def456'
```

### ServerPassword (Legacy)

The legacy authentication method. A single password configured at the server level:

- **Server-wide** — one password for all deployments
- **Not revocable** — changing it affects all future deployments
- **MSI property** — passed as `SERVERPASS=` during installation

```powershell
Install-CWAA -Server 'automate.example.com' -LocationID 1 -ServerPassword 'LegacyPassword'
```

**Always prefer InstallerToken.** ServerPassword is supported for backward compatibility with older Automate server versions and existing deployment scripts.

---

## Version Locking

### Why It Matters

This module runs with administrator privileges on managed endpoints. Scripts that always pull the latest version (`Update-Module`, `Install-Module` without `-RequiredVersion`, or downloading from the `main` branch) are vulnerable to:

- **Supply-chain compromise** — if the PowerShell Gallery package or GitHub repository were compromised, every endpoint running a "latest" script would execute the malicious code on its next run.
- **Breaking changes** — a major version update could change behavior in ways that break existing deployment workflows.
- **Unreproducible deployments** — without a pinned version, two endpoints running the same script a day apart could get different module versions, making troubleshooting difficult.

### Recommended Practice

Pin every production script to a specific version you have tested:

**PowerShell Gallery:**

```powershell
# Install a specific version
Install-Module ConnectWiseAutomateAgent -RequiredVersion '1.0.0' -Force -Scope AllUsers

# Import a specific version (when multiple versions are installed side by side)
Import-Module ConnectWiseAutomateAgent -RequiredVersion '1.0.0'
```

**Single-file (restricted networks):**

```powershell
# Download from a version-locked GitHub Release — the URL is immutable after publication
$ModuleVersion = '1.0.0'
$URI = "https://github.com/christaylorcodes/ConnectWiseAutomateAgent/releases/download/v$ModuleVersion/ConnectWiseAutomateAgent.ps1"
Invoke-RestMethod $URI | Invoke-Expression
```

### Update Workflow

1. A new module version is released.
2. Install and test the new version in a lab or pilot environment.
3. Once validated, update the `$ModuleVersion` variable (or `-RequiredVersion` value) in your deployment scripts.
4. Roll out the updated scripts to production.

This gives you an explicit approval step between "new version available" and "new version running on all endpoints."

### When Floating Versions Are Acceptable

- **Interactive troubleshooting** — running `Install-Module ConnectWiseAutomateAgent` in a one-off PowerShell session to diagnose an issue.
- **Development and testing** — working on the module itself or evaluating new features.
- **Non-production environments** — lab machines where unexpected changes are acceptable.

All [example scripts](../Examples/) in this repository use version-locked patterns by default.

---

## Vulnerability Awareness

`Install-CWAA` checks the Automate server version during installation. If the server reports a version below **v200.197** (the June 2020 security patch), a warning is emitted:

```
WARNING: Automate server version X.Y is below v200.197. This version may have known security vulnerabilities. Consider updating the Automate server.
```

This is informational only — the installation proceeds. The version check uses the same `/LabTech/Agent.aspx` response used for server reachability validation.
