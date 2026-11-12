---
document type: cmdlet
external help file: ConnectWiseAutomateAgent-Help.xml
HelpUri: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
Locale: en-US
Module Name: ConnectWiseAutomateAgent
ms.date: 11/12/2026
PlatyPS schema version: 2024-05-01
title: Set-CWAAProxy
---

# Set-CWAAProxy

## SYNOPSIS

Configures module proxy settings for all operations during the current session.

## SYNTAX

### __AllParameterSets

```
Set-CWAAProxy [[-ProxyServerURL] <string>] [[-ProxyUsername] <string>]
 [[-ProxyPassword] <securestring>] [-EncodedProxyUsername <string>]
 [-EncodedProxyPassword <securestring>] [-ProxyCredential <pscredential>] [-DetectProxy]
 [-ResetProxy] [-SkipCertificateCheck] [-WhatIf] [-Confirm]
```

## ALIASES

This cmdlet has the following aliases:

- Set-LTProxy

## DESCRIPTION

Sets or clears Proxy settings needed for module function and agent operations.
If an agent is already installed, this function will update the ProxyUsername,
ProxyPassword, and ProxyServerURL values in the agent registry settings.
Agent services will be restarted for changes (if found) to be applied.

## EXAMPLES

### EXAMPLE 1

Set-CWAAProxy -DetectProxy
Automatically detects and configures the system proxy.

### EXAMPLE 2

Set-CWAAProxy -ResetProxy
Clears all proxy settings.

### EXAMPLE 3

Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080'
Sets the proxy server URL without authentication.

## PARAMETERS

### -Confirm

Prompts you for confirmation before running the cmdlet.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- cf
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -DetectProxy

Automatically detect system proxy settings for module operations.
Discovered settings are applied to the installed agent (if present).
Cannot be used with other parameters.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases:
- AutoDetect
- Detect
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -EncodedProxyPassword

Encoded password for proxy authentication, encrypted with the agent password
and passed as a SecureString.
Will be decoded using the agent password.
Must be used with ProxyServerURL and EncodedProxyUsername.

```yaml
Type: System.Security.SecureString
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -EncodedProxyUsername

Encoded username for proxy authentication, encrypted with the agent password.
Will be decoded using the agent password.
Must be used with ProxyServerURL
and EncodedProxyPassword.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ProxyCredential

A PSCredential object containing the proxy username and password.
This is the preferred secure alternative to passing -ProxyUsername
and -ProxyPassword separately.
Must be used with -ProxyServerURL.

```yaml
Type: System.Management.Automation.PSCredential
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ProxyPassword

Password for proxy authentication, as a SecureString.
Must be used with ProxyServerURL and ProxyUsername.

```yaml
Type: System.Security.SecureString
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 2
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ProxyServerURL

The URL and optional port to assign as the proxy server for module operations
and for the installed agent (if present).
Example: Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080'
May be used with ProxyUsername/ProxyPassword or EncodedProxyUsername/EncodedProxyPassword.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: true
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ProxyUsername

Plain text username for proxy authentication.
Must be used with ProxyServerURL and ProxyPassword.

```yaml
Type: System.String
DefaultValue: ''
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 1
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -ResetProxy

Clears any currently defined proxy settings for module operations.
Changes are applied to the installed agent (if present).
Cannot be used with other parameters.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases:
- ClearProxy
- Reset
- Clear
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: true
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -SkipCertificateCheck

Bypasses SSL/TLS certificate validation for server connections.
Use in lab or test environments with self-signed certificates.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: False
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### -WhatIf

Runs the command in a mode that only reports what would happen without performing the actions.

```yaml
Type: System.Management.Automation.SwitchParameter
DefaultValue: ''
SupportsWildcards: false
Aliases:
- wi
ParameterSets:
- Name: (All)
  Position: Named
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.String

You can pipe a value to `-ProxyServerURL`. Bound from the pipeline by property name: `-ProxyUsername`, `-EncodedProxyUsername`.

### System.Security.SecureString

Bound from the pipeline by property name: `-ProxyPassword`, `-EncodedProxyPassword`.

### System.Management.Automation.PSCredential

Bound from the pipeline by property name: `-ProxyCredential`.

### System.Management.Automation.SwitchParameter

Bound from the pipeline by property name: `-DetectProxy`, `-ResetProxy`.

## OUTPUTS

## NOTES

Author: Darren White
Alias: Set-LTProxy


## RELATED LINKS

- [Online Version](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)
