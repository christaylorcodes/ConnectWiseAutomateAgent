# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Fixed

## [1.0.0] - 2026-02-03

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
