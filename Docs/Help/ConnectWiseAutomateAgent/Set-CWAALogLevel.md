---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Set-CWAALogLevel
---

# Set-CWAALogLevel

## SYNOPSIS

Sets the logging level for the ConnectWise Automate Agent.

## SYNTAX

### __AllParameterSets

```
Set-CWAALogLevel [[-Level] <Object>] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Set-LTLogging

## DESCRIPTION

Configures the agent's logging verbosity by updating the registry and restarting the
agent services.
Supports Normal (standard) and Verbose (detailed diagnostic) levels.

The function stops the agent service, writes the new logging level to the registry at
HKLM:\SOFTWARE\LabTech\Service\Settings under the "Debuging" value, then restarts the
agent service.
After applying the change, it outputs the current logging level.

## EXAMPLES

### EXAMPLE 1

Set-CWAALogLevel -Level Verbose
Enables verbose diagnostic logging on the agent.

### EXAMPLE 2

Set-CWAALogLevel -Level Normal
Returns the agent to standard logging.

### EXAMPLE 3

Set-CWAALogLevel -Level Verbose -WhatIf
Shows what changes would be made without applying them.

### EXAMPLE 4

'Verbose' | Set-CWAALogLevel
Sets the log level to Verbose via pipeline input.

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

### -Level

The desired logging level.
Valid values are 'Normal' (default) and 'Verbose'.
Normal sets registry value 1; Verbose sets registry value 1000.

```yaml
Type: System.Object
DefaultValue: Normal
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: true
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

### System.Object

You can pipe a value to `-Level`.

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Set-LTLogging


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
