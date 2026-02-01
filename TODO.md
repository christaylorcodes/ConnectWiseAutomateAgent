# ConnectWiseAutomateAgent - TODO List

This document tracks improvements and tasks for the ConnectWiseAutomateAgent project. Tasks are organized by priority and category to help contributors and AI assistants work more effectively with the codebase.

## Priority 1: Polish & Remaining Gaps

These items close out the last gaps from the major development push.

### Documentation

- [x] **Fix incomplete function documentation** (Completed 2025-11-04)
  - [x] Complete synopsis for `Get-CWAALogLevel`
  - [x] Complete synopsis for `New-CWAABackup`
  - [x] Complete synopsis for `Uninstall-CWAA`
  - [x] 25 of 26 public function docs fully complete with MAML format
  - [x] Fix stub doc for [Docs/Private/Initialize-CWAA.md](Docs/Private/Initialize-CWAA.md) (replaced PlatyPS placeholder with real documentation)

- [x] **Add inline code comments for complex logic** (Mostly complete)
  - [x] Encryption/decryption algorithms in `ConvertFrom-CWAASecurity.ps1` and `ConvertTo-CWAASecurity.ps1`
  - [x] WOW64 redirection handling
  - [x] Install-CWAA business logic (vulnerability checks, parameter building)
  - [x] Document the TrayPort selection logic (42000-42009 range)
  - [x] Explain the server version detection mechanism in more detail

- [x] **Create architecture diagram** (Completed 2026-01-31)
  - [x] Module initialization flow (two-phase: import vs. on-demand networking)
  - [x] Agent installation workflow
  - [x] Health check escalation flow (Test-CWAAHealth → Repair-CWAA)
  - [x] Registry/file system interaction map
  - Created [Docs/Architecture.md](Docs/Architecture.md) with 4 Mermaid diagrams

### Code Quality

- [x] **Fix manifest encoding issues** (Resolved)
  - Manifest is clean ASCII/CRLF, no BOM issues

- [x] **Add PSScriptAnalyzer configuration** (Completed 2026-01-31)
  - [x] Create `.PSScriptAnalyzerSettings.psd1` with project-specific rules
  - [x] Run analyzer and fix critical/error issues
  - [x] Document any intentional rule suppressions with justifications (6 suppressions documented)
  - **Why**: Static analysis catches common errors and enforces best practices

- [x] **Standardize error handling patterns** (Complete)
  - All functions use consistent Try-Catch-Finally with context-aware error messages
  - Standard `$_` usage in Catch blocks throughout
  - Consistent `-ErrorAction` parameter usage

### Testing

- [x] **Create comprehensive Pester tests** (Complete — expanded in Phase 4)
  - 377+ tests across 4 files
  - `ConnectWiseAutomateAgent.Tests.ps1` — 58 tests: module structure, exports, security round-trip
  - `ConnectWiseAutomateAgent.Mocked.Tests.ps1` — 193+ tests: 30 functions with Pester mocks
  - `ConnectWiseAutomateAgent.CrossVersion.Tests.ps1` — 14 tests: PS 5.1 + 7+ compatibility
  - `ConnectWiseAutomateAgent.Live.Tests.ps1` — 112 tests: full lifecycle with real Automate server
  - All 30 public functions and 32 aliases covered across test tiers

- [x] **Expand mocked test coverage** (Completed 2026-01-31)
  - All 30 functions now have mocked tests (was 17 of 30)
  - [x] Add mocked tests for `Install-CWAA`, `Uninstall-CWAA`, `Update-CWAA`
  - [x] Add mocked tests for `Test-CWAAPort`, `Test-CWAAServerConnectivity`
  - [x] Add mocked tests for `Set-CWAAProxy`, `New-CWAABackup`
  - [x] Add mocked tests for `Repair-CWAA`, `Test-CWAAHealth`
  - [x] Add mocked tests for `Register-CWAAHealthCheckTask`, `Unregister-CWAAHealthCheckTask`
  - [x] Add edge-case tests for `ConvertTo-CWAASecurity`, `ConvertFrom-CWAASecurity`
  - **Why**: Mocked tests run without system dependencies, making CI faster and more reliable

