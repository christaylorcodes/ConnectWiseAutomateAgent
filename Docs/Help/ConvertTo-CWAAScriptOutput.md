---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# ConvertTo-CWAAScriptOutput

## SYNOPSIS
Converts a script output object or hashtable to the pipe-delimited format expected by ConnectWise Automate.

## SYNTAX

```
ConvertTo-CWAAScriptOutput [-InputObject] <Object> [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Serializes a CWAAScriptOutput object, any PSCustomObject, or a hashtable into the
pipe-delimited key=value format that ConnectWise Automate's script runner parses.

Output format: Status=Success|Result=...|LogPath=...|Data=...

When given a CWAAScriptOutput object (from New-CWAAScriptOutput), only the four standard
properties (Status, Result, LogPath, Data) are serialized, excluding internal members like
PSTypeName.
For hashtables and generic objects, all keys/properties are included.

## EXAMPLES

### EXAMPLE 1
```
$output = New-CWAAScriptOutput -Status 'Success' -Result 'Completed'
ConvertTo-CWAAScriptOutput -InputObject $output
# Returns: Status=Success|Result=Completed|LogPath=|Data=
```

### EXAMPLE 2
```
ConvertTo-CWAAScriptOutput -InputObject @{ Status = 'Error'; Result = 'Disk full' }
# Returns: Status=Error|Result=Disk full
```

## PARAMETERS

### -InputObject
The object to serialize.
Accepts PSCustomObject, CWAAScriptOutput, or hashtable.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: True (ByValue)
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
Alias: ConvertTo-AutomateOutput

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

