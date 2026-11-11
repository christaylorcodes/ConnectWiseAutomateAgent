---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: New-CWAARemoteMonitor
---

# New-CWAARemoteMonitor

## SYNOPSIS

Encodes a PowerShell scriptblock for use in a ConnectWise Automate remote monitor.

## SYNTAX

### __AllParameterSets

```
New-CWAARemoteMonitor [-ScriptBlock] <scriptblock>
```

## ALIASES

This cmdlet has the following aliases:

- New-CWARemoteMonitor

## DESCRIPTION

Converts a PowerShell scriptblock into a Base64-encoded command string suitable for
pasting into an Automate remote monitor's action field.
The output is a fully-formed
command line that launches powershell.exe, decodes, and executes the scriptblock.

The Automate remote monitor action field has an 8191 character limit.
This function
validates the encoded output does not exceed that limit.

## EXAMPLES

### EXAMPLE 1

New-CWAARemoteMonitor -ScriptBlock { Get-Service LTService | Select-Object Status }
Returns the encoded command string ready for the monitor action field.

### EXAMPLE 2

$monitor = New-CWAARemoteMonitor -ScriptBlock { if ((Get-Service LTService).Status -ne 'Running') { exit 1 } }
$monitor | Set-Clipboard
Encodes the scriptblock and copies it to the clipboard.

## PARAMETERS

### -ScriptBlock

The PowerShell scriptblock to encode for remote monitor execution.

```yaml
Type: System.Management.Automation.ScriptBlock
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: New-CWARemoteMonitor


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
