Function Set-CWAALogLevel {
    [CmdletBinding()]
    [Alias('Set-LTLogging')]
    Param (
        [ValidateSet('Normal', 'Verbose')]
        $Level = 'Normal'
    )

    Begin{}

    Process{
        Try{
            Stop-CWAA
            if ($Level -eq 'Normal'){
                Set-ItemProperty HKLM:\SOFTWARE\LabTech\Service\Settings -Name 'Debuging' -Value 1
            }
            if ($Level -eq 'Verbose'){
                Set-ItemProperty HKLM:\SOFTWARE\LabTech\Service\Settings -Name 'Debuging' -Value 1000
            }
            Start-CWAA
        }

        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was a problem writing the registry key. $($Error[0])" -ErrorAction Stop
        }
        }

        End{
        if ($?){
            Get-CWAALogging
        }
    }
}
