---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Start-CWAA
---

# Start-CWAA

## SYNOPSIS

Starts the ConnectWise Automate agent services.

## SYNTAX

### __AllParameterSets

```
Start-CWAA [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Start-LTService

## DESCRIPTION

Verifies that the Automate agent services (LTService, LTSvcMon) are present.
Checks
for any process using the LTTray port (default 42000) and kills it.
If a
protected application holds the port, increments the TrayPort (wrapping from
42009 back to 42000).
Sets services to Automatic startup and starts them via
sc.exe.
Waits up to one minute for LTService to reach the Running state, then
issues a Send Status command for immediate check-in.

## EXAMPLES

### EXAMPLE 1

Start-CWAA
Starts the ConnectWise Automate agent services.

### EXAMPLE 2

Start-CWAA -WhatIf
Shows what would happen without actually starting the services.

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
Alias: Start-LTService


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
