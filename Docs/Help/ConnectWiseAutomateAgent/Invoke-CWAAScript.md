---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/10/2026
PlatyPS schema version: 2024-05-01
title: Invoke-CWAAScript
---

# Invoke-CWAAScript

## SYNOPSIS

Executes a scriptblock with standardized Automate script output and error handling.

## SYNTAX

### ScriptBlock (Default)

```
Invoke-CWAAScript -ScriptBlock <scriptblock> [-EnableLogging] [-LogDirectory <string>]
 [-LogName <string>]
```

### URL

```
Invoke-CWAAScript -URL <string> [-EnableLogging] [-LogDirectory <string>] [-LogName <string>]
```

## ALIASES

This cmdlet has the following aliases:

- Invoke-CWAScript

## DESCRIPTION

Wraps the execution of a PowerShell scriptblock in the standard ConnectWise Automate
script output pattern.
Automatically creates a CWAAScriptOutput object, optionally
initializes a log file, executes the scriptblock, captures the result, and returns
the pipe-delimited output string that Automate expects.

If the scriptblock throws, or an error escapes it to the error stream (for example
Write-Error, or a cmdlet error the script did not handle), the output Status is set
to Error and all error messages are captured in Result, in order.
Errors the
scriptblock handles itself (try/catch, -ErrorAction SilentlyContinue), including
error records it outputs on purpose (catch { $_ }), do not count.
Any output produced before the failure is kept in Data as Output=<text>, which is
always the last item in Data.
Errors are collected, not re-emitted, so the formatted
string is the only output.
Once parameters are bound, the function always returns a
formatted output string and does not throw.

Execution stops at the first terminating error, including statement-terminating
errors such as a .NET method exception or an unknown command name, which a script
run on its own would continue past.

stderr from native commands (git, robocopy, installers) is treated as ordinary output,
not as an error; check $LASTEXITCODE inside the scriptblock to detect native failures.
On Windows PowerShell 5.1 with $ErrorActionPreference = 'Stop' in the calling script,
PowerShell itself stops at the first native stderr line, which is reported as Error.
With $ErrorActionPreference = 'SilentlyContinue' or 'Ignore' in the calling script,
non-terminating errors are hidden from this function and the run can report Success;
use Continue or Stop around this call.

Only the success output of the scriptblock is captured.
Write-Host, Write-Warning,
Write-Verbose and Write-Information output still goes to the host, so Automate sees
it as extra lines before the Status line.

Leaving the scriptblock through exit, or through break/continue to a label outside
this call, is reported as Status=Error.
exit still ends the PowerShell host
afterwards, so use throw (or set a Failed status) to signal failure instead.

An optional URL parameter allows fetching and executing a remote script.
The URL
must use https:// (the agent runs as SYSTEM, so plain HTTP is rejected).
The
downloaded content must not be empty.
It is read as UTF-8 unless it starts with a
byte order mark for another Unicode encoding.
The remote script runs in the caller's
scope, as a scriptblock passed to -ScriptBlock does.

## EXAMPLES

### EXAMPLE 1

Invoke-CWAAScript -ScriptBlock { Get-Service LTService | Select-Object -ExpandProperty Status }
# Returns: Status=Success|Result=Running|LogPath=|Data=

### EXAMPLE 2

Invoke-CWAAScript -ScriptBlock { Get-Service InvalidService -ErrorAction Stop } -EnableLogging
# Returns: Status=Error|Result=<error message>|LogPath=C:\Windows\LTSvc\logs\...

### EXAMPLE 3

Invoke-CWAAScript -URL 'https://example.com/myscript.ps1' -EnableLogging -LogName 'MyScript'
Downloads and executes the remote script, logging to MyScript_<timestamp>.log.

## PARAMETERS

### -EnableLogging

When specified, initializes a log file via Initialize-CWAAScriptLog before execution.
The log path is included in the output object.
Each failure is written to the log
with its stack trace or script location (never the source line text).
If the log
cannot be created, the scriptblock still runs: LogPath is left empty and Data
records LogInitFailed=<message>.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
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

### -LogDirectory

The directory for the log file.
Only used when EnableLogging is specified.
Defaults to the agent log directory (the Initialize-CWAAScriptLog default).

```yaml
Type: System.String
DefaultValue: ''
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

### -LogName

The base name for the log file.
Only used when EnableLogging is specified.
Defaults to the name of the script or function that called Invoke-CWAAScript.

```yaml
Type: System.String
DefaultValue: ''
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

### -ScriptBlock

The PowerShell scriptblock to execute.

```yaml
Type: System.Management.Automation.ScriptBlock
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: ScriptBlock
  Position: Named
  IsRequired: true
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -URL

URL to a remote PowerShell script.
When specified, the script is downloaded via
Invoke-WebRequest and executed instead of the ScriptBlock parameter.
Must use
https://.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: URL
  Position: Named
  IsRequired: true
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
Alias: Invoke-CWAScript


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
