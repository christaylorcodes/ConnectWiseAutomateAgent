---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Register-CWAAHealthCheckTask
---

# Register-CWAAHealthCheckTask

## SYNOPSIS

Creates or updates a scheduled task for periodic ConnectWise Automate agent health checks.

## SYNTAX

### __AllParameterSets

```
Register-CWAAHealthCheckTask [-InstallerToken] <string> [[-Server] <string[]>] [[-LocationID] <int>]
 [[-TaskName] <string>] [[-IntervalHours] <int>] [-Force] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Register-LTHealthCheckTask

## DESCRIPTION

Creates a Windows scheduled task that runs Repair-CWAA at a configurable interval
(default every 6 hours) to monitor agent health and automatically remediate issues.

The task runs as SYSTEM with highest privileges, includes a random delay equal to the
interval to stagger execution across multiple machines, and has a 1-hour execution timeout.

If the task already exists and its configuration (InstallerToken, Server, LocationID, or
IntervalHours) has changed, the task is recreated to match.
Use -Force to recreate
unconditionally.

A backup of the current agent configuration is created before task registration
via New-CWAABackup.

## EXAMPLES

### EXAMPLE 1

Register-CWAAHealthCheckTask -InstallerToken 'abc123def456'
Creates a task that runs Repair-CWAA in Checkup mode every 6 hours.

### EXAMPLE 2

Register-CWAAHealthCheckTask -InstallerToken 'token' -Server 'https://automate.domain.com' -LocationID 42
Creates a task that runs Repair-CWAA in Install mode (can install fresh if agent is missing).

### EXAMPLE 3

Register-CWAAHealthCheckTask -InstallerToken 'token' -IntervalHours 12 -TaskName 'MyHealthCheck'
Creates a custom-named task running every 12 hours.

### EXAMPLE 4

Get-CWAAInfo | Register-CWAAHealthCheckTask -InstallerToken 'token'
Uses Server and LocationID from the installed agent via pipeline to register a health check task.

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

### -Force

Force recreation of the task even if it already exists with a matching configuration.

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

### -InstallerToken

The installer token for authenticated agent deployment.
Embedded in the scheduled
task action for use by Repair-CWAA.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -IntervalHours

Hours between health check runs.
Default: 6.

```yaml
Type: System.Int32
DefaultValue: 6
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 4
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -LocationID

Optional location ID.
Required when Server is provided.

```yaml
Type: System.Int32
DefaultValue: 0
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Server

Optional server URL.
When provided, the scheduled task passes this to Repair-CWAA
in Install mode (with Server, LocationID, and InstallerToken).

```yaml
Type: System.String[]
DefaultValue: ''
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

### -TaskName

Name of the scheduled task.
Default: 'AAutomate'.

```yaml
Type: System.String
DefaultValue: AAutomate
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
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

{{ Fill in the Description }}

### System.Int32

{{ Fill in the Description }}

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Register-LTHealthCheckTask


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
