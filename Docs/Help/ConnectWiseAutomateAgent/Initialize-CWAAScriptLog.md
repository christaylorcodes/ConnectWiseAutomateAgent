---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Initialize-CWAAScriptLog
---

# Initialize-CWAAScriptLog

## SYNOPSIS

Initializes a log file for ConnectWise Automate script execution.

## SYNTAX

### __AllParameterSets

```
Initialize-CWAAScriptLog [[-LogDirectory] <string>] [[-LogName] <string>]
```

## ALIASES

This cmdlet has the following aliases:

- Initialize-AutomateLogging

## DESCRIPTION

Creates a timestamped log file in the specified directory and returns the full path.
The log file is ready for use with Write-CWAAScriptLog.
No external modules are required.

Default log directory is the standard Automate agent log location
(the logs folder under the agent install path, $env:windir\LTSvc\logs by default).
The log filename is derived from the calling script or
function name with a millisecond timestamp suffix (Name_yyyyMMdd-HHmmss-fff.log).

The returned path is absolute.
The file is created exclusively: if a file (or link)
already exists at that path the call fails rather than appending to it, and a log
directory whose path runs through a junction or symbolic link is refused.
On failure a non-terminating error is written
and nothing is returned; use -ErrorAction Stop to make failures terminating.

Logs under the agent folder are typically readable by local users.
Do not log secrets.

This replaces Initialize-AutomateLogging from the legacy CW-Automate-ScriptHelper.ps1
which depended on the PSGallery Logging module.
All logging is now synchronous file
writes with no async queue.

## EXAMPLES

### EXAMPLE 1

$logPath = Initialize-CWAAScriptLog
Write-CWAAScriptLog -Message 'Script started' -LogPath $logPath

### EXAMPLE 2

$logPath = Initialize-CWAAScriptLog -LogDirectory 'C:\Logs' -LogName 'MyScript'

## PARAMETERS

### -LogDirectory

The directory where the log file will be created.
Defaults to the logs folder under the agent install path ($env:windir\LTSvc\logs).
The directory will be created if it does not exist.

```yaml
Type: System.String
DefaultValue: (Join-Path -Path $Script:CWAAInstallPath -ChildPath 'logs')
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

### -LogName

The base name for the log file.
Defaults to the name of the calling script or function
(determined from Get-PSCallStack).
A timestamp is appended automatically.

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

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

Author: Chris Taylor
Alias: Initialize-AutomateLogging


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