## Priority 2: Code Maintainability

These tasks improve long-term maintainability and reduce technical debt.

### Code Organization

- [x] **Refactor long functions** (Completed 2026-01-31)
  - [x] Extracted `Resolve-CWAAServer` — eliminated ~300 duplicated lines across Install/Uninstall/Update
  - [x] Extracted `Test-CWAADownloadIntegrity` — centralized file size validation (was inline in 3 files)
  - [x] Extracted `Remove-CWAAFolderRecursive` — centralized depth-first folder deletion (was inline in 2 files)
  - [x] Updated Install-CWAA, Uninstall-CWAA, Update-CWAA to use new helpers
  - **Note**: Install-CWAA still has Install-specific logic inline (auth branching, vulnerability check, MSI execution) — these are not duplicated elsewhere

- [x] **Consolidate duplicate code** (Completed 2026-01-31)
  - [x] Server validation loop extracted to `Resolve-CWAAServer`
  - [x] Download integrity check extracted to `Test-CWAADownloadIntegrity`
  - [x] Folder cleanup extracted to `Remove-CWAAFolderRecursive`
  - Registry operations remain inline (context-dependent, not worth abstracting)

- [x] **Improve variable naming** (Complete)
  - All cryptic names (`$Svr`, `$SVer`, `$tmpLTSI`) replaced with descriptive names
  - Examples: `$automateServerUrl`, `$serverVersionResponse`, `$restartThreshold`

### Module Structure

- [x] **Add build automation** (Complete)
  - `Build/SingleFileBuild.ps1` — single-file distribution builder
  - `Build/Build-Documentation.ps1` — PlatyPS doc generation
  - `Build/Publish-CWAAModule.ps1` — PSGallery publishing with dry-run support
  - GitHub Actions CI/CD with smoke test → build → prerelease/stable publish

- [x] **Implement proper semantic versioning** (Completed 2026-01-31)
  - [x] Version bumped from `0.1.4.0` to `1.0.0`
  - [x] Document version bump criteria (added to [CONTRIBUTING.md](CONTRIBUTING.md))
  - [x] Add version validation in build process (`SingleFileBuild.ps1` checks manifest vs CHANGELOG)
  - [x] Add changelog generation ([CHANGELOG.md](CHANGELOG.md) with Keep a Changelog format)

- [x] **Add EditorConfig** (Completed 2026-01-31)
  - [x] Create `.editorconfig` for consistent formatting
  - [x] 4-space indentation for PowerShell, 2-space for YAML/JSON/XML
  - [x] CRLF line endings, UTF-8 encoding, trim trailing whitespace

## Priority 3: Security & Best Practices

These tasks address security concerns and improve code quality.

### Security

- [x] **Document security considerations** (Completed 2026-01-31)
  - [x] Document graduated SSL certificate validation strategy (implemented in `Initialize-CWAANetworking`)
  - [x] Explain TripleDES usage and migration path
  - [x] Add security checklist for contributors (added to CLAUDE.md)
  - **Why**: Users need to understand security tradeoffs

- [x] **Implement secure credential handling** (Partially complete)
  - [x] `Get-CWAARedactedValue` added — SHA256 hash prefix for credential logging
  - [x] Password redaction in installer arguments output
  - [ ] Review `$Script:LTServiceKeys` for further hardening
  - [ ] Consider PSCredential objects for password parameters
  - **Why**: Reduces risk of credential exposure

