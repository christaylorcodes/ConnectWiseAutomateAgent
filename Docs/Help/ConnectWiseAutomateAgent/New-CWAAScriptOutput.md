---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: New-CWAAScriptOutput
---

# New-CWAAScriptOutput

## SYNOPSIS

Creates a structured output object for ConnectWise Automate script results.

## SYNTAX

### __AllParameterSets

```
New-CWAAScriptOutput [[-Status] <string>] [[-Result] <string>] [[-LogPath] <string>]
 [[-Data] <string>]
```

## ALIASES

This cmdlet has the following aliases:

- New-AutomateOutput

## DESCRIPTION

Creates a PSCustomObject representing the result of an Automate-deployed script.
The object has Status, Result, LogPath, and Data properties.
A ToString ScriptMethod
is attached that serializes the object to the pipe-delimited format expected by
Automate's script output parser via ConvertTo-CWAAScriptOutput.

This replaces the legacy AutomateOutput class from CW-Automate-ScriptHelper.ps1
with a PSCustomObject that has zero load-time side effects and works on
PowerShell 3.0+.

## EXAMPLES

### EXAMPLE 1

$output = New-CWAAScriptOutput
$output.Result = 'Service is running'
$output.ToString()
# Returns: Status=Success|Result=Service is running|LogPath=|Data=

### EXAMPLE 2

$output = New-CWAAScriptOutput -Status 'Failed' -Result 'Service was stopped'
$output.ToString()
# Returns: Status=Failed|Result=Service was stopped|LogPath=|Data=

## PARAMETERS

### -Data

Optional additional data to include in the output (e.g., EDF values).

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 3
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -LogPath

The file path to the script's log file, if logging was initialized.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Result

A description of the script outcome.

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

### -Status

The execution status.
Valid values: Success, Failed, Error.
Defaults to Success.

```yaml
Type: System.String
DefaultValue: Success
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
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
Alias: New-AutomateOutput


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
