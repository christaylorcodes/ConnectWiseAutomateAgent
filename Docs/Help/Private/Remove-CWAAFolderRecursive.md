---
external help file:
Module Name: ConnectWiseAutomateAgent
online version:
schema: 2.0.0
---

# Remove-CWAAFolderRecursive

## SYNOPSIS
Performs depth-first removal of a folder and all its contents.

## SYNTAX

```
Remove-CWAAFolderRecursive -Path <String> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Remove-CWAAFolderRecursive is a private helper that removes a folder using a three-pass depth-first strategy:

1. **Pass 1:** Remove files inside each subfolder (leaves first)
2. **Pass 2:** Remove subfolders sorted by path depth (deepest first)
3. **Pass 3:** Remove the root folder itself

This approach maximizes cleanup even when some files or folders are locked by running processes, which is common during agent uninstall and update operations. Standard `Remove-Item -Recurse` can fail entirely if any single file is locked; this strategy removes everything it can and leaves only the genuinely locked items.

All removal operations use best-effort error handling (`-ErrorAction SilentlyContinue`). The caller's `$WhatIfPreference` and `$ConfirmPreference` propagate automatically through PowerShell's preference variable mechanism.

Used by `Uninstall-CWAA` to remove the agent installation directory (`C:\Windows\LTSVC`) and installer temp directory (`C:\Windows\Temp\LabTech`).

## EXAMPLES

### Example 1
```powershell
# Called internally by Uninstall-CWAA after stopping agent services.
Remove-CWAAFolderRecursive -Path "$env:windir\LTSVC"
```

Removes the agent installation directory using the three-pass depth-first strategy.

## PARAMETERS

### -Path
The full path to the folder to remove. If the path does not exist, the function returns silently.

```yaml
Type: String
Required: True
Position: Named
Default value: None
```

### -WhatIf
Shows what would happen if the cmdlet runs. The cmdlet is not run.

### -Confirm
Prompts you for confirmation before running the cmdlet.

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

This function does not accept pipeline input.

## OUTPUTS

This function produces no output. It removes the specified folder and its contents.

## NOTES

- **Private function** — not exported by the module.
- Supports `ShouldProcess` (`-WhatIf` / `-Confirm`) for the top-level removal decision; individual file/folder deletions within are not individually confirmed.
- If the path does not exist, the function returns silently with a debug message.
- Locked files are skipped silently — partial cleanup is preferred over total failure.

Author: Chris Taylor

## RELATED LINKS

[Uninstall-CWAA](../Uninstall-CWAA.md)
