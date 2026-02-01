function Redo-CWAA {
    <#
    .SYNOPSIS
        Reinstalls the ConnectWise Automate Agent on the local computer.
    .DESCRIPTION
        Performs a complete reinstall of the ConnectWise Automate Agent by uninstalling and then
        reinstalling the agent. The function attempts to retrieve current settings (server, location,
        etc.) from the existing installation or from a backup. If settings cannot be determined
        automatically, the function will prompt for the required parameters.

        The reinstall process:
        1. Reads current agent settings from registry or backup
        2. Uninstalls the existing agent via Uninstall-CWAA
        3. Waits 20 seconds for the uninstall to settle
        4. Installs a fresh agent via Install-CWAA with the gathered settings
    .PARAMETER Server
        One or more ConnectWise Automate server URLs.
        Example: https://automate.domain.com
        If not provided, the function reads the server URL from the current agent configuration
        or backup settings. If neither is available, prompts interactively.
    .PARAMETER ServerPassword
        The server password for agent authentication. InstallerToken is preferred.
    .PARAMETER InstallerToken
        An installer token for authenticated agent deployment. This is the preferred
        authentication method over ServerPassword.
        See: https://forums.mspgeek.org/topic/5882-contribution-generate-agent-installertoken
    .PARAMETER LocationID
        The LocationID of the location the agent will be assigned to.
        If not provided, reads from the current agent configuration or prompts interactively.
    .PARAMETER Backup
        Creates a backup of the current agent installation before uninstalling by calling New-CWAABackup.
    .PARAMETER Hide
        Hides the agent entry from Add/Remove Programs after reinstallation.
    .PARAMETER Rename
        Renames the agent entry in Add/Remove Programs after reinstallation.
    .PARAMETER SkipDotNet
        Skips .NET Framework 3.5 and 2.0 prerequisite checks during reinstallation.
    .PARAMETER Force
        Forces reinstallation even when a probe agent is detected.
    .EXAMPLE
        Redo-CWAA
        Reinstalls the agent using settings from the current installation registry.
    .EXAMPLE
        Redo-CWAA -Server https://automate.domain.com -InstallerToken 'token' -LocationID 42
        Reinstalls the agent with explicitly provided settings.
    .EXAMPLE
        Redo-CWAA -Backup -Force
        Backs up settings, then forces reinstallation even if a probe agent is detected.
    .EXAMPLE
        Get-CWAAInfo | Redo-CWAA -InstallerToken 'token'
        Reinstalls the agent using Server and LocationID from the current installation via pipeline.
    .NOTES
        Author: Chris Taylor
        Alias: Reinstall-CWAA, Redo-LTService, Reinstall-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Reinstall-CWAA', 'Redo-LTService', 'Reinstall-LTService')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $True, ValueFromPipeline = $True)]
        [AllowNull()]
        [string[]]$Server,
        [Parameter(ParameterSetName = 'deployment')]
        [Parameter(ValueFromPipelineByPropertyName = $True, ValueFromPipeline = $True)]
        [Alias('Password')]
        [string]$ServerPassword,
        [Parameter(ParameterSetName = 'installertoken')]
        [ValidatePattern('(?s:^[0-9a-z]+$)')]
        [string]$InstallerToken,
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [int]$LocationID,
        [switch]$Backup,
        [switch]$Hide,
        [Parameter()]
        [AllowNull()]
        [string]$Rename,
        [switch]$SkipDotNet,
        [switch]$Force
    )

    Begin {
        Write-Debug "Starting $($myInvocation.InvocationName)"

        # Gather install settings from registry or backed up settings
        $Settings = $Null
        Try {
            $Settings = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False
        }
        Catch {
            Write-Debug "Failed to retrieve current Agent Settings: $_"
        }

        Assert-CWAANotProbeAgent -ServiceInfo $Settings -ActionName 'Re-Install' -Force:$Force
        if ($Null -eq $Settings) {
            Write-Debug "Unable to retrieve current Agent Settings. Testing for Backup Settings."
            Try {
                $Settings = Get-CWAAInfoBackup -EA 0
            }
            Catch { Write-Debug "Failed to retrieve backup Agent Settings: $_" }
        }
        $ServerList = @()
    }

    Process {
        if (-not $Server) {
            if ($Settings) {
                $Server = $Settings | Select-Object -Expand 'Server' -EA 0
            }
            if (-not $Server) {
                $Server = Read-Host -Prompt 'Provide the URL to your Automate server (https://automate.domain.com):'
            }
        }
        if (-not $LocationID) {
            if ($Settings) {
                $LocationID = $Settings | Select-Object -Expand LocationID -EA 0
            }
            if (-not $LocationID) {
                $LocationID = Read-Host -Prompt 'Provide the LocationID'
            }
        }
        if (-not $LocationID) {
            $LocationID = '1'
        }
        $ServerList += $Server
    }

    End {
        if ($Backup) {
            if ($PSCmdlet.ShouldProcess('LTService', 'Backup Current Service Settings')) {
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
        Elseif ($ServerPassword) {
            $PasswordPresent = "-Password 'REDACTED'"
        }

        Write-Output "Reinstalling Automate agent with the following information, -Server $($ServerList -join ',') $PasswordPresent -LocationID $LocationID $RenameArg"
        Write-Verbose "Starting: UnInstall-CWAA -Server $($ServerList -join ',')"
        Try {
            Uninstall-CWAA -Server $ServerList -ErrorAction Stop -Force
        }
        Catch {
            Write-CWAAEventLog -EventId 1022 -EntryType Error -Message "Agent reinstall failed during uninstall phase. Error: $($_.Exception.Message)"
            Write-Error "There was an error during the reinstall process while uninstalling. $_" -ErrorAction Stop
        }
        Finally {
            if ($WhatIfPreference -ne $True) {
                Write-Verbose 'Waiting 20 seconds for prior uninstall to settle before starting Install.'
                Start-Sleep 20
            }
        }

        Write-Verbose "Starting: Install-CWAA -Server $($ServerList -join ',') $PasswordPresent -LocationID $LocationID -Hide:`$$Hide $RenameArg"
        Try {
            if ($PSCmdlet.ParameterSetName -ne 'installertoken') {
                Install-CWAA -Server $ServerList -ServerPassword $ServerPassword -LocationID $LocationID -Hide:$Hide -Rename $Rename -SkipDotNet:$SkipDotNet -Force
            }
            else {
                Install-CWAA -Server $ServerList -InstallerToken $InstallerToken -LocationID $LocationID -Hide:$Hide -Rename $Rename -SkipDotNet:$SkipDotNet -Force
            }
        }
        Catch {
            Write-CWAAEventLog -EventId 1022 -EntryType Error -Message "Agent reinstall failed during install phase. Error: $($_.Exception.Message)"
            Write-Error "There was an error during the reinstall process while installing. $_" -ErrorAction Stop
        }

        Write-CWAAEventLog -EventId 1020 -EntryType Information -Message "Agent reinstalled successfully. Server: $($ServerList -join ','), LocationID: $LocationID"
        Write-Debug "Exiting $($myInvocation.InvocationName)"
    }
}
