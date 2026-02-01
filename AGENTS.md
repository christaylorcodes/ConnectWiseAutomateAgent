# AGENTS.md

## Start Here

1. Read **[Project Overview](#project-overview)** for what the module does
2. Run the **[Quick Start](#quick-start)** commands to load and test locally
3. Skim **[Architecture](#architecture)** for directory layout and the two-phase loading model
4. Check **[Code Conventions](#code-conventions)** before writing any code
5. Follow **[AI Contribution Workflow](#ai-contribution-workflow)** to find and claim work

## Project Overview

**ConnectWiseAutomateAgent** is a PowerShell module for managing the ConnectWise Automate (formerly LabTech) Windows agent. Used by MSPs to install, configure, troubleshoot, and manage the Automate agent on Windows systems.

- **Language**: PowerShell 3.0+ (2.0 with limitations)
- **Build System**: Custom scripts (`Build/SingleFileBuild.ps1`)
- **Test Framework**: Pester 5.6+
- **Linter**: PSScriptAnalyzer
- **License**: MIT
- **Platform**: Windows only

## Quick Start

```powershell
# Import module for local testing
Import-Module .\ConnectWiseAutomateAgent\ConnectWiseAutomateAgent.psd1 -Force

# Run all tests (excluding live integration tests)
Invoke-Pester Tests\ -ExcludeTag 'Live'

# Run PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path ConnectWiseAutomateAgent -Recurse -Severity Error,Warning

# Local pre-push validation (build + analyze + test)
./Tests/test-local.ps1
```

## Architecture

### Directory Layout

```text
ConnectWiseAutomateAgent/
  ConnectWiseAutomateAgent/
    ConnectWiseAutomateAgent.psd1     # Module manifest
    ConnectWiseAutomateAgent.psm1     # Root module (auto-loads subdirectories)
    en-US/                            # Localized help (MAML XML)
    Private/                          # Internal helper functions (not exported)
      Initialize/                     # Module bootstrapping
    Public/                           # Exported functions (one file per function)
      AddRemovePrograms/              # Control Panel visibility
      InstallUninstall/               # Install, Uninstall, Update, Redo
      Logging/                        # Error logs, log levels
      Proxy/                          # Proxy configuration
      Service/                        # Service control, health checks
      Settings/                       # Agent configuration and backup
  Build/
    SingleFileBuild.ps1               # Concatenate module into single .ps1
    Build-Documentation.ps1           # PlatyPS markdown + MAML generation
    Publish-CWAAModule.ps1            # PSGallery publishing
    Extract-ChangelogEntry.ps1        # Changelog parser for CI releases
  Tests/
    *.Tests.ps1                       # 11 test suites (Module, Mocked.*, Docs, Security, CrossVersion, Live)
    Helpers/                          # Shared mock helpers
    TestBootstrap.ps1                 # Shared module loading bootstrap
    Invoke-AllTests.ps1               # Dual-mode test runner
    test-local.ps1                    # Pre-push validation script
  Scripts/
    Invoke-QuickTest.ps1              # Fast targeted test runner for dev loops
  Docs/                               # Hand-written guides
    Help/                             # Auto-generated function reference (PlatyPS)
  Examples/                           # Ready-to-use deployment scripts
  Output/                             # Build output (gitignored)
```

### Module Loading (Two-Phase)

**Phase 1 (module import -- fast, no side effects):** `ConnectWiseAutomateAgent.psm1` dot-sources every `.ps1` from `Public/` and `Private/` recursively, emits a 32-bit warning if running under WOW64 in module mode, then calls `Initialize-CWAA`. This creates centralized constants (`$Script:CWAA*`), empty state objects (`$Script:LTServiceKeys`, `$Script:LTProxy`), the PS version guard, and the WOW64 32-to-64-bit relaunch (single-file mode only). No network objects are created and no registry reads occur.

**Phase 2 (on-demand -- first networking call):** `Initialize-CWAANetworking` (private) is called in the `Begin` block of networking functions (`Install-CWAA`, `Uninstall-CWAA`, `Update-CWAA`, `Set-CWAAProxy`). On first call it performs SSL certificate validation bypass, TLS protocol enablement, creates `$Script:LTWebProxy` and `$Script:LTServiceNetWebClient`, and runs `Get-CWAAProxy` to discover proxy settings from the installed agent. The `$Script:CWAANetworkInitialized` flag ensures this runs only once per session.

### Dual Naming System

Every function uses the `CWAA` prefix (e.g., `Install-CWAA`) but also declares an `LT` alias (e.g., `Install-LTService`) for backward compatibility with the legacy LabTech naming. Aliases are declared both in function `[Alias()]` attributes and in the manifest's `AliasesToExport`.

### Build Scripts

- `Build/SingleFileBuild.ps1` -- concatenates all `.ps1` files from the module directory into `ConnectWiseAutomateAgent.ps1` at the repo root, appending `Initialize-CWAA` at the end. This flat file is the distribution artifact for direct-invoke scenarios.
- `Build/Build-Documentation.ps1` -- PlatyPS markdown + MAML generation. Outputs to `Docs/Help/`.
- `Build/Publish-CWAAModule.ps1` -- publishes to PowerShell Gallery.
- `Build/Extract-ChangelogEntry.ps1` -- extracts version-specific release notes from CHANGELOG.md for GitHub Releases.

### CI/CD

CI is intentionally lightweight (smoke test, build, publish). Full testing is local. See the header comments in `.github/workflows/ci-publish.yml` for branch strategy and gating rules.

### Common Patterns

**WOW64 Handling.** The module detects 32-bit PowerShell on 64-bit OS. In single-file mode, it auto-relaunches under 64-bit PowerShell. In module mode, it emits a warning (cannot relaunch `Import-Module`). Registry and file operations must account for WOW64 redirection.

**SSL Callback Persistence.** The SSL certificate validation callback is compiled via `Add-Type` in `Initialize-CWAANetworking`. Because compiled .NET types cannot be unloaded from an AppDomain, the callback persists for the lifetime of the PowerShell process -- even across module re-imports.

**Dual-Mode Testing.** The module ships as both a PSGallery module and a single `.ps1` file. Both loading methods must be tested. See `Get-Help .\Tests\TestBootstrap.ps1` for details on load methods.

## Code Conventions

For the full contributing guide covering development setup, coding standards, and PR workflow, see [CONTRIBUTING.md](CONTRIBUTING.md).

### Quick Reference

- **Naming:** `Verb-CWAA<Noun>` prefix with `[Alias('Verb-LT<LegacyNoun>')]`
- **Parameters:** `[CmdletBinding()]`. Add `SupportsShouldProcess=$True` on destructive operations
- **Debug output:** `Write-Debug "Starting $($MyInvocation.InvocationName)"` in Process block, `"Exiting ..."` in End block
- **Error handling:** `Write-Error "Failed to <action> at '<target>'. <hint>. Error: $($_.Exception.Message)"`. Use `$_` in Catch blocks, not `$Error[0]`
- **Constants:** Use `$Script:CWAA*` constants for paths/registry keys instead of hardcoded strings
- **Returns:** Functions return `[PSCustomObject]` for pipeline compatibility
- **Help:** Comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.NOTES`, `.LINK`) on all public functions
- **Variable names:** Verbose, descriptive names (`$automateServerUrl` not `$srvUrl`)
- **PSScriptAnalyzer:** Zero errors required. Settings in `.PSScriptAnalyzerSettings.psd1`
- **PowerShell files:** UTF-8 with BOM, CRLF line endings

### Documentation and Commits

Source of truth for docs is comment-based help in `.ps1` files. Run `Build\Build-Documentation.ps1 -UpdateExisting` after changes.

**Known pitfall:** Lines starting with `.WORD` (e.g., `.NET`) in comment-based help are parsed as help keywords. Keep such terms mid-line.

For git commit style and the full contributing guide, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Adding New Functions

1. Create `Verb-CWAA<Noun>.ps1` in the appropriate `Public/` subdirectory
2. Add `[Alias('Verb-LT<LegacyNoun>')]` in the function declaration
3. Add to `FunctionsToExport` and `AliasesToExport` in `ConnectWiseAutomateAgent.psd1`
4. Rebuild documentation: `Build\Build-Documentation.ps1`
5. Rebuild single-file: `Build\SingleFileBuild.ps1`

When modifying existing functions:

- Maintain the `LT` alias
- Rebuild documentation: `Build\Build-Documentation.ps1 -UpdateExisting`
- Rebuild single-file after changes
- Consider 32-bit/64-bit WOW64 behavior for registry/file operations

## Testing

Local tests are the CI gate. Run these before pushing.

### Development Loop

```powershell
./Scripts/Invoke-QuickTest.ps1 -FunctionName <Name> -IncludeAnalyzer -OutputFormat Structured
```

Parse the JSON `success` field. If `false`, read `failedTests` and `analyzerErrors`, fix, re-run. See `Get-Help .\Scripts\Invoke-QuickTest.ps1 -Full` for all parameters and short-name mappings.

### Pre-Push Validation

```powershell
./Tests/test-local.ps1                # Full: build + analyze + test
./Tests/test-local.ps1 -DualMode      # Also test SingleFile loading
```

See `Get-Help .\Tests\test-local.ps1` for flags: `-SkipBuild`, `-SkipTests`, `-SkipAnalyze`, `-Quick`.

### Key Rules

- No code is complete without passing tests. A function without a test is unfinished work.
- PSScriptAnalyzer zero errors required. Always use `-IncludeAnalyzer` during development.
- Dual-mode testing details: `Get-Help .\Tests\Invoke-AllTests.ps1`
- Test bootstrap and load methods: `Get-Help .\Tests\TestBootstrap.ps1`

## AI Contribution Workflow

### Finding and Claiming Work

```powershell
gh issue list --label ai-ready --state open
gh issue edit <number> --add-label ai-in-progress --remove-label ai-ready
```

### Working on an Issue

1. Claim the issue (above), create branch: `git checkout -b feature/<number>-short-description`
2. Read the full issue body and acceptance criteria
3. Implement, add tests, iterate with `Invoke-QuickTest.ps1 -IncludeAnalyzer -OutputFormat Structured`
4. Run `./Tests/test-local.ps1` -- build + analyze + test must all pass
5. Commit referencing the issue: `Add feature X (fixes #123)`
6. Push, open PR, update label: `gh issue edit <number> --add-label ai-review --remove-label ai-in-progress`

### Guardrails

- Do not modify CI workflow files without explicit instruction
- Do not add dependencies without discussing in an issue first
- Do not commit secrets or push directly to `main`

### Issue Labels

| Label | Meaning |
| --- | --- |
| `ai-ready` | Available for pickup |
| `ai-in-progress` | Claimed, actively working |
| `ai-review` | PR submitted, awaiting review |
| `ai-blocked` | Needs human input (comment on the issue with details) |

## Security

For SSL certificate validation, TripleDES encryption, credential redaction, and InstallerToken vs ServerPassword, see [Docs/Security.md](Docs/Security.md).

## Key System Locations

These are centralized as `$Script:` constants in `Initialize-CWAA`:

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