- [x] **Add input validation** (Completed 2026-01-31)
  - [x] `InstallerToken` — `ValidatePattern('(?s:^[0-9a-z]+$)')`
  - [x] `IntervalHours` — `ValidateRange(1, 168)`
  - [x] Validate URL parameters against injection (`ValidateScript` on mandatory `Server` params in `Install-CWAA`, `Repair-CWAA`)
  - [x] Validate LocationID ranges (`ValidateRange(1, [int]::MaxValue)` on `Repair-CWAA`, type fix `[string]`→`[int]` on `Redo-CWAA`)
  - [x] Validate TaskName (`ValidatePattern` on `Register-CWAAHealthCheckTask`)
  - **Why**: Prevents injection attacks and improves error messages
  - **Note**: `ValidateScript` intentionally omitted from optional `Server` params — PowerShell fires validation on internal variable assignment, breaking auto-discovery

### Modern PowerShell Practices

- [x] **Add PowerShell Core compatibility** (Complete)
  - Cross-version tests validate PS 5.1 + 7+
  - Module requires PS 3.0+, works on 5.1 and 7+
  - .NET 6+ obsolescence warnings handled with pragma directives

- [x] **Implement proper logging** (Complete)
  - Write-Debug in Begin/Process/End blocks throughout all functions
  - Windows Event Log integration via `Write-CWAAEventLog`
  - Organized event ID ranges: 1000s install, 2000s service, 3000s config, 4000s health

- [ ] **Add pipeline support**
  - [ ] Review all ValueFromPipeline attributes
  - [ ] Test pipeline scenarios
  - [ ] Document pipeline usage in examples
  - **Why**: PowerShell users expect good pipeline support

## Priority 4: Developer Experience

These tasks improve the experience for contributors and users.

### Development Environment

- [x] **Create development setup guide** (Complete)
  - [CONTRIBUTING.md](CONTRIBUTING.md) covers setup, coding conventions, PR workflow, and new function checklist

- [ ] **Add pre-commit hooks**
  - [ ] Run PSScriptAnalyzer before commit
  - [ ] Run tests before commit
  - [ ] Validate formatting
  - **Why**: Catches issues before they reach the repository

- [x] **Improve debugging experience** (Complete)
  - Write-Debug throughout all functions with Begin/End markers
  - Windows Event Log for production debugging
  - Event IDs organized by category for easy filtering

### Examples & Documentation

- [x] **Expand examples** (Completed 2026-01-31)
  - [x] [Examples/AgentInstall.ps1](Examples/AgentInstall.ps1) — basic installation workflow
  - [x] [Examples/HealthCheck-Monitoring.ps1](Examples/HealthCheck-Monitoring.ps1) — health check task lifecycle
  - [x] [Examples/ProxyConfiguration.ps1](Examples/ProxyConfiguration.ps1) — proxy configuration walkthrough
  - [x] [Examples/Troubleshooting-QuickDiagnostic.ps1](Examples/Troubleshooting-QuickDiagnostic.ps1) — all-in-one diagnostic script
  - [x] [Examples/AgentInstallWithHealthCheck.ps1](Examples/AgentInstallWithHealthCheck.ps1) — installation with health monitoring
  - [x] [Examples/GPOScheduledTaskDeployment.ps1](Examples/GPOScheduledTaskDeployment.ps1) — GPO-based deployment
  - **Why**: Examples are the fastest way for users to learn

- [ ] **Add FAQ section**
  - [ ] Common installation errors
  - [ ] Proxy configuration issues
  - [ ] Version compatibility questions
  - **Why**: Reduces support burden

## Priority 5: Features & Enhancements

These tasks add new capabilities to the module.

### New Features

- [x] **Add WhatIf/Confirm to all destructive operations** (Complete)
  - All destructive functions declare `SupportsShouldProcess=$True`
  - `$PSCmdlet.ShouldProcess()` checks before all destructive actions

- [ ] **Implement progress indicators**
  - [ ] Add Write-Progress to long-running operations (Install, Uninstall, Update)
  - [ ] Show download progress for installers
  - [ ] Display installation steps
  - **Why**: Better user experience during long operations

