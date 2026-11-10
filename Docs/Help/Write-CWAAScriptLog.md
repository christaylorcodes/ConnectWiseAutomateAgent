---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Write-CWAAScriptLog

## SYNOPSIS
Writes a timestamped log entry to a ConnectWise Automate script log file.

## SYNTAX

```
Write-CWAAScriptLog [-Message] <String> [-Level <String>] -LogPath <String>
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Appends a formatted, timestamped entry to the log file specified by LogPath.
Entries follow the format: \[yyyy-MM-dd HH:mm:ss\] \[LEVEL\] Message

Use Initialize-CWAAScriptLog to create the log file first.
This function performs
synchronous file writes via Add-Content with no external module dependency.

## EXAMPLES

### EXAMPLE 1
```
Write-CWAAScriptLog -Message 'Processing complete' -LogPath $logPath
```

### EXAMPLE 2
```
Write-CWAAScriptLog -Message 'Service not found' -Level WARNING -LogPath $logPath
```

### EXAMPLE 3
```
Write-CWAAScriptLog -Message 'Unhandled exception' -Level ERROR -LogPath $logPath
```

## PARAMETERS

### -Message
The log message text.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -Level
The severity level of the log entry.
Valid values: INFO, WARNING, ERROR.
Defaults to INFO.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: INFO
Accept pipeline input: False
Accept wildcard characters: False
```

### -LogPath
The full path to the log file.
Typically obtained from Initialize-CWAAScriptLog.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
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
Alias: Write-AutomateLog

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

