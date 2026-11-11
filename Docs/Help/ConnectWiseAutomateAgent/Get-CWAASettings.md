---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Get-CWAASettings
---

# Get-CWAASettings

## SYNOPSIS

Retrieves ConnectWise Automate agent settings from the registry.

## SYNTAX

### __AllParameterSets

```
Get-CWAASettings
```

## ALIASES

This cmdlet has the following aliases:

- Get-LTServiceSettings

## DESCRIPTION

Reads agent settings from the Automate agent service Settings registry subkey
(HKLM:\SOFTWARE\LabTech\Service\Settings) and returns them as an object.
These settings are separate from the main agent configuration returned by
Get-CWAAInfo and include proxy configuration (ProxyServerURL, ProxyUsername,
ProxyPassword), logging level, and other operational parameters written by
the agent or Set-CWAAProxy.

## EXAMPLES

### EXAMPLE 1

Get-CWAASettings
Returns an object containing all agent settings registry properties.

### EXAMPLE 2

(Get-CWAASettings).ProxyServerURL
Returns just the configured proxy URL, if any.

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
Alias: Get-LTServiceSettings


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
