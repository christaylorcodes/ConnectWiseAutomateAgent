---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Repair-CWAA
---

# Repair-CWAA

## SYNOPSIS

Performs escalating remediation of the ConnectWise Automate agent.

## SYNTAX

### Install

```
Repair-CWAA -Server <string> -LocationID <int> -InstallerToken <string> [-HoursRestart <int>]
 [-HoursReinstall <int>] [-WhatIf] [-Confirm]
```

### Checkup

```
Repair-CWAA -InstallerToken <string> [-HoursRestart <int>] [-HoursReinstall <int>] [-WhatIf]
 [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Repair-LTService

## DESCRIPTION

Checks the health of the installed Automate agent and takes corrective action
using an escalating strategy:

1.
If the agent is installed and healthy � no action taken.
2.
If the agent is installed but has not checked in within HoursRestart � restarts
   services and waits up to 2 minutes for the agent to recover.
3.
If the agent is still not checking in after HoursReinstall � reinstalls the agent
   using Redo-CWAA.
4.
If the agent configuration is unreadable � uninstalls and reinstalls.
5.
If the installed agent points to the wrong server � reinstalls with the correct server.
6.
If the agent is not installed � performs a fresh install from provided parameters
   or from backup settings.

All remediation actions are logged to the Windows Event Log (Application log,
source ConnectWiseAutomateAgent) for visibility in unattended scheduled task runs.

Designed to be called periodically via Register-CWAAHealthCheckTask or any
external scheduler.

## EXAMPLES

### EXAMPLE 1

Repair-CWAA -InstallerToken 'abc123def456'
Checks the installed agent and repairs if needed (Checkup mode).

### EXAMPLE 2

Repair-CWAA -Server 'https://automate.domain.com' -LocationID 42 -InstallerToken 'token'
Checks agent health. If the agent is missing or pointed at the wrong server,
installs or reinstalls with the specified settings.

### EXAMPLE 3

Repair-CWAA -InstallerToken 'token' -HoursRestart -4 -HoursReinstall -240
Uses custom thresholds: restart after 4 hours offline, reinstall after 10 days.

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

### -HoursReinstall

Hours since last check-in before a full reinstall is attempted.
Expressed as a
negative number (e.g., -120 means 120 hours / 5 days ago).
Default: -120.

```yaml
Type: System.Int32
DefaultValue: -120
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

### -HoursRestart

Hours since last check-in before a service restart is attempted.
Expressed as a
negative number (e.g., -2 means 2 hours ago).
Default: -2.

```yaml
Type: System.Int32
DefaultValue: -2
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

### -InstallerToken

An installer token for authenticated agent deployment.
Required for both parameter sets.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Checkup
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
- Name: Install
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -LocationID

The LocationID for fresh agent installs.
Required with the Install parameter set.

```yaml
Type: System.Int32
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Install
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Server

The ConnectWise Automate server URL for fresh installs or server mismatch correction.
Required when using the Install parameter set.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: Install
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
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

### System.String

{{ Fill in the Description }}

### System.Int32

{{ Fill in the Description }}

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Repair-LTService


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
