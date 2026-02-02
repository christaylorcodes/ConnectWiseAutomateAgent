function Get-CWAASettings {
    <#
    .SYNOPSIS
        Retrieves ConnectWise Automate agent settings from the registry.
    .DESCRIPTION
        Reads agent settings from the Automate agent service Settings registry subkey
        (HKLM:\SOFTWARE\LabTech\Service\Settings) and returns them as an object.
        These settings are separate from the main agent configuration returned by
        Get-CWAAInfo and include proxy configuration (ProxyServerURL, ProxyUsername,
        ProxyPassword), logging level, and other operational parameters written by
        the agent or Set-CWAAProxy.
    .EXAMPLE
        Get-CWAASettings
        Returns an object containing all agent settings registry properties.
    .EXAMPLE
        (Get-CWAASettings).ProxyServerURL
        Returns just the configured proxy URL, if any.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTServiceSettings
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTServiceSettings')]
    Param ()

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $exclude = 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', 'PSPath'
    }

    Process {
        if (-not (Test-Path $Script:CWAARegistrySettings)) {
            Write-Error "Unable to find LTSvc settings. Make sure the agent is installed."
            return
        }

        Try {
            return Get-ItemProperty $Script:CWAARegistrySettings -ErrorAction Stop | Select-Object * -Exclude $exclude
        }
        Catch {
            Write-Error "There was a problem reading the registry keys. $_"
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
