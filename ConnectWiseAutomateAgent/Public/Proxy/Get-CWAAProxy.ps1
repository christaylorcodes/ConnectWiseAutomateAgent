
function Get-CWAAProxy {
    [CmdletBinding()]
    [Alias('Get-LTProxy')]
    Param(
    )

    Begin {
        Clear-Variable CustomProxyObject, LTSI, LTSS -EA 0 -WhatIf:$False -Confirm:$False #Clearing Variables for use
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"
        Write-Verbose 'Discovering Proxy Settings used by the LT Agent.'
        $Null = Initialize-CWAAKeys
    }

    Process {
        Try {
            $LTSI = Get-CWAAInfo -EA 0 -WA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
            if ($Null -ne $LTSI -and ($LTSI | Get-Member | Where-Object { $_.Name -eq 'ServerPassword' })) {
                $LTSS = Get-CWAASettings -EA 0 -Verbose:$False -WA 0 -Debug:$False
                if ($Null -ne $LTSS) {
                    if (($LTSS | Get-Member | Where-Object { $_.Name -eq 'ProxyServerURL' }) -and ($($LTSS | Select-Object -Expand ProxyServerURL -EA 0) -Match 'https?://.+')) {
                        Write-Debug "Line $(LINENUM): Proxy Detected. Setting ProxyServerURL to $($LTSS|Select-Object -Expand ProxyServerURL -EA 0)"
                        $Script:LTProxy.Enabled = $True
                        $Script:LTProxy.ProxyServerURL = "$($LTSS|Select-Object -Expand ProxyServerURL -EA 0)"
                    }
                    else {
                        Write-Debug "Line $(LINENUM): Setting ProxyServerURL to "
                        $Script:LTProxy.Enabled = $False
                        $Script:LTProxy.ProxyServerURL = ''
                    }
                    if ($Script:LTProxy.Enabled -eq $True -and ($LTSS | Get-Member | Where-Object { $_.Name -eq 'ProxyUsername' }) -and ($LTSS | Select-Object -Expand ProxyUsername -EA 0)) {
                        $Script:LTProxy.ProxyUsername = "$(ConvertFrom-CWAASecurity -InputString "$($LTSS|Select-Object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))"
                        Write-Debug "Line $(LINENUM): Setting ProxyUsername to $($Script:LTProxy.ProxyUsername)"
                    }
                    else {
                        Write-Debug "Line $(LINENUM): Setting ProxyUsername to "
                        $Script:LTProxy.ProxyUsername = ''
                    }
                    if ($Script:LTProxy.Enabled -eq $True -and ($LTSS | Get-Member | Where-Object { $_.Name -eq 'ProxyPassword' }) -and ($LTSS | Select-Object -Expand ProxyPassword -EA 0)) {
                        $Script:LTProxy.ProxyPassword = "$(ConvertFrom-CWAASecurity -InputString "$($LTSS|Select-Object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))"
                        Write-Debug "Line $(LINENUM): Setting ProxyPassword to $($Script:LTProxy.ProxyPassword)"
                    }
                    else {
                        Write-Debug "Line $(LINENUM): Setting ProxyPassword to "
                        $Script:LTProxy.ProxyPassword = ''
                    }
                }
            }
            else {
                Write-Verbose 'No Server password or settings exist. No Proxy information will be available.'
            }
        }
        Catch {
            Write-Error "ERROR: Line $(LINENUM): There was a problem retrieving Proxy Information. $($Error[0])"
        }
    }

    End {
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
        return $Script:LTProxy
    }
}
