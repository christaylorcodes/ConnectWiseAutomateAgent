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
   Import-Module .\ConnectWiseAutomateAgent\ConnectWiseAutomateAgent.psd1 -Force
   Invoke-Pester Tests\ConnectWiseAutomateAgent.Tests.ps1 -Output Detailed
   ```
4. **Rebuild** the single-file distribution:
   ```powershell
   powershell -File Build\SingleFileBuild.ps1
   ```
5. **Submit** a pull request with a clear description of what you changed and why.

## Development Setup

```powershell
# Clone the repository
git clone https://github.com/christaylorcodes/ConnectWiseAutomateAgent.git
cd ConnectWiseAutomateAgent

# Import the module locally
Import-Module .\ConnectWiseAutomateAgent\ConnectWiseAutomateAgent.psd1 -Force

# Run the test suite
Invoke-Pester Tests\ConnectWiseAutomateAgent.Tests.ps1 -Output Detailed
```

## Coding Conventions

- **Naming:** Use the `CWAA` prefix for function names (`Verb-CWAA<Noun>`). Add an `[Alias('Verb-LT<LegacyNoun>')]` for backward compatibility.
- **Parameters:** Use `[CmdletBinding()]`. Add `SupportsShouldProcess=$True` on destructive operations.
- **Debug output:** Include `Write-Debug "Starting $($MyInvocation.InvocationName)"` in the Process block and `Write-Debug "Exiting $($MyInvocation.InvocationName)"` in the End block.
- **Error handling:** Use `Write-Error "Failed to <action> at '<target>'. <troubleshooting hint>. Error: $($_.Exception.Message)"`. Use `$_` in Catch blocks, not `$Error[0]`.
- **Constants:** Use `$Script:CWAA*` constants for paths and registry keys instead of hardcoded strings.
- **Help:** Include comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.NOTES`, `.LINK`) on all public functions.
- **Variable names:** Prefer verbose, descriptive names (`$automateServerUrl` not `$srvUrl`).
- **Returns:** Functions return `[PSCustomObject]` for pipeline compatibility.

### Adding a New Function

1. Create `Verb-CWAA<Noun>.ps1` in the appropriate `Public/` subdirectory.
2. Add `[Alias('Verb-LT<LegacyNoun>')]` in the function declaration.
3. Add to `FunctionsToExport` and `AliasesToExport` in `ConnectWiseAutomateAgent.psd1`.
4. Rebuild documentation: `Build\Build-Documentation.ps1` (outputs to `Docs/Help/`)
5. Rebuild single-file: `Build\SingleFileBuild.ps1`

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

The prerelease tag is set in `ConnectWiseAutomateAgent.psd1` under `PrivateData.PSData.Prerelease`. Remove the tag entirely for a stable release.

### Changelog

All notable changes are documented in [CHANGELOG.md](CHANGELOG.md) using [Keep a Changelog](https://keepachangelog.com/) format. Update the changelog as part of any PR that changes behavior.

## Code of Conduct

Be respectful and constructive in all interactions. We're all here to make this module better.
