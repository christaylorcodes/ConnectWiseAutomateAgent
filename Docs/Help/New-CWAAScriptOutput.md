---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# New-CWAAScriptOutput

## SYNOPSIS
Creates a structured output object for ConnectWise Automate script results.

## SYNTAX

```
New-CWAAScriptOutput [[-Status] <String>] [[-Result] <String>] [[-LogPath] <String>] [[-Data] <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

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
```
$output = New-CWAAScriptOutput
$output.Result = 'Service is running'
$output.ToString()
# Returns: Status=Success|Result=Service is running|LogPath=|Data=
```

### EXAMPLE 2
```
$output = New-CWAAScriptOutput -Status 'Failed' -Result 'Service was stopped'
$output.ToString()
# Returns: Status=Failed|Result=Service was stopped|LogPath=|Data=
```

## PARAMETERS

### -Status
The execution status.
Valid values: Success, Failed, Error.
Defaults to Success.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Success
Accept pipeline input: False
Accept wildcard characters: False
```

### -Result
A description of the script outcome.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
The file path to the script's log file, if logging was initialized.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Data
Optional additional data to include in the output (e.g., EDF values).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
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
Alias: New-AutomateOutput

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

