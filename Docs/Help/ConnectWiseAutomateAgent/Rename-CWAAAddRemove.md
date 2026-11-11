---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Rename-CWAAAddRemove
---

# Rename-CWAAAddRemove

## SYNOPSIS

Renames the Automate agent entry in the Add/Remove Programs list.

## SYNTAX

### __AllParameterSets

```
Rename-CWAAAddRemove [-Name] <Object> [[-PublisherName] <string>] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Rename-LTAddRemove

## DESCRIPTION

Changes the DisplayName (and optionally Publisher) registry values for the Automate agent
uninstall keys, which controls how the agent appears in the Windows Add/Remove Programs
(Programs and Features) list.

## EXAMPLES

### EXAMPLE 1

Rename-CWAAAddRemove -Name 'My Remote Agent'
Renames the Automate agent display name to 'My Remote Agent'.

### EXAMPLE 2

Rename-CWAAAddRemove -Name 'My Remote Agent' -PublisherName 'My Company'
Renames both the display name and publisher name in Add/Remove Programs.

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

### -Name

The display name for the Automate agent as shown in the list of installed software.

```yaml
Type: System.Object
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -PublisherName

The publisher name for the Automate agent as shown in the list of installed software.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
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

### System.Object

{{ Fill in the Description }}

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Rename-LTAddRemove


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
