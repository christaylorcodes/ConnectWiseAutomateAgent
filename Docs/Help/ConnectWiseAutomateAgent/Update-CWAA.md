---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Update-CWAA
---

# Update-CWAA

## SYNOPSIS

Manually updates the ConnectWise Automate Agent to a specified version.

## SYNTAX

### __AllParameterSets

```
Update-CWAA [[-Version] <string>] [-SkipCertificateCheck] [-ShowProgress] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Update-LTService

## DESCRIPTION

Downloads and applies an agent update from the ConnectWise Automate server.
The function
reads the current server configuration from the agent's registry settings, downloads the
appropriate update package, extracts it, and runs the updater.

If no version is specified, the function uses the version advertised by the server.
The function validates that the requested version is higher than the currently installed
version and not higher than the server version before proceeding.

The update process:
1.
Reads current agent settings and server information
2.
Downloads the LabtechUpdate.exe for the target version
3.
Stops agent services
4.
Extracts and runs the update
5.
Restarts agent services

## EXAMPLES

### EXAMPLE 1

Update-CWAA -Version 120.240
Updates the agent to the specific version requested.

### EXAMPLE 2

Update-CWAA
Updates the agent to the current version advertised by the server.

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

### -ShowProgress

Displays a Write-Progress bar showing update progress.
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

### -Version

The target agent version to update to.
Example: 120.240
If omitted, the version advertised by the server will be used.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
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

Author: Darren White
Alias: Update-LTService


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
