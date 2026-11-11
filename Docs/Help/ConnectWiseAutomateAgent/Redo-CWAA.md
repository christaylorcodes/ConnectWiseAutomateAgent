---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Redo-CWAA
---

# Redo-CWAA

## SYNOPSIS

Reinstalls the ConnectWise Automate Agent on the local computer.

## SYNTAX

### deployment

```
Redo-CWAA [-Server <string[]>] [-ServerPassword <string>] [-LocationID <int>] [-Backup] [-Hide]
 [-Rename <string>] [-SkipDotNet] [-Force] [-WhatIf] [-Confirm]
```

### installertoken

```
Redo-CWAA [-Server <string[]>] [-ServerPassword <string>] [-InstallerToken <string>]
 [-LocationID <int>] [-Backup] [-Hide] [-Rename <string>] [-SkipDotNet] [-Force] [-WhatIf]
 [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Redo-LTService
- Reinstall-CWAA
- Reinstall-LTService

## DESCRIPTION

Performs a complete reinstall of the ConnectWise Automate Agent by uninstalling and then
reinstalling the agent.
The function attempts to retrieve current settings (server, location,
etc.) from the existing installation or from a backup.
If settings cannot be determined
automatically, the function will prompt for the required parameters.

The reinstall process:
1.
Reads current agent settings from registry or backup
2.
Uninstalls the existing agent via Uninstall-CWAA
3.
Waits 20 seconds for the uninstall to settle
4.
Installs a fresh agent via Install-CWAA with the gathered settings

## EXAMPLES

### EXAMPLE 1

Redo-CWAA
Reinstalls the agent using settings from the current installation registry.

### EXAMPLE 2

Redo-CWAA -Server https://automate.domain.com -InstallerToken 'token' -LocationID 42
Reinstalls the agent with explicitly provided settings.

### EXAMPLE 3

Redo-CWAA -Backup -Force
Backs up settings, then forces reinstallation even if a probe agent is detected.

### EXAMPLE 4

Get-CWAAInfo | Redo-CWAA -InstallerToken 'token'
Reinstalls the agent using Server and LocationID from the current installation via pipeline.

## PARAMETERS

### -Backup

Creates a backup of the current agent installation before uninstalling by calling New-CWAABackup.

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

Forces reinstallation even when a probe agent is detected.

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

### -Hide

Hides the agent entry from Add/Remove Programs after reinstallation.

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

An installer token for authenticated agent deployment.
This is the preferred
authentication method over ServerPassword.
See: https://forums.mspgeek.org/topic/5882-contribution-generate-agent-installertoken

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: installertoken
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -LocationID

The LocationID of the location the agent will be assigned to.
If not provided, reads from the current agent configuration or prompts interactively.

```yaml
Type: System.Int32
DefaultValue: 0
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

### -Rename

Renames the agent entry in Add/Remove Programs after reinstallation.

```yaml
Type: System.String
DefaultValue: ''
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

One or more ConnectWise Automate server URLs.
Example: https://automate.domain.com
If not provided, the function reads the server URL from the current agent configuration
or backup settings.
If neither is available, prompts interactively.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ServerPassword

The server password for agent authentication.
InstallerToken is preferred.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases:
- Password
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
- Name: deployment
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SkipDotNet

Skips .NET Framework 3.5 and 2.0 prerequisite checks during reinstallation.

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

### System.String

{{ Fill in the Description }}

### System.Int32

{{ Fill in the Description }}

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Reinstall-CWAA, Redo-LTService, Reinstall-LTService


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
