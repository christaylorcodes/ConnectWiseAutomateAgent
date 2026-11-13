# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Script helpers** for scripts run from ConnectWise Automate: `Initialize-CWAAScriptLog`, `Write-CWAAScriptLog`, `New-CWAAScriptOutput`, `ConvertTo-CWAAScriptOutput`, `Invoke-CWAAScript`, `Invoke-CWAAPwsh`, and `New-CWAARemoteMonitor`. See `Examples/ScriptHelper-*.ps1`. Output values are kept to one line (line breaks become ` / `, pipes become `/`). `Invoke-CWAAPwsh` only runs pwsh.exe from Program Files, the PowerShellCore registry install locations, or `-PwshPath`, never from PATH; it reports stderr output as `Status=Error`.
- Aliases for the Script helpers that keep the names from the legacy `CW-Automate-ScriptHelper.ps1`: `Initialize-AutomateLogging`, `Write-AutomateLog`, `New-AutomateOutput`, `ConvertTo-AutomateOutput`, `Invoke-CWAScript`, `Invoke-LTPwsh`, and `New-CWARemoteMonitor`. Scripts that still dot-source the old helper file after importing the module will replace these names with the old definitions.
- Event ID 4023, written by `Register-CWAAHealthCheckTask` when the scheduled task is missing right after it was created.

### Security

- `Invoke-CWAAScript -URL` only accepts `https://` URLs. TLS 1.2 is added for the download when the process setting lacks it, and the previous setting is restored afterwards.
- `Initialize-CWAAScriptLog` refuses a log directory whose path passes through a junction or symbolic link, and creates each log file exclusively instead of appending to an existing file. The default log directory is `%windir%\LTSVC\logs`.
- `Invoke-CWAAPwsh` never searches `PATH` for pwsh.exe (see Added). Parameter values passed with `-Parameters` are visible on the pwsh.exe command line, so do not pass secrets that way.
- `ConvertTo-CWAASecurity` and `ConvertFrom-CWAASecurity` no longer write the encryption key (or, when encoding, the plain text) to the debug stream. `-Debug` output shows a short hash instead.

### Changed

- `Register-CWAAHealthCheckTask -Force` on a task that already exists now returns `Updated = $true` (and logs "updated") instead of `Created = $true`. `Created` is only true when no task existed before.
- `Register-CWAAHealthCheckTask` writes the task definition to a uniquely named temporary file instead of a fixed `CWAAHealthCheckTask.xml`, because the file holds the installer token.
- Dependabot pull requests now target `develop`, the pre-commit hook (`.githooks/pre-commit`) works on Windows and runs `Invoke-QuickTest.ps1`, and `Tests/Invoke-AllTests.ps1` uses the pinned Pester in both modes and fails when the build fails.
- Build and test tooling synced with the GitHub-Template (Nov 2026): Pester 6, Sampler 0.120, PSResourceGet dependency resolution with version ranges in `RequiredModules.psd1`, and a new `Assert_RequiredModule_Versions` build task. Build tooling now requires PowerShell 7.6+; the module itself still supports PowerShell 3.0+.
- Markdown command help is now generated with Microsoft.PowerShell.PlatyPS 1.x (`./build.ps1 -Tasks docs`) into `Docs/Help/ConnectWiseAutomateAgent/`. `Docs/Help/ConnectWiseAutomateAgent.md` remains the hand-written function index. The per-function pages moved from `Docs/Help/<Function>.md` to `Docs/Help/ConnectWiseAutomateAgent/<Function>.md`, so links to the old paths no longer resolve.
- CI hardening: actions pinned to commit SHAs (checkout v7, upload-artifact v7, download-artifact v8) and kept current by Dependabot, read-only default permissions, no `${{ }}` interpolation inside scripts, publish concurrency, `Publish-PSResource`, and builds on `fix/`, `chore/`, `docs/` and `feature/` branches. Publishing now fails on a duplicate PSGallery version instead of silently skipping (re-runs still skip).
- `Invoke-QuickTest.ps1` now uses the pinned modules in `output/RequiredModules`, always tests `source/`, fails on failed blocks/containers or zero tests, and always emits JSON in `-OutputFormat Structured`.
- `test-local.ps1` now runs tests through the build pipeline (same configuration as CI), also checks tooling scripts for analyzer errors, and restores `PSModulePath` afterwards.

