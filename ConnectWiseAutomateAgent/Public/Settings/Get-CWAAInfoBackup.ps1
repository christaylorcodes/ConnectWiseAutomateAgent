function Get-CWAAInfoBackup {
    <#
    .SYNOPSIS
        Retrieves backed-up ConnectWise Automate agent configuration from the registry.
    .DESCRIPTION
        Reads all agent configuration values from the LabTechBackup registry key
        and returns them as a single object. This backup is created by New-CWAABackup and
        stores a snapshot of the agent configuration at the time of backup.

        Expands environment variables in BasePath and parses the pipe-delimited Server
        Address into a clean Server array, matching the behavior of Get-CWAAInfo.
    .EXAMPLE
        Get-CWAAInfoBackup
        Returns an object containing all backed-up agent registry properties.
    .EXAMPLE
        Get-CWAAInfoBackup | Select-Object -ExpandProperty Server
        Returns only the server addresses from the backup configuration.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTServiceInfoBackup
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTServiceInfoBackup')]
    Param ()

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $exclude = 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', 'PSPath'
    }

    Process {
        if (-not (Test-Path $Script:CWAARegistryBackup)) {
            Write-Error "Unable to find backup information on LTSvc. Use New-CWAABackup to create a settings backup."
            return
        }

        Try {
            $key = Get-ItemProperty $Script:CWAARegistryBackup -ErrorAction Stop | Select-Object * -Exclude $exclude

            if ($Null -ne $key -and ($key | Get-Member | Where-Object { $_.Name -match 'BasePath' })) {
                $key.BasePath = [System.Environment]::ExpandEnvironmentVariables($key.BasePath) -replace '\\\\', '\'
            }

            if ($Null -ne $key -and ($key | Get-Member | Where-Object { $_.Name -match 'Server Address' })) {
                $Servers = ($key | Select-Object -Expand 'Server Address' -EA 0).Split('|') |
                    ForEach-Object { $_.Trim() -replace '~', '' } |
                    Where-Object { $_ -match '.+' }
                Add-Member -InputObject $key -MemberType NoteProperty -Name 'Server' -Value $Servers -Force
            }

            return $key
        }
        Catch {
            Write-Error "There was a problem reading the backup registry keys. $_"
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
