---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Write-CWAAScriptLog
---

# Write-CWAAScriptLog

## SYNOPSIS

Writes a timestamped log entry to a ConnectWise Automate script log file.

## SYNTAX

### __AllParameterSets

```
Write-CWAAScriptLog [-Message] <string> -LogPath <string> [-Level <string>]
```

## ALIASES

This cmdlet has the following aliases:

- Write-AutomateLog

## DESCRIPTION

Appends a formatted, timestamped entry to the log file specified by LogPath.
Entries follow the format: [yyyy-MM-dd HH:mm:ss] [LEVEL] Message

Continuation lines of a multi-line message are indented by four spaces, so message
text can never start a line that looks like a new [timestamp] [LEVEL] entry.

Use Initialize-CWAAScriptLog to create the log file first.
This function performs
synchronous file writes via Add-Content with no external module dependency.

## EXAMPLES

### EXAMPLE 1

Write-CWAAScriptLog -Message 'Processing complete' -LogPath $logPath

### EXAMPLE 2

Write-CWAAScriptLog -Message 'Service not found' -Level WARNING -LogPath $logPath

### EXAMPLE 3

Write-CWAAScriptLog -Message 'Unhandled exception' -Level ERROR -LogPath $logPath

## PARAMETERS

### -Level

The severity level of the log entry.
Valid values: INFO, WARNING, ERROR.
Defaults to INFO.

```yaml
Type: System.String
DefaultValue: INFO
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

### -LogPath

The full path to the log file.
Typically obtained from Initialize-CWAAScriptLog.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -Message

The log message text.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

You can pipe a value to `-Message`.

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Write-AutomateLog


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
