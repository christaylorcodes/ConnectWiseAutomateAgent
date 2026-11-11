---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Get-CWAAProbeError
---

# Get-CWAAProbeError

## SYNOPSIS

Reads the ConnectWise Automate Agent probe error log into structured objects.

## SYNTAX

### __AllParameterSets

```
Get-CWAAProbeError
```

## ALIASES

This cmdlet has the following aliases:

- Get-LTProbeErrors

## DESCRIPTION

Parses the LTProbeErrors.txt file from the agent install directory into objects with
ServiceVersion, Timestamp, and Message properties.
This enables filtering, sorting,
and pipeline operations on agent probe error log entries.

The log file location is determined from Get-CWAAInfo; if unavailable, falls back
to the default install path at C:\Windows\LTSVC.

## EXAMPLES

### EXAMPLE 1

Get-CWAAProbeError | Where-Object {$_.Timestamp -gt (Get-Date).AddHours(-24)}
Returns all probe errors from the last 24 hours.

### EXAMPLE 2

Get-CWAAProbeError | Out-GridView
Opens the probe error log in a sortable, searchable grid view window.

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
Alias: Get-LTProbeErrors


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
