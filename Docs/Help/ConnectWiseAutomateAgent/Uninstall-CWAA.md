---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Uninstall-CWAA
---

# Uninstall-CWAA

## SYNOPSIS

Completely uninstalls the ConnectWise Automate Agent from the local computer.

## SYNTAX

### __AllParameterSets

```
Uninstall-CWAA [[-Server] <string[]>] [-Backup] [-Force] [-SkipCertificateCheck] [-ShowProgress]
 [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Uninstall-LTService

## DESCRIPTION

Performs a comprehensive removal of the ConnectWise Automate Agent from a Windows computer.
This function is more thorough than a standard MSI uninstall, as it also removes residual
files, registry keys, and services that may not be cleaned up by the normal uninstall process.

The uninstall process performs the following operations:
1.
Downloads official uninstaller files (Agent_Uninstall.msi and Agent_Uninstall.exe) from the server
2.
Optionally creates a backup of the current agent installation (if -Backup is specified)
3.
Stops all running agent services (LTService, LTSvcMon, LabVNC)
4.
Terminates any running agent processes
5.
Unregisters the wodVPN.dll component
6.
Runs the MSI uninstaller (Agent_Uninstall.msi)
7.
Runs the agent uninstaller executable (Agent_Uninstall.exe)
8.
Removes agent Windows services
9.
Removes all agent files from the installation directory
10.
Removes all agent-related registry keys (over 30 different registry locations)
11.
Verifies the uninstall was successful

Probe Agent Protection: By default, this function will refuse to uninstall probe agents to
prevent accidental removal of critical infrastructure.
Use -Force to override this protection.

## EXAMPLES

### EXAMPLE 1

Uninstall-CWAA
Uninstalls the agent using the server URL from the agent's registry settings.

### EXAMPLE 2

Uninstall-CWAA -Backup
Creates a backup of the agent installation before uninstalling.

### EXAMPLE 3

Uninstall-CWAA -Server "https://automate.company.com"
Uninstalls using the specified server URL to download uninstaller files.

### EXAMPLE 4

Uninstall-CWAA -Server "https://primary.company.com","https://backup.company.com"
Provides multiple server URLs with fallback. Tries each until uninstaller files download successfully.

### EXAMPLE 5

Uninstall-CWAA -Force
Forces uninstallation even if a probe agent is detected.

### EXAMPLE 6

Uninstall-CWAA -WhatIf
Simulates the uninstall process without making any actual changes.

### EXAMPLE 7

Get-CWAAInfo | Uninstall-CWAA
Pipes the installed agent's Server property into Uninstall-CWAA via pipeline.

## PARAMETERS

### -Backup

Creates a complete backup of the agent installation before uninstalling by calling New-CWAABackup.

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

Forces uninstallation even when a probe agent is detected.
Use with extreme caution,
as probe agents are typically critical infrastructure components.

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

One or more ConnectWise Automate server URLs to download uninstaller files from.
If not specified, reads the server URL from the agent's current registry configuration.
If that fails, prompts interactively for a server URL.
Example: https://automate.domain.com

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

### -ShowProgress

Displays a Write-Progress bar showing uninstall progress.
Off by default
to avoid interference with unattended execution (RMM tools, GPO scripts).

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

### -SkipCertificateCheck

Bypasses SSL/TLS certificate validation for server connections.
Use in lab or test environments with self-signed certificates.

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

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Uninstall-LTService
Requires: Administrator privileges


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
