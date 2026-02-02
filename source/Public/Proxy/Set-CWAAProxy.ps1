function Set-CWAAProxy {
    <#
    .SYNOPSIS
        Configures module proxy settings for all operations during the current session.
    .DESCRIPTION
        Sets or clears Proxy settings needed for module function and agent operations.
        If an agent is already installed, this function will update the ProxyUsername,
        ProxyPassword, and ProxyServerURL values in the agent registry settings.
        Agent services will be restarted for changes (if found) to be applied.
    .PARAMETER ProxyServerURL
        The URL and optional port to assign as the proxy server for module operations
        and for the installed agent (if present).
        Example: Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080'
        May be used with ProxyUsername/ProxyPassword or EncodedProxyUsername/EncodedProxyPassword.
    .PARAMETER ProxyUsername
        Plain text username for proxy authentication.
        Must be used with ProxyServerURL and ProxyPassword.
    .PARAMETER ProxyPassword
        Plain text password for proxy authentication.
        Must be used with ProxyServerURL and ProxyUsername.
    .PARAMETER EncodedProxyUsername
        Encoded username for proxy authentication, encrypted with the agent password.
        Will be decoded using the agent password. Must be used with ProxyServerURL
        and EncodedProxyPassword.
    .PARAMETER EncodedProxyPassword
        Encoded password for proxy authentication, encrypted with the agent password.
        Will be decoded using the agent password. Must be used with ProxyServerURL
        and EncodedProxyUsername.
    .PARAMETER DetectProxy
        Automatically detect system proxy settings for module operations.
        Discovered settings are applied to the installed agent (if present).
        Cannot be used with other parameters.
    .PARAMETER ProxyCredential
        A PSCredential object containing the proxy username and password.
        This is the preferred secure alternative to passing -ProxyUsername
        and -ProxyPassword separately. Must be used with -ProxyServerURL.
    .PARAMETER ResetProxy
        Clears any currently defined proxy settings for module operations.
        Changes are applied to the installed agent (if present).
        Cannot be used with other parameters.
    .PARAMETER SkipCertificateCheck
        Bypasses SSL/TLS certificate validation for server connections.
        Use in lab or test environments with self-signed certificates.
    .EXAMPLE
        Set-CWAAProxy -DetectProxy
        Automatically detects and configures the system proxy.
    .EXAMPLE
        Set-CWAAProxy -ResetProxy
        Clears all proxy settings.
    .EXAMPLE
        Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080'
        Sets the proxy server URL without authentication.
    .NOTES
        Author: Darren White
        Alias: Set-LTProxy
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Set-LTProxy')]
    Param(
        [parameter(Mandatory = $False, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0)]
        [string]$ProxyServerURL,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True, Position = 1)]
        [string]$ProxyUsername,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True, Position = 2)]
        [SecureString]$ProxyPassword,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [string]$EncodedProxyUsername,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [SecureString]$EncodedProxyPassword,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $ProxyCredential,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [alias('Detect')]
        [alias('AutoDetect')]
        [switch]$DetectProxy,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [alias('Clear')]
        [alias('Reset')]
        [alias('ClearProxy')]
        [switch]$ResetProxy,
        [switch]$SkipCertificateCheck
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"

        # Lazy initialization of SSL/TLS, WebClient, and proxy configuration.
        # Only runs once per session, skips immediately on subsequent calls.
        $Null = Initialize-CWAANetworking -SkipCertificateCheck:$SkipCertificateCheck

        try {
            $serviceSettings = Get-CWAASettings -EA 0 -Verbose:$False -WA 0 -Debug:$False
        }
        catch { Write-Debug "Failed to retrieve service settings. $_" }
    }

    Process {
        # If a PSCredential was provided, extract username and password.
        # This is the preferred secure alternative to passing plain text proxy credentials.
        if ($ProxyCredential) {
            $ProxyUsername = $ProxyCredential.UserName
            $ProxyPassword = $ProxyCredential.GetNetworkCredential().Password
        }

        if (
            (($ResetProxy -eq $True) -and (($DetectProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) -or
            (($DetectProxy -eq $True) -and (($ResetProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) -or
            ((($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword)) -and (($ResetProxy -eq $True) -or ($DetectProxy -eq $True))) -or
            ((($ProxyUsername) -or ($ProxyPassword)) -and (-not ($ProxyServerURL) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword) -or ($ResetProxy -eq $True) -or ($DetectProxy -eq $True))) -or
            ((($EncodedProxyUsername) -or ($EncodedProxyPassword)) -and (-not ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($ResetProxy -eq $True) -or ($DetectProxy -eq $True)))
        ) { Write-Error "Set-CWAAProxy: Invalid parameter combination specified." -ErrorAction Stop }
        if (-not (($ResetProxy -eq $True) -or ($DetectProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) {
            if ($Args.Count -gt 0) { Write-Error "Set-CWAAProxy: Unknown parameter specified." -ErrorAction Stop }
            else { Write-Error "Set-CWAAProxy: Required parameters missing." -ErrorAction Stop }
        }

        Try {
            if ($($ResetProxy) -eq $True) {
                Write-Verbose 'ResetProxy selected. Clearing Proxy Settings.'
                if ( $PSCmdlet.ShouldProcess('LTProxy', 'Clear') ) {
                    $Script:LTProxy.Enabled = $False
                    $Script:LTProxy.ProxyServerURL = ''
                    $Script:LTProxy.ProxyUsername = ''
                    $Script:LTProxy.ProxyPassword = ''
                    $Script:LTWebProxy = New-Object System.Net.WebProxy
                    $Script:LTServiceNetWebClient.Proxy = $Script:LTWebProxy
                }
            }
            Elseif ($($DetectProxy) -eq $True) {
                Write-Verbose 'DetectProxy selected. Attempting to Detect Proxy Settings.'
                if ( $PSCmdlet.ShouldProcess('LTProxy', 'Detect') ) {
                    $Script:LTWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
                    $Script:LTProxy.Enabled = $False
                    $Script:LTProxy.ProxyServerURL = ''
                    $Servers = @($("$($serviceSettings | Select-Object -Expand 'ServerAddress' -EA 0)|www.connectwise.com").Split('|') | ForEach-Object { $_.Trim() })
                    Foreach ($serverUrl In $Servers) {
                        if (-not ($Script:LTProxy.Enabled)) {
                            if ($serverUrl -match $Script:CWAAServerValidationRegex) {
                                $serverUrl = $serverUrl -replace 'https?://', ''
                                Try {
                                    $Script:LTProxy.ProxyServerURL = $Script:LTWebProxy.GetProxy("http://$($serverUrl)").Authority
                                }
                                catch { Write-Debug "Failed to get proxy for server $serverUrl. $_" }
                                if (($Null -ne $Script:LTProxy.ProxyServerURL) -and ($Script:LTProxy.ProxyServerURL -ne '') -and ($Script:LTProxy.ProxyServerURL -notcontains "$($serverUrl)")) {
                                    Write-Debug "Detected Proxy URL: $($Script:LTProxy.ProxyServerURL) on server $($serverUrl)"
                                    $Script:LTProxy.Enabled = $True
                                }
                            }
                        }
                    }
                    if (-not ($Script:LTProxy.Enabled)) {
                        if (($Script:LTProxy.ProxyServerURL -eq '') -or ($Script:LTProxy.ProxyServerURL -contains '$serverUrl')) {
                            $Script:LTProxy.ProxyServerURL = netsh winhttp show proxy | Select-String -Pattern '(?i)(?<=Proxyserver.*http\=)([^;\r\n]*)' -EA 0 | ForEach-Object { $_.matches } | Select-Object -Expand value
                        }
                        if (($Null -eq $Script:LTProxy.ProxyServerURL) -or ($Script:LTProxy.ProxyServerURL -eq '')) {
                            $Script:LTProxy.ProxyServerURL = ''
                            $Script:LTProxy.Enabled = $False
                        }
                        else {
                            $Script:LTProxy.Enabled = $True
                            Write-Debug "Detected Proxy URL: $($Script:LTProxy.ProxyServerURL)"
                        }
                    }
                    $Script:LTProxy.ProxyUsername = ''
                    $Script:LTProxy.ProxyPassword = ''
                    $Script:LTServiceNetWebClient.Proxy = $Script:LTWebProxy
                }
            }
            Elseif (($ProxyServerURL)) {
                if ( $PSCmdlet.ShouldProcess('LTProxy', 'Set') ) {
                    foreach ($ProxyURL in $ProxyServerURL) {
                        $Script:LTWebProxy = New-Object System.Net.WebProxy($ProxyURL, $true);
                        $Script:LTProxy.Enabled = $True
                        $Script:LTProxy.ProxyServerURL = $ProxyURL
                    }
                    Write-Verbose "Setting Proxy URL to: $($ProxyServerURL)"
                    if ((($ProxyUsername) -and ($ProxyPassword)) -or (($EncodedProxyUsername) -and ($EncodedProxyPassword))) {
                        if (($ProxyUsername)) {
                            foreach ($proxyUser in $ProxyUsername) {
                                $Script:LTProxy.ProxyUsername = $proxyUser
                            }
                        }
                        if (($EncodedProxyUsername)) {
                            foreach ($proxyUser in $EncodedProxyUsername) {
                                $Script:LTProxy.ProxyUsername = $(ConvertFrom-CWAASecurity -InputString "$($proxyUser)" -Key ("$($Script:LTServiceKeys.PasswordString)", ''))
                            }
                        }
                        if (($ProxyPassword)) {
                            foreach ($proxyPass in $ProxyPassword) {
                                $Script:LTProxy.ProxyPassword = $proxyPass
                                $passwd = ConvertTo-SecureString $proxyPass -AsPlainText -Force;
                            }
                        }
                        if (($EncodedProxyPassword)) {
                            foreach ($proxyPass in $EncodedProxyPassword) {
                                $Script:LTProxy.ProxyPassword = $(ConvertFrom-CWAASecurity -InputString "$($proxyPass)" -Key ("$($Script:LTServiceKeys.PasswordString)", ''))
                                $passwd = ConvertTo-SecureString $Script:LTProxy.ProxyPassword -AsPlainText -Force;
                            }
                        }
                        $Script:LTWebProxy.Credentials = New-Object System.Management.Automation.PSCredential ($Script:LTProxy.ProxyUsername, $passwd);
                    }
                    $Script:LTServiceNetWebClient.Proxy = $Script:LTWebProxy
                }
            }

            # Apply settings to agent registry if changes detected
            $settingsChanged = $False
            if ($Null -ne ($serviceSettings)) {
                if (($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyServerURL' })) {
                    if (($($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0) -replace 'https?://', '' -ne $Script:LTProxy.ProxyServerURL) -and (($($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0) -replace 'https?://', '' -eq '' -and $Script:LTProxy.Enabled -eq $True -and $Script:LTProxy.ProxyServerURL -match '.+\..+') -or ($($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0) -replace 'https?://', '' -ne '' -and ($Script:LTProxy.ProxyServerURL -ne '' -or $Script:LTProxy.Enabled -eq $False)))) {
                        Write-Debug "ProxyServerURL Changed: Old Value: $($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0) New Value: $($Script:LTProxy.ProxyServerURL)"
                        $settingsChanged = $True
                    }
                    if (($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyUsername' }) -and ($serviceSettings | Select-Object -Expand ProxyUsername -EA 0)) {
                        if ($(ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)", '')) -ne $Script:LTProxy.ProxyUsername) {
                            Write-Debug "ProxyUsername Changed: Old Value: $(Get-CWAARedactedValue (ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))) New Value: $(Get-CWAARedactedValue $Script:LTProxy.ProxyUsername)"
                            $settingsChanged = $True
                        }
                    }
                    if ($Null -ne ($serviceSettings) -and ($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyPassword' }) -and ($serviceSettings | Select-Object -Expand ProxyPassword -EA 0)) {
                        if ($(ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)", '')) -ne $Script:LTProxy.ProxyPassword) {
                            Write-Debug "ProxyPassword Changed: Old Value: $(Get-CWAARedactedValue (ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))) New Value: $(Get-CWAARedactedValue $Script:LTProxy.ProxyPassword)"
                            $settingsChanged = $True
                        }
                    }
                }
                Elseif ($Script:LTProxy.Enabled -eq $True -and $Script:LTProxy.ProxyServerURL -match '(https?://)?.+\..+') {
                    Write-Debug "ProxyServerURL Changed: Old Value: NOT SET New Value: $($Script:LTProxy.ProxyServerURL)"
                    $settingsChanged = $True
                }
            }
            else {
                $runningServiceCount = ('LTService') | Get-Service -EA 0 | Where-Object { $_.Status -eq 'Running' } | Measure-Object | Select-Object -Expand Count
                if (($runningServiceCount -gt 0) -and ($($Script:LTProxy.ProxyServerURL) -match '.+')) {
                    $settingsChanged = $True
                }
            }
            if ($settingsChanged -eq $True) {
                $serviceRestartNeeded = $False
                if ((Get-Service $Script:CWAAServiceNames -ErrorAction SilentlyContinue | Where-Object { $_.Status -match 'Running' })) {
                    $serviceRestartNeeded = $True
                    try { Stop-CWAA -EA 0 -WA 0 } catch { Write-Debug "Failed to stop services before proxy update. $_" }
                }
                Write-Verbose 'Updating Automate agent proxy configuration.'
                if ( $PSCmdlet.ShouldProcess('LTService Registry', 'Update') ) {
                    $serverUrl = $($Script:LTProxy.ProxyServerURL); if (($serverUrl -ne '') -and ($serverUrl -notmatch 'https?://')) { $serverUrl = "http://$($serverUrl)" }
                    @{'ProxyServerURL'  = $serverUrl;
                        'ProxyUserName' = "$(ConvertTo-CWAASecurity -InputString "$($Script:LTProxy.ProxyUserName)" -Key "$($Script:LTServiceKeys.PasswordString)")";
                        'ProxyPassword' = "$(ConvertTo-CWAASecurity -InputString "$($Script:LTProxy.ProxyPassword)" -Key "$($Script:LTServiceKeys.PasswordString)")"
                    }.GetEnumerator() | ForEach-Object {
                        Write-Debug "Setting Registry value for $($_.Name) to `"$($_.Value)`""
                        Set-ItemProperty -Path $Script:CWAARegistrySettings -Name $($_.Name) -Value $($_.Value) -EA 0 -Confirm:$False
                    }
                }
                if ($serviceRestartNeeded -eq $True) {
                    try { Start-CWAA -EA 0 -WA 0 } catch { Write-Debug "Failed to restart services after proxy update. $_" }
                }
                Write-CWAAEventLog -EventId 3020 -EntryType Information -Message "Proxy settings updated. Enabled: $($Script:LTProxy.Enabled), Server: $($Script:LTProxy.ProxyServerURL)"
            }
        }
        Catch {
            Write-CWAAEventLog -EventId 3022 -EntryType Error -Message "Proxy configuration failed. Error: $($_.Exception.Message)"
            Write-Error "There was an error during the Proxy Configuration process. $_" -ErrorAction Stop
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