- [ ] **Add parallel server testing**
  - [ ] Test multiple servers simultaneously
  - [ ] Return fastest responding server
  - **Why**: Improves installation speed

### Integration

- [x] **Add CI/CD pipeline** (Complete)
  - GitHub Actions workflow: smoke test → build → publish
  - Prerelease publish from `develop` branch
  - Stable publish from `main` branch
  - PSGallery environment gating

- [x] **Create integration tests** (Complete)
  - 112-test live suite with full install → exercise → uninstall lifecycle
  - Three-phase testing: fresh install, restore/reinstall, idempotency check
  - All 30 functions and 32 aliases exercised against real Automate server

## Completed Tasks

Track completed items here for historical reference.

### 2025-11-03

- [x] Create CLAUDE.md with comprehensive codebase context
- [x] Create TODO.md with prioritized improvement tasks
- [x] Create blog posts highlighting the module and use cases
  - [BLOG-Introduction.md](BLOG-Introduction.md) - Module introduction and overview
  - [BLOG-TroubleshootingGuide.md](BLOG-TroubleshootingGuide.md) - Troubleshooting guide
  - [BLOG-MassDeployment.md](BLOG-MassDeployment.md) - Mass deployment strategies
  - [BLOG-UseCases.md](BLOG-UseCases.md) - 10 real-world use cases

### 2025-11-04

- [x] Complete function documentation for `Get-CWAALogLevel`, `New-CWAABackup`, `Uninstall-CWAA`

### Development Branch (Current)

- [x] **Health check and auto-remediation system**
  - `Test-CWAAHealth` — read-only health assessment
  - `Repair-CWAA` — escalating remediation (restart → reinstall → fresh install)
  - `Register-CWAAHealthCheckTask` / `Unregister-CWAAHealthCheckTask` — scheduled task management
- [x] **Server connectivity testing** — `Test-CWAAServerConnectivity` with auto-discovery and `-Quiet` flag
- [x] **Windows Event Log integration** — `Write-CWAAEventLog` with categorized event IDs (1000-4039)
- [x] **Lazy networking initialization** — `Initialize-CWAANetworking` with graduated SSL trust
- [x] **Installer cleanup utility** — `Clear-CWAAInstallerArtifacts`
- [x] **Credential redaction** — `Get-CWAARedactedValue` (SHA256 hash prefix)
- [x] **CONTRIBUTING.md** — comprehensive contributor guide
- [x] **GitHub Actions CI/CD** — smoke test, build artifact, prerelease/stable publish
- [x] **Comprehensive test suite** — 377+ tests across 4 files (structure, mocked, cross-version, live)
- [x] **Variable naming cleanup** — all cryptic names replaced with descriptive names
- [x] **Error handling standardization** — consistent Try-Catch-Finally with context
- [x] **Module version bump** — `0.1.4.0` → `1.0.0`
- [x] **WhatIf/Confirm on all destructive operations**
- [x] **PowerShell Core compatibility** — validated on PS 5.1 and 7+
- [x] **Debug/logging overhaul** — Write-Debug throughout + Windows Event Log

### Phase 4 Production Hardening (2026-01-31)

- [x] **PSScriptAnalyzer configuration** — `.PSScriptAnalyzerSettings.psd1` with 6 documented suppressions, all issues fixed
- [x] **Input validation hardening** — `ValidateScript` on mandatory Server params, `ValidateRange` on LocationID, `ValidatePattern` on TaskName, LocationID type fix
- [x] **Inline comments** — TrayPort selection logic, server version detection thresholds, regex breakdown in Initialize-CWAA
- [x] **Initialize-CWAA.md doc** — replaced PlatyPS placeholder with real documentation
- [x] **Expanded examples** — 5 new example scripts (health check, proxy, troubleshooting, GPO deployment, install with health check)
- [x] **Expanded mocked tests** — 13 functions added, all 30 functions now have mocked tests (377+ total tests)
- [x] **Security documentation** — SSL graduation strategy, TripleDES usage, credential redaction, SecureString handling documented in CLAUDE.md
- [x] **Full verification** — 377 tests pass, PSScriptAnalyzer clean, single-file build (4465 lines, 236.5 KB), docs regenerated

