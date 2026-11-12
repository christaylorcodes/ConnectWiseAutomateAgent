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

The relaunch re-runs the process's own command line, because `$MyInvocation` inside this function describes the `Initialize-CWAA` call and not the caller's script. Two private helpers do the work:

- `Get-CWAARelaunchArgument` takes `[Environment]::CommandLine` and returns the arguments after the executable, unchanged. It returns nothing when the session cannot be reproduced: no `-Command`, `-File` or `-EncodedCommand` among the host switches (an interactive console or a script piped to standard input), `-Command -` or `-File -`, or `-NoExit`. Only switches before the command are inspected, never the command text or script arguments.
- `Invoke-CWAANativeRelaunch` starts the 64-bit `powershell.exe` (through `sysnative`, or `System32` with WOW64 file system redirection switched off for the launch) with those arguments in the directory the process was started in, waits for it, and returns its exit code. It returns nothing if the 64-bit host could not be started.

When an exit code comes back, the 32-bit session exits with it. Otherwise (not re-runnable, the host process is not `powershell.exe`, or the launch failed) the function warns and continues in 32-bit. If the downloaded text was loaded inside another module (for example with `New-Module`), the process is ended with `[Environment]::Exit`, because PowerShell swallows `Exit` while a module loads and the caller's commands would otherwise run a second time in 32-bit.

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
