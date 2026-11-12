---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Invoke-CWAACommand
---

# Invoke-CWAACommand

## SYNOPSIS

Sends a service command to the ConnectWise Automate agent.

## SYNTAX

### __AllParameterSets

```
Invoke-CWAACommand [-Command] <string[]> [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Invoke-LTServiceCommand

## DESCRIPTION

Sends a control command to the LTService Windows service using sc.exe.
The agent supports a set of predefined commands (mapped to numeric IDs 128-145)
that trigger actions such as sending inventory, updating schedules, or killing processes.

## EXAMPLES

### EXAMPLE 1

Invoke-CWAACommand -Command 'Send Inventory'
Sends the 'Send Inventory' command to the agent service.

### EXAMPLE 2

'Send Status', 'Send Apps' | Invoke-CWAACommand
Sends multiple commands to the agent service via pipeline.

## PARAMETERS

### -Command

One or more commands to send to the agent service.
Valid values include
'Update Schedule', 'Send Inventory', 'Send Drives', 'Send Processes',
'Send Spyware List', 'Send Apps', 'Send Events', 'Send Printers',
'Send Status', 'Send Screen', 'Send Services', 'Analyze Network',
'Write Last Contact Date', 'Kill VNC', 'Kill Trays', 'Send Patch Reboot',
'Run App Care Update', and 'Start App Care Daytime Patching'.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

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

### System.String[]

You can pipe a value to `-Command`.

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Invoke-LTServiceCommand


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
