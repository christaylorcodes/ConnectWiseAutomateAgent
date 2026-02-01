---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Test-CWAAServerConnectivity

## SYNOPSIS
Tests connectivity to a ConnectWise Automate server's agent endpoint.

## SYNTAX

```
Test-CWAAServerConnectivity [[-Server] <String[]>] [-Quiet] [<CommonParameters>]
```

## DESCRIPTION
Verifies that an Automate server is online and responding by querying the
agent.aspx endpoint.
Validates that the response matches the expected version
format (pipe-delimited string ending with a version number).

If no server is provided, the function attempts to discover it from the
installed agent configuration or backup settings.

Returns a result object per server with availability status and version info,
or a simple boolean in Quiet mode.

## EXAMPLES

### EXAMPLE 1
```
Test-CWAAServerConnectivity -Server 'https://automate.domain.com'
```

Tests connectivity and returns a result object with Server, Available, Version, and ErrorMessage.

### EXAMPLE 2
```
Test-CWAAServerConnectivity -Quiet
```

Returns $True if the discovered server is reachable, $False otherwise.

### EXAMPLE 3
```
Get-CWAAInfo | Test-CWAAServerConnectivity
```

Tests connectivity to the server configured on the installed agent via pipeline.

## PARAMETERS

### -Quiet
Returns $True if all servers are reachable, $False otherwise.

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

### -Server
One or more ConnectWise Automate server URLs (e.g., https://automate.domain.com).
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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Chris Taylor
Alias: Test-LTServerConnectivity

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

