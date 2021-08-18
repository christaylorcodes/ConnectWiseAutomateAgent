
function Set-CWAAProxy {
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
        [alias('Detect')]
        [alias('AutoDetect')]
        [switch]$DetectProxy,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [alias('Clear')]
        [alias('Reset')]
        [alias('ClearProxy')]
        [switch]$ResetProxy
    )

    Begin {
        Clear-Variable LTServiceSettingsChanged, LTSS, LTServiceRestartNeeded, proxyURL, proxyUser, proxyPass, passwd, Svr -EA 0 -WhatIf:$False -Confirm:$False #Clearing Variables for use
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"

        try {
            $LTSS = Get-CWAASettings -EA 0 -Verbose:$False -WA 0 -Debug:$False
        }
        catch {}

    }

    Process {

        if (
            (($ResetProxy -eq $True) -and (($DetectProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) -or
            (($DetectProxy -eq $True) -and (($ResetProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) -or
            ((($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword)) -and (($ResetProxy -eq $True) -or ($DetectProxy -eq $True))) -or
            ((($ProxyUsername) -or ($ProxyPassword)) -and (-not ($ProxyServerURL) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword) -or ($ResetProxy -eq $True) -or ($DetectProxy -eq $True))) -or
            ((($EncodedProxyUsername) -or ($EncodedProxyPassword)) -and (-not ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($ResetProxy -eq $True) -or ($DetectProxy -eq $True)))
        ) { Write-Error "ERROR: Line $(LINENUM): Set-CWAAProxy: Invalid Parameter specified" -ErrorAction Stop }
        if (-not (($ResetProxy -eq $True) -or ($DetectProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) {
            if ($Args.Count -gt 0) { Write-Error "ERROR: Line $(LINENUM): Set-CWAAProxy: Unknown Parameter specified" -ErrorAction Stop }
            else { Write-Error "ERROR: Line $(LINENUM): Set-CWAAProxy: Required Parameters Missing" -ErrorAction Stop }
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
                    $Servers = @($("$($LTSS|Select-Object -Expand 'ServerAddress' -EA 0)|www.connectwise.com").Split('|') | ForEach-Object { $_.Trim() })
                    Foreach ($Svr In $Servers) {
                        if (-not ($Script:LTProxy.Enabled)) {
                            if ($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$') {
                                $Svr = $Svr -replace 'https?://', ''
                                Try {
                                    $Script:LTProxy.ProxyServerURL = $Script:LTWebProxy.GetProxy("http://$($Svr)").Authority
                                }
                                catch {}
                                if (($Null -ne $Script:LTProxy.ProxyServerURL) -and ($Script:LTProxy.ProxyServerURL -ne '') -and ($Script:LTProxy.ProxyServerURL -notcontains "$($Svr)")) {
                                    Write-Debug "Line $(LINENUM): Detected Proxy URL: $($Script:LTProxy.ProxyServerURL) on server $($Svr)"
                                    $Script:LTProxy.Enabled = $True
                                }
                            }
                        }
                    }
                    if (-not ($Script:LTProxy.Enabled)) {
                        if (($Script:LTProxy.ProxyServerURL -eq '') -or ($Script:LTProxy.ProxyServerURL -contains '$Svr')) {
                            $Script:LTProxy.ProxyServerURL = netsh winhttp show proxy | Select-String -Pattern '(?i)(?<=Proxyserver.*http\=)([^;\r\n]*)' -EA 0 | ForEach-Object { $_.matches } | Select-Object -Expand value
                        }
                        if (($Null -eq $Script:LTProxy.ProxyServerURL) -or ($Script:LTProxy.ProxyServerURL -eq '')) {
                            $Script:LTProxy.ProxyServerURL = ''
                            $Script:LTProxy.Enabled = $False
                        }
                        else {
                            $Script:LTProxy.Enabled = $True
                            Write-Debug "Line $(LINENUM): Detected Proxy URL: $($Script:LTProxy.ProxyServerURL)"
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
                                $passwd = ConvertTo-SecureString $proxyPass -AsPlainText -Force; ## Website credentials
                            }
                        }
                        if (($EncodedProxyPassword)) {
                            foreach ($proxyPass in $EncodedProxyPassword) {
                                $Script:LTProxy.ProxyPassword = $(ConvertFrom-CWAASecurity -InputString "$($proxyPass)" -Key ("$($Script:LTServiceKeys.PasswordString)", ''))
                                $passwd = ConvertTo-SecureString $Script:LTProxy.ProxyPassword -AsPlainText -Force; ## Website credentials
                            }
                        }
                        $Script:LTWebProxy.Credentials = New-Object System.Management.Automation.PSCredential ($Script:LTProxy.ProxyUsername, $passwd);
                    }
                    $Script:LTServiceNetWebClient.Proxy = $Script:LTWebProxy
                }
            }
        }

        Catch {
            Write-Error "ERROR: Line $(LINENUM): There was an error during the Proxy Configuration process. $($Error[0])" -ErrorAction Stop
        }
    }

    End {
        if ($?) {
            $LTServiceSettingsChanged = $False
            if ($Null -ne ($LTSS)) {
                if (($LTSS | Get-Member | Where-Object { $_.Name -eq 'ProxyServerURL' })) {
                    if (($($LTSS | Select-Object -Expand ProxyServerURL -EA 0) -replace 'https?://', '' -ne $Script:LTProxy.ProxyServerURL) -and (($($LTSS | Select-Object -Expand ProxyServerURL -EA 0) -replace 'https?://', '' -eq '' -and $Script:LTProxy.Enabled -eq $True -and $Script:LTProxy.ProxyServerURL -match '.+\..+') -or ($($LTSS | Select-Object -Expand ProxyServerURL -EA 0) -replace 'https?://', '' -ne '' -and ($Script:LTProxy.ProxyServerURL -ne '' -or $Script:LTProxy.Enabled -eq $False)))) {
                        Write-Debug "Line $(LINENUM): ProxyServerURL Changed: Old Value: $($LTSS|Select-Object -Expand ProxyServerURL -EA 0) New Value: $($Script:LTProxy.ProxyServerURL)"
                        $LTServiceSettingsChanged = $True
                    }
                    if (($LTSS | Get-Member | Where-Object { $_.Name -eq 'ProxyUsername' }) -and ($LTSS | Select-Object -Expand ProxyUsername -EA 0)) {
                        if ($(ConvertFrom-CWAASecurity -InputString "$($LTSS|Select-Object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)", '')) -ne $Script:LTProxy.ProxyUsername) {
                            Write-Debug "Line $(LINENUM): ProxyUsername Changed: Old Value: $(ConvertFrom-CWAASecurity -InputString "$($LTSS|Select-Object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",'')) New Value: $($Script:LTProxy.ProxyUsername)"
                            $LTServiceSettingsChanged = $True
                        }
                    }
                    if ($Null -ne ($LTSS) -and ($LTSS | Get-Member | Where-Object { $_.Name -eq 'ProxyPassword' }) -and ($LTSS | Select-Object -Expand ProxyPassword -EA 0)) {
                        if ($(ConvertFrom-CWAASecurity -InputString "$($LTSS|Select-Object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)", '')) -ne $Script:LTProxy.ProxyPassword) {
                            Write-Debug "Line $(LINENUM): ProxyPassword Changed: Old Value: $(ConvertFrom-CWAASecurity -InputString "$($LTSS|Select-Object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",'')) New Value: $($Script:LTProxy.ProxyPassword)"
                            $LTServiceSettingsChanged = $True
                        }
                    }
                }
                Elseif ($Script:LTProxy.Enabled -eq $True -and $Script:LTProxy.ProxyServerURL -match '(https?://)?.+\..+') {
                    Write-Debug "Line $(LINENUM): ProxyServerURL Changed: Old Value: NOT SET New Value: $($Script:LTProxy.ProxyServerURL)"
                    $LTServiceSettingsChanged = $True
                }
            }
            else {
                $svcRun = ('LTService') | Get-Service -EA 0 | Where-Object { $_.Status -eq 'Running' } | Measure-Object | Select-Object -Expand Count
                if (($svcRun -gt 0) -and ($($Script:LTProxy.ProxyServerURL) -match '.+')) {
                    $LTServiceSettingsChanged = $True
                }
            }
            if ($LTServiceSettingsChanged -eq $True) {
                if ((Get-Service 'LTService', 'LTSvcMon' -ErrorAction SilentlyContinue | Where-Object { $_.Status -match 'Running' })) { $LTServiceRestartNeeded = $True; try { Stop-CWAA -EA 0 -WA 0 } catch {} }
                Write-Verbose 'Updating LabTech\Service\Settings Proxy Configuration.'
                if ( $PSCmdlet.ShouldProcess('LTService Registry', 'Update') ) {
                    $Svr = $($Script:LTProxy.ProxyServerURL); if (($Svr -ne '') -and ($Svr -notmatch 'https?://')) { $Svr = "http://$($Svr)" }
                    @{'ProxyServerURL'  = $Svr;
                        'ProxyUserName' = "$(ConvertTo-CWAASecurity -InputString "$($Script:LTProxy.ProxyUserName)" -Key "$($Script:LTServiceKeys.PasswordString)")";
                        'ProxyPassword' = "$(ConvertTo-CWAASecurity -InputString "$($Script:LTProxy.ProxyPassword)" -Key "$($Script:LTServiceKeys.PasswordString)")"
                    }.GetEnumerator() | ForEach-Object {
                        Write-Debug "Line $(LINENUM): Setting Registry value for $($_.Name) to `"$($_.Value)`""
                        Set-ItemProperty -Path 'HKLM:Software\LabTech\Service\Settings' -Name $($_.Name) -Value $($_.Value) -EA 0 -Confirm:$False
                    }
                }
                if ($LTServiceRestartNeeded -eq $True) { try { Start-CWAA -EA 0 -WA 0 } catch {} }
            }
        }
        else { $Error[0] }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }

}
