---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Set-CWAAProxy

## SYNOPSIS
Configures module proxy settings for all operations during the current session.

## SYNTAX

```
Set-CWAAProxy [[-ProxyServerURL] <String>] [[-ProxyUsername] <String>] [[-ProxyPassword] <SecureString>]
 [-EncodedProxyUsername <String>] [-EncodedProxyPassword <SecureString>] [-DetectProxy] [-ResetProxy]
 [-SkipCertificateCheck] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Sets or clears Proxy settings needed for module function and agent operations.
If an agent is already installed, this function will update the ProxyUsername,
ProxyPassword, and ProxyServerURL values in the agent registry settings.
Agent services will be restarted for changes (if found) to be applied.

## EXAMPLES

### EXAMPLE 1
```
Set-CWAAProxy -DetectProxy
```

Automatically detects and configures the system proxy.

### EXAMPLE 2
```
Set-CWAAProxy -ResetProxy
```

Clears all proxy settings.

### EXAMPLE 3
```
Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080'
```

Sets the proxy server URL without authentication.

## PARAMETERS

### -DetectProxy
Automatically detect system proxy settings for module operations.
Discovered settings are applied to the installed agent (if present).
Cannot be used with other parameters.

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

### -EncodedProxyPassword
Encoded password for proxy authentication, encrypted with the agent password.
Will be decoded using the agent password.
Must be used with ProxyServerURL
and EncodedProxyUsername.

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

### -EncodedProxyUsername
Encoded username for proxy authentication, encrypted with the agent password.
Will be decoded using the agent password.
Must be used with ProxyServerURL
and EncodedProxyPassword.

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

### -ProxyPassword
Plain text password for proxy authentication.
Must be used with ProxyServerURL and ProxyUsername.

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

### -ProxyServerURL
The URL and optional port to assign as the proxy server for module operations
and for the installed agent (if present).
Example: Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080'
May be used with ProxyUsername/ProxyPassword or EncodedProxyUsername/EncodedProxyPassword.

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
Plain text username for proxy authentication.
Must be used with ProxyServerURL and ProxyPassword.

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

### -ResetProxy
Clears any currently defined proxy settings for module operations.
Changes are applied to the installed agent (if present).
Cannot be used with other parameters.

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
Alias: Set-LTProxy

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

