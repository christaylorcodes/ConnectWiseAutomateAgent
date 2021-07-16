---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# Stop-CWAA

## SYNOPSIS
This function will stop the LabTech Services.

## SYNTAX

```
Stop-CWAA [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function will verify that the LabTech services are present then attempt to stop them.
It will then check for any remaining LabTech processes and kill them.

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
Version:        1.3
Author:         Chris Taylor
Website:        labtechconsulting.com
Creation Date:  3/14/2016
Purpose/Change: Initial script development

Update Date: 6/1/2017
Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

Update Date: 3/12/2018
Purpose/Change: Updated Support for ShouldProcess to enable -Confirm and -WhatIf parameters.

Update Date: 3/21/2018
Purpose/Change: Removed ErrorAction Override

## RELATED LINKS

[http://labtechconsulting.com](http://labtechconsulting.com)

