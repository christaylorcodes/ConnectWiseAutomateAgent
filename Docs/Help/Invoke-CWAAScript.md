---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Invoke-CWAAScript

## SYNOPSIS
Executes a scriptblock with standardized Automate script output and error handling.

## SYNTAX

### ScriptBlock (Default)
```
Invoke-CWAAScript -ScriptBlock <ScriptBlock> [-EnableLogging] [-LogDirectory <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### URL
```
Invoke-CWAAScript -URL <String> [-EnableLogging] [-LogDirectory <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
Wraps the execution of a PowerShell scriptblock in the standard ConnectWise Automate
script output pattern.
Automatically creates a CWAAScriptOutput object, optionally
initializes a log file, executes the scriptblock, captures the result, and returns
the pipe-delimited output string that Automate expects.

If the scriptblock throws or writes any non-terminating error, the output Status is set to Error and the exception
message(s) are captured in Result.
The function always returns a formatted output string
and never throws to the caller.

An optional URL parameter allows fetching and executing a remote script.
The URL
must use https:// (the agent runs as SYSTEM, so plain HTTP is rejected).

## EXAMPLES

### EXAMPLE 1
```
Invoke-CWAAScript -ScriptBlock { Get-Service LTService | Select-Object -ExpandProperty Status }
# Returns: Status=Success|Result=Running|LogPath=|Data=
```

### EXAMPLE 2
```
Invoke-CWAAScript -ScriptBlock { Get-Service InvalidService -ErrorAction Stop } -EnableLogging
# Returns: Status=Error|Result=<error message>|LogPath=C:\Windows\LTSvc\logs\...
```

### EXAMPLE 3
```
Invoke-CWAAScript -URL 'https://example.com/myscript.ps1' -EnableLogging
Downloads and executes the remote script with logging enabled.
```

## PARAMETERS

### -ScriptBlock
The PowerShell scriptblock to execute.

```yaml
Type: ScriptBlock
Parameter Sets: ScriptBlock
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -URL
URL to a remote PowerShell script.
When specified, the script is downloaded via
Invoke-RestMethod and executed instead of the ScriptBlock parameter.
Must use https://.

```yaml
Type: String
Parameter Sets: URL
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnableLogging
When specified, initializes a log file via Initialize-CWAAScriptLog before execution.
The log path is included in the output object.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogDirectory
The directory for the log file.
Only used when EnableLogging is specified.
Defaults to the agent log directory (the Initialize-CWAAScriptLog default).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Chris Taylor
Alias: Invoke-CWAScript

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

