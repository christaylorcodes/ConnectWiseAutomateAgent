Function Redo-CWAA{
    [CmdletBinding(SupportsShouldProcess=$True)]
    [Alias('Reinstall-CWAA','Redo-LTService','Reinstall-LTService')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $True, ValueFromPipeline=$True)]
        [AllowNull()]
        [string[]]$Server,
        [Parameter(ParameterSetName = 'deployment')]
        [Parameter(ValueFromPipelineByPropertyName = $True, ValueFromPipeline=$True)]
        [Alias("Password")]
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

    Begin{
        Clear-Variable PasswordArg, RenameArg, Svr, ServerList, Settings -EA 0 -WhatIf:$False -Confirm:$False #Clearing Variables for use
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"

        # Gather install stats from registry or backed up settings
        Try {
            $Settings = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False
            If ($Null -ne $Settings) {
                If (($Settings|Select-Object -Expand Probe -EA 0) -eq '1') {
                    If ($Force -eq $True) {
                        Write-Output "Probe Agent Detected. Re-Install Forced."
                    } Else {
                        If ($WhatIfPreference -ne $True) {
                            Write-Error -Exception [System.OperationCanceledException]"ERROR: Line $(LINENUM): Probe Agent Detected. Re-Install Denied." -ErrorAction Stop
                        } Else {
                            Write-Error -Exception [System.OperationCanceledException]"What If: Line $(LINENUM): Probe Agent Detected. Re-Install Denied." -ErrorAction Stop
                        }
                    }
                }
            }
        } Catch {
            Write-Debug "Line $(LINENUM): Failed to retrieve current Agent Settings."
        }
        If ($Null -eq $Settings) {
            Write-Debug "Line $(LINENUM): Unable to retrieve current Agent Settings. Testing for Backup Settings"
            Try {
                $Settings = Get-CWAAInfoBackup -EA 0
            } Catch {}
        }
        $ServerList=@()
    }

    Process{
        if (-not ($Server)){
            if ($Settings){
                $Server = $Settings|Select-Object -Expand 'Server' -EA 0
            }
            if (-not ($Server)){
                $Server = Read-Host -Prompt 'Provide the URL to your LabTech server (https://lt.domain.com):'
            }
        }
        if (-not ($LocationID)){
            if ($Settings){
                $LocationID = $Settings|Select-Object -Expand LocationID -EA 0
            }
            if (-not ($LocationID)){
                $LocationID = Read-Host -Prompt 'Provide the LocationID'
            }
        }
        if (-not ($LocationID)){
            $LocationID = "1"
        }
        $ServerList += $Server
    }
    End{
        If ($Backup){
            If ( $PSCmdlet.ShouldProcess("LTService","Backup Current Service Settings") ) {
                New-CWAABackup
            }
        }

        $RenameArg=''
        If ($Rename){
            $RenameArg = "-Rename $Rename"
        }

        If ($PSCmdlet.ParameterSetName -eq 'installertoken') {
            $PasswordPresent = "-InstallerToken 'REDACTED'"
        } ElseIf (($ServerPassword)){
            $PasswordPresent = "-Password 'REDACTED'"
        }

        Write-Output "Reinstalling LabTech with the following information, -Server $($ServerList -join ',') $PasswordPresent -LocationID $LocationID $RenameArg"
        Write-Verbose "Starting: UnInstall-CWAA -Server $($ServerList -join ',')"
        Try{
            Uninstall-CWAA -Server $ServerList -ErrorAction Stop -Force
        }

        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was an error during the reinstall process while uninstalling. $($Error[0])" -ErrorAction Stop
        }

        Finally{
            If ($WhatIfPreference -ne $True) {
                Write-Verbose "Waiting 20 seconds for prior uninstall to settle before starting Install."
                Start-Sleep 20
            }
        }

        Write-Verbose "Starting: Install-CWAA -Server $($ServerList -join ',') $PasswordPresent -LocationID $LocationID -Hide:`$$($Hide) $RenameArg"
        Try{
            If ($PSCmdlet.ParameterSetName -ne 'installertoken') {
                Install-CWAA -Server $ServerList -ServerPassword $ServerPassword -LocationID $LocationID -Hide:$Hide -Rename $Rename -SkipDotNet:$SkipDotNet -Force
            } Else {
                Install-CWAA -Server $ServerList -InstallerToken $InstallerToken -LocationID $LocationID -Hide:$Hide -Rename $Rename -SkipDotNet:$SkipDotNet -Force
            }
        }
        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was an error during the reinstall process while installing. $($Error[0])" -ErrorAction Stop
        }

        If (!($?)){
            $($Error[0])
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}