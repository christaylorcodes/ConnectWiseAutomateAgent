Function Get-CWAAInfoBackup {
    [CmdletBinding()]
    [Alias('Get-LTServiceInfoBackup')]
    Param ()

    Begin{
        Write-Verbose "Checking for registry keys."
        $exclude = "PSParentPath","PSChildName","PSDrive","PSProvider","PSPath"
    }

    Process{
        If ((Test-Path 'HKLM:\SOFTWARE\LabTechBackup\Service') -eq $False){
            Write-Error "ERROR: Line $(LINENUM): Unable to find backup information on LTSvc. Use New-CWAABackup to create a settings backup."
            return
        }
        Try{
            $key = Get-ItemProperty HKLM:\SOFTWARE\LabTechBackup\Service -ErrorAction Stop | Select-Object * -exclude $exclude
            If ($Null -ne $key -and ($key|Get-Member|Where-Object {$_.Name -match 'BasePath'})) {
                $key.BasePath = [System.Environment]::ExpandEnvironmentVariables($key.BasePath) -replace '\\\\','\'
            }
            If ($Null -ne $key -and ($key|Get-Member|Where-Object {$_.Name -match 'Server Address'})) {
                $Servers = ($Key|Select-Object -Expand 'Server Address' -EA 0).Split('|')|ForEach-Object {$_.Trim()}
                Add-Member -InputObject $key -MemberType NoteProperty -Name 'Server' -Value $Servers -Force
            }
        }
        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was a problem reading the backup registry keys. $($Error[0])"
            return
        }
    }

    End{
        If ($?){
            return $key
        }
    }
}
