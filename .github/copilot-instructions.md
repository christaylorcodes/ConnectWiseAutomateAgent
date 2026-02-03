# Copilot Instructions

This is a PowerShell 3.0+ module for managing the ConnectWise Automate Windows agent. For full conventions, architecture, build commands, and contribution workflow, read [AGENTS.md](../AGENTS.md).

Key file locations: `source/Public/` (exported), `source/Private/` (internal), `Tests/`, `.build/`.

Before committing: run `./Scripts/Invoke-QuickTest.ps1 -IncludeAnalyzer -OutputFormat Structured` and verify `success` is `true`. Before pushing: `./Tests/test-local.ps1`. See AGENTS.md for full workflow.
