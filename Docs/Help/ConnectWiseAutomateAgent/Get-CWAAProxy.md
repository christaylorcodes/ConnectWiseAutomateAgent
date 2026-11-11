---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Get-CWAAProxy
---

# Get-CWAAProxy

## SYNOPSIS

Retrieves the current agent proxy settings for module operations.

## SYNTAX

### __AllParameterSets

```
Get-CWAAProxy
```

## ALIASES

This cmdlet has the following aliases:

- Get-LTProxy

## DESCRIPTION

Reads the current Automate agent proxy settings from the installed agent (if present)
and stores them in the module-scoped $Script:LTProxy object.
The proxy URL,
username, and password are decrypted using the agent's password string.
The
discovered settings are used by all module communication operations for the
duration of the session, and returned as the function result.

## EXAMPLES

### EXAMPLE 1

Get-CWAAProxy
Retrieves and returns the current proxy configuration.

### EXAMPLE 2

$proxy = Get-CWAAProxy
if ($proxy.Enabled) { Write-Host "Proxy: $($proxy.ProxyServerURL)" }
Checks whether a proxy is configured and displays the URL.

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

Author: Darren White
Alias: Get-LTProxy


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
