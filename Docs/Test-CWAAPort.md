---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# Test-CWAAPort

## SYNOPSIS
This function will attempt to connect to all required TCP ports.

## SYNTAX

```
Test-CWAAPort [[-Server] <String[]>] [[-TrayPort] <Int32>] [-Quiet] [<CommonParameters>]
```

## DESCRIPTION
The function will confirm the LTTray port is available locally.
It will then test required TCP ports to the Server.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -Server
This is the URL to your LabTech server.
Example: https://automate.domain.com
If no server is provided the function will use Get-CWAAInfo to
get the server address.
If it is unable to find LT currently installed
it will try calling Get-CWAAInfoBackup.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -TrayPort
This is the port LTSvc.exe listens on for communication with LTTray.
It will be checked to verify it is available.
If not provided the
default port will be used (42000).

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Quiet
This will return a boolean for connectivity status to the Server

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Version:        1.6
Author:         Chris Taylor
Website:        labtechconsulting.com
Creation Date:  3/14/2016
Purpose/Change: Initial script development

Update Date:    5/11/2017
Purpose/Change: Quiet feature

Update Date: 6/1/2017
Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

Update Date: 6/10/2017
Purpose/Change: Updates for pipeline input, support for multiple servers

Update Date: 8/24/2017
Purpose/Change: Update to use Clear-Variable.

Update Date: 8/29/2017
Purpose/Change: Added Server Address Format Check

Update Date: 2/13/2018
Purpose/Change: Added -TrayPort parameter.

## RELATED LINKS

[http://labtechconsulting.com](http://labtechconsulting.com)