### Phase 5 Code Quality & Documentation (2026-01-31)

- [x] **Architecture diagrams** — [Docs/Architecture.md](Docs/Architecture.md) with 4 Mermaid diagrams (module init, install workflow, health check escalation, registry/file interaction map)
- [x] **Refactored duplicate code** — 3 new private helpers: `Resolve-CWAAServer` (~300 lines deduplicated), `Test-CWAADownloadIntegrity` (~18 lines), `Remove-CWAAFolderRecursive` (~6 lines)
- [x] **Updated callers** — Install-CWAA, Uninstall-CWAA, Update-CWAA refactored to use helpers
- [x] **EditorConfig** — `.editorconfig` with PS 4-space, YAML/JSON 2-space, CRLF, UTF-8
- [x] **CHANGELOG.md** — Keep a Changelog format, v1.0.0-alpha001 and v0.1.4.0 entries
- [x] **Versioning docs** — CONTRIBUTING.md updated with semver bump criteria and prerelease tag progression
- [x] **Version validation** — `SingleFileBuild.ps1` checks manifest version vs CHANGELOG latest entry
- [x] **New mocked tests** — 18 tests for private helpers (392 total tests, up from 377)
- [x] **Full verification** — 392 tests pass, PSScriptAnalyzer clean, single-file build (4552 lines, 235 KB), docs regenerated

### Documentation Restructure (2026-01-31)

- [x] **Separated generated vs hand-written docs** — clear folder structure distinguishing auto-generated reference from hand-written guides
  - `Docs/` — hand-written documentation (Architecture.md)
  - `Docs/Help/` — auto-generated function reference (26 function docs + module overview, generated by PlatyPS)
  - `Docs/Help/Private/` — private function reference (Initialize-CWAA.md)
  - `.blog/` — gitignored blog drafts (Introduction, UseCases, MassDeployment, TroubleshootingGuide)
- [x] **Updated Build-Documentation.ps1** — default output path now `Docs\Help`
- [x] **Updated cross-references** — README.md, CLAUDE.md, CONTRIBUTING.md paths updated to `Docs/Help/`
- [x] **Restructured README.md** — new "Documentation" section with distinct "Guides" (hand-written) and "Function Reference (Auto-Generated)" subsections
- [x] **Added documentation structure tests** — 11 new Pester tests validating folder layout, function doc coverage, MAML help, and build script config (403 total tests, up from 392)
- [x] **Full verification** — 403 tests pass, PSScriptAnalyzer clean

---

## How to Use This TODO List

### For AI Assistants

When working on this codebase:

1. **Check Priority 1 tasks first** — these close remaining gaps
2. **Run tests after changes** — `Invoke-Pester Tests\ -ExcludeTag 'Live'`
3. **Run analyzer after changes** — `Invoke-ScriptAnalyzer -Path ConnectWiseAutomateAgent -Recurse -Severity Error,Warning`
4. **Rebuild after changes** — `Build\SingleFileBuild.ps1` and `Build\Build-Documentation.ps1`

### For Contributors

1. Pick tasks that match your skill level
2. Reference [CLAUDE.md](CLAUDE.md) for codebase context and conventions
3. Reference [CONTRIBUTING.md](CONTRIBUTING.md) for workflow and standards
4. Create an issue before starting major work
5. Submit small, focused PRs rather than large changes
6. Update this TODO.md as you complete tasks

### For Maintainers

1. Review and update priorities quarterly
2. Move completed tasks to "Completed Tasks" section
3. Add new tasks as issues are discovered
4. Link to GitHub issues where applicable

---

**Last Updated**: 2026-01-31 (Phase 5)
**Module Version**: 1.0.0-alpha001
