function Get-CWAAInfo {
    <#
    .SYNOPSIS
        Retrieves ConnectWise Automate agent configuration from the registry.
    .DESCRIPTION
        Reads all agent configuration values from the Automate agent service registry key and
        returns them as a single object. Resolves the BasePath from the service image path
        if not present in the registry, expands environment variables in BasePath, and parses
        the pipe-delimited Server Address into a clean Server array.

        This function supports ShouldProcess because many internal callers pass
        -WhatIf:$False -Confirm:$False to suppress prompts during automated operations.
    .EXAMPLE
        Get-CWAAInfo
        Returns an object containing all agent registry properties including ID, Server,
        LocationID, BasePath, and other configuration values.
    .EXAMPLE
        Get-CWAAInfo -WhatIf:$False -Confirm:$False
        Retrieves agent info with ShouldProcess suppressed, as used by internal callers.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTServiceInfo
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'Low')]
    [Alias('Get-LTServiceInfo')]
    Param ()

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $exclude = 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', 'PSPath'
    }

    Process {
        if (-not (Test-Path $Script:CWAARegistryRoot)) {
            Write-Error "Unable to find information on LTSvc. Make sure the agent is installed."
            return $Null
        }

        if ($PSCmdlet.ShouldProcess('LTService', 'Retrieving Service Registry Values')) {
            Write-Verbose 'Checking for LT Service registry keys.'
            Try {
                $key = Get-ItemProperty $Script:CWAARegistryRoot -ErrorAction Stop | Select-Object * -Exclude $exclude

                if ($Null -ne $key -and -not ($key | Get-Member -EA 0 | Where-Object { $_.Name -match 'BasePath' })) {
                    $BasePath = $Script:CWAAInstallPath
                    if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LTService') {
                        Try {
                            $BasePath = Get-Item $(
                                Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LTService' -ErrorAction Stop |
                                    Select-Object -Expand ImagePath |
                                    Select-String -Pattern '^[^"][^ ]+|(?<=^")[^"]+' |
                                    Select-Object -Expand Matches -First 1 |
                                    Select-Object -Expand Value -EA 0 -First 1
                            ) | Select-Object -Expand DirectoryName -EA 0
                        }
                        Catch {
                            Write-Debug "Could not resolve BasePath from service ImagePath, using default: $_"
                        }
                    }
                    Add-Member -InputObject $key -MemberType NoteProperty -Name BasePath -Value $BasePath
                }

                $key.BasePath = [System.Environment]::ExpandEnvironmentVariables(
                    $($key | Select-Object -Expand BasePath -EA 0)
                ) -replace '\\\\', '\'

                if ($Null -ne $key -and ($key | Get-Member | Where-Object { $_.Name -match 'Server Address' })) {
                    $Servers = ($key | Select-Object -Expand 'Server Address' -EA 0).Split('|') |
                        ForEach-Object { $_.Trim() -replace '~', '' } |
                        Where-Object { $_ -match '.+' }
                    Add-Member -InputObject $key -MemberType NoteProperty -Name 'Server' -Value $Servers -Force
                }

                return $key
            }
            Catch {
                Write-Error "There was a problem reading the registry keys. $_"
            }
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
