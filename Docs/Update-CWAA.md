---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# Update-CWAA

## SYNOPSIS
This function will manually update the LabTech agent to the requested version.

## SYNTAX

```
Update-CWAA [[-Version] <String>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This script will attempt to pull current server settings from machine, then download and run the agent updater.

## EXAMPLES

### EXAMPLE 1
```
Update-CWAA -Version 120.240
```

This will update the Automate agent to the specific version requested, using the server address in the registry.

### EXAMPLE 2
```
Update-CWAA
```

This will update the Automate agent to the current version advertised, using the server address in the registry.

## PARAMETERS

### -Version
This is the agent version to install.
Example: 120.240
This is needed to download the update file.
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
Version:        1.1
Author:         Darren White
Creation Date:  8/28/2018
Purpose/Change: Initial function development

Update Date: 1/21/2019
Purpose/Change: Minor bugfixes/adjustments.
Allow single label server name, accept less digits for Agent Minor version number

## RELATED LINKS

[http://labtechconsulting.com](http://labtechconsulting.com)

