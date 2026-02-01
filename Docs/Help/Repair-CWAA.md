---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Repair-CWAA

## SYNOPSIS
Performs escalating remediation of the ConnectWise Automate agent.

## SYNTAX

### Install
```
Repair-CWAA -Server <String> -LocationID <Int32> -InstallerToken <String> [-HoursRestart <Int32>]
 [-HoursReinstall <Int32>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Checkup
```
Repair-CWAA -InstallerToken <String> [-HoursRestart <Int32>] [-HoursReinstall <Int32>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Checks the health of the installed Automate agent and takes corrective action
using an escalating strategy:

1.
If the agent is installed and healthy - no action taken.
2.
If the agent is installed but has not checked in within HoursRestart - restarts
   services and waits up to 2 minutes for the agent to recover.
3.
If the agent is still not checking in after HoursReinstall - reinstalls the agent
   using Redo-CWAA.
4.
If the agent configuration is unreadable - uninstalls and reinstalls.
5.
If the installed agent points to the wrong server - reinstalls with the correct server.
6.
If the agent is not installed - performs a fresh install from provided parameters
   or from backup settings.

All remediation actions are logged to the Windows Event Log (Application log,
source ConnectWiseAutomateAgent) for visibility in unattended scheduled task runs.

Designed to be called periodically via Register-CWAAHealthCheckTask or any
external scheduler.

## EXAMPLES

### EXAMPLE 1
```
Repair-CWAA -InstallerToken 'abc123def456'
```

Checks the installed agent and repairs if needed (Checkup mode).

### EXAMPLE 2
```
Repair-CWAA -Server 'https://automate.domain.com' -LocationID 42 -InstallerToken 'token'
```

Checks agent health.
If the agent is missing or pointed at the wrong server,
installs or reinstalls with the specified settings.

### EXAMPLE 3
```
Repair-CWAA -InstallerToken 'token' -HoursRestart -4 -HoursReinstall -240
```

Uses custom thresholds: restart after 4 hours offline, reinstall after 10 days.

## PARAMETERS

### -HoursReinstall
Hours since last check-in before a full reinstall is attempted.
Expressed as a
negative number (e.g., -120 means 120 hours / 5 days ago).
Default: -120.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: -120
Accept pipeline input: False
Accept wildcard characters: False
```

### -HoursRestart
Hours since last check-in before a service restart is attempted.
Expressed as a
negative number (e.g., -2 means 2 hours ago).
Default: -2.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: -2
Accept pipeline input: False
Accept wildcard characters: False
```

### -InstallerToken
An installer token for authenticated agent deployment.
Required for both parameter sets.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LocationID
The LocationID for fresh agent installs.
Required with the Install parameter set.

```yaml
Type: Int32
Parameter Sets: Install
Aliases:

Required: True
Position: Named
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Server
The ConnectWise Automate server URL for fresh installs or server mismatch correction.
Required when using the Install parameter set.

```yaml
Type: String
Parameter Sets: Install
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
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
Alias: Repair-LTService

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

