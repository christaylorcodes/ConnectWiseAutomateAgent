function Resolve-CWAAServer {
    <#
    .SYNOPSIS
        Finds the first reachable ConnectWise Automate server from a list of candidates.
    .DESCRIPTION
        Private helper that iterates through server URLs, validates each against the
        server format regex, normalizes the URL scheme, and tests reachability by
        downloading the version string from /LabTech/Agent.aspx. Returns the first
        server that responds with a parseable version.

        Used by Install-CWAA, Uninstall-CWAA, and Update-CWAA to eliminate the
        duplicated server validation loop. Callers handle their own download logic
        after receiving the resolved server, since URL construction differs per operation.

        Requires $Script:LTServiceNetWebClient to be initialized (via Initialize-CWAANetworking)
        before calling.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string[]]$Server
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        # Normalize: prepend https:// to bare hostnames/IPs so the loop has consistent URLs
        $normalizedServers = ForEach ($serverUrl in $Server) {
            if ($serverUrl -notmatch 'https?://.+') { "https://$serverUrl" }
            else { $serverUrl }
        }

        ForEach ($serverUrl in $normalizedServers) {
            if ($serverUrl -match $Script:CWAAServerValidationRegex) {
                # Ensure a scheme is present for the actual request
                if ($serverUrl -notmatch 'https?://.+') { $serverUrl = "http://$serverUrl" }
                Try {
                    $versionCheckUrl = "$serverUrl/LabTech/Agent.aspx"
                    Write-Debug "Testing Server Response and Version: $versionCheckUrl"
                    $serverVersionResponse = $Script:LTServiceNetWebClient.DownloadString($versionCheckUrl)
                    Write-Debug "Raw Response: $serverVersionResponse"

                    # Extract version from the pipe-delimited response string.
                    # Format: six pipe characters followed by major.minor version (e.g. '||||||220.105')
                    $serverVersion = $serverVersionResponse |
                        Select-String -Pattern '(?<=[|]{6})[0-9]{1,3}\.[0-9]{1,3}' |
                        ForEach-Object { $_.Matches } |
                        Select-Object -Expand Value -ErrorAction SilentlyContinue

                    if ($null -eq $serverVersion) {
                        Write-Verbose "Unable to test version response from $serverUrl."
                        Continue
                    }

                    Write-Verbose "Server $serverUrl responded with version $serverVersion."
                    return [PSCustomObject]@{
                        ServerUrl     = $serverUrl
                        ServerVersion = $serverVersion
                    }
                }
                Catch {
                    Write-Warning "Error encountered testing server $serverUrl."
                    Continue
                }
            }
            else {
                Write-Warning "Server address $serverUrl is not formatted correctly. Example: https://automate.domain.com"
            }
        }

        # No server responded successfully
        Write-Debug "No reachable server found from candidates: $($Server -join ', ')"
        return $null
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
