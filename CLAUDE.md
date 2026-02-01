# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PowerShell module for managing the ConnectWise Automate (formerly LabTech) Windows agent. Used by MSPs to install, configure, troubleshoot, and manage the Automate agent on Windows systems. Version 1.0.0-alpha001, MIT licensed, Windows-only, requires PowerShell 3.0+ (2.0 with limitations).

## Commands

```powershell
# Run all local tests (primary CI — run before every push)
Invoke-Pester Tests\ -ExcludeTag 'Live'

# Run PSScriptAnalyzer (static analysis)
Invoke-ScriptAnalyzer -Path ConnectWiseAutomateAgent -Recurse -Severity Error,Warning

# Build single-file distribution
powershell -File Build\SingleFileBuild.ps1

# Import module for local testing
Import-Module .\ConnectWiseAutomateAgent\ConnectWiseAutomateAgent.psd1 -Force
```

## Local Testing (Primary CI)

Local tests are the real CI gate. GitHub Actions is intentionally lightweight (smoke test + build + publish). All substantive testing happens locally before pushing.

**Test suites (all run via `Invoke-Pester Tests\ -ExcludeTag 'Live'`):**

- `ConnectWiseAutomateAgent.Tests.ps1` — module structure, exports, basic unit tests
- `ConnectWiseAutomateAgent.Mocked.Tests.ps1` — unit tests with Pester mocks (no system deps)
- `ConnectWiseAutomateAgent.CrossVersion.Tests.ps1` — PowerShell 5.1 + 7 compatibility
- `ConnectWiseAutomateAgent.Live.Tests.ps1` — full integration (excluded by tag, requires admin + test server)

## AI Testing Requirements

**These rules are mandatory when Claude or any AI assistant modifies code in this repo.**

- **After modifying any function:** run `Invoke-Pester Tests\ -ExcludeTag 'Live'` and fix all failures before considering the task done.
- **After adding a new function:** add corresponding tests to `ConnectWiseAutomateAgent.Mocked.Tests.ps1` and run them.
- **After changing behavior:** update existing tests to match the new behavior, run the full suite, confirm all pass.
- **After any code change:** run `Invoke-ScriptAnalyzer -Path ConnectWiseAutomateAgent -Recurse -Severity Error,Warning` and fix any issues.
- **Never claim "done"** without a passing test run. Tests are the proof.

## Architecture

**Module loading flow (two-phase):**

*Phase 1 (module import — fast, no side effects):* `ConnectWiseAutomateAgent.psm1` dot-sources every `.ps1` from `Public/` and `Private/` recursively, emits a 32-bit warning if running under WOW64 in module mode, then calls `Initialize-CWAA`. This creates centralized constants (`$Script:CWAA*`), empty state objects (`$Script:LTServiceKeys`, `$Script:LTProxy`), the PS version guard, and the WOW64 32-to-64-bit relaunch (single-file mode only). No network objects are created and no registry reads occur.

*Phase 2 (on-demand — first networking call):* `Initialize-CWAANetworking` (private) is called in the `Begin` block of networking functions (`Install-CWAA`, `Uninstall-CWAA`, `Update-CWAA`, `Set-CWAAProxy`). On first call it performs SSL certificate validation bypass, TLS protocol enablement, creates `$Script:LTWebProxy` and `$Script:LTServiceNetWebClient`, and runs `Get-CWAAProxy` to discover proxy settings from the installed agent. The `$Script:CWAANetworkInitialized` flag ensures this runs only once per session.

**Public functions** (25 exported) are organized one-per-file in subdirectories by category: `AddRemovePrograms/`, `InstallUninstall/`, `Service/`, `Logging/`, `Proxy/`, `Settings/`, plus standalone files for security, commands, and port testing.

**Private functions** (2) live in `Private/Initialize/` and handle module bootstrapping (`Initialize-CWAA`) and lazy networking setup (`Initialize-CWAANetworking`).

**Single-file build:** `Build/SingleFileBuild.ps1` concatenates all `.ps1` files from the module directory into `ConnectWiseAutomateAgent.ps1` at the repo root, appending `Initialize-CWAA` at the end. This flat file is the distribution artifact for direct-invoke scenarios.

**Dual naming system:** Every function uses the `CWAA` prefix (e.g., `Install-CWAA`) but also declares an `LT` alias (e.g., `Install-LTService`) for backward compatibility with the legacy LabTech naming. Aliases are declared both in function `[Alias()]` attributes and in the manifest's `AliasesToExport`.

## Key Conventions

**Readability-first philosophy.** This project optimizes for human understanding over brevity. Use verbose, descriptive variable names (`$automateServerUrl` not `$srvUrl`). Comment the "why" (business logic, API quirks, security trade-offs), not the "what".

