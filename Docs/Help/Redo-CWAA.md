---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Redo-CWAA

## SYNOPSIS
Reinstalls the ConnectWise Automate Agent on the local computer.

## SYNTAX

### deployment
```
Redo-CWAA [-Server <String[]>] [-ServerPassword <String>] [-LocationID <Int32>] [-Backup] [-Hide]
 [-Rename <String>] [-SkipDotNet] [-Force] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### installertoken
```
Redo-CWAA [-Server <String[]>] [-ServerPassword <String>] [-InstallerToken <String>] [-LocationID <Int32>]
 [-Backup] [-Hide] [-Rename <String>] [-SkipDotNet] [-Force] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Performs a complete reinstall of the ConnectWise Automate Agent by uninstalling and then
reinstalling the agent.
The function attempts to retrieve current settings (server, location,
etc.) from the existing installation or from a backup.
If settings cannot be determined
automatically, the function will prompt for the required parameters.

The reinstall process:
1.
Reads current agent settings from registry or backup
2.
Uninstalls the existing agent via Uninstall-CWAA
3.
Waits 20 seconds for the uninstall to settle
4.
Installs a fresh agent via Install-CWAA with the gathered settings

## EXAMPLES

### EXAMPLE 1
```
Redo-CWAA
```

Reinstalls the agent using settings from the current installation registry.

### EXAMPLE 2
```
Redo-CWAA -Server https://automate.domain.com -InstallerToken 'token' -LocationID 42
```

Reinstalls the agent with explicitly provided settings.

### EXAMPLE 3
```
Redo-CWAA -Backup -Force
```

Backs up settings, then forces reinstallation even if a probe agent is detected.

## PARAMETERS

### -Backup
Creates a backup of the current agent installation before uninstalling by calling New-CWAABackup.

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
Forces reinstallation even when a probe agent is detected.

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

### -Hide
Hides the agent entry from Add/Remove Programs after reinstallation.

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

### -InstallerToken
An installer token for authenticated agent deployment.
This is the preferred
authentication method over ServerPassword.
See: https://forums.mspgeek.org/topic/5882-contribution-generate-agent-installertoken

```yaml
Type: String
Parameter Sets: installertoken
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LocationID
The LocationID of the location the agent will be assigned to.
If not provided, reads from the current agent configuration or prompts interactively.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

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

### -Rename
Renames the agent entry in Add/Remove Programs after reinstallation.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Server
One or more ConnectWise Automate server URLs.
Example: https://automate.domain.com
If not provided, the function reads the server URL from the current agent configuration
or backup settings.
If neither is available, prompts interactively.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -ServerPassword
The server password for agent authentication.
InstallerToken is preferred.

```yaml
Type: String
Parameter Sets: deployment
Aliases: Password

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

```yaml
Type: String
Parameter Sets: installertoken
Aliases: Password

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipDotNet
Skips .NET Framework 3.5 and 2.0 prerequisite checks during reinstallation.

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
Alias: Reinstall-CWAA, Redo-LTService, Reinstall-LTService

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

