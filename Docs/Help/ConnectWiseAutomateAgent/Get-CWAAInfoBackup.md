---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Get-CWAAInfoBackup
---

# Get-CWAAInfoBackup

## SYNOPSIS

Retrieves backed-up ConnectWise Automate agent configuration from the registry.

## SYNTAX

### __AllParameterSets

```
Get-CWAAInfoBackup
```

## ALIASES

This cmdlet has the following aliases:

- Get-LTServiceInfoBackup

## DESCRIPTION

Reads all agent configuration values from the LabTechBackup registry key
and returns them as a single object.
This backup is created by New-CWAABackup and
stores a snapshot of the agent configuration at the time of backup.

Expands environment variables in BasePath and parses the pipe-delimited Server
Address into a clean Server array, matching the behavior of Get-CWAAInfo.

## EXAMPLES

### EXAMPLE 1

Get-CWAAInfoBackup
Returns an object containing all backed-up agent registry properties.

### EXAMPLE 2

Get-CWAAInfoBackup | Select-Object -ExpandProperty Server
Returns only the server addresses from the backup configuration.

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
Alias: Get-LTServiceInfoBackup


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
