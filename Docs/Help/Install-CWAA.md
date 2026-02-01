---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Install-CWAA

## SYNOPSIS
Installs the ConnectWise Automate Agent on the local computer.

## SYNTAX

### deployment (Default)
```
Install-CWAA [-Server <String[]>] [-ServerPassword <String>] [-LocationID <Int32>] [-TrayPort <Int32>]
 [-Rename <String>] [-Hide] [-SkipDotNet] [-Force] [-NoWait] [-SkipCertificateCheck]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### installertoken
```
Install-CWAA [-Server <String[]>] [-ServerPassword <String>] [-InstallerToken <String>] [-LocationID <Int32>]
 [-TrayPort <Int32>] [-Rename <String>] [-Hide] [-SkipDotNet] [-Force] [-NoWait] [-SkipCertificateCheck]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Downloads and installs the ConnectWise Automate agent from the specified server URL.
Supports authentication via InstallerToken (preferred) or ServerPassword.
The function handles .NET Framework 3.5 prerequisite checks, MSI download with file integrity validation, proxy configuration, TrayPort conflict resolution, and post-install agent registration verification.

If a previous installation is detected, the function will automatically call Uninstall-LTService before proceeding.
The -Force parameter allows installation even when services are already present or when only .NET 4.0+ is available without 3.5.

## EXAMPLES

### EXAMPLE 1
```
Install-CWAA -Server https://automate.domain.com -InstallerToken 'GeneratedToken' -LocationID 42
```

Installs the agent using an InstallerToken for authentication.

### EXAMPLE 2
```
Install-CWAA -Server https://automate.domain.com -ServerPassword 'encryptedpass' -LocationID 1
```

Installs the agent using a legacy server password.

### EXAMPLE 3
```
Install-CWAA -Server https://automate.domain.com -InstallerToken 'token' -LocationID 42 -NoWait
```

Installs the agent without waiting for registration to complete.

## PARAMETERS

### -Force
Disables safety checks including existing service detection and .NET version requirements.

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
Hides the agent entry from Add/Remove Programs after installation by calling Hide-CWAAAddRemove.

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
This is the preferred authentication method over ServerPassword.

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

### -NoWait
Skips the post-install health check that waits for agent registration.
The function exits immediately after the installer completes.

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
Renames the agent entry in Add/Remove Programs after installation by calling Rename-CWAAAddRemove.

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
One or more ConnectWise Automate server URLs to download the installer from.
Example: https://automate.domain.com The function tries each server in order until a successful download occurs.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ServerPassword
The server password that agents use to authenticate with the Automate server.
Used for legacy deployment method.
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

### -SkipCertificateCheck
Bypasses SSL/TLS certificate validation for server connections.
Use in lab or test environments with self-signed certificates.

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

### -SkipDotNet
Skips .NET Framework 3.5 and 2.0 prerequisite checks.
Use when .NET 4.0+ is already installed.

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

### -TrayPort
The local port LTSvc.exe listens on for communication with LTTray processes.
Defaults to 42000.
If the port is in use, the function auto-selects the next available port.

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

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: False
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
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String[]
### System.String
### System.Int32
## OUTPUTS

### System.Object
## NOTES
Author: Chris Taylor Alias: Install-LTService

## RELATED LINKS
