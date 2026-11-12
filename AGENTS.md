# AGENTS.md

## Start Here

1. Read **[Project Overview](#project-overview)** for what the module does
2. Run the **[Quick Start](#quick-start)** commands to load and test locally
3. Skim **[Architecture](#architecture)** for directory layout and the two-phase loading model
4. Check **[Code Conventions](#code-conventions)** before writing any code
5. Follow **[AI Contribution Workflow](#ai-contribution-workflow)** to find and claim work

## Project Overview

**ConnectWiseAutomateAgent** is a PowerShell module for managing the ConnectWise Automate (formerly LabTech) Windows agent. Used by MSPs to install, configure, troubleshoot, and manage the Automate agent on Windows systems.

- **Language**: PowerShell, in three tiers: 2.0+ for agent deployment, 5.1+ for everything that runs once an agent is installed, 7 for build and test tooling. See [PowerShell Version Tiers](#powershell-version-tiers)
- **Build System**: Sampler/ModuleBuilder/InvokeBuild (`./build.ps1`)
- **Test Framework**: Pester 6 (pinned range in `RequiredModules.psd1`)
- **Linter**: PSScriptAnalyzer
- **License**: MIT
- **Platform**: Windows only (build and test tooling requires PowerShell 7.6+)

## Quick Start

```powershell
# First time setup (resolve build dependencies)
./build.ps1 -ResolveDependency -Tasks noop

# Import source module for local testing
Import-Module .\source\ConnectWiseAutomateAgent.psd1 -Force

# Build the module (output goes to output/)
./build.ps1 -Tasks build

# Run all tests
./build.ps1 -Tasks test

# Run PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path source -Recurse -Severity Error,Warning

# Regenerate markdown command help (Docs/Help/ConnectWiseAutomateAgent/)
./build.ps1 -Tasks docs

# Local pre-push validation (build + analyze + test)
./Tests/test-local.ps1
```

## Architecture

### Directory Layout

```text
ConnectWiseAutomateAgent/
  build.ps1                           # Build entry point (Invoke-Build)
  build.yaml                          # Sampler build configuration
  RequiredModules.psd1                # Build dependency manifest (NuGet version ranges)
  Resolve-Dependency.ps1              # Bootstrap script for build deps
  .build/                             # Custom build tasks (dependency version check, docs)
  source/
    ConnectWiseAutomateAgent.psd1     # Module manifest
    ConnectWiseAutomateAgent.psm1     # Root module (auto-loads subdirectories)
    en-US/                            # about_ help topic (Get-Help for functions uses comment-based help)
    Private/                          # Internal helper functions (not exported)
      Initialize/                     # Module bootstrapping
    Public/                           # Exported functions (one file per function)
      AddRemovePrograms/              # Control Panel visibility
      InstallUninstall/               # Install, Uninstall, Update, Redo
      Logging/                        # Error logs, log levels
      Proxy/                          # Proxy configuration
      Scripting/                      # Helpers for scripts run from Automate
      Service/                        # Service control, health checks
      Settings/                       # Agent configuration and backup
  output/                             # Build output (gitignored)
  Tests/
    *.Tests.ps1                       # 13 test suites (Module, Mocked.*, Docs, Security, Compatibility, CrossVersion, Live)
    Helpers/                          # Shared mock helpers
    TestBootstrap.ps1                 # Shared module loading bootstrap
    Invoke-AllTests.ps1               # Dual-mode test runner
    test-local.ps1                    # Pre-push validation script
  Scripts/
    Invoke-QuickTest.ps1              # Fast targeted test runner for dev loops
    Update-MarkdownHelp.ps1           # PlatyPS 1.x markdown help generator (run via build.ps1 -Tasks docs)
  Docs/                               # Hand-written guides
    Help/
      ConnectWiseAutomateAgent.md     # Hand-written categorized function index
      ConnectWiseAutomateAgent/       # Generated per-function reference (do not hand-edit)
      Private/                        # Hand-written private helper notes
  Examples/                           # Ready-to-use deployment scripts
```

### Module Loading (Two-Phase)

**Phase 1 (module import -- fast, no side effects):** `ConnectWiseAutomateAgent.psm1` dot-sources every `.ps1` from `Public/` and `Private/` recursively (in source mode; ModuleBuilder merges them during build), emits a 32-bit warning if running under WOW64 in module mode, then calls `Initialize-CWAA`. This creates centralized constants (`$Script:CWAA*`), empty state objects (`$Script:LTServiceKeys`, `$Script:LTProxy`), the PS version guard, and the WOW64 32-to-64-bit relaunch (direct download mode only). No network objects are created and no registry reads occur.

**Phase 2 (on-demand -- first networking call):** `Initialize-CWAANetworking` (private) is called in the `Begin` block of networking functions (`Install-CWAA`, `Uninstall-CWAA`, `Update-CWAA`, `Set-CWAAProxy`). On first call it performs SSL certificate validation bypass, TLS protocol enablement, creates `$Script:LTWebProxy` and `$Script:LTServiceNetWebClient`, and runs `Get-CWAAProxy` to discover proxy settings from the installed agent. The `$Script:CWAANetworkInitialized` flag ensures this runs only once per session.

### Dual Naming System

Every function uses the `CWAA` prefix (e.g., `Install-CWAA`) but also declares an `LT` alias (e.g., `Install-LTService`) for backward compatibility with the legacy LabTech naming. Aliases are declared both in function `[Alias()]` attributes and in the manifest's `AliasesToExport`.

Exception: the Script helpers in `source/Public/Scripting/` carry their names from the legacy `CW-Automate-ScriptHelper.ps1` as aliases instead (e.g., `Write-AutomateLog`, `Invoke-CWAScript`, `Invoke-LTPwsh`).

### Build Pipeline

The build uses [Sampler](https://github.com/gaelcolas/Sampler) with ModuleBuilder and Invoke-Build. Configuration lives in `build.yaml`.

- `./build.ps1 -ResolveDependency -Tasks noop` -- first-time setup; installs build dependencies listed in `RequiredModules.psd1` into `output/RequiredModules` (via PSResourceGet). Re-run from a new PowerShell session after changing versions.
- `./build.ps1 -Tasks build` -- compiles the module from `source/` into `output/`. ModuleBuilder merges Public/Private functions into a single `.psm1` and auto-populates `FunctionsToExport` and `AliasesToExport` in the manifest.
- `./build.ps1 -Tasks test` -- runs Pester tests against the built module in `output/`.
- `./build.ps1 -Tasks docs` -- builds the module and regenerates `Docs/Help/ConnectWiseAutomateAgent/` with Microsoft.PowerShell.PlatyPS 1.x. Files are regenerated from scratch and validated; remaining `{{ ... }}` placeholders are listed so they can be filled in via comment-based help.
- `Assert_RequiredModule_Versions` runs at the start of `build` and `test` and fails if a dependency is missing, duplicated, or outside its range.
- Publishing is done by CI (`.github/workflows/ci.yml`), not a build task.
- The version is calculated by GitVersion at build time (`GitVersion.yml`): `develop` produces `X.Y.0-alphaNNNN` prereleases, `main` produces stable versions. `ModuleVersion` and `Prerelease` in the source manifest are placeholders; never edit them. Use `+semver: major|minor|patch` in a commit message to force a bump. See [CONTRIBUTING.md](CONTRIBUTING.md#versioning).
- Release notes come from `CHANGELOG.md`: the build labels the `[Unreleased]` section with the version being built and uses it for the manifest's `ReleaseNotes` and the GitHub Release body. Keep release content under `[Unreleased]` until the release is published; rename the heading to the version afterwards.
- Custom tasks live in `.build/` and are referenced from `build.yaml`.

### CI/CD

CI runs build + a consolidated smoke test (PSScriptAnalyzer + Pester on one runner) + publish. It is a safety net -- local validation is the primary gate. See CLAUDE.md for the mandatory validation workflow and `.github/workflows/ci.yml` for branch strategy.

### Common Patterns

**WOW64 Handling.** The module detects 32-bit PowerShell on 64-bit OS. In direct download mode (.psm1 via IEX), it auto-relaunches under 64-bit PowerShell. In module mode, it emits a warning (cannot relaunch `Import-Module`). Registry and file operations must account for WOW64 redirection.

**SSL Callback Persistence.** The SSL certificate validation callback is compiled via `Add-Type` in `Initialize-CWAANetworking`. Because compiled .NET types cannot be unloaded from an AppDomain, the callback persists for the lifetime of the PowerShell process -- even across module re-imports.

**Dual-Mode Testing.** The module ships as both a PSGallery module and a single compiled `.psm1` file attached to each GitHub Release. Both loading methods must be tested. See `Get-Help .\Tests\TestBootstrap.ps1` for details on load methods.

**.psm1 Module Scoping.** PowerShell treats `.psm1` files differently from `.ps1` when dot-sourced. Dot-sourcing a `.psm1` applies module-scoping rules that make functions invisible to `Get-Command` and the `Function:` drive -- even in the global scope. This means `. .\Module.psm1` does not make functions callable the way `. .\Script.ps1` does. To execute `.psm1` content without module scoping, read the file as a string and execute via `Invoke-Expression` or `[scriptblock]::Create()`. The cross-version tests use the scriptblock approach for this reason.

**System-Installed Module Interference.** If an older version of the module is installed system-wide (e.g., in `C:\Program Files\WindowsPowerShell\Modules\`), `Get-Command` may return functions from the installed version via auto-discovery instead of functions defined in the current session. This can cause tests to report incorrect function counts matching the old version rather than the current source. Always verify which module version `Get-Command` is resolving from by checking the `.Source` or `.ModuleName` property on returned commands.

## Code Conventions

For the full contributing guide covering development setup, coding standards, and PR workflow, see [CONTRIBUTING.md](CONTRIBUTING.md). General PowerShell guidance shared across projects lives in the template repository: [PowerShell Style Guide](https://github.com/christaylorcodes/GitHub-Template/blob/main/docs/PowerShell-StyleGuide.md) and [PowerShell Deep Review](https://github.com/christaylorcodes/GitHub-Template/blob/main/docs/PowerShell-DeepReview.md). Where they differ, this file wins (for example, this module keeps the PowerShell version tiers below).

### PowerShell Version Tiers

The module is deployed into environments where endpoints have not been managed and may never have been updated. Getting the agent onto those machines is the point, so how old a PowerShell a piece of code must support depends on when it runs.

| Tier | Runs on | What is in it |
| --- | --- | --- |
| **Deployment** | Windows 7 / Server 2008 R2 as shipped: PowerShell 2.0, .NET 3.5 | Everything needed to load the module and install, reinstall or remove an agent. This is the default: a source file is in this tier unless it is listed as managed |
| **Managed** | PowerShell 5.1 and 7 | Code that only runs once an agent is installed, when the machine can be assumed to be on the newest PowerShell it supports. Windows 7 stops at 5.1, so this tier must work on 5.1 as well as 7 |
| **Tooling** | PowerShell 7 | The build, tests, `Scripts/`, `.build/` and anything else that is not shipped to endpoints |

The managed tier is the list in `$managedTier` at the top of `Tests/ConnectWiseAutomateAgent.Compatibility.Tests.ps1`: the Script helpers, logging functions, `Repair-CWAA`, the health check functions, `Test-CWAAServerConnectivity`, `Update-CWAA`, `Invoke-CWAACommand` and `Reset-CWAA`. That test file is the source of truth; add a file to the list only when it cannot run before an agent exists.

Rules:

- **Every shipped file must parse on PowerShell 2.0**, whatever its tier. Direct download mode loads the whole module text at once, so one piece of newer syntax anywhere stops the install. That rules out `-in` / `-notin` (use `-contains`), `[Parameter(Mandatory)]` without `= $True`, and redirecting streams other than output and error.
- **Deployment tier code must also run on PowerShell 2.0 / .NET 3.5.** Common traps:
  - `[PSCustomObject]@{}` quietly returns a hashtable. Use `New-Object PSObject -Property @{}`.
  - No `Expand-Archive`, `Get-CimInstance`, `Invoke-WebRequest`, `Invoke-RestMethod`, `ConvertTo-Json` or `ConvertFrom-Json`. Use the private helpers (`Expand-CWAAZipFile`), `System.Net.WebClient` and `System.Net.WebRequest`.
  - No `$PSScriptRoot`, `::new()`, `.Where()` / `.ForEach()`, `Where-Object Name -eq x` without a script block, or `-ErrorAction Ignore`.
  - `foreach` over `$null` runs once, and `$list.Name` does not read a property from every item. Guard the loop and use `ForEach-Object`.
  - .NET 4 members such as `[string]::IsNullOrWhiteSpace` and `[Environment]::Is64BitOperatingSystem` do not exist.
- `Tests/ConnectWiseAutomateAgent.Compatibility.Tests.ps1` enforces the first rule on every file and a block list of the second on deployment tier files. It reads the syntax tree; it cannot run PowerShell 2.0 (current Windows no longer has the engine) and cannot see run-time traps like the `foreach` one. A Windows 7 / Server 2008 R2 machine is the real check before a release.
- PSScriptAnalyzer's `PSUseCompatibleSyntax` targets 3.0 and 5.1 only (it has no 2.0 target), so it does not replace the test above.

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

Source of truth for docs is comment-based help in `.ps1` files under `source/`. After changing it, run `./build.ps1 -Tasks docs` and commit the regenerated `Docs/Help/ConnectWiseAutomateAgent/` files. Update the hand-written index (`Docs/Help/ConnectWiseAutomateAgent.md`) when adding or renaming a public function.

**Known pitfall:** Lines starting with `.WORD` (e.g., `.NET`) in comment-based help are parsed as help keywords. Keep such terms mid-line.

For git commit style and the full contributing guide, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Adding New Functions

1. Create `Verb-CWAA<Noun>.ps1` in the appropriate `source/Public/` subdirectory
2. Add `[Alias('Verb-LT<LegacyNoun>')]` in the function declaration (Script helpers use their legacy ScriptHelper name instead)
3. Build the module: `./build.ps1 -Tasks build` -- ModuleBuilder auto-populates `FunctionsToExport` and `AliasesToExport` in the manifest (no manual manifest update needed)
4. Regenerate docs: `./build.ps1 -Tasks docs`, then add the function to the hand-written index `Docs/Help/ConnectWiseAutomateAgent.md`

When modifying existing functions:

- Maintain the `LT` alias (or the legacy ScriptHelper alias for Script helpers)
- Rebuild: `./build.ps1 -Tasks build`
- Consider 32-bit/64-bit WOW64 behavior for registry/file operations
- Keep to the file's [PowerShell version tier](#powershell-version-tiers)

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
./Tests/test-local.ps1 -DualMode      # Also test BuiltModule loading
```

See `Get-Help .\Tests\test-local.ps1` for flags: `-SkipBuild`, `-SkipTests`, `-SkipAnalyze`, `-Quick`.

### Key Rules

- **Local validation is mandatory before every commit.** Run `Invoke-QuickTest.ps1 -IncludeAnalyzer` during development and `test-local.ps1` before committing. CI is a safety net, not the primary gate.
- No code is complete without passing tests. A function without a test is unfinished work.
- PSScriptAnalyzer zero errors required. Run against `source/`. Always use `-IncludeAnalyzer` during development.
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
3. Implement changes, adding tests as you go
4. **After each meaningful change**, validate:
   ```powershell
   ./Scripts/Invoke-QuickTest.ps1 -IncludeAnalyzer -OutputFormat Structured
   ```
   Parse the JSON `success` field. Fix all `failedTests` and `analyzerErrors` before proceeding.
5. **Before committing**, run the full pipeline:
   ```powershell
   ./Tests/test-local.ps1
   ```
   All three stages (build, analyze, test) must pass. Do not commit until they do.
6. Commit referencing the issue: `Add feature X (fixes #123)`
7. Push, open PR, update label: `gh issue edit <number> --add-label ai-review --remove-label ai-in-progress`

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
