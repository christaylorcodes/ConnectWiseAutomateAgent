function Redo-CWAA {
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Reinstall-CWAA', 'Redo-LTService', 'Reinstall-LTService')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $True, ValueFromPipeline = $True)]
        [AllowNull()]
        [string[]]$Server,
        [Parameter(ParameterSetName = 'deployment')]
        [Parameter(ValueFromPipelineByPropertyName = $True, ValueFromPipeline = $True)]
        [Alias('Password')]
        [SecureString]$ServerPassword,
        [Parameter(ParameterSetName = 'installertoken')]
        [ValidatePattern('(?s:^[0-9a-z]+$)')]
        [string]$InstallerToken,
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [string]$LocationID,
        [switch]$Backup,
        [switch]$Hide,
        [Parameter()]
        [AllowNull()]
        [string]$Rename,
        [switch]$SkipDotNet,
        [switch]$Force
    )

    Begin {
        Clear-Variable PasswordArg, RenameArg, Svr, ServerList, Settings -EA 0 -WhatIf:$False -Confirm:$False #Clearing Variables for use
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"

        # Gather install stats from registry or backed up settings
        Try {
            $Settings = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False
            if ($Null -ne $Settings) {
                if (($Settings | Select-Object -Expand Probe -EA 0) -eq '1') {
                    if ($Force -eq $True) {
                        Write-Output 'Probe Agent Detected. Re-Install Forced.'
                    }
                    else {
                        if ($WhatIfPreference -ne $True) {
                            Write-Error -Exception [System.OperationCanceledException]"ERROR: Line $(LINENUM): Probe Agent Detected. Re-Install Denied." -ErrorAction Stop
                        }
                        else {
                            Write-Error -Exception [System.OperationCanceledException]"What If: Line $(LINENUM): Probe Agent Detected. Re-Install Denied." -ErrorAction Stop
                        }
                    }
                }
            }
        }
        Catch {
            Write-Debug "Line $(LINENUM): Failed to retrieve current Agent Settings."
        }
        if ($Null -eq $Settings) {
            Write-Debug "Line $(LINENUM): Unable to retrieve current Agent Settings. Testing for Backup Settings"
            Try {
                $Settings = Get-CWAAInfoBackup -EA 0
            }
            Catch {}
        }
        $ServerList = @()
    }

    Process {
        if (-not ($Server)) {
            if ($Settings) {
                $Server = $Settings | Select-Object -Expand 'Server' -EA 0
            }
            if (-not ($Server)) {
                $Server = Read-Host -Prompt 'Provide the URL to your LabTech server (https://lt.domain.com):'
            }
        }
        if (-not ($LocationID)) {
            if ($Settings) {
                $LocationID = $Settings | Select-Object -Expand LocationID -EA 0
            }
            if (-not ($LocationID)) {
                $LocationID = Read-Host -Prompt 'Provide the LocationID'
            }
        }
        if (-not ($LocationID)) {
            $LocationID = '1'
        }
        $ServerList += $Server
    }
    End {
        if ($Backup) {
            if ( $PSCmdlet.ShouldProcess('LTService', 'Backup Current Service Settings') ) {
                New-CWAABackup
            }
        }

        $RenameArg = ''
        if ($Rename) {
            $RenameArg = "-Rename $Rename"
        }

        if ($PSCmdlet.ParameterSetName -eq 'installertoken') {
            $PasswordPresent = "-InstallerToken 'REDACTED'"
        }
        Elseif (($ServerPassword)) {
            $PasswordPresent = "-Password 'REDACTED'"
        }

        Write-Output "Reinstalling LabTech with the following information, -Server $($ServerList -join ',') $PasswordPresent -LocationID $LocationID $RenameArg"
        Write-Verbose "Starting: UnInstall-CWAA -Server $($ServerList -join ',')"
        Try {
            Uninstall-CWAA -Server $ServerList -ErrorAction Stop -Force
        }

        Catch {
            Write-Error "ERROR: Line $(LINENUM): There was an error during the reinstall process while uninstalling. $($Error[0])" -ErrorAction Stop
        }

        Finally {
            if ($WhatIfPreference -ne $True) {
                Write-Verbose 'Waiting 20 seconds for prior uninstall to settle before starting Install.'
                Start-Sleep 20
            }
        }

        Write-Verbose "Starting: Install-CWAA -Server $($ServerList -join ',') $PasswordPresent -LocationID $LocationID -Hide:`$$($Hide) $RenameArg"
        Try {
            if ($PSCmdlet.ParameterSetName -ne 'installertoken') {
                Install-CWAA -Server $ServerList -ServerPassword $ServerPassword -LocationID $LocationID -Hide:$Hide -Rename $Rename -SkipDotNet:$SkipDotNet -Force
            }
            else {
                Install-CWAA -Server $ServerList -InstallerToken $InstallerToken -LocationID $LocationID -Hide:$Hide -Rename $Rename -SkipDotNet:$SkipDotNet -Force
            }
        }
        Catch {
            Write-Error "ERROR: Line $(LINENUM): There was an error during the reinstall process while installing. $($Error[0])" -ErrorAction Stop
        }

        if (!($?)) {
            $($Error[0])
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}