---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Hide-CWAAAddRemove
---

# Hide-CWAAAddRemove

## SYNOPSIS

Hides the Automate agent from the Add/Remove Programs list.

## SYNTAX

### __AllParameterSets

```
Hide-CWAAAddRemove [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Hide-LTAddRemove

## DESCRIPTION

Sets the SystemComponent registry value to 1 on Automate agent uninstall keys,
which hides the agent from the Windows Add/Remove Programs (Programs and Features) list.
Also cleans up any leftover HiddenProductName registry values from older hiding methods.

## EXAMPLES

### EXAMPLE 1

Hide-CWAAAddRemove
Hides the Automate agent entry from Add/Remove Programs.

### EXAMPLE 2

Hide-CWAAAddRemove -WhatIf
Shows what registry changes would be made without applying them.

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
Alias: Hide-LTAddRemove


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
