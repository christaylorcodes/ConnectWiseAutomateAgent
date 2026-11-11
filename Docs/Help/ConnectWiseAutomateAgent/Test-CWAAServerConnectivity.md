---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Test-CWAAServerConnectivity
---

# Test-CWAAServerConnectivity

## SYNOPSIS

Tests connectivity to a ConnectWise Automate server's agent endpoint.

## SYNTAX

### __AllParameterSets

```
Test-CWAAServerConnectivity [[-Server] <string[]>] [-Quiet]
```

## ALIASES

This cmdlet has the following aliases:

- Test-LTServerConnectivity

## DESCRIPTION

Verifies that an Automate server is online and responding by querying the
agent.aspx endpoint.
Validates that the response matches the expected version
format (pipe-delimited string ending with a version number).

If no server is provided, the function attempts to discover it from the
installed agent configuration or backup settings.

Returns a result object per server with availability status and version info,
or a simple boolean in Quiet mode.

## EXAMPLES

### EXAMPLE 1

Test-CWAAServerConnectivity -Server 'https://automate.domain.com'
Tests connectivity and returns a result object with Server, Available, Version, and ErrorMessage.

### EXAMPLE 2

Test-CWAAServerConnectivity -Quiet
Returns $True if the discovered server is reachable, $False otherwise.

### EXAMPLE 3

Get-CWAAInfo | Test-CWAAServerConnectivity
Tests connectivity to the server configured on the installed agent via pipeline.

## PARAMETERS

### -Quiet

Returns $True if all servers are reachable, $False otherwise.

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
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Server

One or more ConnectWise Automate server URLs (e.g., https://automate.domain.com).
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]

{{ Fill in the Description }}

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Test-LTServerConnectivity


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
