---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Test-CWAAPort
---

# Test-CWAAPort

## SYNOPSIS

Tests connectivity to TCP ports required by the ConnectWise Automate agent.

## SYNTAX

### __AllParameterSets

```
Test-CWAAPort [[-Server] <string[]>] [[-TrayPort] <int>] [-Quiet]
```

## ALIASES

This cmdlet has the following aliases:

- Test-LTPorts

## DESCRIPTION

Verifies that the local LTTray port is available and tests connectivity to
the required TCP ports (70, 80, 443) on the Automate server, plus port 8002
on the Automate mediator server.
If no server is provided, the function attempts to detect it from the installed
agent configuration or backup info.

## EXAMPLES

### EXAMPLE 1

Test-CWAAPort -Server 'https://automate.domain.com'
Tests all required ports against the specified server.

### EXAMPLE 2

Test-CWAAPort -Quiet
Returns $True if the TrayPort is available, $False otherwise.

### EXAMPLE 3

Get-CWAAInfo | Test-CWAAPort
Pipes the installed agent's Server and TrayPort into Test-CWAAPort via pipeline.

## PARAMETERS

### -Quiet

Returns a boolean connectivity result instead of verbose output.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Server

The URL of the Automate server (e.g., https://automate.domain.com).
If not provided, the function uses Get-CWAAInfo or Get-CWAAInfoBackup to discover it.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TrayPort

The local port LTSvc.exe listens on for LTTray communication.
Defaults to 42000 if not provided or not found in agent configuration.

```yaml
Type: System.Int32
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
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

{{ Fill in the Description }}

### System.Int32

{{ Fill in the Description }}

### System.Management.Automation.SwitchParameter

{{ Fill in the Description }}

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Test-LTPorts


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
