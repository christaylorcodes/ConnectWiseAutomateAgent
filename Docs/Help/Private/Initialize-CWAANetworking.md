---
external help file:
Module Name: ConnectWiseAutomateAgent
online version:
schema: 2.0.0
---

# Initialize-CWAANetworking

## SYNOPSIS
Lazily initializes networking objects on first use rather than at module load.

## SYNTAX

```
Initialize-CWAANetworking [-SkipCertificateCheck] [<CommonParameters>]
```

## DESCRIPTION
Initialize-CWAANetworking is the Phase 2 initialization function that performs deferred setup of SSL certificate validation, TLS protocol enablement, WebProxy, WebClient, and proxy configuration. It runs on first networking call rather than at module import, keeping `Import-Module` fast and side-effect free.

SSL certificate handling uses a compiled C# callback (`ServerCertificateValidationCallback`) with graduated trust:

1. **IP address targets:** auto-bypass (IPs cannot have properly signed certificates)
2. **Hostname name mismatch:** tolerated (certificate is trusted but CN/SAN does not match)
3. **Chain/trust errors on hostnames:** rejected (untrusted CA, self-signed)
4. **`-SkipCertificateCheck`:** full bypass for all certificate errors

The C# type is compiled via `Add-Type` once per AppDomain. Because compiled .NET types cannot be unloaded, the callback survives module re-import. On PowerShell 7+ (`.NET 6+`), `ServicePointManager` triggers `SYSLIB0014` obsolescence warnings; these are suppressed with `#pragma` directives.

This function is idempotent. The `$Script:CWAANetworkInitialized` flag ensures TLS enablement, WebClient creation, and proxy discovery only run once per session. The SSL callback registration has its own guard (`$Script:CWAACertCallbackRegistered`) since it must execute even when called multiple times with different `-SkipCertificateCheck` values.

Called automatically by networking functions (`Install-CWAA`, `Uninstall-CWAA`, `Update-CWAA`, `Set-CWAAProxy`) in their `Begin` blocks.

## EXAMPLES

### Example 1
```powershell
# Called automatically — not typically invoked directly.
# Networking functions call this in their Begin block:
Initialize-CWAANetworking
```

Initializes TLS protocols, creates WebClient/WebProxy objects, and discovers proxy settings from the installed agent.

### Example 2
```powershell
Initialize-CWAANetworking -SkipCertificateCheck
```

Same as above, but also sets the `SkipAll` flag on the SSL callback to bypass all certificate validation for the session.

## PARAMETERS

### -SkipCertificateCheck
Disables all SSL certificate validation for the current PowerShell session. Use when connecting to servers with self-signed certificates on hostname URLs. This affects ALL HTTPS connections in the session, not just Automate operations.

```yaml
Type: SwitchParameter
Required: False
Position: Named
Default value: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

This function takes no pipeline input.

## OUTPUTS

This function produces no output. It initializes `$Script:` scoped networking objects.

## NOTES

- **Private function** — not exported by the module.
- Creates: `$Script:LTWebProxy` (System.Net.WebProxy), `$Script:LTServiceNetWebClient` (System.Net.WebClient).
- Sets flag: `$Script:CWAANetworkInitialized` to `$True` after first successful run.
- Sets flag: `$Script:CWAACertCallbackRegistered` to `$True` after SSL callback compilation.
- Enables TLS 1.2 and TLS 1.3 via bitwise OR on `[Net.ServicePointManager]::SecurityProtocol`.
- Calls `Get-CWAAProxy` to auto-discover proxy settings from the installed agent (non-fatal if no agent is present).
- WebClient and WebProxy are deprecated in .NET 6+ but remain the only option compatible with PowerShell 3.0-5.1.

Author: Chris Taylor

## RELATED LINKS

[Initialize-CWAA](Initialize-CWAA.md)
