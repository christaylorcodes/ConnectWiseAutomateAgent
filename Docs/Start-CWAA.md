---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# Start-CWAA

## SYNOPSIS
This function will start the LabTech Services.

## SYNTAX

```
Start-CWAA [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function will verify that the LabTech services are present.
It will then check for any process that is using the LTTray port (Default 42000) and kill it.
Next it will start the services.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

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
Version:        1.5
Author:         Chris Taylor
Website:        labtechconsulting.com
Creation Date:  3/14/2016
Purpose/Change: Initial script development

Update Date: 5/11/2017
Purpose/Change: added check for non standard port number and set services to auto start

Update Date: 6/1/2017
Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

Update Date: 12/14/2017
Purpose/Change: Will increment the tray port if a conflict is detected.

Update Date: 2/1/2018
Purpose/Change: Added support for -WhatIf.
Added Service Control Command to request agent check-in immediately after startup.

Update Date: 3/21/2018
Purpose/Change: Removed ErrorAction Override

## RELATED LINKS

[http://labtechconsulting.com](http://labtechconsulting.com)

