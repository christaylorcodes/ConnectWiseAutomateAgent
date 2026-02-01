<h1 align="center">
  <br>
  <img src=".\Media\automate-horiz-master.webp" alt="logo" width="75%">
  <br>
  ConnectWiseAutomateAgent
  <br>
</h1>

<h4 align="center">Stop managing Automate agents by hand. Automate it with PowerShell.</h4>

<div align="center">

[![CI / Publish](https://github.com/christaylorcodes/ConnectWiseAutomateAgent/actions/workflows/ci-publish.yml/badge.svg)](https://github.com/christaylorcodes/ConnectWiseAutomateAgent/actions/workflows/ci-publish.yml)
[![Codacy Badge](https://api.codacy.com/project/badge/Grade/8aa3633cda3d41d5baa5e9f595b8124f)](https://www.codacy.com/gh/christaylorcodes/ConnectWiseAutomateAgent/dashboard?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=christaylorcodes/ConnectWiseAutomateAgent&amp;utm_campaign=Badge_Grade)
[![Gallery](https://img.shields.io/powershellgallery/v/ConnectWiseAutomateAgent?label=PS%20Gallery&logo=powershell&logoColor=white)](https://www.powershellgallery.com/packages/ConnectWiseAutomateAgent)
[![Donate](https://img.shields.io/badge/$-donate-ff69b4.svg?maxAge=2592000&amp;style=flat)](https://paypal.me/ChrisTaylorCodes)

</div>

<p align="center">
    <a href="Docs/Help/ConnectWiseAutomateAgent.md">Function Reference</a> &bull;
    <a href="Examples/">Examples</a> &bull;
    <a href="#install">Install</a> &bull;
    <a href="CONTRIBUTING.md">Contribute</a> &bull;
    <a href="https://github.com/christaylorcodes/ConnectWiseAutomateAgent/issues/new?template=bug_report.md">Submit a Bug</a> &bull;
    <a href="https://github.com/christaylorcodes/ConnectWiseAutomateAgent/issues/new?template=feature_request.md">Request a Feature</a>
</p>

---

[ConnectWise Automate](https://www.connectwise.com/software/automate) is a remote monitoring and management (RMM) platform used by Managed Service Providers (MSPs) to monitor and maintain their clients' Windows endpoints. The **Automate agent** is the Windows service that runs on each managed machine, reporting status back to the Automate server and executing remote commands. This module manages that agent.

## Why ConnectWiseAutomateAgent?

Deploying agents to hundreds of endpoints, chasing down offline machines at 2 AM, manually restarting services through RDP -- it's slow, error-prone, and doesn't scale. This module puts the entire Automate agent lifecycle into PowerShell so you can script, automate, and move on.

**One command to install.** **One command to diagnose.** **One command to fix.**

```powershell
Import-Module ConnectWiseAutomateAgent

# Deploy an agent
Install-CWAA -Server 'automate.example.com' -LocationID 1 -InstallerToken 'MyToken'

# What's wrong with this agent?
Get-CWAAInfo | Format-List

# Fix it
Redo-CWAA -Server 'automate.example.com' -LocationID 1 -InstallerToken 'MyToken'
```

## What You Get

| Category | Functions | What it covers |
| --- | --- | --- |
| **Install & Lifecycle** | `Install-CWAA`, `Uninstall-CWAA`, `Update-CWAA`, `Redo-CWAA` | Deploy, remove, upgrade, and reinstall agents |
| **Service Control** | `Start-CWAA`, `Stop-CWAA`, `Restart-CWAA`, `Repair-CWAA` | Manage agent services with escalating remediation |
| **Health & Connectivity** | `Test-CWAAHealth`, `Test-CWAAPort`, `Test-CWAAServerConnectivity` | Diagnose problems before they become tickets |
| **Settings & Backup** | `Get-CWAAInfo`, `Get-CWAAInfoBackup`, `Get-CWAASettings`, `New-CWAABackup`, `Reset-CWAA` | Read, back up, and reset agent configuration |
| **Logging & Diagnostics** | `Get-CWAAError`, `Get-CWAAProbeError`, `Get-CWAALogLevel`, `Set-CWAALogLevel` | Structured error logs and verbosity control |
| **Proxy** | `Get-CWAAProxy`, `Set-CWAAProxy` | Full proxy support for restricted networks |
| **Scheduled Monitoring** | `Register-CWAAHealthCheckTask`, `Unregister-CWAAHealthCheckTask` | Automated health checks via Windows Task Scheduler |
| **Add/Remove Programs** | `Hide-CWAAAddRemove`, `Show-CWAAAddRemove`, `Rename-CWAAAddRemove` | Control agent visibility in Control Panel |
| **Security & Utilities** | `ConvertFrom-CWAASecurity`, `ConvertTo-CWAASecurity`, `Invoke-CWAACommand` | Agent credential encryption and remote command execution |

30 functions total. Full details in the **[Function Reference](Docs/Help/ConnectWiseAutomateAgent.md)**.

## Install

Install from the [PowerShell Gallery](https://www.powershellgallery.com/packages/ConnectWiseAutomateAgent):

```powershell
Install-Module 'ConnectWiseAutomateAgent'
```

Or for prerelease builds:

```powershell
Install-Module 'ConnectWiseAutomateAgent' -AllowPrerelease
```

> Having issues with the Gallery? Try this [repair script](https://github.com/christaylorcodes/Initialize-PSGallery).

### Single-File Usage

For older machines or environments without PowerShell Gallery access, a standalone `.ps1` file is available. This is a fallback -- prefer `Install-Module` above whenever possible.

```powershell
Invoke-RestMethod 'https://raw.githubusercontent.com/christaylorcodes/ConnectWiseAutomateAgent/main/ConnectWiseAutomateAgent.ps1' | Invoke-Expression
```

> **Note:** This downloads and executes code at runtime. Use `Install-Module` when the Gallery is available.

## Getting Started

After installing, import the module and check the agent status on the local machine:

```powershell
Import-Module ConnectWiseAutomateAgent
Get-CWAAInfo
```

From there, jump straight to the [Examples](Examples/) for ready-to-use scripts, or browse the [Function Reference](Docs/Help/ConnectWiseAutomateAgent.md) for full details on every command.

## Requirements

- **Windows** (all supported versions)
- **PowerShell 3.0+** (2.0 with limitations)
- **Administrator privileges** for most operations

## Backward Compatibility

Every function has a legacy `LT` alias (`Install-CWAA` = `Install-LTService`, etc.) so existing LabTech-era scripts keep working. Run `Get-Alias -Definition *-CWAA*` to see them all.

## Documentation

### Guides

_Hand-written documentation covering architecture and concepts._

| Guide | Description |
| --- | --- |
| [Architecture](Docs/Architecture.md) | Module initialization, installation, health check, proxy, uninstall, and system interaction diagrams |
| [Migration Guide](Docs/Migration.md) | Upgrading from 0.1.4.0 to 1.0.0, function-to-alias mapping, breaking changes |
| [Security Model](Docs/Security.md) | SSL certificate validation, TripleDES encryption, credential redaction, authentication methods |
| [Common Parameters](Docs/CommonParameters.md) | Shared parameters (-Server, -LocationID, -InstallerToken, etc.) with cross-reference tables |
| [Troubleshooting](Docs/Troubleshooting.md) | Symptom-based diagnostic guide with resolution steps |
| [FAQ](Docs/FAQ.md) | Common questions about deployment, configuration, compatibility, and usage |

### Function Reference (Auto-Generated)

_Generated from source code comment-based help via [PlatyPS](https://github.com/PowerShell/platyPS). Regenerate with `Build\Build-Documentation.ps1`._

| Resource | Description |
| --- | --- |
| [Function Reference](Docs/Help/ConnectWiseAutomateAgent.md) | All 30 functions organized by category with descriptions |
| [Individual Function Docs](Docs/Help/) | One file per function -- parameters, examples, and syntax |
| `Get-Help <function>` | In-session help compiled from the same source (MAML XML) |

### Examples

Ready-to-use scripts in the [Examples/](Examples/) directory:

| Script | Purpose |
| --- | --- |
| [AgentInstall.ps1](Examples/AgentInstall.ps1) | Basic agent deployment |
| [AgentInstallWithHealthCheck.ps1](Examples/AgentInstallWithHealthCheck.ps1) | Deploy with automated health monitoring |
| [GPOScheduledTaskDeployment.ps1](Examples/GPOScheduledTaskDeployment.ps1) | Deploy via Group Policy scheduled task |
| [ProxyConfiguration.ps1](Examples/ProxyConfiguration.ps1) | Configure proxy settings for restricted networks |
| [HealthCheck-Monitoring.ps1](Examples/HealthCheck-Monitoring.ps1) | Set up ongoing health check monitoring |
| [Troubleshooting-QuickDiagnostic.ps1](Examples/Troubleshooting-QuickDiagnostic.ps1) | Quick diagnostic script for common issues |
| [PipelineUsage.ps1](Examples/PipelineUsage.ps1) | Pipeline patterns, multi-machine operations, function chaining |

## Project

| | |
| --- | --- |
| [Roadmap](MAP.md) | Where the project has been and where it's going |
| [Changelog](CHANGELOG.md) | Version history and release notes |
| [Contributing](CONTRIBUTING.md) | How to report bugs, suggest features, and submit PRs |

If you use this project, please star and follow the repo -- it helps prioritize development time. Contributions of all kinds are welcome, even if you don't write code. See the [contributing guide](CONTRIBUTING.md) for details.

## For AI Agents

If you're an AI assistant helping a user with this module, start here:

| Resource | What it contains |
| --- | --- |
| [CLAUDE.md](CLAUDE.md) | Architecture, module loading flow, coding conventions, key system paths, security considerations, and testing requirements |
| [Docs/Help/ConnectWiseAutomateAgent.md](Docs/Help/ConnectWiseAutomateAgent.md) | Complete function reference with links to per-function documentation (parameters, examples, syntax) |
| [Docs/Help/](Docs/Help/) | Individual function docs -- one file per function (e.g., `Docs/Help/Install-CWAA.md`) |
| [Examples/](Examples/) | Ready-to-use scripts covering common deployment and troubleshooting scenarios |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Development setup, coding standards, and PR workflow for code changes |

Key things to know: every `CWAA` function has a legacy `LT` alias (e.g., `Install-CWAA` = `Install-LTService`). The module requires Windows + PowerShell 3.0+ + admin privileges. `InstallerToken` is the preferred auth method over `ServerPassword`.

## [Donate](https://github.com/christaylorcodes/GitHub-Template/blob/main/DONATE.md)

This module is free and open source. If it saves you time, consider [buying me a beer](https://paypal.me/ChrisTaylorCodes).
