Function Get-CWAALogLevel{
    [CmdletBinding()]
    [Alias('Get-LTLogging')]
    Param ()

    Begin{
        Write-Verbose "Checking for registry keys."
    }

    Process{
        Try{
            $Value = (Get-CWAASettings|Select-Object -Expand Debuging -EA 0)
        }

        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was a problem reading the registry key. $($Error[0])"
            return
        }
    }

    End{
        if ($?){
            if ($value -eq 1){
                Write-Output "Current logging level: Normal"
            }
            elseif ($value -eq 1000){
                Write-Output "Current logging level: Verbose"
            }
            else{
                Write-Error "ERROR: Line $(LINENUM): Unknown Logging level $($value)"
            }
        }
    }
}
