function Test-CWAAUrlAvailable {
    <#
    .SYNOPSIS
        Tests whether a file URL on the Automate server answers with HTTP 200.
    .DESCRIPTION
        Sends a single HTTP/1.0 request (no keep-alive) to the URL, through the module
        proxy when one is enabled, and aborts it as soon as the response headers arrive
        so the file body is not downloaded. Returns $true only for a 200 response.

        Request failures (DNS, connection refused, 4xx/5xx) are not caught here; the
        exception reaches the caller, which reports it in the context of its own download.
    .PARAMETER Url
        The full URL to probe.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$Url
    )

    $request = [System.Net.WebRequest]::Create($Url)
    if (($Script:LTProxy.Enabled) -eq $True) {
        Write-Debug "Proxy Configuration Needed. Applying Proxy Settings to request."
        $request.Proxy = $Script:LTWebProxy
    }
    $request.KeepAlive = $False
    $request.ProtocolVersion = '1.0'
    $response = $request.GetResponse()
    $request.Abort()
    return ($response.StatusCode -eq 200)
}
