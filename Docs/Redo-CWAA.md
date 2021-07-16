---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# Redo-CWAA

## SYNOPSIS
This function will reinstall the LabTech agent from the machine.

## SYNTAX

### deployment
```
Redo-CWAA [[-Server] <String[]>] [[-ServerPassword] <SecureString>] [[-LocationID] <String>] [-Backup] [-Hide]
 [[-Rename] <String>] [-SkipDotNet] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### installertoken
```
Redo-CWAA [[-Server] <String[]>] [[-ServerPassword] <SecureString>] [-InstallerToken <String>]
 [[-LocationID] <String>] [-Backup] [-Hide] [[-Rename] <String>] [-SkipDotNet] [-Force] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
This script will attempt to pull all current settings from machine and issue an 'Uninstall-CWAA', 'Install-CWAA' with gathered information.
If the function is unable to find the settings it will ask for needed parameters.

## EXAMPLES

### EXAMPLE 1
```
Redo-CWAA
```

This will ReInstall the LabTech agent using the server address in the registry.

### EXAMPLE 2
```
Redo-CWAA -Server https://lt.domain.com -Password sQWZzEDYKFFnTT0yP56vgA== -LocationID 42
```

This will ReInstall the LabTech agent using the provided server URL to download the installation files.

## PARAMETERS

### -Server
This is the URL to your LabTech server.
Example: https://lt.domain.com
This is used to download the installation and removal utilities.
If no server is provided the uninstaller will use Get-CWAAInfo to get the server address.
If it is unable to find LT currently installed it will try Get-CWAAInfoBackup

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

### -ServerPassword
{{ Fill ServerPassword Description }}

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
The LocationID of the location that you want the agent in
example: 555

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Backup
This will run a New-CWAABackup command before uninstalling.

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
Will remove from add-remove programs

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

### -Rename
This will call Rename-CWAAAddRemove to rename the install in Add/Remove Programs

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
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
This will force operation on an agent detected as a probe.

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
{{ Fill InstallerToken Description }}

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
Version:        1.5
Author:         Chris Taylor
Website:        labtechconsulting.com
Creation Date:  3/14/2016
Purpose/Change: Initial script development

Update Date: 6/1/2017
Purpose/Change: Updates for better overall compatibility, including better support for PowerShell V2

Update Date: 6/8/2017
Purpose/Change: Update to support user provided settings for -Server, -Password, -LocationID.

Update Date: 6/10/2017
Purpose/Change: Updates for pipeline input, support for multiple servers

Update Date: 8/24/2017
Purpose/Change: Update to use Clear-Variable.

Update Date: 3/12/2018
Purpose/Change: Added detection of "Probe" enabled agent.
Added support for -Force parameter to override probe detection.
Updated support of -WhatIf parameter.

Update Date: 2/22/2019
Purpose/Change: Added -SkipDotNet parameter.
Allows for skipping of .NET 3.5 and 2.0 framework checks for installing on OS with .NET 4.0+ already installed

## RELATED LINKS

[http://labtechconsulting.com](http://labtechconsulting.com)

