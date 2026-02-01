---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Get-CWAAProbeError

## SYNOPSIS
Reads the ConnectWise Automate Agent probe error log into structured objects.

## SYNTAX

```
Get-CWAAProbeError [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Parses the LTProbeErrors.txt file from the agent install directory into objects with
ServiceVersion, Timestamp, and Message properties.
This enables filtering, sorting,
and pipeline operations on agent probe error log entries.

The log file location is determined from Get-CWAAInfo; if unavailable, falls back
to the default install path at C:\Windows\LTSVC.

## EXAMPLES

### EXAMPLE 1
```
Get-CWAAProbeError | Where-Object {$_.Timestamp -gt (Get-Date).AddHours(-24)}
```

Returns all probe errors from the last 24 hours.

### EXAMPLE 2
```
Get-CWAAProbeError | Out-GridView
```

Opens the probe error log in a sortable, searchable grid view window.

## PARAMETERS

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
Alias: Get-LTProbeErrors

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

