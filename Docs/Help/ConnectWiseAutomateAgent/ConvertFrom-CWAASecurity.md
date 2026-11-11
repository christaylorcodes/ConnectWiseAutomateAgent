---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: ConvertFrom-CWAASecurity
---

# ConvertFrom-CWAASecurity

## SYNOPSIS

Decodes a Base64-encoded string using TripleDES decryption.

## SYNTAX

### __AllParameterSets

```
ConvertFrom-CWAASecurity [-InputString] <string[]> [-Key <string[]>] [-Force]
```

## ALIASES

This cmdlet has the following aliases:

- ConvertFrom-LTSecurity

## DESCRIPTION

This function decodes the provided string using the specified or default key.
It uses TripleDES with an MD5-derived key and a fixed initialization vector.
If decoding fails with the provided key and Force is enabled, alternate key
values are attempted automatically.

## EXAMPLES

### EXAMPLE 1

ConvertFrom-CWAASecurity -InputString 'EncodedValue'
Decodes the string using the default key.

### EXAMPLE 2

ConvertFrom-CWAASecurity -InputString 'EncodedValue' -Key 'MyCustomKey'
Decodes the string using a custom key.

## PARAMETERS

### -Force

Forces the function to try alternate key values if decoding fails using
the provided key.
Enabled by default.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: True
SupportsWildcards: false
Aliases: []
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

### -InputString

The Base64-encoded string to be decoded.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: true
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Key

The key used for decoding.
If not provided, default values will be tried.

```yaml
Type: System.String[]
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
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

### System.String[]

{{ Fill in the Description }}

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: ConvertFrom-LTSecurity


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
