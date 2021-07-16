---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: http://labtechconsulting.com
schema: 2.0.0
---

# Set-CWAAProxy

## SYNOPSIS
This function configures module functions to use the specified proxy
configuration for all operations as long as the module remains loaded.

## SYNTAX

```
Set-CWAAProxy [[-ProxyServerURL] <String>] [[-ProxyUsername] <String>] [[-ProxyPassword] <SecureString>]
 [-EncodedProxyUsername <String>] [-EncodedProxyPassword <SecureString>] [-DetectProxy] [-ResetProxy] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
This function will set or clear Proxy settings needed for function and
agent operations.
If an agent is already installed, this function will
set the ProxyUsername, ProxyPassword, and ProxyServerURL values for the
Agent.
NOTE: Agent Services will be restarted for changes (if found) to be applied.

## EXAMPLES

### Example 1
```powershell
PS C:\> {{ Add example code here }}
```

{{ Add example description here }}

## PARAMETERS

### -ProxyServerURL
This is the URL and Port to assign as the ProxyServerURL for Module
operations during this session and for the Installed Agent (if present).
Example: Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com'
Example: Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080'
This parameter may be used with the additional following parameters:
ProxyUsername, ProxyPassword, EncodedProxyUsername, EncodedProxyPassword

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: True (ByPropertyName, ByValue)
Accept wildcard characters: False
```

### -ProxyUsername
This is the plain text Username for Proxy operations.
Example: Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080' -ProxyUsername 'Test-User' -ProxyPassword 'SomeFancyPassword'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ProxyPassword
This is the plain text Password for Proxy operations.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -EncodedProxyUsername
This is the encoded Username for Proxy operations.
The parameter must be
encoded with the Agent Password.
This Parameter will be decoded using the
Agent Password, and the decoded string will be configured.
NOTE: Reinstallation of the Agent will generate a new agent password.
Example: Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080' -EncodedProxyUsername '1GzhlerwMy0ElG9XNgiIkg==' -EncodedProxyPassword 'Duft4r7fekTp5YnQL9F0V9TbP7sKzm0n'

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -EncodedProxyPassword
This is the encoded Password for Proxy operations.
The parameter must be
encoded with the Agent Password.
This Parameter will be decoded using the
Agent Password, and the decoded string will be configured.
NOTE: Reinstallation of the Agent will generate a new password.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -DetectProxy
This parameter attempts to automatically detect the system Proxy settings
for Module operations during this session.
Discovered settings will be
assigned to the Installed Agent (if present).
Example: Set-CWAAProxy -DetectProxy
This parameter may not be used with other parameters.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: AutoDetect, Detect

Required: False
Position: Named
Default value: False
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -ResetProxy
This parameter clears any currently defined Proxy Settings for Module
operations during this session.
Discovered settings will be assigned
to the Installed Agent (if present).
Example: Set-CWAAProxy -ResetProxy
This parameter may not be used with other parameters.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: ClearProxy, Reset, Clear

Required: False
Position: Named
Default value: False
Accept pipeline input: True (ByPropertyName)
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
Creation Date:  1/24/2018
Purpose/Change: Initial function development

## RELATED LINKS

[http://labtechconsulting.com](http://labtechconsulting.com)

