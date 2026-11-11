---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: New-CWAABackup
---

# New-CWAABackup

## SYNOPSIS

Creates a complete backup of the ConnectWise Automate agent installation.

## SYNTAX

### __AllParameterSets

```
New-CWAABackup [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- New-LTServiceBackup

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

New-CWAABackup
Creates a complete backup of the agent installation files and registry settings.

### EXAMPLE 2

New-CWAABackup -WhatIf
Shows what the backup operation would do without actually creating the backup.

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WhatIf

Runs the command in a mode that only reports what would happen without performing the actions.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: New-LTServiceBackup


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
