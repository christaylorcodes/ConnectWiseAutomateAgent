---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# ConvertFrom-CWAASecurity

## SYNOPSIS
This function decodes an encoded Base64 value

## SYNTAX

```
ConvertFrom-CWAASecurity [-InputString] <String[]> [-Key <String[]>] [-Force] [<CommonParameters>]
```

## DESCRIPTION
This function decodes the provided string using the specified or default key.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -InputString
This is the string to be decoded.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -Key
This is the key used for decoding.
If not provided, default values will be tried.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Force
This forces the function to try alternate key values if decoding fails using provided key.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: True
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

