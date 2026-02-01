---
external help file:
Module Name: ConnectWiseAutomateAgent
online version:
schema: 2.0.0
---

# Resolve-CWAAServer

## SYNOPSIS
Finds the first reachable ConnectWise Automate server from a list of candidates.

## SYNTAX

```
Resolve-CWAAServer -Server <String[]> [<CommonParameters>]
```

## DESCRIPTION
Resolve-CWAAServer is a private helper that iterates through server URLs, validates each against `$Script:CWAAServerValidationRegex`, normalizes the URL scheme (prepending `https://` to bare hostnames), and tests reachability by downloading the version string from `/LabTech/Agent.aspx`.

The version response uses a pipe-delimited format: six pipe characters followed by a major.minor version number (e.g., `||||||220.105`). The function extracts this version using the regex pattern `(?<=[|]{6})[0-9]{1,3}\.[0-9]{1,3}`.

Returns the first server that responds with a parseable version as a `[PSCustomObject]`, or `$null` if no server is reachable.

Used by `Install-CWAA`, `Uninstall-CWAA`, and `Update-CWAA` to eliminate duplicated server validation logic. Callers handle their own download logic after receiving the resolved server, since URL construction differs per operation.

Requires `$Script:LTServiceNetWebClient` to be initialized (via `Initialize-CWAANetworking`) before calling.

## EXAMPLES

### Example 1
```powershell
# Called internally by Install-CWAA, Uninstall-CWAA, Update-CWAA.
$resolved = Resolve-CWAAServer -Server 'automate.example.com', 'automate2.example.com'
if ($resolved) {
    Write-Verbose "Using server $($resolved.ServerUrl) (version $($resolved.ServerVersion))"
}
```

Tests each server URL in order and returns the first one that responds with a valid version string.

## PARAMETERS

### -Server
One or more server URLs to test. Bare hostnames are normalized with `https://` prefix. Each URL is validated against `$Script:CWAAServerValidationRegex` before testing.

```yaml
Type: String[]
Required: True
Position: Named
Default value: None
Pipeline input: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

This function does not accept pipeline input.

## OUTPUTS

### PSCustomObject
Returns a `[PSCustomObject]` with two properties:
- **ServerUrl** `[string]` — The normalized URL of the first reachable server.
- **ServerVersion** `[string]` — The version string reported by the server (e.g., `220.105`).

Returns `$null` if no server is reachable.

## NOTES

- **Private function** — not exported by the module.
- Depends on `$Script:LTServiceNetWebClient` being initialized by `Initialize-CWAANetworking`.
- Bare hostnames are normalized to `https://` before testing.
- Invalid server formats produce a warning and are skipped, not an error.

Author: Chris Taylor

## RELATED LINKS

[Install-CWAA](../Install-CWAA.md)

[Uninstall-CWAA](../Uninstall-CWAA.md)

[Update-CWAA](../Update-CWAA.md)
