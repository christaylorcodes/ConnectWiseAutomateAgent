---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# Install-CWAA

## SYNOPSIS
This function will install the LabTech agent on the machine.

## SYNTAX

### deployment (Default)
```
Install-CWAA [[-Server] <String[]>] [[-ServerPassword] <SecureString>] [[-LocationID] <Int32>]
 [[-TrayPort] <Int32>] [[-Rename] <String>] [-Hide] [-SkipDotNet] [-Force] [-NoWait] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

### installertoken
```
Install-CWAA [[-Server] <String[]>] [[-ServerPassword] <SecureString>] [-InstallerToken <String>]
 [[-LocationID] <Int32>] [[-TrayPort] <Int32>] [[-Rename] <String>] [-Hide] [-SkipDotNet] [-Force] [-NoWait]
 [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function will install the LabTech agent on the machine with the specified server/password/location.

## EXAMPLES

### EXAMPLE 1
```
Install-CWAA -Server https://automate.domain.com -InstallerToken 'GeneratedToken' -LocationID 42
```

This will install the LabTech agent using the provided Server URL, InstallerToken, and LocationID.

## PARAMETERS

### -Server
This is the URL to your LabTech server.
example: https://automate.domain.com
This is used to download the installation files.
(Get-CWAAInfo|Select-Object -Expand 'Server Address' -ErrorAction SilentlyContinue)

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ServerPassword
This is the server password that agents use to authenticate with the LabTech server.
SELECT SystemPassword FROM config;

```yaml
Type: SecureString
Parameter Sets: deployment
Aliases: Password

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

```yaml
Type: SecureString
Parameter Sets: installertoken
Aliases: Password

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -LocationID
This is the LocationID of the location that the agent will be put into.
(Get-CWAAInfo).LocationID

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -TrayPort
This is the port LTSvc.exe listens on for communication with LTTray processes.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: 0
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Rename
This will call Rename-CWAAAddRemove after the install.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Hide
This will call Hide-CWAAAddRemove after the install.

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
This will disable the error checking for the .NET 3.5 and .NET 2.0 frameworks during the install process.

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
This will disable some of the error checking on the install process.

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

### -NoWait
This will skip the ending health check for the install process.
The function will exit once the installer has completed.

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

### -InstallerToken
An installer token is preferred over the server password. Please see the following forum post about generating installer tokens.

https://forums.mspgeek.org/topic/5882-contribution-generate-agent-installertoken


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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Version:        2.0
Author:         Chris Taylor
Website:        labtechconsulting.com
Creation Date:  3/14/2016
Purpose/Change: Initial script development

Update Date: 6/1/2017
Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

Update Date: 6/10/2017
Purpose/Change: Updates for pipeline input, support for multiple servers

Update Date: 6/24/2017
Purpose/Change: Update to detect Server Version and use updated URL format for LabTech 11 Patch 13.

Update Date: 8/24/2017
Purpose/Change: Update to use Clear-Variable.
Additional Debugging.

Update Date: 8/29/2017
Purpose/Change: Additional Debugging.

Update Date: 9/7/2017
Purpose/Change: Support for ShouldProcess to enable -Confirm and -WhatIf.

Update Date: 1/26/2018
Purpose/Change: Added support for Proxy Server for Download and Installation steps.

Update Date: 2/13/2018
Purpose/Change: Added -TrayPort parameter.

Update Date: 3/13/2018
Purpose/Change: Added -NoWait parameter.
Added minimum size requirement for agent installer to detect and skip a bad file download.

Update Date: 6/5/2018
Purpose/Change: Added -SkipDotNet parameter.
Allows for skipping of .NET 3.5 and 2.0 framework checks for installing on OS with .NET 4.0+ already installed

Update Date: 1/21/2019
Purpose/Change: Minor bugfixes/adjustments.
Allow single label server name, accept Agent ID 1 as valid.

Update Date: 2/28/2019
Purpose/Change: Update to try both http and https methods if not specified for Server

Update Date: 12/28/2019
Purpose/Change: Handle .NET 3.5 in pending state, accept .NET 4.0+ or higher with -Force parameter

Update Date: 6/10/2020
Purpose/Change: Remove Deployment.aspx dependance

Update Date: 6/11/2020
Purpose/Change: Update to work with or without Deployment.aspx

## RELATED LINKS

[http://labtechconsulting.com](http://labtechconsulting.com)

