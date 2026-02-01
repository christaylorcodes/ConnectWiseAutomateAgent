# ConnectWiseAutomateAgent - Strategic Roadmap

**Last Updated**: 2026-01-31
**Current Module Version**: 1.0.0
**Purpose**: Track project evolution from initial release through production hardening

---

## Overview

ConnectWiseAutomateAgent PowerShell module for managing the ConnectWise Automate agent (formerly LabTech) on Windows systems. Used by MSPs for agent installation, configuration, troubleshooting, and automated health monitoring.

---

## Phase 1: Documentation & Testing ✅ Complete

**Status**: Complete
**Completed**: Development branch (current)

### Delivered

- **Comment-based help** — all 30 public functions have full `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.NOTES`, `.LINK`
- **Pester test suite** — 377+ tests across 4 tiers (structure, mocked, cross-version, live), 100% function coverage
- **Mocked unit tests** — all 30 functions isolated with Pester mocks (no system dependencies)
- **Cross-version tests** — PowerShell 5.1 + 7+ validated
- **Live integration tests** — 112 tests with full install/exercise/uninstall lifecycle
- **CONTRIBUTING.md** — development setup, coding conventions, PR workflow
- **Blog posts** — introduction, troubleshooting guide, mass deployment, use cases

### Remaining

*All remaining Phase 1 items were completed in Phase 4 (2026-01-31):*

- [x] PSScriptAnalyzer settings file (`.PSScriptAnalyzerSettings.psd1`) — completed with 6 documented suppressions
- [x] Expand mocked test coverage to remaining 13 functions — all 30 functions now have mocked tests
- [x] Fix stub doc for `Docs/Private/Initialize-CWAA.md` — replaced placeholder with real documentation

---

## Phase 2: CI/CD & Build Infrastructure ✅ Complete

**Status**: Complete
**Completed**: Development branch (current)

### What Was Delivered

- **GitHub Actions CI/CD** — smoke test → build → publish pipeline
  - Prerelease publish from `develop` branch
  - Stable publish from `main` branch
  - PSGallery environment gating
- **Build scripts** — `SingleFileBuild.ps1`, `Build-Documentation.ps1`, `Publish-CWAAModule.ps1`
- **Module version** — bumped from `0.1.4.0` to `1.0.0`

### Still Needed

- [ ] Changelog generation (CHANGELOG.md)
- [ ] Version bump automation
- [ ] EditorConfig for consistent formatting
- [ ] Pre-commit hooks (PSScriptAnalyzer + tests)

---

## Phase 3: v1.0 Feature Completion ✅ Complete

**Status**: Complete
**Completed**: Development branch (current)

### Features Shipped

- **Health check system** — `Test-CWAAHealth`, `Repair-CWAA`, `Register-CWAAHealthCheckTask`, `Unregister-CWAAHealthCheckTask`
- **Server connectivity testing** — `Test-CWAAServerConnectivity` with auto-discovery
- **Windows Event Log integration** — `Write-CWAAEventLog` with categorized event IDs (1000-4039)
- **Lazy networking initialization** — `Initialize-CWAANetworking` with graduated SSL trust
- **Installer cleanup** — `Clear-CWAAInstallerArtifacts`
- **Credential redaction** — `Get-CWAARedactedValue` (SHA256 hash prefix)
- **Error handling standardization** — consistent Try-Catch-Finally throughout
- **Variable naming cleanup** — all cryptic names replaced with descriptive names
- **WhatIf/Confirm** — all destructive operations support `ShouldProcess`
- **PowerShell Core compatibility** — PS 5.1 and 7+ validated
- **Debug/logging overhaul** — Write-Debug throughout + Windows Event Log

---

## Phase 4: Production Hardening ✅ Complete

**Status**: Complete
**Completed**: 2026-01-31

### Delivered

