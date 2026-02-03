---
external help file:
Module Name: ConnectWiseAutomateAgent
online version:
schema: 2.0.0
---

# Initialize-CWAA

## SYNOPSIS
Bootstraps module-level constants, state objects, and the PowerShell version guard.

## SYNTAX

```
Initialize-CWAA [<CommonParameters>]
```

## DESCRIPTION
Initialize-CWAA is the Phase 1 initialization function called once at module import time by ConnectWiseAutomateAgent.psm1. It creates all `$Script:CWAA*` constants (registry paths, file paths, service names, validation patterns), initializes empty state objects for credential storage (`$Script:LTServiceKeys`) and proxy configuration (`$Script:LTProxy`), and sets the deferred networking flags to `$False`.

This function also handles the WOW64 relaunch guard: when running as 32-bit PowerShell on a 64-bit OS, it re-launches the script under the native 64-bit PowerShell host. This is critical because the Automate agent's registry keys and file paths differ between 32-bit and 64-bit views. The relaunch works in direct download mode (`.psm1` via `Invoke-Expression`); in module mode the `.psm1` emits a warning instead.

Phase 2 initialization (networking, SSL, proxy) is handled separately by `Initialize-CWAANetworking`, which runs on-demand at first networking call.

**No network calls, registry reads, or side effects occur during Phase 1.** Module import remains fast and safe.

## EXAMPLES

### Example 1
```powershell
# Called automatically by the module — not typically invoked directly.
# In direct download mode, Initialize-CWAA is called at the end of the compiled .psm1.
Initialize-CWAA
```

Bootstraps all module constants and state. This runs automatically during module import.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

This function takes no input.

## OUTPUTS

This function produces no output. It initializes `$Script:` scoped variables.

## NOTES

- **Private function** — not exported by the module.
- Creates constants: `$Script:CWAARegistryRoot`, `$Script:CWAARegistrySettings`, `$Script:CWAAInstallPath`, `$Script:CWAAInstallerTempPath`, `$Script:CWAAServiceNames`, `$Script:CWAAServerValidationRegex`, and others.
- Creates state objects: `$Script:LTServiceKeys`, `$Script:LTProxy`.
- Sets flags: `$Script:CWAANetworkInitialized`, `$Script:CWAACertCallbackRegistered` to `$False`.
- Also defines the private helper function `Get-CWAARedactedValue` for credential logging.

Author: Chris Taylor

## RELATED LINKS

[Initialize-CWAANetworking](Initialize-CWAANetworking.md)
