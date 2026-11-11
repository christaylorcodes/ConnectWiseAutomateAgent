---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Get-CWAAInfo
---

# Get-CWAAInfo

## SYNOPSIS

Retrieves ConnectWise Automate agent configuration from the registry.

## SYNTAX

### __AllParameterSets

```
Get-CWAAInfo [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Get-LTServiceInfo

## DESCRIPTION

Reads all agent configuration values from the Automate agent service registry key and
returns them as a single object.
Resolves the BasePath from the service image path
if not present in the registry, expands environment variables in BasePath, and parses
the pipe-delimited Server Address into a clean Server array.

This function supports ShouldProcess because many internal callers pass
-WhatIf:$False -Confirm:$False to suppress prompts during automated operations.

## EXAMPLES

### EXAMPLE 1

Get-CWAAInfo
Returns an object containing all agent registry properties including ID, Server,
LocationID, BasePath, and other configuration values.

### EXAMPLE 2

Get-CWAAInfo -WhatIf:$False -Confirm:$False
Retrieves agent info with ShouldProcess suppressed, as used by internal callers.

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

Author: Chris Taylor
Alias: Get-LTServiceInfo


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
