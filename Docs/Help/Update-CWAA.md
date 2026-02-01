---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Update-CWAA

## SYNOPSIS
Manually updates the ConnectWise Automate Agent to a specified version.

## SYNTAX

```
Update-CWAA [[-Version] <String>] [-SkipCertificateCheck] [-ProgressAction <ActionPreference>] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Downloads and applies an agent update from the ConnectWise Automate server.
The function
reads the current server configuration from the agent's registry settings, downloads the
appropriate update package, extracts it, and runs the updater.

If no version is specified, the function uses the version advertised by the server.
The function validates that the requested version is higher than the currently installed
version and not higher than the server version before proceeding.

The update process:
1.
Reads current agent settings and server information
2.
Downloads the LabtechUpdate.exe for the target version
3.
Stops agent services
4.
Extracts and runs the update
5.
Restarts agent services

## EXAMPLES

### EXAMPLE 1
```
Update-CWAA -Version 120.240
```

Updates the agent to the specific version requested.

### EXAMPLE 2
```
Update-CWAA
```

Updates the agent to the current version advertised by the server.

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

### -SkipCertificateCheck
{{ Fill SkipCertificateCheck Description }}

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

### -Version
The target agent version to update to.
Example: 120.240
If omitted, the version advertised by the server will be used.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
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
Author: Darren White
Alias: Update-LTService

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

