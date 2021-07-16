Function Get-CWAAProbeError {
    [CmdletBinding()]
    [Alias('Get-LTProbeErrors')]
    Param()

    Begin{
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"
        $BasePath = $(Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False|Select-Object -Expand BasePath -EA 0)
        if (!($BasePath)){$BasePath = "$env:windir\LTSVC"}
    }

    Process{
        if ($(Test-Path -Path "$BasePath\LTProbeErrors.txt") -eq $False) {
            Write-Error "ERROR: Line $(LINENUM): Unable to find log."
            return
        }
        $errors = Get-Content "$BasePath\LTProbeErrors.txt"
        $errors = $errors -join ' ' -split '::: '
        Try {
            Foreach($Line in $Errors){
                $items = $Line -split "`t" -replace ' - ',''
                $object = New-Object -TypeName PSObject
                $object | Add-Member -MemberType NoteProperty -Name ServiceVersion -Value $items[0]
                $object | Add-Member -MemberType NoteProperty -Name Timestamp -Value $(Try {[datetime]::Parse($items[1])} Catch {})
                $object | Add-Member -MemberType NoteProperty -Name Message -Value $items[2]
                Write-Output $object
            }
        }

        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was an error reading the log. $($Error[0])"
        }
    }

    End{
        if ($?){
        }
        Else {$Error[0]}
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}
