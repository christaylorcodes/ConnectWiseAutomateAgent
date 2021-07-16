---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# Reset-CWAA

## SYNOPSIS
This function will remove local settings on the agent.

## SYNTAX

```
Reset-CWAA [-ID] [-Location] [-MAC] [-Force] [-NoWait] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function can remove some of the agents local settings.
ID, MAC, LocationID
The function will stop the services, make the change, then start the services.
Resetting all of these will force the agent to check in as a new agent.
If you have MAC filtering enabled it should check back in with the same ID.
This function is useful for duplicate agents.

## EXAMPLES

### EXAMPLE 1
```
Reset-CWAA
```

This resets the ID, MAC and LocationID on the agent.

### EXAMPLE 2
```
Reset-CWAA -ID
```

This resets only the ID of the agent.

## PARAMETERS

### -ID
This will reset the AgentID of the computer

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

### -Location
This will reset the LocationID of the computer

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

### -MAC
This will reset the MAC of the computer

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

### -Force
This will force operation on an agent detected as a probe.

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

### -NoWait
This will skip the ending health check for the reset process.
The function will exit once the values specified have been reset.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Version:        1.4
Author:         Chris Taylor
Website:        labtechconsulting.com
Creation Date:  3/14/2016
Purpose/Change: Initial script development

Update Date: 6/1/2017
Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

Update Date: 3/12/2018
Purpose/Change: Added detection of "Probe" enabled agent.
Added support for -Force parameter to override probe detection.
Added support for -WhatIf.
Added support for -NoWait paramter to bypass agent health check.

Update Date: 3/21/2018
Purpose/Change: Removed ErrorAction Override

Update Date: 8/5/2019
Purpose/Change: Bugfixes for -Location parameter

## RELATED LINKS

[http://labtechconsulting.com](http://labtechconsulting.com)

