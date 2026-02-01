---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Stop-CWAA

## SYNOPSIS
Stops the ConnectWise Automate agent services.

## SYNTAX

```
Stop-CWAA [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Verifies that the Automate agent services (LTService, LTSvcMon) are present, then
attempts to stop them gracefully via sc.exe.
Waits up to one minute for the
services to reach a Stopped state.
If they do not stop in time, remaining
Automate agent processes (LTTray, LTSVC, LTSvcMon) are forcefully terminated.

## EXAMPLES

### EXAMPLE 1
```
Stop-CWAA
```

Stops the ConnectWise Automate agent services.

### EXAMPLE 2
```
Stop-CWAA -WhatIf
```

Shows what would happen without actually stopping the services.

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
Alias: Stop-LTService

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

