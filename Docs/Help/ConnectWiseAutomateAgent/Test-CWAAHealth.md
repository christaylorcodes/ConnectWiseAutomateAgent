---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Test-CWAAHealth
---

# Test-CWAAHealth

## SYNOPSIS

Performs a read-only health assessment of the ConnectWise Automate agent.

## SYNTAX

### __AllParameterSets

```
Test-CWAAHealth [[-Server] <string[]>] [-TestServerConnectivity]
```

## ALIASES

This cmdlet has the following aliases:

- Test-LTHealth

## DESCRIPTION

Checks the overall health of the installed Automate agent without taking any
remediation action.
Returns a status object with details about the agent's
installation state, service status, last check-in times, and server connectivity.

This function never modifies the agent, services, or registry.
It is safe to call
at any time for monitoring or diagnostic purposes.

Health assessment criteria:
- Agent is installed (LTService exists)
- Services are running (LTService and LTSvcMon)
- Agent has checked in recently (LastSuccessStatus or HeartbeatLastSent within threshold)
- Server is reachable (optional, tested when Server param is provided or auto-discovered)

The Healthy property is True only when the agent is installed, services are running,
and LastContact is not null.

## EXAMPLES

### EXAMPLE 1

Test-CWAAHealth
Returns a health status object for the installed agent.

### EXAMPLE 2

Test-CWAAHealth -Server 'https://automate.domain.com' -TestServerConnectivity
Checks agent health, validates the server address matches, and tests server connectivity.

### EXAMPLE 3

if ((Test-CWAAHealth).Healthy) { Write-Output 'Agent is healthy' }
Uses the Healthy boolean for conditional logic.

### EXAMPLE 4

Get-CWAAInfo | Test-CWAAHealth
Pipes the installed agent's Server property into Test-CWAAHealth via pipeline.

## PARAMETERS

### -Server

An Automate server URL to validate against the installed agent's configured server.
If provided, the ServerMatch property indicates whether the installed agent points
to this server.
If omitted, ServerMatch is null.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -TestServerConnectivity

When specified, tests whether the agent's server is reachable via the agent.aspx
endpoint.
Adds a brief network call.
The ServerReachable property is null when
this switch is not used.

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
Alias: Test-LTHealth


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
