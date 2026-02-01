---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# New-CWAABackup

## SYNOPSIS
Creates a complete backup of the ConnectWise Automate agent installation.

## SYNTAX

```
New-CWAABackup [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Creates a comprehensive backup of the currently installed ConnectWise Automate agent
by copying all files from the agent installation directory and exporting all related
registry keys.
This backup can be used to restore the agent configuration if needed,
or to preserve settings before performing maintenance operations.

The backup process performs the following operations:
1.
Locates the agent installation directory (typically C:\Windows\LTSVC)
2.
Creates a Backup subdirectory within the agent installation path
3.
Copies all files from the installation directory to the Backup folder
4.
Exports registry keys from HKLM\SOFTWARE\LabTech to a .reg file
5.
Modifies the exported registry data to use the LabTechBackup key name
6.
Imports the modified registry data to HKLM\SOFTWARE\LabTechBackup

## EXAMPLES

### EXAMPLE 1
```
New-CWAABackup
```

Creates a complete backup of the agent installation files and registry settings.

### EXAMPLE 2
```
New-CWAABackup -WhatIf
```

Shows what the backup operation would do without actually creating the backup.

## PARAMETERS

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Chris Taylor
Alias: New-LTServiceBackup

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

