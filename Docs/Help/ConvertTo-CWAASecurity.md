---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# ConvertTo-CWAASecurity

## SYNOPSIS
Encodes a string using TripleDES encryption compatible with Automate operations.

## SYNTAX

```
ConvertTo-CWAASecurity [-InputString] <String> [[-Key] <Object>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

## DESCRIPTION
This function encodes the provided string using the specified or default key.
It uses TripleDES with an MD5-derived key and a fixed initialization vector,
returning a Base64-encoded result.

## EXAMPLES

### EXAMPLE 1
```
ConvertTo-CWAASecurity -InputString 'PlainTextValue'
```

Encodes the string using the default key.

### EXAMPLE 2
```
ConvertTo-CWAASecurity -InputString 'PlainTextValue' -Key 'MyCustomKey'
```

Encodes the string using a custom key.

## PARAMETERS

### -InputString
The string to be encoded.

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
The key used for encoding.
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
Alias: ConvertTo-LTSecurity

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

