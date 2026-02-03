# Contributing to ConnectWiseAutomateAgent

Thank you for your interest in contributing! This project benefits from all kinds of contributions, whether you code or not.

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/christaylorcodes/ConnectWiseAutomateAgent/issues) to see if it has already been reported.
2. Open a [new issue](https://github.com/christaylorcodes/ConnectWiseAutomateAgent/issues/new) with:
   - PowerShell version (`$PSVersionTable`)
   - Windows version
   - Steps to reproduce
   - Expected vs actual behavior
   - Error messages (use `-Debug` and `-Verbose` flags for detail)

### Suggesting Enhancements

Open an issue describing what you would like to see and why. Include use cases so maintainers can understand the context.

### Submitting Pull Requests

1. **Fork** the repository and create a branch from `main`.
2. **Make your changes** following the coding conventions below.
3. **Test** your changes:
   ```powershell
   ./build.ps1 -Tasks test
   ```
4. **Submit** a pull request with a clear description of what you changed and why.

## Development Setup

```powershell
# Clone the repository
git clone https://github.com/christaylorcodes/ConnectWiseAutomateAgent.git
cd ConnectWiseAutomateAgent

# First time: resolve build dependencies (Sampler, ModuleBuilder, InvokeBuild, etc.)
./build.ps1 -ResolveDependency -Tasks noop

# Build the module (output goes to output/)
./build.ps1 -Tasks build

# Run all checks (build + analyze + test)
./build.ps1 -Tasks test

# Import from source for quick dev iteration (no build required)
Import-Module .\source\ConnectWiseAutomateAgent.psd1 -Force

# Enable pre-commit hooks (runs PSScriptAnalyzer + tests before each commit)
git config core.hooksPath .githooks
```

## Coding Conventions

See the [Code Conventions](AGENTS.md#code-conventions) section in AGENTS.md for the full quick-reference covering naming, parameters, debug output, error handling, constants, help, variable names, and PSScriptAnalyzer requirements.

The key points:

- Functions use `Verb-CWAA<Noun>` naming with `[Alias('Verb-LT<LegacyNoun>')]` for backward compatibility
- `[CmdletBinding()]` on everything; `SupportsShouldProcess=$True` on destructive operations
- Zero PSScriptAnalyzer errors required (settings in `.PSScriptAnalyzerSettings.psd1`)
- PowerShell files use UTF-8 with BOM, CRLF line endings

### Adding a New Function

See [Adding New Functions](AGENTS.md#adding-new-functions) in AGENTS.md for the full checklist. Summary:

1. Create `Verb-CWAA<Noun>.ps1` in the appropriate `source/Public/` subdirectory
2. Add the `LT` alias -- ModuleBuilder auto-discovers functions and aliases from `source/Public/`, so no manifest edits are needed for export lists
3. Rebuild: `./build.ps1 -Tasks build`

## Versioning

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (`MAJOR.MINOR.PATCH`).

### When to Bump Each Component

| Component | When to bump | Examples |
| --------- | ------------ | -------- |
| **MAJOR** | Breaking changes to public function signatures, removed functions, renamed parameters | Removing `Install-CWAA`, changing mandatory parameter names |
| **MINOR** | New functions, new optional parameters, new features (backward-compatible) | Adding `Test-CWAAHealth`, adding `-Quiet` switch to existing function |
| **PATCH** | Bug fixes, documentation improvements, internal refactoring (no behavior change) | Fixing a regex bug, updating help text, extracting a private helper |

### Prerelease Tags

Prerelease versions use the format `MAJOR.MINOR.PATCH-TAG` where TAG follows this progression:

1. `alpha001`, `alpha002`, ... — early development, API may change
2. `beta001`, `beta002`, ... — feature-complete, testing in progress
3. `rc001`, `rc002`, ... — release candidate, final validation
4. *(no tag)* — stable release

The prerelease tag is set in `source/ConnectWiseAutomateAgent.psd1` under `PrivateData.PSData.Prerelease`. Remove the tag entirely for a stable release.

### Changelog

All notable changes are documented in [CHANGELOG.md](CHANGELOG.md) using [Keep a Changelog](https://keepachangelog.com/) format. Update the changelog as part of any PR that changes behavior.

## Code of Conduct

Be respectful and constructive in all interactions. We're all here to make this module better.
