function Get-CWAAProxy {
    <#
    .SYNOPSIS
        Retrieves the current agent proxy settings for module operations.
    .DESCRIPTION
        Reads the current Automate agent proxy settings from the installed agent (if present)
        and stores them in the module-scoped $Script:LTProxy object. The proxy URL,
        username, and password are decrypted using the agent's password string. The
        discovered settings are used by all module communication operations for the
        duration of the session, and returned as the function result.
    .EXAMPLE
        Get-CWAAProxy
        Retrieves and returns the current proxy configuration.
    .EXAMPLE
        $proxy = Get-CWAAProxy
        if ($proxy.Enabled) { Write-Host "Proxy: $($proxy.ProxyServerURL)" }
        Checks whether a proxy is configured and displays the URL.
    .NOTES
        Author: Darren White
        Alias: Get-LTProxy
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTProxy')]
    Param()

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        Write-Verbose 'Discovering Proxy Settings used by the LT Agent.'

        # Decrypt agent passwords from registry. The decrypted PasswordString is used
        # below to decode proxy credentials. This logic was formerly in the private
        # Initialize-CWAAKeys function â€” inlined here because Get-CWAAProxy is the only
        # consumer, and key decryption is inherently the first step of proxy discovery.
        # The $serviceInfo result is reused in Process to avoid a redundant registry read.
        $serviceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
        if ($serviceInfo -and ($serviceInfo | Get-Member | Where-Object { $_.Name -eq 'ServerPassword' })) {
            Write-Debug "Decoding Server Password."
            $Script:LTServiceKeys.ServerPasswordString = ConvertFrom-CWAASecurity -InputString "$($serviceInfo.ServerPassword)"
            if ($Null -ne $serviceInfo -and ($serviceInfo | Get-Member | Where-Object { $_.Name -eq 'Password' })) {
                Write-Debug "Decoding Agent Password."
                $Script:LTServiceKeys.PasswordString = ConvertFrom-CWAASecurity -InputString "$($serviceInfo.Password)" -Key "$($Script:LTServiceKeys.ServerPasswordString)"
            }
            else {
                $Script:LTServiceKeys.PasswordString = ''
            }
        }
        else {
            $Script:LTServiceKeys.ServerPasswordString = ''
            $Script:LTServiceKeys.PasswordString = ''
        }
    }

    Process {
        Try {
            # Reuse $serviceInfo from Begin block â€” eliminates a redundant Get-CWAAInfo call.
            if ($Null -ne $serviceInfo -and ($serviceInfo | Get-Member | Where-Object { $_.Name -eq 'ServerPassword' })) {
                $serviceSettings = Get-CWAASettings -EA 0 -Verbose:$False -WA 0 -Debug:$False
                if ($Null -ne $serviceSettings) {
                    if (($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyServerURL' }) -and ($($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0) -Match 'https?://.+')) {
                        Write-Debug "Proxy Detected. Setting ProxyServerURL to $($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0)"
                        $Script:LTProxy.Enabled = $True
                        $Script:LTProxy.ProxyServerURL = "$($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0)"
                    }
                    else {
                        Write-Debug 'Setting ProxyServerURL to empty.'
                        $Script:LTProxy.Enabled = $False
                        $Script:LTProxy.ProxyServerURL = ''
                    }
                    if ($Script:LTProxy.Enabled -eq $True -and ($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyUsername' }) -and ($serviceSettings | Select-Object -Expand ProxyUsername -EA 0)) {
                        $Script:LTProxy.ProxyUsername = "$(ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))"
                        Write-Debug "Setting ProxyUsername to $(Get-CWAARedactedValue $Script:LTProxy.ProxyUsername)"
                    }
                    else {
                        Write-Debug 'Setting ProxyUsername to empty.'
                        $Script:LTProxy.ProxyUsername = ''
                    }
                    if ($Script:LTProxy.Enabled -eq $True -and ($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyPassword' }) -and ($serviceSettings | Select-Object -Expand ProxyPassword -EA 0)) {
                        $Script:LTProxy.ProxyPassword = "$(ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))"
                        Write-Debug "Setting ProxyPassword to $(Get-CWAARedactedValue $Script:LTProxy.ProxyPassword)"
                    }
                    else {
                        Write-Debug 'Setting ProxyPassword to empty.'
                        $Script:LTProxy.ProxyPassword = ''
                    }
                }
            }
            else {
                Write-Verbose 'No Server password or settings exist. No Proxy information will be available.'
            }
        }
        Catch {
            Write-Error "There was a problem retrieving Proxy Information. $_"
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
        return $Script:LTProxy
    }
}
