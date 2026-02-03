---
external help file:
Module Name: ConnectWiseAutomateAgent
online version:
schema: 2.0.0
---

# Test-CWAADownloadIntegrity

## SYNOPSIS
Validates a downloaded file meets minimum size requirements.

## SYNTAX

```
Test-CWAADownloadIntegrity -FilePath <String> [-FileName <String>] [-MinimumSizeKB <Int32>] [<CommonParameters>]
```

## DESCRIPTION
Test-CWAADownloadIntegrity is a private helper that checks whether a downloaded installer file exists and exceeds a specified minimum size threshold. If the file is missing or below the threshold, it is treated as corrupt or incomplete: a warning is emitted and any undersized file is removed.

The default threshold of 1234 KB matches the established convention for MSI/EXE installer files. The `Agent_Uninstall.exe` uses a lower threshold of 80 KB due to its smaller expected size.

This function is used by `Install-CWAA` and `Uninstall-CWAA` after downloading installer files to verify the download completed successfully before proceeding with execution.

## EXAMPLES

### Example 1
```powershell
# Called internally after downloading the MSI installer.
$isValid = Test-CWAADownloadIntegrity -FilePath "$env:windir\Temp\LabTech\Agent_Install.msi"
if (-not $isValid) { return }
```

Checks that the MSI file exists and is larger than 1234 KB (default threshold).

### Example 2
```powershell
# Called with a lower threshold for the smaller uninstall executable.
Test-CWAADownloadIntegrity -FilePath "$env:windir\Temp\LabTech\Agent_Uninstall.exe" -MinimumSizeKB 80
```

Checks that the uninstall executable exists and is larger than 80 KB.

## PARAMETERS

### -FilePath
The full path to the downloaded file to validate.

```yaml
Type: String
Required: True
Position: Named
Default value: None
```

### -FileName
A display name for the file used in warning and debug messages. If not provided, it is automatically extracted from the `-FilePath` using `Split-Path -Leaf`.

```yaml
Type: String
Required: False
Position: Named
Default value: (extracted from FilePath)
```

### -MinimumSizeKB
The minimum acceptable file size in kilobytes. Files at or below this threshold are treated as corrupt and removed.

```yaml
Type: Int32
Required: False
Position: Named
Default value: 1234
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

This function does not accept pipeline input.

## OUTPUTS

### Boolean
Returns `$true` if the file exists and exceeds the minimum size threshold. Returns `$false` if the file is missing or undersized (the undersized file is removed automatically).

## NOTES

- **Private function** — not exported by the module.
- Undersized files are removed automatically to prevent execution of corrupt installers.
- Default threshold (1234 KB) matches established MSI installer conventions.
- The 80 KB threshold for `Agent_Uninstall.exe` is passed explicitly by callers.

Author: Chris Taylor

## RELATED LINKS

[Install-CWAA](../Install-CWAA.md)

[Uninstall-CWAA](../Uninstall-CWAA.md)
