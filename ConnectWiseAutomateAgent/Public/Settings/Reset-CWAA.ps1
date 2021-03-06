function Reset-CWAA {
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Reset-LTService')]
    Param(
        [switch]$ID,
        [switch]$Location,
        [switch]$MAC,
        [switch]$Force,
        [switch]$NoWait
    )

    Begin {
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"

        $Reg = 'HKLM:\Software\LabTech\Service'
        if (!$PsBoundParameters.ContainsKey('ID') -and !$PsBoundParameters.ContainsKey('Location') -and !$PsBoundParameters.ContainsKey('MAC')) {
            $ID = $True
            $Location = $True
            $MAC = $True
        }

        $LTSI = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
        if (($LTSI) -and ($LTSI | Select-Object -Expand Probe -EA 0) -eq '1') {
            if ($Force -eq $True) {
                Write-Output 'Probe Agent Detected. Reset Forced.'
            }
            else {
                if ($WhatIfPreference -ne $True) {
                    Write-Error -Exception [System.OperationCanceledException]"ERROR: Line $(LINENUM): Probe Agent Detected. Reset Denied." -ErrorAction Stop
                }
                else {
                    Write-Error -Exception [System.OperationCanceledException]"What If: Line $(LINENUM): Probe Agent Detected. Reset Denied." -ErrorAction Stop
                }
            }
        }
        Write-Output "OLD ID: $($LTSI|Select-Object -Expand ID -EA 0) LocationID: $($LTSI|Select-Object -Expand LocationID -EA 0) MAC: $($LTSI|Select-Object -Expand MAC -EA 0)"
        $LTSI = $Null
    }

    Process {
        if (!(Get-Service 'LTService', 'LTSvcMon' -ErrorAction SilentlyContinue)) {
            if ($WhatIfPreference -ne $True) {
                Write-Error "ERROR: Line $(LINENUM): LabTech Services NOT Found $($Error[0])"
                return
            }
            else {
                Write-Error "What If: Line $(LINENUM): Stopping: LabTech Services NOT Found"
                return
            }
        }

        Try {
            if ($ID -or $Location -or $MAC) {
                Stop-CWAA
                if ($ID) {
                    Write-Output '.Removing ID'
                    Remove-ItemProperty -Name ID -Path $Reg -ErrorAction SilentlyContinue
                }
                if ($Location) {
                    Write-Output '.Removing LocationID'
                    Remove-ItemProperty -Name LocationID -Path $Reg -ErrorAction SilentlyContinue
                }
                if ($MAC) {
                    Write-Output '.Removing MAC'
                    Remove-ItemProperty -Name MAC -Path $Reg -ErrorAction SilentlyContinue
                }
                Start-CWAA
            }
        }

        Catch {
            Write-Error "ERROR: Line $(LINENUM): There was an error during the reset process. $($Error[0])" -ErrorAction Stop
        }
    }

    End {
        if ($?) {
            if (-NOT $NoWait -and $PSCmdlet.ShouldProcess('LTService', 'Discover new settings after Service Start')) {
                $timeout = New-TimeSpan -Minutes 1
                $sw = [diagnostics.stopwatch]::StartNew()
                $LTSI = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
                Write-Host -NoNewline 'Waiting for agent to register.'
                While (!($LTSI | Select-Object -Expand ID -EA 0) -or !($LTSI | Select-Object -Expand LocationID -EA 0) -or !($LTSI | Select-Object -Expand MAC -EA 0) -and $($sw.elapsed) -lt $timeout) {
                    Write-Host -NoNewline '.'
                    Start-Sleep 2
                    $LTSI = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
                }
                Write-Host ''
                $LTSI = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
                Write-Output "NEW ID: $($LTSI|Select-Object -Expand ID -EA 0) LocationID: $($LTSI|Select-Object -Expand LocationID -EA 0) MAC: $($LTSI|Select-Object -Expand MAC -EA 0)"
            }
        }
        else { $Error[0] }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}