### Removed

- The `publish` build workflow (`./build.ps1 -Tasks publish`). Publishing to the PowerShell Gallery happens only in CI.
- The `Pester_if_Code_Coverage_Under_Threshold` build task.
- The stale MAML help file (`en-US/ConnectWiseAutomateAgent-help.xml`) and the manifest's `HelpInfoURI`. Nothing generated the file any more and it did not cover the Script helpers. `Get-Help` is unchanged: it reads the comment-based help in each function.

### Fixed

- The example deployment scripts could not run on PowerShell 2.0: the module bootstrap used `*>$null` (a parse error there) and a TLS 1.2 line that does nothing on .NET 3.5, and the GPO example used `Get-CimInstance`. The README now gives a direct download form that works on Windows 7 / Server 2008 R2.
- Module source is now ASCII only. The single-file module has no byte order mark, so Windows PowerShell decoded its em dashes as characters that include a double quote when it was loaded by direct download. They were all in comments, so nothing broke, but one inside a string would have stopped the module loading.
- `Install-CWAA` could not install on PowerShell versions before 5.0 when using an InstallerToken against a current Automate server, because it unpacked the installer with `Expand-Archive`. It now falls back to .NET 4.5's ZIP support, then to the Windows shell's. It also used the `-in` operator, which stopped the whole module from loading on PowerShell 2.0.
- On PowerShell 2.0, server resolution and the module's proxy and key state used `[PSCustomObject]`, which returns a hashtable there. They are now created with `New-Object PSObject`.
- TLS 1.2 is now also requested on .NET 3.5 (PowerShell 2.0 on Windows 7 / Server 2008 R2), where it works once the TLS 1.2 update for .NET 3.5.1 is installed.
- The automatic relaunch from 32-bit to 64-bit PowerShell in direct download mode (used when the module is loaded from tools such as ScreenConnect) ran `Initialize-CWAA` in the 64-bit session instead of the caller's commands, failed, and then ended the 32-bit session with nothing done. It now runs the original `powershell.exe` command line again in 64-bit (`-Command`, `-File` with its arguments, or `-EncodedCommand`) and exits with its exit code. Sessions that cannot be run again (not started with `-Command`, `-File` or `-EncodedCommand`, or started with `-NoExit`) get a warning and continue in 32-bit, as does a session whose 64-bit relaunch fails to start.
- Importing the module with `Import-Module` from 32-bit PowerShell no longer attempts that relaunch; it only warns, as documented.
- `Set-CWAAProxy -ProxyPassword` and `-EncodedProxyPassword` stored the text "System.Security.SecureString" as the proxy password, and `-ProxyCredential` failed with a conversion error. All three now apply the real password. Encoded credentials that cannot be decoded with the agent password are now an error instead of being applied as blank.
- `Install-CWAA` with a proxy enabled failed after the MSI had installed, because it passed the proxy password to `Set-CWAAProxy` as plain text. The install was logged as failed and installer cleanup, `-Hide` and `-Rename` were skipped.
- `Set-CWAAProxy -DetectProxy` could enable the Automate server's own address as the proxy when no proxy was in use. It now falls back to the WinHTTP proxy setting, and leaves the proxy disabled when there is none. The fallback did not match the English output of `netsh winhttp show proxy`; it now reads both the single-proxy and the per-protocol form, whatever language the label is in, and routes the module's own requests through the proxy it finds.
- `Set-CWAAProxy -ProxyServerURL` without credentials kept the previous proxy's username and password and wrote them to the agent for the new proxy. They are now cleared.
- `Update-CWAA` without `-Version` threw a version conversion error when no server could be reached or the server was too old to offer updates. It now writes a warning that says which.
- `Update-CWAA` could leave the session in the updater's temporary folder when the update extractor failed to start.
- `Repair-CWAA` only detected another running repair when it ran under `powershell.exe` and was called as `Repair-CWAA`. It now also detects `pwsh.exe` and the `Repair-LTService` alias, and never terminates the process chain that launched it.
- `Repair-CWAA` reported "Agent recovered" after a service restart whenever the last check-in was recent, even if the heartbeat that triggered the restart was still stale. It now waits for both (up to two minutes) and otherwise reports that the agent has not recovered yet.
- `-WhatIf` no longer writes "success" events: `Set-CWAAProxy` (event 3020), `Set-CWAALogLevel` (event 3030) and `New-CWAABackup` (event 3010). `New-CWAABackup` also no longer reports "backup has been created" when files could not be copied or `reg.exe` returned an error. Both cases now write an error, and a failed registry export stops before the import instead of importing an older export file.
- Pester configuration in `build.yaml` used the `Script` key, which Sampler ignores; test discovery could fall back to a lowercase `tests` path on case-sensitive runners.
- Per-function and per-alias export tests in `ConnectWiseAutomateAgent.Module.Tests.ps1` were silently generating zero test cases because their data was defined after discovery.
- `Register-CWAAHealthCheckTask` now recreates the scheduled task when `-IntervalHours`, `-Server`, or `-LocationID` change, not only when `-InstallerToken` changes.
- `Register-CWAAHealthCheckTask` now verifies the scheduled task actually exists after registration and logs an error (event ID 4023) if it doesn't (e.g. removed by AV/policy immediately after creation).
- `Register-CWAAHealthCheckTask` now correctly writes to the Windows Event Log on registration failure even when the caller has set `$ErrorActionPreference = 'Stop'`. The event is written first and the error then follows the caller's `-ErrorAction`, so `-ErrorAction Stop` callers can catch the failure.
- `Register-CWAAHealthCheckTask` now replaces an existing task in place (`schtasks /CREATE /F`) instead of deleting it first, so a failed update no longer leaves the machine without a health check task.
- `Register-CWAAHealthCheckTask` no longer returns `Updated = $true` when nothing was updated (`-WhatIf`, a failed create, or a failed verification).

