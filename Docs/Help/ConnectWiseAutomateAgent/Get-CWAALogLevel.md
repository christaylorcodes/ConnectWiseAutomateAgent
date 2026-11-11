---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Get-CWAALogLevel
---

# Get-CWAALogLevel

## SYNOPSIS

Retrieves the current logging level for the ConnectWise Automate Agent.

## SYNTAX

### __AllParameterSets

```
Get-CWAALogLevel
```

## ALIASES

This cmdlet has the following aliases:

- Get-LTLogging

## DESCRIPTION

Checks the agent's registry settings to determine the current logging verbosity level.
The ConnectWise Automate Agent supports two logging levels: Normal (value 1) for standard
operations, and Verbose (value 1000) for detailed diagnostic logging.

The logging level is stored in the registry at HKLM:\SOFTWARE\LabTech\Service\Settings
under the "Debuging" value.

## EXAMPLES

### EXAMPLE 1

Get-CWAALogLevel
Returns the current logging level (Normal or Verbose).

### EXAMPLE 2

Get-CWAALogLevel
Set-CWAALogLevel -Level Verbose
Get-CWAALogLevel
Typical troubleshooting workflow: check level, enable verbose, verify the change.

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Get-LTLogging


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