- **PSScriptAnalyzer compliance** — `.PSScriptAnalyzerSettings.psd1` with 6 documented suppressions, all issues fixed (empty catch blocks, global variable removal)
- **Expanded mocked tests** — 13 functions added, all 30 functions now covered (377+ tests total, up from 272)
- **Security documentation** — SSL graduation strategy, TripleDES usage, credential redaction, SecureString handling, InstallerToken vs ServerPassword documented in CLAUDE.md
- **Input validation hardening** — `ValidateScript` on mandatory Server params (`Install-CWAA`, `Repair-CWAA`), `ValidateRange` on LocationID, `ValidatePattern` on TaskName, LocationID type fix (`[string]`→`[int]` on `Redo-CWAA`)
- **Expanded examples** — 5 new scripts: health check monitoring, proxy configuration, troubleshooting diagnostic, GPO deployment, install with health check
- **Inline comments** — TrayPort selection logic (42000-42009), server version detection thresholds (110.374/200.197/240.331), regex breakdown in Initialize-CWAA
- **Documentation fixes** — Initialize-CWAA.md replaced PlatyPS placeholder with real docs, all 31 markdown docs + MAML regenerated
- **Single-file build** — verified at 4,465 lines / 236.5 KB

### Remaining

- [ ] **Merge develop → main** — ship v1.0.0 stable release to PSGallery

---

## Phase 5: Code Quality & Documentation ✅ Complete

**Status**: Complete
**Completed**: 2026-01-31

### Delivered

- **Architecture diagrams** — [Docs/Architecture.md](Docs/Architecture.md) with 4 Mermaid diagrams (module init, install workflow, health check escalation, registry/file interaction map)
- **Duplicate code refactoring** — 3 new private helpers extracted:
  - `Resolve-CWAAServer` — server validation loop (~300 duplicated lines eliminated)
  - `Test-CWAADownloadIntegrity` — download file size validation (~18 lines)
  - `Remove-CWAAFolderRecursive` — depth-first folder deletion (~6 lines)
- **Caller updates** — `Install-CWAA`, `Uninstall-CWAA`, `Update-CWAA` refactored to use helpers
- **EditorConfig** — `.editorconfig` with PS 4-space, YAML/JSON 2-space, CRLF, UTF-8
- **CHANGELOG.md** — Keep a Changelog format with v1.0.0-alpha001 and v0.1.4.0 entries
- **Versioning documentation** — CONTRIBUTING.md updated with semver bump criteria and prerelease tag progression
- **Version validation** — `SingleFileBuild.ps1` checks manifest version vs CHANGELOG latest entry
- **18 new mocked tests** — private helper functions fully tested (392 total, up from 377)
- **Documentation restructure** — separated generated vs hand-written docs into distinct folders
  - `Docs/` for hand-written guides (Architecture.md)
  - `Docs/Help/` for auto-generated function reference (PlatyPS output)
  - `.blog/` for gitignored blog drafts
  - `Build-Documentation.ps1` updated to output to `Docs/Help/`
  - README.md restructured with clear "Guides" and "Function Reference (Auto-Generated)" sections
  - 11 new documentation structure tests (403 total, up from 392)

---

## Phase 6: Community & Polish 🔮 Planned

**Status**: Planned
**Target**: Q2-Q3 2026

### Targets

1. **Pre-commit hooks** — PSScriptAnalyzer + Pester before commit
2. **Pipeline support review** — audit `ValueFromPipeline` attributes, test and document
3. **FAQ section** — common installation errors, proxy issues, version compatibility
4. **Progress indicators** — `Write-Progress` for long-running operations

---

## Scorecard

| Area | Status | Detail |
| --- | --- | --- |
| Public functions | 30 | 25 original + 5 new |
| Private functions | 6 | Initialize, Networking, Cleanup, Resolve, Integrity, FolderRemove |
| Legacy aliases | 32 | Full backward compatibility |
| Test cases | 403+ | Structure + mocked + cross-version + live + doc structure |
| Test files | 4 | ~5,200 lines total |
| Build scripts | 3 | Single-file, docs, publish |
| CI/CD | GitHub Actions | Smoke, build, prerelease/stable publish |
| PS compatibility | 5.1 + 7+ | Cross-version tested |
| Comment-based help | 100% | All public functions documented |
| PSScriptAnalyzer | Clean | `.PSScriptAnalyzerSettings.psd1` with 6 suppressions |
| Event log integration | Yes | Categorized IDs (1000-4039) |
| Health monitoring | Yes | Test, Repair, Scheduled Task |
| Example scripts | 6 | Install, health check, proxy, troubleshooting, GPO, install+health |
| Architecture docs | Yes | 4 Mermaid diagrams in Docs/Architecture.md |
| Doc structure | Separated | Hand-written (Docs/) vs auto-generated (Docs/Help/) |
| Changelog | Yes | CHANGELOG.md (Keep a Changelog format) |
| EditorConfig | Yes | .editorconfig for consistent formatting |

---