## [2.1.0] - 2026-06-17

### Added

- **WMI dependency service enforcement** — `Confirm-CWAADependencyService` ensures `winmgmt` (WMI) is set to Automatic startup and Running before install, repair, and service start. Configurable via `$Script:CWAADependencyServiceNames`; respects `-WhatIf`. Event IDs 2030–2039.

## [2.0.0] - 2026-02-03

### Added

- **Health check and auto-remediation system**
  - `Test-CWAAHealth` — read-only health assessment with configurable checks
  - `Repair-CWAA` — escalating remediation (restart, reinstall, fresh install)
  - `Register-CWAAHealthCheckTask` / `Unregister-CWAAHealthCheckTask` — scheduled task management
- **Server connectivity testing** — `Test-CWAAServerConnectivity` with auto-discovery and `-Quiet` flag
- **Windows Event Log integration** — `Write-CWAAEventLog` with categorized event IDs (1000-4039)
- **Lazy networking initialization** — `Initialize-CWAANetworking` with graduated SSL trust (IP bypass, hostname mismatch tolerance, chain rejection unless `-SkipCertificateCheck`)
- **Installer cleanup utility** — `Clear-CWAAInstallerArtifacts` for pre-install hygiene
- **Credential redaction** — `Get-CWAARedactedValue` using SHA256 hash prefix for safe logging
- **Private helper functions** — `Resolve-CWAAServer`, `Test-CWAADownloadIntegrity`, `Remove-CWAAFolderRecursive` to eliminate duplicate code across Install/Uninstall/Update
- **Comprehensive test suite** — 392+ tests across 4 files (structure, mocked, cross-version, live)
- **PSScriptAnalyzer configuration** — `.PSScriptAnalyzerSettings.psd1` with 6 documented suppressions
- **Input validation hardening** — `ValidateScript` on mandatory Server params, `ValidateRange` on LocationID, `ValidatePattern` on InstallerToken and TaskName
- **GitHub Actions CI/CD** — smoke test, single-file build artifact, prerelease/stable PSGallery publish
- **Build scripts** — `SingleFileBuild.ps1`, `Build-Documentation.ps1`, `Publish-CWAAModule.ps1`
- **6 example scripts** — installation, health check monitoring, proxy configuration, troubleshooting diagnostic, GPO deployment, install with health check
- **WhatIf/Confirm support** on all destructive operations via `SupportsShouldProcess`
- **PowerShell Core compatibility** — validated on PowerShell 5.1 and 7+
- **CONTRIBUTING.md** — development setup, coding conventions, PR workflow, versioning guide
- **EditorConfig** — consistent formatting across editors (4-space PS, 2-space YAML/JSON)
- **Architecture documentation** — Mermaid diagrams for module init, install workflow, health check, and system interaction map

