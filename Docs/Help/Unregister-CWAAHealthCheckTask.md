---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Unregister-CWAAHealthCheckTask

## SYNOPSIS
Removes the ConnectWise Automate agent health check scheduled task.

## SYNTAX

```
Unregister-CWAAHealthCheckTask [[-TaskName] <String>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Deletes the Windows scheduled task created by Register-CWAAHealthCheckTask.
If the task does not exist, writes a warning and returns gracefully.

## EXAMPLES

### EXAMPLE 1
```
Unregister-CWAAHealthCheckTask
```

Removes the default CWAAHealthCheck scheduled task.

### EXAMPLE 2
```
Unregister-CWAAHealthCheckTask -TaskName 'MyHealthCheck'
```

Removes a custom-named health check task.

## PARAMETERS

### -TaskName
Name of the scheduled task to remove.
Default: 'CWAAHealthCheck'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: CWAAHealthCheck
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
Alias: Unregister-LTHealthCheckTask

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

