# Copilot Instructions

This is a PowerShell module for managing the ConnectWise Automate Windows agent. Code that installs an agent must run on PowerShell 2.0 (Windows 7 / Server 2008 R2 as shipped); code that only runs once an agent is installed can assume 5.1 or later (see "PowerShell Version Tiers" in AGENTS.md). For full conventions, architecture, build commands, and contribution workflow, read [AGENTS.md](../AGENTS.md).

Key file locations: `source/Public/` (exported), `source/Private/` (internal), `Tests/`, `.build/`.

Before committing: run `./Scripts/Invoke-QuickTest.ps1 -IncludeAnalyzer -OutputFormat Structured` and verify `success` is `true`. Before pushing: `./Tests/test-local.ps1`. See AGENTS.md for full workflow.