### Changed

- **Module prefix** renamed from `LT` to `CWAA` (all 32 `LT` aliases preserved for backward compatibility)
- **Variable naming cleanup** — all cryptic names replaced with descriptive names (`$Svr` → `$automateServerUrl`, `$tmpLTSI` → `$restartThreshold`, etc.)
- **Error handling standardization** — consistent Try-Catch-Finally with context-aware error messages throughout
- **Debug/logging overhaul** — `Write-Debug` in Begin/Process/End blocks for all functions
- **Server loop refactored** — duplicated ~300-line server validation loop in Install/Uninstall/Update extracted to `Resolve-CWAAServer`
- **Download integrity checks** — centralized in `Test-CWAADownloadIntegrity` (was inline in 3 files)
- **Folder cleanup** — centralized in `Remove-CWAAFolderRecursive` (was inline in 2 files)

### Fixed

- **LocationID type** — changed from `[string]` to `[int]` on `Redo-CWAA` to match validation
- **Empty catch blocks** — all empty catch blocks now log via `Write-Debug`

### Security

- **Graduated SSL certificate validation** — replaces blanket bypass with IP auto-bypass, hostname mismatch tolerance, and chain rejection
- **Vulnerability check** — `Install-CWAA` warns when server is below v200.197 (June 2020 CVE)
- **Password redaction** — installer command-line arguments sanitized in debug output

## [0.1.4.0] - 2024-01-15

### Added

- Initial public release of ConnectWiseAutomateAgent module
- 25 public functions for agent lifecycle management
- 32 legacy `LT` aliases for backward compatibility
- Single-file distribution build (`ConnectWiseAutomateAgent.ps1`)
- Basic Pester test suite
- Comment-based help on all public functions

### Functions

- `Install-CWAA` / `Uninstall-CWAA` / `Update-CWAA` / `Redo-CWAA` — agent lifecycle
- `Start-CWAA` / `Stop-CWAA` / `Restart-CWAA` — service management
- `Get-CWAAInfo` / `Get-CWAASettings` / `Get-CWAAInfoBackup` — agent information
- `New-CWAABackup` / `Reset-CWAA` — backup and reset
- `Get-CWAAError` / `Get-CWAAProbeError` — log retrieval
- `Get-CWAALogLevel` / `Set-CWAALogLevel` — log configuration
- `Get-CWAAProxy` / `Set-CWAAProxy` — proxy management
- `Hide-CWAAAddRemove` / `Show-CWAAAddRemove` / `Rename-CWAAAddRemove` — Add/Remove Programs control
- `ConvertTo-CWAASecurity` / `ConvertFrom-CWAASecurity` — TripleDES encryption interop
- `Invoke-CWAACommand` — send commands to agent service
- `Test-CWAAPort` — TrayPort availability check
