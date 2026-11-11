---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Unregister-CWAAHealthCheckTask
---

# Unregister-CWAAHealthCheckTask

## SYNOPSIS

Removes the ConnectWise Automate agent health check scheduled task.

## SYNTAX

### __AllParameterSets

```
Unregister-CWAAHealthCheckTask [[-TaskName] <string>] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Unregister-LTHealthCheckTask

## DESCRIPTION

Deletes the Windows scheduled task created by Register-CWAAHealthCheckTask.
If the task does not exist, writes a warning and returns gracefully.

## EXAMPLES

### EXAMPLE 1

Unregister-CWAAHealthCheckTask
Removes the default CWAAHealthCheck scheduled task.

### EXAMPLE 2

Unregister-CWAAHealthCheckTask -TaskName 'MyHealthCheck'
Removes a custom-named health check task.

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

### -TaskName

Name of the scheduled task to remove.
Default: 'AAutomate'.

```yaml
Type: System.String
DefaultValue: AAutomate
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
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
Alias: Unregister-LTHealthCheckTask


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
