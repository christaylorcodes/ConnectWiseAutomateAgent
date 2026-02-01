---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Get-CWAAInfo

## SYNOPSIS
Retrieves ConnectWise Automate agent configuration from the registry.

## SYNTAX

```
Get-CWAAInfo [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Reads all agent configuration values from the Automate agent service registry key and
returns them as a single object.
Resolves the BasePath from the service image path
if not present in the registry, expands environment variables in BasePath, and parses
the pipe-delimited Server Address into a clean Server array.

This function supports ShouldProcess because many internal callers pass
-WhatIf:$False -Confirm:$False to suppress prompts during automated operations.

## EXAMPLES

### EXAMPLE 1
```
Get-CWAAInfo
```

Returns an object containing all agent registry properties including ID, Server,
LocationID, BasePath, and other configuration values.

### EXAMPLE 2
```
Get-CWAAInfo -WhatIf:$False -Confirm:$False
```

Retrieves agent info with ShouldProcess suppressed, as used by internal callers.

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

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

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
Alias: Get-LTServiceInfo

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

