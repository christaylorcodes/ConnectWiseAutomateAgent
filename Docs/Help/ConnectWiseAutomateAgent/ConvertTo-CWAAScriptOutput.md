---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: ConvertTo-CWAAScriptOutput
---

# ConvertTo-CWAAScriptOutput

## SYNOPSIS

Converts a script output object or hashtable to the pipe-delimited format expected by ConnectWise Automate.

## SYNTAX

### __AllParameterSets

```
ConvertTo-CWAAScriptOutput [-InputObject] <Object>
```

## ALIASES

This cmdlet has the following aliases:

- ConvertTo-AutomateOutput

## DESCRIPTION

Serializes a CWAAScriptOutput object, any PSCustomObject, or a hashtable into the
pipe-delimited key=value format that ConnectWise Automate's script runner parses.

Output format: Status=Success|Result=...|LogPath=...|Data=...

All note properties (objects) or keys (hashtables/dictionaries) are serialized in order.
A CWAAScriptOutput object (from New-CWAAScriptOutput) yields Status, Result, LogPath, Data.
Plain hashtables have no guaranteed key order; use [ordered]@{} when order matters.

Values are trimmed and sanitized so they cannot break the single-line format: line
breaks become ' / ' and pipe characters become '/'.
A value therefore can never
inject an extra field (such as a second Status=) into the output.

## EXAMPLES

### EXAMPLE 1

$output = New-CWAAScriptOutput -Status 'Success' -Result 'Completed'
ConvertTo-CWAAScriptOutput -InputObject $output
# Returns: Status=Success|Result=Completed|LogPath=|Data=

### EXAMPLE 2

ConvertTo-CWAAScriptOutput -InputObject ([ordered]@{ Status = 'Error'; Result = 'Disk full' })
# Returns: Status=Error|Result=Disk full

### EXAMPLE 3

ConvertTo-CWAAScriptOutput -InputObject ([ordered]@{ Status = 'Success'; Result = "line1`nline2|x" })
# Returns: Status=Success|Result=line1 / line2/x

## PARAMETERS

### -InputObject

The object to serialize.
Accepts PSCustomObject, CWAAScriptOutput, hashtable, or [ordered] dictionary.

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
Alias: ConvertTo-AutomateOutput


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
