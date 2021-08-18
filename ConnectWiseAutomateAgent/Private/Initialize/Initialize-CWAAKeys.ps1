function Initialize-CWAAKeys {
    [CmdletBinding()]
    Param()

    Process {
        $LTSI = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
        if (($LTSI) -and ($LTSI | Get-Member | Where-Object { $_.Name -eq 'ServerPassword' })) {
            Write-Debug "Line $(LINENUM): Decoding Server Password."
            $Script:LTServiceKeys.ServerPasswordString = $(ConvertFrom-CWAASecurity -InputString "$($LTSI.ServerPassword)")
            if ($Null -ne $LTSI -and ($LTSI | Get-Member | Where-Object { $_.Name -eq 'Password' })) {
                Write-Debug "Line $(LINENUM): Decoding Agent Password."
                $Script:LTServiceKeys.PasswordString = $(ConvertFrom-CWAASecurity -InputString "$($LTSI.Password)" -Key "$($Script:LTServiceKeys.ServerPasswordString)")
            }
            else {
                $Script:LTServiceKeys.PasswordString = ''
            }
        }
        else {
            $Script:LTServiceKeys.ServerPasswordString = ''
            $Script:LTServiceKeys.PasswordString = ''
        }
    }

    End {
    }
}
