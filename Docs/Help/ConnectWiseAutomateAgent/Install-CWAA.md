---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Install-CWAA
---

# Install-CWAA

## SYNOPSIS

Installs the ConnectWise Automate Agent on the local computer.

## SYNTAX

### deployment (Default)

```
Install-CWAA [-Server <string[]>] [-ServerPassword <string>] [-Credential <pscredential>]
 [-LocationID <int>] [-TrayPort <int>] [-Rename <string>] [-Hide] [-SkipDotNet] [-Force] [-NoWait]
 [-SkipCertificateCheck] [-ShowProgress] [-WhatIf] [-Confirm]
```

### installertoken

```
Install-CWAA [-Server <string[]>] [-ServerPassword <string>] [-InstallerToken <string>]
 [-LocationID <int>] [-TrayPort <int>] [-Rename <string>] [-Hide] [-SkipDotNet] [-Force] [-NoWait]
 [-SkipCertificateCheck] [-ShowProgress] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Install-LTService

## DESCRIPTION

Downloads and installs the ConnectWise Automate agent from the specified server URL.
Supports authentication via InstallerToken (preferred) or ServerPassword.
The function handles
prerequisite checks for .NET Framework 3.5, MSI download with file integrity validation,
proxy configuration, TrayPort conflict resolution, and post-install agent registration verification.

If a previous installation is detected, the function will automatically call Uninstall-LTService
before proceeding.
The -Force parameter allows installation even when services are already present
or when only .NET 4.0+ is available without 3.5.

## EXAMPLES

### EXAMPLE 1

Install-CWAA -Server https://automate.domain.com -InstallerToken 'GeneratedToken' -LocationID 42
Installs the agent using an InstallerToken for authentication.

### EXAMPLE 2

Install-CWAA -Server https://automate.domain.com -ServerPassword 'encryptedpass' -LocationID 1
Installs the agent using a legacy server password.

### EXAMPLE 3

Install-CWAA -Server https://automate.domain.com -InstallerToken 'token' -LocationID 42 -NoWait
Installs the agent without waiting for registration to complete.

### EXAMPLE 4

Get-CWAAInfoBackup | Install-CWAA -InstallerToken 'GeneratedToken'
Reinstalls the agent using Server and LocationID from a previous backup via pipeline.

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

### -Credential

A PSCredential object containing the server password for deployment authentication.
The password is extracted and used as the ServerPassword.
This is the preferred
secure alternative to passing -ServerPassword as plain text.

```yaml
Type: System.Management.Automation.PSCredential
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
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

### -Force

Disables safety checks including existing service detection and .NET version requirements.

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

Hides the agent entry from Add/Remove Programs after installation by calling Hide-CWAAAddRemove.

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

### -NoWait

Skips the post-install health check that waits for agent registration.
The function exits immediately after the installer completes.

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

### -Rename

Renames the agent entry in Add/Remove Programs after installation by calling Rename-CWAAAddRemove.

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

One or more ConnectWise Automate server URLs to download the installer from.
Example: https://automate.domain.com
The function tries each server in order until a successful download occurs.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
- Name: installertoken
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
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

### -ServerPassword

The server password that agents use to authenticate with the Automate server.
Used for legacy deployment method.
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
  ValueFromPipeline: false
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

### -ShowProgress

Displays a Write-Progress bar showing installation progress.
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

### -SkipDotNet

Skips .NET Framework 3.5 and 2.0 prerequisite checks.
Use when .NET 4.0+ is already installed.

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

### -TrayPort

The local port LTSvc.exe listens on for communication with LTTray processes.
Defaults to 42000.
If the port is in use, the function auto-selects the next available port.

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
Alias: Install-LTService


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
