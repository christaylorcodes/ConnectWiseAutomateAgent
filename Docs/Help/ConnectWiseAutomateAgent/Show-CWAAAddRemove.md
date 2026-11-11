---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Show-CWAAAddRemove
---

# Show-CWAAAddRemove

## SYNOPSIS

Shows the Automate agent in the Add/Remove Programs list.

## SYNTAX

### __AllParameterSets

```
Show-CWAAAddRemove [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Show-LTAddRemove

## DESCRIPTION

Sets the SystemComponent registry value to 0 on Automate agent uninstall keys,
which makes the agent visible in the Windows Add/Remove Programs (Programs and Features) list.
Also cleans up any leftover HiddenProductName registry values from older hiding methods.

## EXAMPLES

### EXAMPLE 1

Show-CWAAAddRemove
Makes the Automate agent entry visible in Add/Remove Programs.

### EXAMPLE 2

Show-CWAAAddRemove -WhatIf
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
Alias: Show-LTAddRemove


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