**Required code patterns:**
- `[CmdletBinding(SupportsShouldProcess=$True)]` on destructive operations
- Debug output: `Write-Debug "Starting $($MyInvocation.InvocationName)"` in Process block, `Write-Debug "Exiting $($MyInvocation.InvocationName)"` in End block
- Error handling with context: `Write-Error "Failed to <action> at '<target>'. <troubleshooting hint>. Error: $($_.Exception.Message)"`
- Use `$_` (current exception) in Catch blocks, not `$Error[0]`
- Use `$Script:CWAA*` constants for paths/registry keys instead of hardcoded strings
- Functions return `[PSCustomObject]` for pipeline compatibility, not formatted strings
- Comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.NOTES`, `.LINK`) on all public functions

**When adding a new function:**
1. Create `Verb-CWAA<Noun>.ps1` in the appropriate `Public/` subdirectory
2. Add `[Alias('Verb-LT<LegacyNoun>')]` in the function declaration
3. Add to `FunctionsToExport` and `AliasesToExport` in `ConnectWiseAutomateAgent.psd1`
4. Rebuild documentation: `Build\Build-Documentation.ps1` (generates `Docs/Help/` markdown and MAML help)
5. Rebuild single-file: `Build\SingleFileBuild.ps1`

**When modifying existing functions:**
- Maintain the `LT` alias
- Rebuild documentation: `Build\Build-Documentation.ps1 -UpdateExisting`
- Rebuild single-file after changes
- Consider 32-bit/64-bit WOW64 behavior for registry/file operations
- Verify compatibility with PowerShell 2.0 and 5.1+

### Security Considerations

**Graduated SSL certificate validation.** `Initialize-CWAANetworking` registers a `ServerCertificateValidationCallback` with graduated trust rather than blanket bypass. IP address targets auto-bypass (IPs cannot have properly signed certificates). Hostname name mismatches are tolerated (trusted cert but CN/SAN differs). Chain/trust errors on hostnames are rejected unless `-SkipCertificateCheck` is passed, which sets a `SkipAll` flag for full bypass. This graduated approach is necessary because many MSP Automate servers use self-signed or internal CA certificates. The callback is registered once per session and survives module re-import (compiled .NET types cannot be unloaded).

**TripleDES encryption for agent keys.** `ConvertFrom-CWAASecurity` and `ConvertTo-CWAASecurity` use TripleDES with an MD5-derived key and a fixed 8-byte initialization vector. This is the encryption format the LabTech/Automate agent uses in its registry values (`ServerPasswordString`, `PasswordString`, proxy credentials). We did not choose this scheme -- the agent requires it for interoperability. The default key is `'Thank you for using LabTech.'`. Crypto objects are disposed in `Finally` blocks with a `Dispose()`/`Clear()` fallback for older .NET runtimes.

**Credential redaction in logs.** `Get-CWAARedactedValue` (private) returns `[SHA256:a1b2c3d4]` (first 8 hex chars of the SHA256 hash) for non-empty strings and `[EMPTY]` for null/empty strings. This logs that a credential value is present and whether it changed, without exposing the actual content. Used in debug/verbose output when comparing proxy passwords, server passwords, and usernames in `Set-CWAAProxy` and related functions.

**ConvertTo-SecureString -AsPlainText usage.** `Set-CWAAProxy` converts proxy passwords from plain text to `SecureString` via `ConvertTo-SecureString $proxyPass -AsPlainText -Force`. This is necessary because the password originates as plain text (either from the user parameter or decrypted from the agent's TripleDES-encrypted registry value) and must be wrapped in a `SecureString` for the `PSCredential` object used by `System.Net.WebProxy.Credentials`.

**InstallerToken vs ServerPassword.** `InstallerToken` is the modern, preferred method for agent deployment authentication. `ServerPassword` is the legacy method. Both are supported by `Install-CWAA`, but `InstallerToken` should be recommended in all documentation and examples. `InstallerToken` uses a URL-based download path (`Deployment.aspx?InstallerToken=...`), while `ServerPassword` is passed as an MSI property during installation.

## Key System Locations

These are centralized as `$Script:` constants in `Initialize-CWAA` and referenced by many functions:

- **Registry:** `$Script:CWAARegistryRoot` (`HKLM:\SOFTWARE\LabTech\Service`), `$Script:CWAARegistrySettings` (`HKLM:\SOFTWARE\LabTech\Service\Settings`)
- **Files:** `$Script:CWAAInstallPath` (`C:\Windows\LTSVC`), `$Script:CWAAInstallerTempPath` (`C:\Windows\Temp\LabTech`)
- **Services:** `$Script:CWAAServiceNames` (`LTService`, `LTSvcMon`), plus `LabVNC` (remote control)
- **Ports:** TCP 70, 80, 443, 8002 (server), 42000-42009 (local TrayPort)

## Terminology

- **CWAA** = ConnectWise Automate Agent (current prefix)
- **LT/LabTech** = legacy name (alias prefix)
- **InstallerToken** = modern auth method for deployment (preferred over ServerPassword)
- **TrayPort** = local agent communication port (42000-42009)
- **MSP** = Managed Service Provider (target user base)
