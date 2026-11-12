---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: ConvertTo-CWAASecurity
---

# ConvertTo-CWAASecurity

## SYNOPSIS

Encodes a string using TripleDES encryption compatible with Automate operations.

## SYNTAX

### __AllParameterSets

```
ConvertTo-CWAASecurity [-InputString] <string> [[-Key] <Object>]
```

## ALIASES

This cmdlet has the following aliases:

- ConvertTo-LTSecurity

## DESCRIPTION

This function encodes the provided string using the specified or default key.
It uses TripleDES with an MD5-derived key and a fixed initialization vector,
returning a Base64-encoded result.

## EXAMPLES

### EXAMPLE 1

ConvertTo-CWAASecurity -InputString 'PlainTextValue'
Encodes the string using the default key.

### EXAMPLE 2

ConvertTo-CWAASecurity -InputString 'PlainTextValue' -Key 'MyCustomKey'
Encodes the string using a custom key.

## PARAMETERS

### -InputString

The string to be encoded.

```yaml
Type: System.String
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

### -Key

The key used for encoding.
If not provided, a default value will be used.

```yaml
Type: System.Object
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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

You can pipe a value to `-InputString`.

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: ConvertTo-LTSecurity


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
