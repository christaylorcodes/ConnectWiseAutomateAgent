---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Stop-CWAA
---

# Stop-CWAA

## SYNOPSIS

Stops the ConnectWise Automate agent services.

## SYNTAX

### __AllParameterSets

```
Stop-CWAA [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Stop-LTService

## DESCRIPTION

Verifies that the Automate agent services (LTService, LTSvcMon) are present, then
attempts to stop them gracefully via sc.exe.
Waits up to one minute for the
services to reach a Stopped state.
If they do not stop in time, remaining
Automate agent processes (LTTray, LTSVC, LTSvcMon) are forcefully terminated.

## EXAMPLES

### EXAMPLE 1

Stop-CWAA
Stops the ConnectWise Automate agent services.

### EXAMPLE 2

Stop-CWAA -WhatIf
Shows what would happen without actually stopping the services.

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
Alias: Stop-LTService


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
