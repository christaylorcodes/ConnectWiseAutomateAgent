Function New-CWAABackup{
    [CmdletBinding()]
    [Alias('New-LTServiceBackup')]
    Param ()

    Begin{
        Clear-Variable LTPath,BackupPath,Keys,Path,Result,Reg,RegPath -EA 0 -WhatIf:$False -Confirm:$False #Clearing Variables for use
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"

        $LTPath = "$(Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False|Select-Object -Expand BasePath -EA 0)"
        if (-not ($LTPath)) {
            Write-Error "ERROR: Line $(LINENUM): Unable to find LTSvc folder path." -ErrorAction Stop
        }
        $BackupPath = "$($LTPath)Backup"
        $Keys = "HKLM\SOFTWARE\LabTech"
        $RegPath = "$BackupPath\LTBackup.reg"

        Write-Verbose "Checking for registry keys."
        if ((Test-Path ($Keys -replace '^(H[^\\]*)','$1:')) -eq $False){
            Write-Error "ERROR: Line $(LINENUM): Unable to find registry information on LTSvc. Make sure the agent is installed." -ErrorAction Stop
        }
        if ($(Test-Path -Path $LTPath -PathType Container) -eq $False) {
            Write-Error "ERROR: Line $(LINENUM): Unable to find LTSvc folder path $LTPath" -ErrorAction Stop
        }
        New-Item $BackupPath -type directory -ErrorAction SilentlyContinue | Out-Null
        if ($(Test-Path -Path $BackupPath -PathType Container) -eq $False) {
            Write-Error "ERROR: Line $(LINENUM): Unable to create backup folder path $BackupPath" -ErrorAction Stop
        }
    }

    Process{
        Try{
            Copy-Item $LTPath $BackupPath -Recurse -Force
        }

        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was a problem backing up the LTSvc Folder. $($Error[0])"
        }

        Try{
            Write-Debug "Line $(LINENUM): Exporting Registry Data"
            $Null = & "$env:windir\system32\reg.exe" export "$Keys" "$RegPath" /y 2>''
            Write-Debug "Line $(LINENUM): Loading and modifying registry key name"
            $Reg = Get-Content $RegPath
            $Reg = $Reg -replace [Regex]::Escape('[HKEY_LOCAL_MACHINE\SOFTWARE\LabTech'),'[HKEY_LOCAL_MACHINE\SOFTWARE\LabTechBackup'
            Write-Debug "Line $(LINENUM): Writing output information"
            $Reg | Out-File $RegPath
            Write-Debug "Line $(LINENUM): Importing Registry data to Backup Path"
            $Null = & "$env:windir\system32\reg.exe" import "$RegPath" 2>''
            $True | Out-Null #Protection to prevent exit status error
        }

        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was a problem backing up the LTSvc Registry keys. $($Error[0])"
        }
    }

    End{
        If ($?){
            Write-Output "The LabTech Backup has been created."
        } Else {
            Write-Error "ERROR: Line $(LINENUM): There was a problem completing the LTSvc Backup. $($Error[0])"
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}
