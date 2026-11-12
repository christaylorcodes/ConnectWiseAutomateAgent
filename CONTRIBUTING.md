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

1. **Fork** the repository and create a branch from `develop` (pull requests target `develop`; `main` holds stable releases).
2. **Make your changes** following the coding conventions below.
3. **Test** your changes (build + analyze + test):
   ```powershell
   ./Tests/test-local.ps1
   ```
4. **Submit** a pull request with a clear description of what you changed and why.

## Development Setup

Build and test tooling requires **PowerShell 7.6+**. The module itself is written to three PowerShell version tiers: code that deploys an agent must run on Windows 7 / Server 2008 R2 as shipped (PowerShell 2.0), and code that only runs once an agent is installed can assume 5.1 or later. See [PowerShell Version Tiers](AGENTS.md#powershell-version-tiers) before changing anything under `source/`.

```powershell
# Clone the repository
git clone https://github.com/christaylorcodes/ConnectWiseAutomateAgent.git
cd ConnectWiseAutomateAgent

# First time: resolve build dependencies (Sampler, ModuleBuilder, InvokeBuild, etc.)
./build.ps1 -ResolveDependency -Tasks noop

# Build the module (output goes to output/)
./build.ps1 -Tasks build

# Run tests
./build.ps1 -Tasks test

# Run all checks (build + analyze + test)
./Tests/test-local.ps1

# Regenerate markdown command help after changing comment-based help
./build.ps1 -Tasks docs

# Import from source for quick dev iteration (no build required)
Import-Module .\source\ConnectWiseAutomateAgent.psd1 -Force

# Enable pre-commit hooks (runs PSScriptAnalyzer + tests before each commit)
git config core.hooksPath .githooks
```

## Coding Conventions

See the [Code Conventions](AGENTS.md#code-conventions) section in AGENTS.md for the full quick-reference covering naming, parameters, debug output, error handling, constants, help, variable names, and PSScriptAnalyzer requirements.

The key points:

- Functions use `Verb-CWAA<Noun>` naming with `[Alias('Verb-LT<LegacyNoun>')]` for backward compatibility (Script helpers use their legacy ScriptHelper name as the alias instead)
- `[CmdletBinding()]` on everything; `SupportsShouldProcess=$True` on destructive operations
- Zero PSScriptAnalyzer errors required (settings in `.PSScriptAnalyzerSettings.psd1`)
- PowerShell files use UTF-8 with BOM, CRLF line endings

### Adding a New Function

See [Adding New Functions](AGENTS.md#adding-new-functions) in AGENTS.md for the full checklist. Summary:

1. Create `Verb-CWAA<Noun>.ps1` in the appropriate `source/Public/` subdirectory
2. Add the `LT` alias -- ModuleBuilder auto-discovers functions and aliases from `source/Public/`, so no manifest edits are needed for export lists
3. Rebuild: `./build.ps1 -Tasks build`. Regenerate docs (`./build.ps1 -Tasks docs`) and add the function to `Docs/Help/ConnectWiseAutomateAgent.md`

## Versioning

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (`MAJOR.MINOR.PATCH`).

### When to Bump Each Component

| Component | When to bump | Examples |
| --------- | ------------ | -------- |
| **MAJOR** | Breaking changes to public function signatures, removed functions, renamed parameters | Removing `Install-CWAA`, changing mandatory parameter names |
| **MINOR** | New functions, new optional parameters, new features (backward-compatible) | Adding `Test-CWAAHealth`, adding `-Quiet` switch to existing function |
| **PATCH** | Bug fixes, documentation improvements, internal refactoring (no behavior change) | Fixing a regex bug, updating help text, extracting a private helper |

### How the Version Is Set

The version is calculated by [GitVersion](https://gitversion.net/) at build time from the branch and git history (`GitVersion.yml`). Do not edit `ModuleVersion` or `PrivateData.PSData.Prerelease` in `source/ConnectWiseAutomateAgent.psd1`; they are placeholders (`0.0.1` and empty) that the build overwrites.

| Branch | Version produced | Published as |
| --- | --- | --- |
| `develop` | Next minor with an `alpha` tag, e.g. `2.2.0-alpha0001`, `2.2.0-alpha0002`, ... | Prerelease on the PowerShell Gallery |
| `main` | Stable, e.g. `2.2.0` | Stable release on the PowerShell Gallery and a GitHub Release |

To force a specific bump, include `+semver: major`, `+semver: minor`, or `+semver: patch` in a commit message (`+semver: none` to skip).

A local build without GitVersion installed produces version `0.0.1`. That is expected and only affects local output.

### Changelog

All notable changes are documented in [CHANGELOG.md](CHANGELOG.md) using [Keep a Changelog](https://keepachangelog.com/) format. Update the `[Unreleased]` section as part of any PR that changes behavior.

The build takes everything under `[Unreleased]`, labels it with the version being built, and uses it as the module's release notes on the PowerShell Gallery and as the GitHub Release body. So leave release content under `[Unreleased]` until the release is published. Renaming the heading to a version beforehand leaves `[Unreleased]` empty and produces empty release notes (this happened with 2.1.0).

After a stable release is published, rename `[Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` and add a new empty `[Unreleased]` section above it.

## Code of Conduct

Be respectful and constructive in all interactions. We're all here to make this module better.
