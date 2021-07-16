---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# ConvertTo-CWAASecurity

## SYNOPSIS
This function encodes a value compatible with LT operations.

## SYNTAX

```
ConvertTo-CWAASecurity [-InputString] <String> [[-Key] <Object>] [<CommonParameters>]
```

## DESCRIPTION
This function encodes the provided string using the specified or default key.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -InputString
This is the string to be encoded.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Key
This is the key used for encoding.
If not provided, a default value will be used.

```yaml
Type: Object
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Version:        1.1
Author:         Darren White
Creation Date:  1/25/2018
Purpose/Change: Initial function development

## RELATED LINKS

[http://labtechconsulting.com](http://labtechconsulting.com)

