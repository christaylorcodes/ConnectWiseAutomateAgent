---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# Invoke-CWAACommand

## SYNOPSIS
This function tells the agent to execute the desired command.

## SYNTAX

```
Invoke-CWAACommand [-Command] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function will allow you to execute all known commands against an agent.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Command
{{ Fill Command Description }}

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: True (ByValue)
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
Version:        1.2
Author:         Chris Taylor
Website:        labtechconsulting.com
Creation Date:  2/2/2018
Purpose/Change: Initial script development
Thanks:         Gavin Stone, for finding the command list

Update Date: 2/8/2018
Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

Update Date: 3/21/2018
Purpose/Change: Removed ErrorAction Override

## RELATED LINKS

[http://labtechconsulting.com](http://labtechconsulting.com)

