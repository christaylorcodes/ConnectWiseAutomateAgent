Function Get-CWAAInfo {
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact='Low')]
    [Alias('Get-LTServiceInfo')]
    Param ()

    Begin{
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"
        Clear-Variable key,BasePath,exclude,Servers -EA 0 -WhatIf:$False -Confirm:$False #Clearing Variables for use
        $exclude = "PSParentPath","PSChildName","PSDrive","PSProvider","PSPath"
        $key = $Null
    }

    Process{
        If ((Test-Path 'HKLM:\SOFTWARE\LabTech\Service') -eq $False){
            Write-Error "ERROR: Line $(LINENUM): Unable to find information on LTSvc. Make sure the agent is installed."
            Return $Null
        }

        If ($PSCmdlet.ShouldProcess("LTService", "Retrieving Service Registry Values")) {
            Write-Verbose "Checking for LT Service registry keys."
            Try{
                $key = Get-ItemProperty 'HKLM:\SOFTWARE\LabTech\Service' -ErrorAction Stop | Select-Object * -exclude $exclude
                If ($Null -ne $key -and -not ($key|Get-Member -EA 0|Where-Object {$_.Name -match 'BasePath'})) {
                    If ((Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LTService') -eq $True) {
                        Try {
                            $BasePath = Get-Item $( Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LTService' -ErrorAction Stop|Select-Object -Expand ImagePath | Select-String -Pattern '^[^"][^ ]+|(?<=^")[^"]+'|Select-Object -Expand Matches -First 1 | Select-Object -Expand Value -EA 0 -First 1 ) | Select-Object -Expand DirectoryName -EA 0
                        } Catch {
                            $BasePath = "${env:windir}\LTSVC"
                        }
                    } Else {
                        $BasePath = "${env:windir}\LTSVC"
                    }
                    Add-Member -InputObject $key -MemberType NoteProperty -Name BasePath -Value $BasePath
                }
                $key.BasePath = [System.Environment]::ExpandEnvironmentVariables($($key|Select-Object -Expand BasePath -EA 0)) -replace '\\\\','\'
                If ($Null -ne $key -and ($key|Get-Member|Where-Object {$_.Name -match 'Server Address'})) {
                    $Servers = ($Key|Select-Object -Expand 'Server Address' -EA 0).Split('|')|ForEach-Object {$_.Trim() -replace '~',''}|Where-Object {$_ -match '.+'}
                    Add-Member -InputObject $key -MemberType NoteProperty -Name 'Server' -Value $Servers -Force
                }
            }

            Catch{
                Write-Error "ERROR: Line $(LINENUM): There was a problem reading the registry keys. $($Error[0])"
            }
        }
    }

    End{
        If ($?){
            Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
            return $key
        } Else {
            Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
        }
    }
}