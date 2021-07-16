Function Get-CWAASettings{
    [CmdletBinding()]
    [Alias('Get-LTServiceSettings')]
    Param ()

    Begin{
        Write-Verbose "Checking for registry keys."
        if ((Test-Path 'HKLM:\SOFTWARE\LabTech\Service\Settings') -eq $False){
            Write-Error "ERROR: Unable to find LTSvc settings. Make sure the agent is installed."
        }
        $exclude = "PSParentPath","PSChildName","PSDrive","PSProvider","PSPath"
    }

    Process{
        Try{
            Get-ItemProperty HKLM:\SOFTWARE\LabTech\Service\Settings -ErrorAction Stop | Select-Object * -exclude $exclude
        }

        Catch{
            Write-Error "ERROR: There was a problem reading the registry keys. $($Error[0])"
        }
    }

    End{
        if ($?){
            $key
        }
    }
}