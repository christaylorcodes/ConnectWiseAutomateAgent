function Initialize-CWAANetworking {
    <#
    .SYNOPSIS
        Lazily initializes networking objects on first use rather than at module load.
    .DESCRIPTION
        Performs deferred initialization of SSL certificate validation, TLS protocol enablement,
        WebProxy, WebClient, and proxy configuration. This function is idempotent --
        subsequent calls skip core initialization after the first successful run.

        SSL certificate handling uses a smart callback with graduated trust:
        - IP address targets: auto-bypass (IPs cannot have properly signed certificates)
        - Hostname name mismatch: tolerated (cert is trusted but CN/SAN does not match)
        - Chain/trust errors on hostnames: rejected (untrusted CA, self-signed)
        - -SkipCertificateCheck: full bypass for all certificate errors

        Called automatically by networking functions (Install-CWAA, Uninstall-CWAA,
        Update-CWAA, Set-CWAAProxy) in their Begin blocks. Non-networking functions
        never trigger these side effects, keeping module import fast and clean.
    .PARAMETER SkipCertificateCheck
        Disables all SSL certificate validation for the current PowerShell session.
        Use this when connecting to servers with self-signed certificates on hostname URLs.
        Note: This affects ALL HTTPS connections in the session, not just Automate operations.
    .NOTES
        Version: 0.1.5.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param(
        [switch]$SkipCertificateCheck
    )

    Write-Debug "Starting $($MyInvocation.InvocationName)"

    # Smart SSL certificate callback: Registered once per session. Uses graduated trust
    # rather than blanket bypass. The callback handles three scenarios:
    #   1. IP address targets: auto-bypass (IPs cannot have properly signed certs)
    #   2. Name mismatch only: tolerate (cert is trusted but hostname differs from CN/SAN)
    #   3. Chain/trust errors: reject unless SkipAll is set via -SkipCertificateCheck
    # On .NET 6+ (PS 7+), ServicePointManager triggers SYSLIB0014 obsolescence warning.
    # Conditionally wrap with pragma directives based on the runtime.
    if (-not $Script:CWAACertCallbackRegistered) {
        Try {
            # Check if the type already exists in the AppDomain (survives module re-import
            # because .NET types cannot be unloaded). Only call Add-Type if it's truly new.
            if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
                $sslCallbackSource = @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class ServerCertificateValidationCallback
{
    public static bool SkipAll = false;
    public static void Register()
    {
        if (ServicePointManager.ServerCertificateValidationCallback == null)
        {
            ServicePointManager.ServerCertificateValidationCallback +=
                delegate(Object obj, X509Certificate certificate,
                         X509Chain chain, SslPolicyErrors errors)
                {
                    if (errors == SslPolicyErrors.None) return true;
                    if (SkipAll) return true;
                    var request = obj as HttpWebRequest;
                    if (request != null)
                    {
                        IPAddress ip;
                        if (IPAddress.TryParse(request.RequestUri.Host, out ip))
                            return true;
                    }
                    if (errors == SslPolicyErrors.RemoteCertificateNameMismatch)
                        return true;
                    return false;
                };
        }
    }
}
"@
                if ($PSVersionTable.PSEdition -eq 'Core') {
                    $sslCallbackSource = "#pragma warning disable SYSLIB0014`n" + $sslCallbackSource + "`n#pragma warning restore SYSLIB0014"
                }
                Add-Type -Debug:$False $sslCallbackSource
            }
            [ServerCertificateValidationCallback]::Register()
            $Script:CWAACertCallbackRegistered = $True
        }
        Catch {
            Write-Debug "SSL certificate validation callback could not be registered: $_"
        }
    }

    # Full bypass mode: sets the SkipAll flag on the C# class so the callback
    # accepts all certificates regardless of error type. Useful for servers with
    # self-signed certificates on hostname URLs.
    if ($SkipCertificateCheck -and $Script:CWAACertCallbackRegistered) {
        if (-not [ServerCertificateValidationCallback]::SkipAll) {
            Write-Warning 'SSL certificate validation is disabled for this session. This affects all HTTPS connections in this PowerShell session.'
            [ServerCertificateValidationCallback]::SkipAll = $True
        }
    }

    # Idempotency guard: TLS, WebClient, and proxy only need to run once per session
    if ($Script:CWAANetworkInitialized -eq $True) {
        Write-Debug "Initialize-CWAANetworking: Core networking already initialized, skipping."
        return
    }

    Write-Verbose 'Initializing networking subsystem (TLS, WebClient, Proxy).'

    # TLS protocol enablement: Enable TLS 1.2 and 1.3 for secure communication.
    # TLS 1.0 and 1.1 are deprecated (POODLE, BEAST vulnerabilities) and intentionally
    # excluded. Each version is added via bitwise OR to preserve already-enabled protocols.
    Try {
        if ([Net.SecurityProtocolType]::Tls12) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
        if ([Net.SecurityProtocolType]::Tls13) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13 }
    }
    Catch {
        Write-Debug "TLS protocol configuration skipped (may not apply to this .NET runtime): $_"
    }

    # WebClient and WebProxy are deprecated in .NET 6+ (SYSLIB0014) but still functional.
    # They remain the only option compatible with PowerShell 3.0-5.1 (.NET Framework).
    Try {
        $Script:LTWebProxy = New-Object System.Net.WebProxy

        $Script:LTServiceNetWebClient = New-Object System.Net.WebClient
        $Script:LTServiceNetWebClient.Proxy = $Script:LTWebProxy
    }
    Catch {
        Write-Warning "Failed to initialize network objects (WebClient/WebProxy may be unavailable in this .NET runtime). $_"
    }

    # Discover proxy settings from the installed agent (if present).
    # Errors are non-fatal: the module works without proxy on systems with no agent.
    $Null = Get-CWAAProxy -ErrorAction Continue

    $Script:CWAANetworkInitialized = $True
    Write-Debug "Exiting $($MyInvocation.InvocationName)"
}
