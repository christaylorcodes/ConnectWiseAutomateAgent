---
external help file:
Module Name: ConnectWiseAutomateAgent
online version:
schema: 2.0.0
---

# Clear-CWAAInstallerArtifacts

## SYNOPSIS
Cleans up stale ConnectWise Automate installer processes and temporary files.

## SYNTAX

```
Clear-CWAAInstallerArtifacts [<CommonParameters>]
```

## DESCRIPTION
Clear-CWAAInstallerArtifacts is a private helper that terminates any running installer-related processes and removes temporary installer files left behind by incomplete or failed installations. This prevents conflicts when starting a new install, reinstall, or update operation.

Process names are read from `$Script:CWAAInstallerProcessNames` (includes `Agent_Uninstall`, `Uninstall`, `LTUpdate`). File paths are read from `$Script:CWAAInstallerArtifactPaths` (includes temp MSI files, executables, and extracted archives in the installer temp directory).

All operations are best-effort with errors suppressed. This function is intended as a defensive cleanup step, not a validated operation. If a process cannot be stopped or a file cannot be removed, the function continues silently.

Called by `Install-CWAA` and `Redo-CWAA` before beginning a new installation to ensure a clean starting state.

## EXAMPLES

### Example 1
```powershell
# Called internally before starting a new installation.
Clear-CWAAInstallerArtifacts
```

Kills any stale installer processes and removes leftover temporary files from prior installation attempts.

## PARAMETERS

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

This function takes no input.

## OUTPUTS

This function produces no output. It terminates processes and removes files as a side effect.

## NOTES

- **Private function** — not exported by the module.
- Uses centralized constants: `$Script:CWAAInstallerProcessNames`, `$Script:CWAAInstallerArtifactPaths`.
- All errors are suppressed (`-ErrorAction SilentlyContinue`) — this function never disrupts the caller.
- Process termination uses `Stop-Process -Force` to handle unresponsive installer processes.

Author: Chris Taylor

## RELATED LINKS

[Install-CWAA](../Install-CWAA.md)

[Redo-CWAA](../Redo-CWAA.md)
