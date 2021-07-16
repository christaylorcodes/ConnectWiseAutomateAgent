Function Initialize-CWAAKeys {
    [CmdletBinding()]
    Param()

    Process {
        $LTSI=Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
        If (($LTSI) -and ($LTSI|Get-Member|Where-Object {$_.Name -eq 'ServerPassword'})) {
            Write-Debug "Line $(LINENUM): Decoding Server Password."
            $Script:LTServiceKeys.ServerPasswordString=$(ConvertFrom-CWAASecurity -InputString "$($LTSI.ServerPassword)")
            If ($Null -ne $LTSI -and ($LTSI|Get-Member|Where-Object {$_.Name -eq 'Password'})) {
                Write-Debug "Line $(LINENUM): Decoding Agent Password."
                $Script:LTServiceKeys.PasswordString=$(ConvertFrom-CWAASecurity -InputString "$($LTSI.Password)" -Key "$($Script:LTServiceKeys.ServerPasswordString)")
            } Else {
                $Script:LTServiceKeys.PasswordString=''
            }
        } Else {
            $Script:LTServiceKeys.ServerPasswordString=''
            $Script:LTServiceKeys.PasswordString=''
        }
    }

    End {
    }
}
