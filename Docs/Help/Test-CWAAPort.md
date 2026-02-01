---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Test-CWAAPort

## SYNOPSIS
Tests connectivity to TCP ports required by the ConnectWise Automate agent.

## SYNTAX

```
Test-CWAAPort [[-Server] <String[]>] [[-TrayPort] <Int32>] [-Quiet] [<CommonParameters>]
```

## DESCRIPTION
Verifies that the local LTTray port is available and tests connectivity to
the required TCP ports (70, 80, 443) on the Automate server, plus port 8002
on the Automate mediator server.
If no server is provided, the function attempts to detect it from the installed
agent configuration or backup info.

## EXAMPLES

### EXAMPLE 1
```
Test-CWAAPort -Server 'https://automate.domain.com'
```

Tests all required ports against the specified server.

### EXAMPLE 2
```
Test-CWAAPort -Quiet
```

Returns $True if the TrayPort is available, $False otherwise.

## PARAMETERS

### -Quiet
Returns a boolean connectivity result instead of verbose output.

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

### -Server
The URL of the Automate server (e.g., https://automate.domain.com).
If not provided, the function uses Get-CWAAInfo or Get-CWAAInfoBackup to discover it.

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
The local port LTSvc.exe listens on for LTTray communication.
Defaults to 42000 if not provided or not found in agent configuration.

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Chris Taylor
Alias: Test-LTPorts

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

