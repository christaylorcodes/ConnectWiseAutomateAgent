# ConnectWiseAutomateAgent 1.0.0-alpha001
# Single-file distribution - built 2026-02-01
# https://github.com/christaylorcodes/ConnectWiseAutomateAgent

function Assert-CWAANotProbeAgent {
    <#
    .SYNOPSIS
        Blocks operations on probe agents unless -Force is specified.
    .DESCRIPTION
        Checks the agent info object to determine if the current machine is a probe agent.
        If it is and -Force is not set, writes a terminating error to prevent accidental
        removal of critical infrastructure. If -Force is set, writes a warning message and
        allows continuation.
        The ActionName parameter produces contextual messages like
        "Probe Agent Detected. UnInstall Denied." or "Probe Agent Detected. Reset Forced."
        This consolidates the duplicated probe agent protection check found in
        Uninstall-CWAA, Redo-CWAA, and Reset-CWAA.
    .PARAMETER ServiceInfo
        The agent info object from Get-CWAAInfo. If null or missing the Probe property,
        the check is skipped silently.
    .PARAMETER ActionName
        The name of the operation for error/output messages. Used directly in the message
        string, e.g., 'UnInstall', 'Re-Install', 'Reset'.
    .PARAMETER Force
        When set, allows the operation to proceed on a probe agent with an output message
        instead of a terminating error.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    Param(
        [Parameter()]
        [AllowNull()]
        $ServiceInfo,
        [Parameter(Mandatory = $True)]
        [string]$ActionName,
        [switch]$Force
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        if ($ServiceInfo -and ($ServiceInfo | Select-Object -Expand Probe -EA 0) -eq '1') {
            if ($Force) {
                Write-Output "Probe Agent Detected. $ActionName Forced."
            }
            else {
                if ($WhatIfPreference -ne $True) {
                    Write-Error -Exception ([System.OperationCanceledException]"Probe Agent Detected. $ActionName Denied.") -ErrorAction Stop
                }
                else {
                    Write-Error -Exception ([System.OperationCanceledException]"What If: Probe Agent Detected. $ActionName Denied.") -ErrorAction Stop
                }
            }
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Clear-CWAAInstallerArtifacts {
    <#
    .SYNOPSIS
        Cleans up stale ConnectWise Automate installer processes and temporary files.
    .DESCRIPTION
        Terminates any running installer-related processes and removes temporary installer
        files left behind by incomplete or failed installations. This prevents conflicts
        when starting a new install, reinstall, or update operation.
        Process names and file paths are read from the centralized module constants
        $Script:CWAAInstallerProcessNames and $Script:CWAAInstallerArtifactPaths.
        All operations are best-effort with errors suppressed. This function is intended
        as a defensive cleanup step, not a validated operation.
    .NOTES
        Version: 0.1.5.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        # Kill stale installer processes that may block new installations
        foreach ($processName in $Script:CWAAInstallerProcessNames) {
            Get-Process -Name $processName -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }
        # Remove leftover temporary installer files
        foreach ($artifactPath in $Script:CWAAInstallerArtifactPaths) {
            Remove-Item -Path $artifactPath -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Invoke-CWAAMsiInstaller {
    <#
    .SYNOPSIS
        Executes the Automate agent MSI installer with retry logic.
    .DESCRIPTION
        Launches msiexec.exe with the provided arguments and retries up to a configurable
        number of attempts if the LTService service is not detected after installation.
        Between retries, polls for the service using Wait-CWAACondition. Redacts server
        passwords from verbose output for security.
    .PARAMETER InstallerArguments
        The full argument string to pass to msiexec.exe (e.g., '/i "path\Agent_Install.msi" SERVERADDRESS=... /qn').
    .PARAMETER MaxAttempts
        Maximum number of install attempts before giving up. Defaults to $Script:CWAAInstallMaxAttempts.
    .PARAMETER RetryDelaySeconds
        Seconds to wait (polling for service) between retry attempts. Defaults to $Script:CWAAInstallRetryDelaySeconds.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$InstallerArguments,
        [Parameter()]
        [int]$MaxAttempts = $Script:CWAAInstallMaxAttempts,
        [Parameter()]
        [int]$RetryDelaySeconds = $Script:CWAAInstallRetryDelaySeconds
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        if (-not $PSCmdlet.ShouldProcess("msiexec.exe $InstallerArguments", 'Execute Install')) {
            return $true
        }
        $installAttempt = 0
        Do {
            if ($installAttempt -gt 0) {
                Write-Warning "Service Failed to Install. Retrying in $RetryDelaySeconds seconds." -WarningAction 'Continue'
                $Null = Wait-CWAACondition -Condition {
                    $serviceCount = ('LTService') | Get-Service -EA 0 | Measure-Object | Select-Object -Expand Count
                    $serviceCount -eq 1
                } -TimeoutSeconds $RetryDelaySeconds -IntervalSeconds 5 -Activity 'Waiting for service availability before retry'
            }
            $installAttempt++
            $runningServiceCount = ('LTService') | Get-Service -EA 0 | Measure-Object | Select-Object -Expand Count
            if ($runningServiceCount -eq 0) {
                $redactedArguments = $InstallerArguments -replace 'SERVERPASS="[^"]*"', 'SERVERPASS="REDACTED"'
                Write-Verbose "Launching Installation Process: msiexec.exe $redactedArguments"
                Start-Process -Wait -FilePath "${env:windir}\system32\msiexec.exe" -ArgumentList $InstallerArguments -WorkingDirectory $env:TEMP
                Start-Sleep 5
            }
            $runningServiceCount = ('LTService') | Get-Service -EA 0 | Measure-Object | Select-Object -Expand Count
        } Until ($installAttempt -ge $MaxAttempts -or $runningServiceCount -eq 1)
        if ($runningServiceCount -eq 0) {
            Write-Error "LTService was not installed. Installation failed after $MaxAttempts attempts."
            return $false
        }
        return $true
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Remove-CWAAFolderRecursive {
    <#
    .SYNOPSIS
        Performs depth-first removal of a folder and all its contents.
    .DESCRIPTION
        Private helper that removes a folder using a three-pass depth-first strategy:
        1. Remove files inside each subfolder (leaves first)
        2. Remove subfolders sorted by path depth (deepest first)
        3. Remove the root folder itself
        This approach maximizes cleanup even when some files or folders are locked
        by running processes, which is common during agent uninstall/update operations.
        All removal operations use best-effort error handling (-ErrorAction SilentlyContinue).
        The caller's $WhatIfPreference and $ConfirmPreference propagate automatically
        through PowerShell's preference variable mechanism.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$Path,
        [switch]$ShowProgress
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
            Write-Debug "Path '$Path' does not exist. Nothing to remove."
            return
        }
        if ($PSCmdlet.ShouldProcess($Path, 'Remove Folder')) {
            Write-Debug "Removing Folder: $Path"
            $folderProgressId = 10
            $folderProgressActivity = "Removing folder: $Path"
            Try {
                # Pass 1: Remove files inside each subfolder (leaves first)
                if ($ShowProgress) { Write-Progress -Id $folderProgressId -Activity $folderProgressActivity -Status 'Removing files (pass 1 of 3)' -PercentComplete 33 }
                Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.psiscontainer } |
                    ForEach-Object {
                        Get-ChildItem -Path $_.FullName -ErrorAction SilentlyContinue |
                            Where-Object { -not $_.psiscontainer } |
                            Remove-Item -Force -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                    }
                # Pass 2: Remove subfolders sorted by path depth (deepest first)
                if ($ShowProgress) { Write-Progress -Id $folderProgressId -Activity $folderProgressActivity -Status 'Removing subfolders (pass 2 of 3)' -PercentComplete 66 }
                Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.psiscontainer } |
                    Sort-Object { $_.FullName.Length } -Descending |
                    Remove-Item -Force -ErrorAction SilentlyContinue -Recurse -Confirm:$False -WhatIf:$False
                # Pass 3: Remove the root folder itself
                if ($ShowProgress) { Write-Progress -Id $folderProgressId -Activity $folderProgressActivity -Status 'Removing root folder (pass 3 of 3)' -PercentComplete 100 }
                Remove-Item -Recurse -Force -Path $Path -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                if ($ShowProgress) { Write-Progress -Id $folderProgressId -Activity $folderProgressActivity -Completed }
            }
            Catch {
                if ($ShowProgress) { Write-Progress -Id $folderProgressId -Activity $folderProgressActivity -Completed }
                Write-Debug "Error removing folder '$Path': $($_.Exception.Message)"
            }
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Resolve-CWAAServer {
    <#
    .SYNOPSIS
        Finds the first reachable ConnectWise Automate server from a list of candidates.
    .DESCRIPTION
        Private helper that iterates through server URLs, validates each against the
        server format regex, normalizes the URL scheme, and tests reachability by
        downloading the version string from /LabTech/Agent.aspx. Returns the first
        server that responds with a parseable version.
        Used by Install-CWAA, Uninstall-CWAA, and Update-CWAA to eliminate the
        duplicated server validation loop. Callers handle their own download logic
        after receiving the resolved server, since URL construction differs per operation.
        Requires $Script:LTServiceNetWebClient to be initialized (via Initialize-CWAANetworking)
        before calling.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string[]]$Server
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        # Normalize: prepend https:// to bare hostnames/IPs so the loop has consistent URLs
        $normalizedServers = ForEach ($serverUrl in $Server) {
            if ($serverUrl -notmatch 'https?://.+') { "https://$serverUrl" }
            $serverUrl
        }
        ForEach ($serverUrl in $normalizedServers) {
            if ($serverUrl -match $Script:CWAAServerValidationRegex) {
                # Ensure a scheme is present for the actual request
                if ($serverUrl -notmatch 'https?://.+') { $serverUrl = "http://$serverUrl" }
                Try {
                    $versionCheckUrl = "$serverUrl/LabTech/Agent.aspx"
                    Write-Debug "Testing Server Response and Version: $versionCheckUrl"
                    $serverVersionResponse = $Script:LTServiceNetWebClient.DownloadString($versionCheckUrl)
                    Write-Debug "Raw Response: $serverVersionResponse"
                    # Extract version from the pipe-delimited response string.
                    # Format: six pipe characters followed by major.minor version (e.g. '||||||220.105')
                    $serverVersion = $serverVersionResponse |
                        Select-String -Pattern '(?<=[|]{6})[0-9]{1,3}\.[0-9]{1,3}' |
                        ForEach-Object { $_.Matches } |
                        Select-Object -Expand Value -ErrorAction SilentlyContinue
                    if ($null -eq $serverVersion) {
                        Write-Verbose "Unable to test version response from $serverUrl."
                        Continue
                    }
                    Write-Verbose "Server $serverUrl responded with version $serverVersion."
                    return [PSCustomObject]@{
                        ServerUrl     = $serverUrl
                        ServerVersion = $serverVersion
                    }
                }
                Catch {
                    Write-Warning "Error encountered testing server $serverUrl."
                    Continue
                }
            }
            else {
                Write-Warning "Server address $serverUrl is not formatted correctly. Example: https://automate.domain.com"
            }
        }
        # No server responded successfully
        Write-Debug "No reachable server found from candidates: $($Server -join ', ')"
        return $null
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Test-CWAADotNetPrerequisite {
    <#
    .SYNOPSIS
        Checks for and optionally installs the .NET Framework 3.5 prerequisite.
    .DESCRIPTION
        Verifies that .NET Framework 3.5 is installed, which is required by the ConnectWise
        Automate agent. If 3.5 is missing, attempts automatic installation via
        Enable-WindowsOptionalFeature (Windows 8+) or Dism.exe (Windows 7/Server 2008 R2).
        With -Force, allows the agent install to proceed if .NET 2.0 or higher is present
        even when 3.5 cannot be installed. Without -Force, a missing 3.5 is a terminating error.
    .PARAMETER SkipDotNet
        Skips the .NET Framework check entirely. Returns $true immediately.
    .PARAMETER Force
        Allows fallback to .NET 2.0+ if 3.5 cannot be installed.
        Without -Force, missing 3.5 is a terminating error.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [switch]$SkipDotNet,
        [switch]$Force
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        if ($SkipDotNet) {
            Write-Debug 'SkipDotNet specified, skipping .NET prerequisite check.'
            return $true
        }
        $DotNET = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse -EA 0 | Get-ItemProperty -Name Version, Release -EA 0 | Where-Object { $_.PSChildName -match '^(?!S)\p{L}' } | Select-Object -ExpandProperty Version -EA 0
        if ($DotNet -like '3.5.*') {
            Write-Debug '.NET Framework 3.5 is already installed.'
            return $true
        }
        Write-Warning '.NET Framework 3.5 installation needed.'
        $OSVersion = [System.Environment]::OSVersion.Version
        if ([version]$OSVersion -gt [version]'6.2') {
            # Windows 8 / Server 2012 and later -- use Enable-WindowsOptionalFeature
            Try {
                if ($PSCmdlet.ShouldProcess('NetFx3', 'Enable-WindowsOptionalFeature')) {
                    $Install = Get-WindowsOptionalFeature -Online -FeatureName 'NetFx3'
                    if ($Install.State -ne 'EnablePending') {
                        $Install = Enable-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -All -NoRestart
                    }
                    if ($Install.RestartNeeded -or $Install.State -eq 'EnablePending') {
                        Write-Warning '.NET Framework 3.5 installed but a reboot is needed.'
                    }
                }
            }
            Catch {
                Write-Error ".NET 3.5 install failed." -ErrorAction Continue
                if (-not $Force) { Write-Error $Install -ErrorAction Stop }
            }
        }
        Elseif ([version]$OSVersion -gt [version]'6.1') {
            # Windows 7 / Server 2008 R2 -- use Dism.exe
            if ($PSCmdlet.ShouldProcess('NetFx3', 'Add Windows Feature')) {
                Try { $Result = & "${env:windir}\system32\Dism.exe" /English /NoRestart /Online /Enable-Feature /FeatureName:NetFx3 2>'' }
                Catch { Write-Warning 'Error calling Dism.exe.'; $Result = $Null }
                Try { $Result = & "${env:windir}\system32\Dism.exe" /English /Online /Get-FeatureInfo /FeatureName:NetFx3 2>'' }
                Catch { Write-Warning 'Error calling Dism.exe.'; $Result = $Null }
                if ($Result -contains 'State : Enabled') {
                    Write-Warning ".Net Framework 3.5 has been installed and enabled."
                }
                Elseif ($Result -contains 'State : Enable Pending') {
                    Write-Warning ".Net Framework 3.5 installed but a reboot is needed."
                }
                else {
                    Write-Error ".NET Framework 3.5 install failed." -ErrorAction Continue
                    if (-not $Force) { Write-Error $Result -ErrorAction Stop }
                }
            }
        }
        # Re-check after install attempt
        $DotNET = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name Version -EA 0 | Where-Object { $_.PSChildName -match '^(?!S)\p{L}' } | Select-Object -ExpandProperty Version
        if ($DotNet -like '3.5.*') {
            return $true
        }
        # .NET 3.5 still not available after install attempt
        if ($Force) {
            if ($DotNet -match '(?m)^[2-4].\d') {
                Write-Error ".NET 3.5 is not detected and could not be installed." -ErrorAction Continue
                return $true
            }
            else {
                Write-Error ".NET 2.0 or greater is not detected and could not be installed." -ErrorAction Stop
                return $false
            }
        }
        else {
            Write-Error ".NET 3.5 is not detected and could not be installed." -ErrorAction Stop
            return $false
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Test-CWAADownloadIntegrity {
    <#
    .SYNOPSIS
        Validates a downloaded file meets minimum size requirements.
    .DESCRIPTION
        Private helper that checks whether a downloaded installer file exists and
        exceeds the specified minimum size threshold. If the file is below the
        threshold, it is treated as corrupt or incomplete: a warning is emitted
        and the file is removed.
        The default threshold of 1234 KB matches the established convention for
        MSI/EXE installer files. The Agent_Uninstall.exe uses a lower threshold
        of 80 KB due to its smaller expected size.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$FilePath,
        [Parameter()]
        [string]$FileName,
        [Parameter()]
        [int]$MinimumSizeKB = 1234
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        if (-not $FileName) {
            $FileName = Split-Path $FilePath -Leaf
        }
    }
    Process {
        if (-not (Test-Path $FilePath)) {
            Write-Debug "$FileName not found at '$FilePath'."
            return $false
        }
        $fileSizeKB = (Get-Item $FilePath -ErrorAction SilentlyContinue).Length / 1KB
        if (-not ($fileSizeKB -gt $MinimumSizeKB)) {
            Write-Warning "$FileName size is below normal ($([math]::Round($fileSizeKB, 1)) KB < $MinimumSizeKB KB). Removing suspected corrupt file."
            Remove-Item $FilePath -ErrorAction SilentlyContinue -Force -Confirm:$False
            return $false
        }
        Write-Debug "$FileName integrity check passed ($([math]::Round($fileSizeKB, 1)) KB >= $MinimumSizeKB KB)."
        return $true
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Test-CWAAServiceExists {
    <#
    .SYNOPSIS
        Tests whether the Automate agent services are installed on the local computer.
    .DESCRIPTION
        Checks for the existence of the LTService and LTSvcMon services using the
        centralized $Script:CWAAServiceNames constant. Returns $true if at least one
        service is found, $false otherwise.
        When -WriteErrorOnMissing is specified, writes a WhatIf-aware error message
        if the services are not found. This consolidates the duplicated service existence
        check pattern found in Start-CWAA, Stop-CWAA, Restart-CWAA, and Reset-CWAA.
    .PARAMETER WriteErrorOnMissing
        When specified, writes a Write-Error message if the services are not found.
        The error message is WhatIf-aware (includes 'What If:' prefix when
        $WhatIfPreference is $true in the caller's scope).
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    Param(
        [switch]$WriteErrorOnMissing
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        $services = Get-Service $Script:CWAAServiceNames -ErrorAction SilentlyContinue
        if ($services) {
            return $true
        }
        if ($WriteErrorOnMissing) {
            if ($WhatIfPreference -ne $True) {
                Write-Error "Services NOT Found."
            }
            else {
                Write-Error "What If: Services NOT Found."
            }
        }
        return $false
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Wait-CWAACondition {
    <#
    .SYNOPSIS
        Polls a condition script block until it returns $true or a timeout is reached.
    .DESCRIPTION
        Generic polling helper that evaluates a condition at regular intervals. Returns $true
        if the condition was satisfied before the timeout, or $false if the timeout expired.
        Used to replace duplicated stopwatch-based Do-Until polling loops throughout the module.
    .PARAMETER Condition
        A script block that is evaluated each interval. The loop exits when this returns $true.
    .PARAMETER TimeoutSeconds
        Maximum number of seconds to wait before giving up. Must be at least 1.
    .PARAMETER IntervalSeconds
        Number of seconds to sleep between condition evaluations. Defaults to 5.
    .PARAMETER Activity
        Optional description logged via Write-Verbose at start and finish for diagnostics.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [ScriptBlock]$Condition,
        [Parameter(Mandatory = $True)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$TimeoutSeconds,
        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$IntervalSeconds = 5,
        [Parameter()]
        [string]$Activity
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        if ($Activity) { Write-Verbose "Waiting for: $Activity" }
        $timeout = New-TimeSpan -Seconds $TimeoutSeconds
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Do {
            Start-Sleep -Seconds $IntervalSeconds
            $conditionMet = & $Condition
        } Until ($stopwatch.Elapsed -gt $timeout -or $conditionMet)
        $stopwatch.Stop()
        $elapsedSeconds = [int]$stopwatch.Elapsed.TotalSeconds
        if ($conditionMet) {
            if ($Activity) { Write-Verbose "$Activity completed after $elapsedSeconds seconds." }
            return $true
        }
        else {
            if ($Activity) { Write-Verbose "$Activity timed out after $elapsedSeconds seconds." }
            return $false
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Write-CWAAEventLog {
    <#
    .SYNOPSIS
        Writes an entry to the Windows Event Log for ConnectWise Automate Agent operations.
    .DESCRIPTION
        Centralized event log writer for the ConnectWiseAutomateAgent module. Writes to the
        Application event log under the source defined by $Script:CWAAEventLogSource.
        On first call, registers the event source if it does not already exist (requires
        administrator privileges for registration). If the source cannot be registered or
        the write fails for any reason, the error is written to Write-Debug and the function
        returns silently. This ensures event logging never disrupts the calling function.
        Event ID ranges by category:
          1000-1039  Installation (Install, Uninstall, Redo, Update)
          2000-2029  Service Control (Start, Stop, Restart)
          3000-3069  Configuration (Reset, Backup, Proxy, LogLevel, AddRemove)
          4000-4039  Health/Monitoring (Repair, Register/Unregister task)
    .NOTES
        Version: 0.1.5.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$Message,
        [Parameter(Mandatory = $True)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$EntryType,
        [Parameter(Mandatory = $True)]
        [int]$EventId
    )
    Try {
        # Register the event source if it does not exist yet.
        # This requires administrator privileges the first time.
        if (-not [System.Diagnostics.EventLog]::SourceExists($Script:CWAAEventLogSource)) {
            New-EventLog -LogName $Script:CWAAEventLogName -Source $Script:CWAAEventLogSource -ErrorAction Stop
            Write-Debug "Write-CWAAEventLog: Registered event source '$($Script:CWAAEventLogSource)' in '$($Script:CWAAEventLogName)' log."
        }
        Write-EventLog -LogName $Script:CWAAEventLogName `
            -Source $Script:CWAAEventLogSource `
            -EventId $EventId `
            -EntryType $EntryType `
            -Message $Message `
            -ErrorAction Stop
        Write-Debug "Write-CWAAEventLog: Wrote EventId $EventId ($EntryType) to '$($Script:CWAAEventLogName)' log."
    }
    Catch {
        # Best-effort: never disrupt the calling function if event logging fails.
        Write-Debug "Write-CWAAEventLog: Failed to write event log entry. Error: $($_.Exception.Message)"
    }
}
function Get-CWAARedactedValue {
    <#
    .SYNOPSIS
        Returns a SHA256-hashed redacted representation of a sensitive string.
    .DESCRIPTION
        Private helper that returns '[SHA256:a1b2c3d4]' for non-empty strings
        and '[EMPTY]' for null/empty strings. Used to log that a credential value
        is present without exposing the actual content.
    .NOTES
        Version: 0.1.5.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$InputString
    )
    if ([string]::IsNullOrEmpty($InputString)) {
        return '[EMPTY]'
    }
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($InputString))
    $hashHex = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
    $sha256.Dispose()
    return "[SHA256:$($hashHex.Substring(0, 8))]"
}
function Initialize-CWAA {
    # Guard: PowerShell 1.0 lacks $PSVersionTable entirely
    if (-not ($PSVersionTable)) {
        Write-Warning 'PS1 Detected. PowerShell Version 2.0 or higher is required.'
        return
    }
    if ($PSVersionTable.PSVersion.Major -lt 3) {
        Write-Verbose 'PS2 Detected. PowerShell Version 3.0 or higher may be required for full functionality.'
    }
    # WOW64 relaunch: When running as 32-bit PowerShell on a 64-bit OS, many registry
    # and file system operations target the wrong hive/path. Re-launch under native
    # 64-bit PowerShell to ensure consistent behavior with the Automate agent services.
    # Note: This relaunch works correctly in single-file mode (ConnectWiseAutomateAgent.ps1).
    # In module mode (Import-Module), the .psm1 emits a warning instead since relaunch
    # cannot re-invoke Import-Module from within a function.
    if ($env:PROCESSOR_ARCHITEW6432 -match '64' -and [IntPtr]::Size -ne 8) {
        Write-Warning '32-bit PowerShell session detected on 64-bit OS. Attempting to launch 64-Bit session to process commands.'
        $pshell = "${env:WINDIR}\sysnative\windowspowershell\v1.0\powershell.exe"
        if (!(Test-Path -Path $pshell)) {
            # sysnative virtual folder is unavailable (e.g. older OS or non-interactive context).
            # Fall back to the real System32 path after disabling WOW64 file system redirection
            # so the 64-bit powershell.exe is accessible instead of the 32-bit redirected copy.
            Write-Warning 'SYSNATIVE PATH REDIRECTION IS NOT AVAILABLE. Attempting to access 64-bit PowerShell directly.'
            $pshell = "${env:WINDIR}\System32\WindowsPowershell\v1.0\powershell.exe"
            $FSRedirection = $True
            Add-Type -Debug:$False -Name Wow64 -Namespace 'Kernel32' -MemberDefinition @'
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool Wow64DisableWow64FsRedirection(ref IntPtr ptr);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool Wow64RevertWow64FsRedirection(ref IntPtr ptr);
'@
            [ref]$ptr = New-Object System.IntPtr
            $Null = [Kernel32.Wow64]::Wow64DisableWow64FsRedirection($ptr)
        }
        # Re-invoke the original command/script under the 64-bit host
        if ($myInvocation.Line) {
            &"$pshell" -NonInteractive -NoProfile $myInvocation.Line
        }
        elseif ($myInvocation.InvocationName) {
            &"$pshell" -NonInteractive -NoProfile -File "$($myInvocation.InvocationName)" $args
        }
        else {
            &"$pshell" -NonInteractive -NoProfile $myInvocation.MyCommand
        }
        $ExitResult = $LASTEXITCODE
        # Restore file system redirection if it was disabled
        if ($FSRedirection -eq $True) {
            [ref]$defaultptr = New-Object System.IntPtr
            $Null = [Kernel32.Wow64]::Wow64RevertWow64FsRedirection($defaultptr)
        }
        Write-Warning 'Exiting 64-bit session. Module will only remain loaded in native 64-bit PowerShell environment.'
        Exit $ExitResult
    }
    # Module-level constants â€” centralized to avoid duplication across functions.
    # These are cheap to create with no side effects, so they run at module load.
    $Script:CWAARegistryRoot          = 'HKLM:\SOFTWARE\LabTech\Service'
    $Script:CWAARegistrySettings      = 'HKLM:\SOFTWARE\LabTech\Service\Settings'
    $Script:CWAAInstallPath           = "${env:windir}\LTSVC"
    $Script:CWAAInstallerTempPath     = "${env:windir}\Temp\LabTech"
    $Script:CWAAServiceNames          = @('LTService', 'LTSvcMon')
    # Server URL validation regex breakdown:
    #   ^(https?://)?                              — optional http:// or https:// scheme
    #   (([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}   — IPv4 address (0.0.0.0 - 299.299.299.299)
    #   |                                          — OR
    #   [a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)  — hostname with optional subdomains
    #   $                                          — end of string, no trailing path/query
    $Script:CWAAServerValidationRegex = '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$'
    # Registry paths for Add/Remove Programs operations (shared by Hide, Show, Rename functions)
    $Script:CWAAInstallerProductKeys  = @(
        'HKLM:\SOFTWARE\Classes\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
        'HKLM:\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC'
    )
    $Script:CWAAUninstallKeys         = @(
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}'
    )
    $Script:CWAARegistryBackup        = 'HKLM:\SOFTWARE\LabTechBackup\Service'
    # Installer artifact paths for cleanup (used by Clear-CWAAInstallerArtifacts)
    $Script:CWAAInstallerArtifactPaths = @(
        "${env:windir}\Temp\_LTUpdate",
        "${env:windir}\Temp\Agent_Uninstall.exe",
        "${env:windir}\Temp\RemoteAgent.msi",
        "${env:windir}\Temp\Uninstall.exe",
        "${env:windir}\Temp\Uninstall.exe.config"
    )
    # Installer process names for cleanup (used by Clear-CWAAInstallerArtifacts)
    $Script:CWAAInstallerProcessNames = @('Agent_Uninstall', 'Uninstall', 'LTUpdate')
    # Windows Event Log settings (used by Write-CWAAEventLog)
    $Script:CWAAEventLogSource = 'ConnectWiseAutomateAgent'
    $Script:CWAAEventLogName   = 'Application'
    # Timeout and retry configuration — used by Wait-CWAACondition and Install-CWAA callers.
    # Centralized here so they are tunable and self-documenting in one place.
    $Script:CWAAInstallMaxAttempts       = 3
    $Script:CWAAInstallRetryDelaySeconds = 30
    $Script:CWAAServiceStartTimeoutSec   = 120   # 2 minutes — proxy startup wait
    $Script:CWAARegistrationTimeoutSec   = 900   # 15 minutes — agent registration wait
    $Script:CWAATrayPortMin              = 42000
    $Script:CWAATrayPortMax              = 42009
    $Script:CWAATrayPortDefault          = 42000
    $Script:CWAAUninstallWaitSeconds     = 10
    $Script:CWAAServiceWaitTimeoutSec    = 60    # 1 minute — Start/Stop/Restart/Reset service waits
    $Script:CWAARedoSettleDelaySeconds   = 20    # Redo-CWAA settling delay between uninstall and reinstall
    # Server version thresholds — document breaking changes in the server's deployment API.
    # Each threshold gates a different URL construction or installer format in Install-CWAA.
    $Script:CWAAVersionZipInstaller     = '240.331'  # InstallerToken deployments return ZIP (MSI+MST)
    $Script:CWAAVersionAnonymousChange  = '110.374'  # Anonymous MSI download URL changed (LT11 Patch 13)
    $Script:CWAAVersionVulnerabilityFix = '200.197'  # CVE fix: unauthenticated Deployment.aspx access
    $Script:CWAAVersionUpdateMinimum    = '105.001'  # Minimum version with update support
    # Agent process names — for forceful termination in Stop-CWAA after service stop timeout.
    $Script:CWAAAgentProcessNames = @('LTTray', 'LTSVC', 'LTSvcMon')
    # All service names including LabVNC — for full service cleanup in Uninstall-CWAA.
    $Script:CWAAAllServiceNames = @('LTService', 'LTSvcMon', 'LabVNC')
    # Service credential storage â€" populated on-demand by Get-CWAAProxy
    $Script:LTServiceKeys = [PSCustomObject]@{
        ServerPasswordString = ''
        PasswordString       = ''
    }
    # Proxy configuration â€” populated on-demand by Initialize-CWAANetworking
    $Script:LTProxy = [PSCustomObject]@{
        ProxyServerURL = ''
        ProxyUsername   = ''
        ProxyPassword   = ''
        Enabled         = $False
    }
    # Networking subsystem deferred flags. Initialize-CWAANetworking sets these to $True
    # after registration/initialization. This keeps module import fast and avoids
    # irreversible global session side effects until networking is actually needed.
    $Script:CWAANetworkInitialized = $False
    $Script:CWAACertCallbackRegistered = $False
}
function Initialize-CWAANetworking {
    <#
    .SYNOPSIS
        Lazily initializes networking objects on first use rather than at module load.
    .DESCRIPTION
        Performs deferred initialization of SSL certificate validation, TLS protocol enablement,
        WebProxy, WebClient, and proxy configuration. This function is idempotent --
        subsequent calls skip core initialization after the first successful run.
        SSL certificate handling uses a smart callback with graduated trust:
        - IP address targets: auto-bypass (IPs cannot have properly signed certificates)
        - Hostname name mismatch: tolerated (cert is trusted but CN/SAN does not match)
        - Chain/trust errors on hostnames: rejected (untrusted CA, self-signed)
        - -SkipCertificateCheck: full bypass for all certificate errors
        Called automatically by networking functions (Install-CWAA, Uninstall-CWAA,
        Update-CWAA, Set-CWAAProxy) in their Begin blocks. Non-networking functions
        never trigger these side effects, keeping module import fast and clean.
    .PARAMETER SkipCertificateCheck
        Disables all SSL certificate validation for the current PowerShell session.
        Use this when connecting to servers with self-signed certificates on hostname URLs.
        Note: This affects ALL HTTPS connections in the session, not just Automate operations.
    .NOTES
        Version: 0.1.5.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param(
        [switch]$SkipCertificateCheck
    )
    Write-Debug "Starting $($MyInvocation.InvocationName)"
    # Smart SSL certificate callback: Registered once per session. Uses graduated trust
    # rather than blanket bypass. The callback handles three scenarios:
    #   1. IP address targets: auto-bypass (IPs cannot have properly signed certs)
    #   2. Name mismatch only: tolerate (cert is trusted but hostname differs from CN/SAN)
    #   3. Chain/trust errors: reject unless SkipAll is set via -SkipCertificateCheck
    # On .NET 6+ (PS 7+), ServicePointManager triggers SYSLIB0014 obsolescence warning.
    # Conditionally wrap with pragma directives based on the runtime.
    if (-not $Script:CWAACertCallbackRegistered) {
        Try {
            # Check if the type already exists in the AppDomain (survives module re-import
            # because .NET types cannot be unloaded). Only call Add-Type if it's truly new.
            if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type) {
                $sslCallbackSource = @"
using System;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;
public class ServerCertificateValidationCallback
{
    public static bool SkipAll = false;
    public static void Register()
    {
        if (ServicePointManager.ServerCertificateValidationCallback == null)
        {
            ServicePointManager.ServerCertificateValidationCallback +=
                delegate(Object obj, X509Certificate certificate,
                         X509Chain chain, SslPolicyErrors errors)
                {
                    if (errors == SslPolicyErrors.None) return true;
                    if (SkipAll) return true;
                    var request = obj as HttpWebRequest;
                    if (request != null)
                    {
                        IPAddress ip;
                        if (IPAddress.TryParse(request.RequestUri.Host, out ip))
                            return true;
                    }
                    if (errors == SslPolicyErrors.RemoteCertificateNameMismatch)
                        return true;
                    return false;
                };
        }
    }
}
"@
                if ($PSVersionTable.PSEdition -eq 'Core') {
                    $sslCallbackSource = "#pragma warning disable SYSLIB0014`n" + $sslCallbackSource + "`n#pragma warning restore SYSLIB0014"
                }
                Add-Type -Debug:$False $sslCallbackSource
            }
            [ServerCertificateValidationCallback]::Register()
            $Script:CWAACertCallbackRegistered = $True
        }
        Catch {
            Write-Debug "SSL certificate validation callback could not be registered: $_"
        }
    }
    # Full bypass mode: sets the SkipAll flag on the C# class so the callback
    # accepts all certificates regardless of error type. Useful for servers with
    # self-signed certificates on hostname URLs.
    if ($SkipCertificateCheck -and $Script:CWAACertCallbackRegistered) {
        if (-not [ServerCertificateValidationCallback]::SkipAll) {
            Write-Warning 'SSL certificate validation is disabled for this session. This affects all HTTPS connections in this PowerShell session.'
            [ServerCertificateValidationCallback]::SkipAll = $True
        }
    }
    # Idempotency guard: TLS, WebClient, and proxy only need to run once per session
    if ($Script:CWAANetworkInitialized -eq $True) {
        Write-Debug "Initialize-CWAANetworking: Core networking already initialized, skipping."
        return
    }
    Write-Verbose 'Initializing networking subsystem (TLS, WebClient, Proxy).'
    # TLS protocol enablement: Enable TLS 1.2 and 1.3 for secure communication.
    # TLS 1.0 and 1.1 are deprecated (POODLE, BEAST vulnerabilities) and intentionally
    # excluded. Each version is added via bitwise OR to preserve already-enabled protocols.
    Try {
        if ([Net.SecurityProtocolType]::Tls12) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
        if ([Net.SecurityProtocolType]::Tls13) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13 }
    }
    Catch {
        Write-Debug "TLS protocol configuration skipped (may not apply to this .NET runtime): $_"
    }
    # WebClient and WebProxy are deprecated in .NET 6+ (SYSLIB0014) but still functional.
    # They remain the only option compatible with PowerShell 3.0-5.1 (.NET Framework).
    Try {
        $Script:LTWebProxy = New-Object System.Net.WebProxy
        $Script:LTServiceNetWebClient = New-Object System.Net.WebClient
        $Script:LTServiceNetWebClient.Proxy = $Script:LTWebProxy
    }
    Catch {
        Write-Warning "Failed to initialize network objects (WebClient/WebProxy may be unavailable in this .NET runtime). $_"
    }
    # Discover proxy settings from the installed agent (if present).
    # Errors are non-fatal: the module works without proxy on systems with no agent.
    $Null = Get-CWAAProxy -ErrorAction Continue
    $Script:CWAANetworkInitialized = $True
    Write-Debug "Exiting $($MyInvocation.InvocationName)"
}
function ConvertFrom-CWAASecurity {
    <#
    .SYNOPSIS
        Decodes a Base64-encoded string using TripleDES decryption.
    .DESCRIPTION
        This function decodes the provided string using the specified or default key.
        It uses TripleDES with an MD5-derived key and a fixed initialization vector.
        If decoding fails with the provided key and Force is enabled, alternate key
        values are attempted automatically.
    .PARAMETER InputString
        The Base64-encoded string to be decoded.
    .PARAMETER Key
        The key used for decoding. If not provided, default values will be tried.
    .PARAMETER Force
        Forces the function to try alternate key values if decoding fails using
        the provided key. Enabled by default.
    .EXAMPLE
        ConvertFrom-CWAASecurity -InputString 'EncodedValue'
        Decodes the string using the default key.
    .EXAMPLE
        ConvertFrom-CWAASecurity -InputString 'EncodedValue' -Key 'MyCustomKey'
        Decodes the string using a custom key.
    .NOTES
        Author: Chris Taylor
        Alias: ConvertFrom-LTSecurity
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('ConvertFrom-LTSecurity')]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 1)]
        [string[]]$InputString,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [string[]]$Key,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
        [switch]$Force = $True
    )
    Begin {
        $DefaultKey = 'Thank you for using LabTech.'
        $_initializationVector = [byte[]](240, 3, 45, 29, 0, 76, 173, 59)
        $NoKeyPassed = $False
        $DecodedString = $Null
        $DecodeString = $Null
    }
    Process {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        if ($Null -eq $Key) {
            $NoKeyPassed = $True
            $Key = $DefaultKey
        }
        foreach ($testInput in $InputString) {
            $DecodeString = $Null
            foreach ($testKey in $Key) {
                if ($Null -eq $DecodeString) {
                    if ($Null -eq $testKey) {
                        $NoKeyPassed = $True
                        $testKey = $DefaultKey
                    }
                    Write-Debug "Attempting Decode for '$($testInput)' with Key '$($testKey)'"
                    Try {
                        $inputBytes = [System.Convert]::FromBase64String($testInput)
                        $tripleDesProvider = New-Object System.Security.Cryptography.TripleDESCryptoServiceProvider
                        $tripleDesProvider.key = (New-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([Text.Encoding]::UTF8.GetBytes($testKey))
                        $tripleDesProvider.IV = $_initializationVector
                        $cryptoTransform = $tripleDesProvider.CreateDecryptor()
                        $DecodeString = [System.Text.Encoding]::UTF8.GetString($cryptoTransform.TransformFinalBlock($inputBytes, 0, ($inputBytes.Length)))
                        $DecodedString += @($DecodeString)
                    }
                    Catch {
                        Write-Debug "Decode failed for '$($testInput)' with Key '$($testKey)': $_"
                    }
                    Finally {
                        if ((Get-Variable -Name cryptoTransform -Scope 0 -EA 0)) { try { $cryptoTransform.Dispose() } catch { $cryptoTransform.Clear() } }
                        if ((Get-Variable -Name tripleDesProvider -Scope 0 -EA 0)) { try { $tripleDesProvider.Dispose() } catch { $tripleDesProvider.Clear() } }
                    }
                }
            }
            if ($Null -eq $DecodeString) {
                if ($Force) {
                    if ($NoKeyPassed) {
                        $DecodeString = ConvertFrom-CWAASecurity -InputString "$($testInput)" -Key '' -Force:$False
                        if (-not ($Null -eq $DecodeString)) {
                            $DecodedString += @($DecodeString)
                        }
                    }
                    else {
                        $DecodeString = ConvertFrom-CWAASecurity -InputString "$($testInput)"
                        if (-not ($Null -eq $DecodeString)) {
                            $DecodedString += @($DecodeString)
                        }
                    }
                }
                else {
                    Write-Debug "All decode attempts exhausted for '$($testInput)' with Force disabled."
                }
            }
        }
    }
    End {
        if ($Null -eq $DecodedString) {
            Write-Debug "Failed to Decode string: '$($InputString)'"
            return $Null
        }
        else {
            return $DecodedString
        }
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function ConvertTo-CWAASecurity {
    <#
    .SYNOPSIS
        Encodes a string using TripleDES encryption compatible with Automate operations.
    .DESCRIPTION
        This function encodes the provided string using the specified or default key.
        It uses TripleDES with an MD5-derived key and a fixed initialization vector,
        returning a Base64-encoded result.
    .PARAMETER InputString
        The string to be encoded.
    .PARAMETER Key
        The key used for encoding. If not provided, a default value will be used.
    .EXAMPLE
        ConvertTo-CWAASecurity -InputString 'PlainTextValue'
        Encodes the string using the default key.
    .EXAMPLE
        ConvertTo-CWAASecurity -InputString 'PlainTextValue' -Key 'MyCustomKey'
        Encodes the string using a custom key.
    .NOTES
        Author: Chris Taylor
        Alias: ConvertTo-LTSecurity
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('ConvertTo-LTSecurity')]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [string]$InputString,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Key
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        $_initializationVector = [byte[]](240, 3, 45, 29, 0, 76, 173, 59)
        $DefaultKey = 'Thank you for using LabTech.'
        if ($Null -eq $Key) {
            $Key = $DefaultKey
        }
        try {
            $inputBytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
        }
        catch {
            try { $inputBytes = [System.Text.Encoding]::ASCII.GetBytes($InputString) } catch {
                Write-Debug "Failed to convert InputString to byte array: $_"
            }
        }
        Write-Debug "Attempting Encode for '$($InputString)' with Key '$($Key)'"
        $encodedString = ''
        try {
            $tripleDesProvider = New-Object System.Security.Cryptography.TripleDESCryptoServiceProvider
            $tripleDesProvider.key = (New-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([Text.Encoding]::UTF8.GetBytes($Key))
            $tripleDesProvider.IV = $_initializationVector
            $cryptoTransform = $tripleDesProvider.CreateEncryptor()
            $encodedString = [System.Convert]::ToBase64String($cryptoTransform.TransformFinalBlock($inputBytes, 0, ($inputBytes.Length)))
        }
        catch {
            Write-Debug "Failed to Encode string: '$($InputString)'. $_"
        }
        Finally {
            if ($cryptoTransform) { try { $cryptoTransform.Dispose() } catch { $cryptoTransform.Clear() } }
            if ($tripleDesProvider) { try { $tripleDesProvider.Dispose() } catch { $tripleDesProvider.Clear() } }
        }
        return $encodedString
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Invoke-CWAACommand {
    <#
    .SYNOPSIS
        Sends a service command to the ConnectWise Automate agent.
    .DESCRIPTION
        Sends a control command to the LTService Windows service using sc.exe.
        The agent supports a set of predefined commands (mapped to numeric IDs 128-145)
        that trigger actions such as sending inventory, updating schedules, or killing processes.
    .PARAMETER Command
        One or more commands to send to the agent service. Valid values include
        'Update Schedule', 'Send Inventory', 'Send Drives', 'Send Processes',
        'Send Spyware List', 'Send Apps', 'Send Events', 'Send Printers',
        'Send Status', 'Send Screen', 'Send Services', 'Analyze Network',
        'Write Last Contact Date', 'Kill VNC', 'Kill Trays', 'Send Patch Reboot',
        'Run App Care Update', and 'Start App Care Daytime Patching'.
    .EXAMPLE
        Invoke-CWAACommand -Command 'Send Inventory'
        Sends the 'Send Inventory' command to the agent service.
    .EXAMPLE
        'Send Status', 'Send Apps' | Invoke-CWAACommand
        Sends multiple commands to the agent service via pipeline.
    .NOTES
        Author: Chris Taylor
        Alias: Invoke-LTServiceCommand
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Invoke-LTServiceCommand')]
    Param(
        [Parameter(Mandatory = $True, Position = 1, ValueFromPipeline = $True)]
        [ValidateSet(
            "Update Schedule",
            "Send Inventory",
            "Send Drives",
            "Send Processes",
            "Send Spyware List",
            "Send Apps",
            "Send Events",
            "Send Printers",
            "Send Status",
            "Send Screen",
            "Send Services",
            "Analyze Network",
            "Write Last Contact Date",
            "Kill VNC",
            "Kill Trays",
            "Send Patch Reboot",
            "Run App Care Update",
            "Start App Care Daytime Patching"
        )]
        [string[]]$Command
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $Service = Get-Service 'LTService' -ErrorAction SilentlyContinue
    }
    Process {
        if (-not $Service) {
            Write-Warning "Service 'LTService' was not found. Cannot send service command."
            return
        }
        if ($Service.Status -ne 'Running') {
            Write-Warning "Service 'LTService' is not running. Cannot send service command."
            return
        }
        foreach ($Cmd in $Command) {
            $CommandID = $Null
            Try {
                switch ($Cmd) {
                    'Update Schedule'                  { $CommandID = 128 }
                    'Send Inventory'                   { $CommandID = 129 }
                    'Send Drives'                      { $CommandID = 130 }
                    'Send Processes'                    { $CommandID = 131 }
                    'Send Spyware List'                { $CommandID = 132 }
                    'Send Apps'                        { $CommandID = 133 }
                    'Send Events'                      { $CommandID = 134 }
                    'Send Printers'                    { $CommandID = 135 }
                    'Send Status'                      { $CommandID = 136 }
                    'Send Screen'                      { $CommandID = 137 }
                    'Send Services'                    { $CommandID = 138 }
                    'Analyze Network'                  { $CommandID = 139 }
                    'Write Last Contact Date'          { $CommandID = 140 }
                    'Kill VNC'                         { $CommandID = 141 }
                    'Kill Trays'                       { $CommandID = 142 }
                    'Send Patch Reboot'                { $CommandID = 143 }
                    'Run App Care Update'              { $CommandID = 144 }
                    'Start App Care Daytime Patching'  { $CommandID = 145 }
                    default { Write-Debug "Unrecognized command: '$Cmd'" }
                }
                if ($PSCmdlet.ShouldProcess("LTService", "Send Service Command '$($Cmd)' ($($CommandID))")) {
                    if ($Null -ne $CommandID) {
                        Write-Debug "Sending service command '$($Cmd)' ($($CommandID)) to 'LTService'"
                        Try {
                            $Null = & "$env:windir\system32\sc.exe" control LTService $($CommandID) 2>''
                            if ($LASTEXITCODE -ne 0) {
                                Write-Warning "sc.exe control returned exit code $LASTEXITCODE for command '$Cmd' ($CommandID)."
                            }
                            Write-Output "Sent Command '$($Cmd)' to 'LTService'"
                        }
                        Catch {
                            Write-Output "Error calling sc.exe. Failed to send command."
                        }
                    }
                }
            }
            Catch {
                Write-Warning "Failed to process command '$Cmd'. $($_.Exception.Message)"
            }
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Test-CWAAPort {
    <#
    .SYNOPSIS
        Tests connectivity to TCP ports required by the ConnectWise Automate agent.
    .DESCRIPTION
        Verifies that the local LTTray port is available and tests connectivity to
        the required TCP ports (70, 80, 443) on the Automate server, plus port 8002
        on the Automate mediator server.
        If no server is provided, the function attempts to detect it from the installed
        agent configuration or backup info.
    .PARAMETER Server
        The URL of the Automate server (e.g., https://automate.domain.com).
        If not provided, the function uses Get-CWAAInfo or Get-CWAAInfoBackup to discover it.
    .PARAMETER TrayPort
        The local port LTSvc.exe listens on for LTTray communication.
        Defaults to 42000 if not provided or not found in agent configuration.
    .PARAMETER Quiet
        Returns a boolean connectivity result instead of verbose output.
    .EXAMPLE
        Test-CWAAPort -Server 'https://automate.domain.com'
        Tests all required ports against the specified server.
    .EXAMPLE
        Test-CWAAPort -Quiet
        Returns $True if the TrayPort is available, $False otherwise.
    .EXAMPLE
        Get-CWAAInfo | Test-CWAAPort
        Pipes the installed agent's Server and TrayPort into Test-CWAAPort via pipeline.
    .NOTES
        Author: Chris Taylor
        Alias: Test-LTPorts
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Test-LTPorts')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $True)]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [int]$TrayPort,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Quiet
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $MediatorServer = 'mediator.labtechsoftware.com'
        function Private:TestPort {
            Param(
                [parameter(Position = 0)]
                [string]$ComputerName,
                [parameter(Mandatory = $False)]
                [System.Net.IPAddress]$IPAddress,
                [parameter(Mandatory = $True, Position = 1)]
                [int]$Port
            )
            $RemoteServer = if ([string]::IsNullOrEmpty($ComputerName)) { $IPAddress } else { $ComputerName }
            if ([string]::IsNullOrEmpty($RemoteServer)) {
                Write-Error "No ComputerName or IPAddress was provided to test."
                return
            }
            $tcpClient = New-Object System.Net.Sockets.TcpClient
            Try {
                Write-Output "Connecting to $($RemoteServer):$Port (TCP).."
                $tcpClient.Connect($RemoteServer, $Port)
                Write-Output 'Connection successful'
            }
            Catch {
                Write-Output 'Connection failed'
            }
            Finally {
                $tcpClient.Close()
            }
        }
    }
    Process {
        if (-not ($Server) -and (-not ($TrayPort) -or -not ($Quiet))) {
            Write-Verbose 'No Server Input - Checking for names.'
            $Server = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand 'Server' -EA 0
            if (-not ($Server)) {
                Write-Verbose 'No Server found in installed Service Info. Checking for Service Backup.'
                $Server = Get-CWAAInfoBackup -EA 0 -Verbose:$False | Select-Object -Expand 'Server' -EA 0
            }
        }
        if (-not ($Quiet) -or (($TrayPort) -ge 1 -and ($TrayPort) -le 65530)) {
            if (-not ($TrayPort) -or -not (($TrayPort) -ge 1 -and ($TrayPort) -le 65530)) {
                # Discover TrayPort from agent configuration if not provided
                $TrayPort = (Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand TrayPort -EA 0)
            }
            if (-not ($TrayPort) -or $TrayPort -notmatch '^\d+$') { $TrayPort = 42000 }
            [array]$processes = @()
            # Get all processes using the TrayPort (default 42000)
            Try {
                $netstatOutput = & "$env:windir\system32\netstat.exe" -a -o -n | Select-String -Pattern " .*[0-9\.]+:$($TrayPort).*[0-9\.]+:[0-9]+ .*?([0-9]+)" -EA 0
            }
            Catch {
                Write-Output 'Error calling netstat.exe.'
                $netstatOutput = $null
            }
            foreach ($netstatLine in $netstatOutput) {
                $processes += ($netstatLine -split ' {4,}')[-1]
            }
            $processes = $processes | Where-Object { $_ -gt 0 -and $_ -match '^\d+$' } | Sort-Object | Get-Unique
            if (($processes)) {
                if (-not ($Quiet)) {
                    foreach ($processId in $processes) {
                        if ((Get-Process -Id $processId -EA 0 | Select-Object -Expand ProcessName -EA 0) -eq 'LTSvc') {
                            Write-Output "TrayPort Port $TrayPort is being used by LTSvc."
                        }
                        else {
                            Write-Output "Error: TrayPort Port $TrayPort is being used by $(Get-Process -Id $processId | Select-Object -Expand ProcessName -EA 0)."
                        }
                    }
                }
                else { return $False }
            }
            elseif (($Quiet) -eq $True) {
                return $True
            }
            else {
                Write-Output "TrayPort Port $TrayPort is available."
            }
        }
        foreach ($serverEntry in $Server) {
            if ($Quiet) {
                $cleanServerAddress = ($serverEntry -replace 'https?://', '' | ForEach-Object { $_.Trim() })
                Test-Connection $cleanServerAddress -Quiet
                return
            }
            if ($serverEntry -match $Script:CWAAServerValidationRegex) {
                Try {
                    $cleanServerAddress = ($serverEntry -replace 'https?://', '' | ForEach-Object { $_.Trim() })
                    Write-Output 'Testing connectivity to required TCP ports:'
                    TestPort -ComputerName $cleanServerAddress -Port 70
                    TestPort -ComputerName $cleanServerAddress -Port 80
                    TestPort -ComputerName $cleanServerAddress -Port 443
                    TestPort -ComputerName $MediatorServer -Port 8002
                }
                Catch {
                    Write-Error "There was an error testing the ports for '$serverEntry'. $($_)" -ErrorAction Stop
                }
            }
            else {
                Write-Warning "Server address '$($serverEntry)' is not valid or not formatted correctly. Example: https://automate.domain.com"
            }
        }
    }
    End {
        if (-not ($Quiet)) {
            Write-Output 'Test-CWAAPort Finished'
        }
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Test-CWAAServerConnectivity {
    <#
    .SYNOPSIS
        Tests connectivity to a ConnectWise Automate server's agent endpoint.
    .DESCRIPTION
        Verifies that an Automate server is online and responding by querying the
        agent.aspx endpoint. Validates that the response matches the expected version
        format (pipe-delimited string ending with a version number).
        If no server is provided, the function attempts to discover it from the
        installed agent configuration or backup settings.
        Returns a result object per server with availability status and version info,
        or a simple boolean in Quiet mode.
    .PARAMETER Server
        One or more ConnectWise Automate server URLs (e.g., https://automate.domain.com).
        If not provided, the function uses Get-CWAAInfo or Get-CWAAInfoBackup to discover it.
    .PARAMETER Quiet
        Returns $True if all servers are reachable, $False otherwise.
    .EXAMPLE
        Test-CWAAServerConnectivity -Server 'https://automate.domain.com'
        Tests connectivity and returns a result object with Server, Available, Version, and ErrorMessage.
    .EXAMPLE
        Test-CWAAServerConnectivity -Quiet
        Returns $True if the discovered server is reachable, $False otherwise.
    .EXAMPLE
        Get-CWAAInfo | Test-CWAAServerConnectivity
        Tests connectivity to the server configured on the installed agent via pipeline.
    .NOTES
        Author: Chris Taylor
        Alias: Test-LTServerConnectivity
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Test-LTServerConnectivity')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $True, ValueFromPipeline = $True)]
        [string[]]$Server,
        [switch]$Quiet
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        # Enable TLS 1.2 for the web request without full Initialize-CWAANetworking
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        # Expected response pattern from agent.aspx: pipe-delimited string ending with version
        $agentResponsePattern = '\|\|\|\|\|\|\d+\.\d+'
        $versionExtractPattern = '(\d+\.\d+)\s*$'
        $allAvailable = $True
    }
    Process {
        if (-not $Server) {
            Write-Verbose 'No Server provided - checking installed agent configuration.'
            $Server = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False |
                Select-Object -Expand 'Server' -EA 0
            if (-not $Server) {
                Write-Verbose 'No Server found in agent config. Checking backup settings.'
                $Server = Get-CWAAInfoBackup -EA 0 -Verbose:$False |
                    Select-Object -Expand 'Server' -EA 0
            }
            if (-not $Server) {
                Write-Error "No server could be determined. Provide a -Server parameter or ensure the agent is installed."
                return
            }
        }
        foreach ($serverEntry in $Server) {
            # Normalize: ensure the URL has a scheme
            $serverUrl = $serverEntry.Trim()
            if ($serverUrl -notmatch '^https?://') {
                $serverUrl = "https://$serverUrl"
            }
            # Validate server address format
            $cleanAddress = $serverUrl -replace 'https?://', ''
            if ($cleanAddress -notmatch $Script:CWAAServerValidationRegex) {
                Write-Warning "Server address '$serverEntry' is not valid or not formatted correctly. Example: https://automate.domain.com"
                $allAvailable = $False
                if (-not $Quiet) {
                    [PSCustomObject]@{
                        Server       = $serverEntry
                        Available    = $False
                        Version      = $Null
                        ErrorMessage = 'Invalid server address format'
                    }
                }
                continue
            }
            $endpointUrl = "$serverUrl/LabTech/agent.aspx"
            $available = $False
            $version = $Null
            $errorMessage = $Null
            Try {
                Write-Verbose "Testing connectivity to $endpointUrl"
                $response = Invoke-RestMethod -Uri $endpointUrl -TimeoutSec 10 -ErrorAction Stop
                if ($response -match $agentResponsePattern) {
                    $available = $True
                    if ($response -match $versionExtractPattern) {
                        $version = $Matches[1]
                    }
                    Write-Verbose "Server '$serverEntry' is available (version $version)."
                }
                else {
                    $errorMessage = 'Server responded but with unexpected format'
                    Write-Verbose "Server '$serverEntry' responded but response did not match expected agent pattern."
                }
            }
            Catch {
                $errorMessage = $_.Exception.Message
                Write-Verbose "Server '$serverEntry' is not available: $errorMessage"
            }
            if (-not $available) {
                $allAvailable = $False
            }
            if (-not $Quiet) {
                [PSCustomObject]@{
                    Server       = $serverEntry
                    Available    = $available
                    Version      = $version
                    ErrorMessage = $errorMessage
                }
            }
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
        if ($Quiet) {
            return $allAvailable
        }
    }
}
function Hide-CWAAAddRemove {
    <#
    .SYNOPSIS
        Hides the Automate agent from the Add/Remove Programs list.
    .DESCRIPTION
        Sets the SystemComponent registry value to 1 on Automate agent uninstall keys,
        which hides the agent from the Windows Add/Remove Programs (Programs and Features) list.
        Also cleans up any leftover HiddenProductName registry values from older hiding methods.
    .EXAMPLE
        Hide-CWAAAddRemove
        Hides the Automate agent entry from Add/Remove Programs.
    .EXAMPLE
        Hide-CWAAAddRemove -WhatIf
        Shows what registry changes would be made without applying them.
    .NOTES
        Author: Chris Taylor
        Alias: Hide-LTAddRemove
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Hide-LTAddRemove')]
    Param()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $RegRoots = $Script:CWAAInstallerProductKeys
        $PublisherRegRoots = $Script:CWAAUninstallKeys
        $RegEntriesFound = 0
        $RegEntriesChanged = 0
    }
    Process {
        Try {
            foreach ($RegRoot in $RegRoots) {
                if (Test-Path $RegRoot) {
                    if (Get-ItemProperty $RegRoot -Name HiddenProductName -ErrorAction SilentlyContinue) {
                        if (!(Get-ItemProperty $RegRoot -Name ProductName -ErrorAction SilentlyContinue)) {
                            Write-Verbose 'Automate agent found with HiddenProductName value.'
                            Try {
                                Rename-ItemProperty $RegRoot -Name HiddenProductName -NewName ProductName
                            }
                            Catch {
                                Write-Error "There was an error renaming the registry value. $($_)" -ErrorAction Stop
                            }
                        }
                        else {
                            Write-Verbose 'Automate agent found with unused HiddenProductName value.'
                            Try {
                                Remove-ItemProperty $RegRoot -Name HiddenProductName -EA 0 -Confirm:$False -WhatIf:$False -Force
                            }
                            Catch {
                                Write-Debug "Failed to remove unused HiddenProductName from '$RegRoot': $($_)"
                            }
                        }
                    }
                }
            }
            foreach ($RegRoot in $PublisherRegRoots) {
                if (Test-Path $RegRoot) {
                    $RegKey = Get-Item $RegRoot -ErrorAction SilentlyContinue
                    if ($RegKey) {
                        $RegEntriesFound++
                        if ($PSCmdlet.ShouldProcess("$($RegRoot)", "Set Registry Values to Hide $($RegKey.GetValue('DisplayName'))")) {
                            $RegEntriesChanged++
                            @('SystemComponent') | ForEach-Object {
                                if (($RegKey.GetValue("$($_)")) -ne 1) {
                                    Write-Verbose "Setting $($RegRoot)\$($_)=1"
                                    Set-ItemProperty $RegRoot -Name "$($_)" -Value 1 -Type DWord -WhatIf:$False -Confirm:$False -Verbose:$False
                                }
                            }
                        }
                    }
                }
            }
            # Output success/warning at end of try block (replaces if($?) pattern in End block)
            if ($RegEntriesFound -gt 0 -and $RegEntriesChanged -eq $RegEntriesFound) {
                Write-Output 'Automate agent is hidden from Add/Remove Programs.'
                Write-CWAAEventLog -EventId 3040 -EntryType Information -Message 'Agent hidden from Add/Remove Programs.'
            }
            elseif ($WhatIfPreference -ne $True) {
                Write-Warning "Automate agent may not be hidden from Add/Remove Programs."
                Write-CWAAEventLog -EventId 3041 -EntryType Warning -Message 'Agent may not be hidden from Add/Remove Programs.'
            }
        }
        Catch {
            Write-CWAAEventLog -EventId 3042 -EntryType Error -Message "Failed to hide agent from Add/Remove Programs. Error: $($_.Exception.Message)"
            Write-Error "There was an error setting the registry values. $($_)" -ErrorAction Stop
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Rename-CWAAAddRemove {
    <#
    .SYNOPSIS
        Renames the Automate agent entry in the Add/Remove Programs list.
    .DESCRIPTION
        Changes the DisplayName (and optionally Publisher) registry values for the Automate agent
        uninstall keys, which controls how the agent appears in the Windows Add/Remove Programs
        (Programs and Features) list.
    .PARAMETER Name
        The display name for the Automate agent as shown in the list of installed software.
    .PARAMETER PublisherName
        The publisher name for the Automate agent as shown in the list of installed software.
    .EXAMPLE
        Rename-CWAAAddRemove -Name 'My Remote Agent'
        Renames the Automate agent display name to 'My Remote Agent'.
    .EXAMPLE
        Rename-CWAAAddRemove -Name 'My Remote Agent' -PublisherName 'My Company'
        Renames both the display name and publisher name in Add/Remove Programs.
    .NOTES
        Author: Chris Taylor
        Alias: Rename-LTAddRemove
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Rename-LTAddRemove')]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        $Name,
        [Parameter(Mandatory = $False)]
        [AllowNull()]
        [string]$PublisherName
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $RegRoots = @($Script:CWAAUninstallKeys[0], $Script:CWAAUninstallKeys[1]) + $Script:CWAAInstallerProductKeys
        $PublisherRegRoots = $Script:CWAAUninstallKeys
        $RegNameFound = 0
        $RegPublisherFound = 0
    }
    Process {
        Try {
            foreach ($RegRoot in $RegRoots) {
                if (Get-ItemProperty $RegRoot -Name DisplayName -ErrorAction SilentlyContinue) {
                    if ($PSCmdlet.ShouldProcess("$($RegRoot)\DisplayName=$($Name)", 'Set Registry Value')) {
                        Write-Verbose "Setting $($RegRoot)\DisplayName=$($Name)"
                        Set-ItemProperty $RegRoot -Name DisplayName -Value $Name -Confirm:$False
                        $RegNameFound++
                    }
                }
                elseif (Get-ItemProperty $RegRoot -Name HiddenProductName -ErrorAction SilentlyContinue) {
                    if ($PSCmdlet.ShouldProcess("$($RegRoot)\HiddenProductName=$($Name)", 'Set Registry Value')) {
                        Write-Verbose "Setting $($RegRoot)\HiddenProductName=$($Name)"
                        Set-ItemProperty $RegRoot -Name HiddenProductName -Value $Name -Confirm:$False
                        $RegNameFound++
                    }
                }
            }
        }
        Catch {
            Write-CWAAEventLog -EventId 3062 -EntryType Error -Message "Failed to rename agent in Add/Remove Programs. Error: $($_.Exception.Message)"
            Write-Error "There was an error setting the DisplayName registry value. $($_)" -ErrorAction Stop
        }
        if (($PublisherName)) {
            Try {
                foreach ($RegRoot in $PublisherRegRoots) {
                    if (Get-ItemProperty $RegRoot -Name Publisher -ErrorAction SilentlyContinue) {
                        if ($PSCmdlet.ShouldProcess("$($RegRoot)\Publisher=$($PublisherName)", 'Set Registry Value')) {
                            Write-Verbose "Setting $($RegRoot)\Publisher=$($PublisherName)"
                            Set-ItemProperty $RegRoot -Name Publisher -Value $PublisherName -Confirm:$False
                            $RegPublisherFound++
                        }
                    }
                }
            }
            Catch {
                Write-CWAAEventLog -EventId 3062 -EntryType Error -Message "Failed to set agent publisher name. Error: $($_.Exception.Message)"
                Write-Error "There was an error setting the Publisher registry value. $($_)" -ErrorAction Stop
            }
        }
        # Output success/warning (replaces if($?) pattern formerly in End block).
        # Guarded by $WhatIfPreference because SupportsShouldProcess is enabled and
        # these messages would be misleading during a -WhatIf dry run.
        if ($WhatIfPreference -ne $True) {
            if ($RegNameFound -gt 0) {
                Write-Output "Automate agent is now listed as $($Name) in Add/Remove Programs."
                Write-CWAAEventLog -EventId 3060 -EntryType Information -Message "Agent display name changed to '$Name' in Add/Remove Programs."
            }
            else {
                Write-Warning "Automate agent was not found in installed software and the Name was not changed."
                Write-CWAAEventLog -EventId 3061 -EntryType Warning -Message "Agent not found in installed software. Display name not changed."
            }
            if (($PublisherName)) {
                if ($RegPublisherFound -gt 0) {
                    Write-Output "The Publisher is now listed as $($PublisherName)."
                    Write-CWAAEventLog -EventId 3060 -EntryType Information -Message "Agent publisher changed to '$PublisherName' in Add/Remove Programs."
                }
                else {
                    Write-Warning "Automate agent was not found in installed software and the Publisher was not changed."
                    Write-CWAAEventLog -EventId 3061 -EntryType Warning -Message "Agent not found in installed software. Publisher name not changed."
                }
            }
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Show-CWAAAddRemove {
    <#
    .SYNOPSIS
        Shows the Automate agent in the Add/Remove Programs list.
    .DESCRIPTION
        Sets the SystemComponent registry value to 0 on Automate agent uninstall keys,
        which makes the agent visible in the Windows Add/Remove Programs (Programs and Features) list.
        Also cleans up any leftover HiddenProductName registry values from older hiding methods.
    .EXAMPLE
        Show-CWAAAddRemove
        Makes the Automate agent entry visible in Add/Remove Programs.
    .EXAMPLE
        Show-CWAAAddRemove -WhatIf
        Shows what registry changes would be made without applying them.
    .NOTES
        Author: Chris Taylor
        Alias: Show-LTAddRemove
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Show-LTAddRemove')]
    Param()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $RegRoots = $Script:CWAAInstallerProductKeys
        $PublisherRegRoots = $Script:CWAAUninstallKeys
        $RegEntriesFound = 0
        $RegEntriesChanged = 0
    }
    Process {
        Try {
            foreach ($RegRoot in $RegRoots) {
                if (Test-Path $RegRoot) {
                    if (Get-ItemProperty $RegRoot -Name HiddenProductName -ErrorAction SilentlyContinue) {
                        if (!(Get-ItemProperty $RegRoot -Name ProductName -ErrorAction SilentlyContinue)) {
                            Write-Verbose 'Automate agent found with HiddenProductName value.'
                            Try {
                                Rename-ItemProperty $RegRoot -Name HiddenProductName -NewName ProductName
                            }
                            Catch {
                                Write-Error "There was an error renaming the registry value. $($_)" -ErrorAction Stop
                            }
                        }
                        else {
                            Write-Verbose 'Automate agent found with unused HiddenProductName value.'
                            Try {
                                Remove-ItemProperty $RegRoot -Name HiddenProductName -EA 0 -Confirm:$False -WhatIf:$False -Force
                            }
                            Catch {
                                Write-Debug "Failed to remove unused HiddenProductName from '$RegRoot': $($_)"
                            }
                        }
                    }
                }
            }
            foreach ($RegRoot in $PublisherRegRoots) {
                if (Test-Path $RegRoot) {
                    $RegKey = Get-Item $RegRoot -ErrorAction SilentlyContinue
                    if ($RegKey) {
                        $RegEntriesFound++
                        if ($PSCmdlet.ShouldProcess("$($RegRoot)", "Set Registry Values to Show $($RegKey.GetValue('DisplayName'))")) {
                            $RegEntriesChanged++
                            @('SystemComponent') | ForEach-Object {
                                if (($RegKey.GetValue("$($_)")) -eq 1) {
                                    Write-Verbose "Setting $($RegRoot)\$($_)=0"
                                    Set-ItemProperty $RegRoot -Name "$($_)" -Value 0 -Type DWord -WhatIf:$False -Confirm:$False -Verbose:$False
                                }
                            }
                        }
                    }
                }
            }
            # Output success/warning at end of try block (replaces if($?) pattern in End block)
            if ($RegEntriesFound -gt 0 -and $RegEntriesChanged -eq $RegEntriesFound) {
                Write-Output 'Automate agent is visible in Add/Remove Programs.'
                Write-CWAAEventLog -EventId 3050 -EntryType Information -Message 'Agent shown in Add/Remove Programs.'
            }
            elseif ($WhatIfPreference -ne $True) {
                Write-Warning "Automate agent may not be visible in Add/Remove Programs."
                Write-CWAAEventLog -EventId 3051 -EntryType Warning -Message 'Agent may not be visible in Add/Remove Programs.'
            }
        }
        Catch {
            Write-CWAAEventLog -EventId 3052 -EntryType Error -Message "Failed to show agent in Add/Remove Programs. Error: $($_.Exception.Message)"
            Write-Error "There was an error setting the registry values. $($_)" -ErrorAction Stop
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Install-CWAA {
    <#
    .SYNOPSIS
        Installs the ConnectWise Automate Agent on the local computer.
    .DESCRIPTION
        Downloads and installs the ConnectWise Automate agent from the specified server URL.
        Supports authentication via InstallerToken (preferred) or ServerPassword. The function handles
        prerequisite checks for .NET Framework 3.5, MSI download with file integrity validation,
        proxy configuration, TrayPort conflict resolution, and post-install agent registration verification.
        If a previous installation is detected, the function will automatically call Uninstall-LTService
        before proceeding. The -Force parameter allows installation even when services are already present
        or when only .NET 4.0+ is available without 3.5.
    .PARAMETER Server
        One or more ConnectWise Automate server URLs to download the installer from.
        Example: https://automate.domain.com
        The function tries each server in order until a successful download occurs.
    .PARAMETER ServerPassword
        The server password that agents use to authenticate with the Automate server.
        Used for legacy deployment method. InstallerToken is preferred.
    .PARAMETER InstallerToken
        An installer token for authenticated agent deployment. This is the preferred
        authentication method over ServerPassword.
        See: https://forums.mspgeek.org/topic/5882-contribution-generate-agent-installertoken
    .PARAMETER LocationID
        The LocationID of the location the agent will be assigned to.
    .PARAMETER TrayPort
        The local port LTSvc.exe listens on for communication with LTTray processes.
        Defaults to 42000. If the port is in use, the function auto-selects the next available port.
    .PARAMETER Rename
        Renames the agent entry in Add/Remove Programs after installation by calling Rename-CWAAAddRemove.
    .PARAMETER Hide
        Hides the agent entry from Add/Remove Programs after installation by calling Hide-CWAAAddRemove.
    .PARAMETER SkipDotNet
        Skips .NET Framework 3.5 and 2.0 prerequisite checks. Use when .NET 4.0+ is already installed.
    .PARAMETER Force
        Disables safety checks including existing service detection and .NET version requirements.
    .PARAMETER NoWait
        Skips the post-install health check that waits for agent registration.
        The function exits immediately after the installer completes.
    .PARAMETER Credential
        A PSCredential object containing the server password for deployment authentication.
        The password is extracted and used as the ServerPassword. This is the preferred
        secure alternative to passing -ServerPassword as plain text.
    .PARAMETER SkipCertificateCheck
        Bypasses SSL/TLS certificate validation for server connections.
        Use in lab or test environments with self-signed certificates.
    .PARAMETER ShowProgress
        Displays a Write-Progress bar showing installation progress. Off by default
        to avoid interference with unattended execution (RMM tools, GPO scripts).
    .EXAMPLE
        Install-CWAA -Server https://automate.domain.com -InstallerToken 'GeneratedToken' -LocationID 42
        Installs the agent using an InstallerToken for authentication.
    .EXAMPLE
        Install-CWAA -Server https://automate.domain.com -ServerPassword 'encryptedpass' -LocationID 1
        Installs the agent using a legacy server password.
    .EXAMPLE
        Install-CWAA -Server https://automate.domain.com -InstallerToken 'token' -LocationID 42 -NoWait
        Installs the agent without waiting for registration to complete.
    .EXAMPLE
        Get-CWAAInfoBackup | Install-CWAA -InstallerToken 'GeneratedToken'
        Reinstalls the agent using Server and LocationID from a previous backup via pipeline.
    .NOTES
        Author: Chris Taylor
        Alias: Install-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True, DefaultParameterSetName = 'deployment')]
    [Alias('Install-LTService')]
    Param(
        [Parameter(ParameterSetName = 'deployment')]
        [Parameter(ParameterSetName = 'installertoken')]
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $True)]
        [ValidateScript({
            if ($_ -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$') { $true }
            else { throw "Server address '$_' is not valid. Expected format: https://automate.domain.com" }
        })]
        [string[]]$Server,
        [Parameter(ParameterSetName = 'deployment')]
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [Alias('Password')]
        [string]$ServerPassword,
        [Parameter(ParameterSetName = 'deployment')]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential,
        [Parameter(ParameterSetName = 'installertoken')]
        [ValidatePattern('(?s:^[0-9a-z]+$)')]
        [string]$InstallerToken,
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [int]$LocationID,
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [int]$TrayPort,
        [Parameter()]
        [AllowNull()]
        [string]$Rename,
        [switch]$Hide,
        [switch]$SkipDotNet,
        [switch]$Force,
        [switch]$NoWait,
        [switch]$SkipCertificateCheck,
        [switch]$ShowProgress
    )
    Begin {
        Write-Debug "Starting $($myInvocation.InvocationName)"
        # Snapshot error count so we can detect new errors from this function only,
        # rather than checking the global $Error collection which accumulates all session errors.
        $errorCountAtStart = $Error.Count
        # If a PSCredential was provided, extract the password for the deployment workflow.
        # This is the preferred secure alternative to passing -ServerPassword as plain text.
        if ($Credential) {
            $ServerPassword = $Credential.GetNetworkCredential().Password
        }
        # Lazy initialization of SSL/TLS, WebClient, and proxy configuration.
        # Only runs once per session, skips immediately on subsequent calls.
        $Null = Initialize-CWAANetworking -SkipCertificateCheck:$SkipCertificateCheck
        $progressId = 1
        $progressActivity = 'Installing ConnectWise Automate Agent'
        if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Checking prerequisites' -PercentComplete 11 }
        if (-not $Force) {
            if (Get-Service $Script:CWAAServiceNames -ErrorAction SilentlyContinue) {
                if ($WhatIfPreference -ne $True) {
                    Write-Error "Services are already installed." -ErrorAction Stop
                }
                else {
                    Write-Error "What if: Stopping: Services are already installed." -ErrorAction Stop
                }
            }
        }
        if (-not ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent() | Select-Object -Expand groups -EA 0) -match 'S-1-5-32-544'))) {
            Throw 'Needs to be ran as Administrator'
        }
        $Null = Test-CWAADotNetPrerequisite -SkipDotNet:$SkipDotNet -Force:$Force
        $InstallBase = $Script:CWAAInstallerTempPath
        $logfile = 'LTAgentInstall'
        $curlog = "$InstallBase\$logfile.log"
        if (-not (Test-Path -PathType Container -Path "$InstallBase\Installer")) {
            New-Item "$InstallBase\Installer" -type directory -ErrorAction SilentlyContinue | Out-Null
        }
        if (Test-Path -PathType Leaf -Path $curlog) {
            if ($PSCmdlet.ShouldProcess($curlog, 'Rotate existing log file')) {
                Get-Item -LiteralPath $curlog -EA 0 | Where-Object { $_ } | ForEach-Object {
                    Rename-Item -Path ($_ | Select-Object -Expand FullName -EA 0) -NewName "$logfile-$(Get-Date ($_ | Select-Object -Expand LastWriteTime -EA 0) -Format 'yyyyMMddHHmmss').log" -Force -Confirm:$False -WhatIf:$False
                    Remove-Item -Path ($_ | Select-Object -Expand FullName -EA 0) -Force -EA 0 -Confirm:$False -WhatIf:$False
                }
            }
        }
    }
    Process {
        # Escape double quotes in ServerPassword for MSI argument safety.
        # Placed in Process (not Begin) because ServerPassword may arrive via pipeline binding.
        if ($ServerPassword -match '"') { $ServerPassword = $ServerPassword.Replace('"', '""') }
        if (-not ($LocationID -or $PSCmdlet.ParameterSetName -eq 'installertoken')) {
            $LocationID = '1'
        }
        if (-not ($TrayPort) -or -not ($TrayPort -ge 1 -and $TrayPort -le 65535)) {
            $TrayPort = $Script:CWAATrayPortDefault
        }
        # Resolve the first reachable server and its advertised version
        if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Resolving server address' -PercentComplete 22 }
        $serverResult = Resolve-CWAAServer -Server $Server
        if ($serverResult) {
            $serverUrl = $serverResult.ServerUrl
            $serverVersion = $serverResult.ServerVersion
        }
        if ($serverResult) {
            $InstallMSI = 'Agent_Install.msi'
            # Server version detection and installer URL selection:
            # The download URL and installer format vary by server version and auth method.
            # - v240.331+: InstallerToken deployments use a ZIP containing MSI+MST (new format)
            # - v110.374+: Anonymous MSI download changed; direct location targeting removed (LT11 Patch 13)
            # - v200.197+: Fixed a critical API vulnerability (CVE, June 2020) that allowed
            #   unauthenticated access to Deployment.aspx. Servers below this version get a warning.
            # - Pre-110.374: Legacy deployment URL with per-location MSI targeting
            if ($PSCmdlet.ParameterSetName -eq 'installertoken') {
                $installer = "$serverUrl/LabTech/Deployment.aspx?InstallerToken=$InstallerToken"
                if ([System.Version]$serverVersion -ge [System.Version]$Script:CWAAVersionZipInstaller) {
                    Write-Debug "New MSI Installer Format Needed"
                    $InstallMSI = 'Agent_Install.zip'
                }
            }
            Elseif ($ServerPassword) {
                $installer = "$serverUrl/LabTech/Service/LabTechRemoteAgent.msi"
            }
            Elseif ([System.Version]$serverVersion -ge [System.Version]$Script:CWAAVersionAnonymousChange) {
                $installer = "$serverUrl/LabTech/Deployment.aspx?Probe=1&installType=msi&MSILocations=1"
            }
            else {
                Write-Warning 'The server version is not supported. Please update your Automate server.'
                $installer = "$serverUrl/LabTech/Deployment.aspx?Probe=1&installType=msi&MSILocations=$LocationID"
            }
            # Vulnerability test June 10, 2020: ConnectWise Automate API Vulnerability
            # Servers below v200.197 may allow unauthenticated access to Deployment.aspx
            if ([System.Version]$serverVersion -lt [System.Version]$Script:CWAAVersionVulnerabilityFix) {
                Try {
                    $HTTP_Request = [System.Net.WebRequest]::Create("$serverUrl/LabTech/Deployment.aspx")
                    if ($HTTP_Request.GetResponse().StatusCode -eq 'OK') {
                        $Message = @('Your server is vulnerable!!')
                        $Message += 'https://docs.connectwise.com/ConnectWise_Automate/ConnectWise_Automate_Supportability_Statements/Supportability_Statement%3A_ConnectWise_Automate_Mitigation_Steps'
                        Write-Warning ($Message | Out-String)
                    }
                }
                Catch {
                    if (-not $ServerPassword) {
                        Write-Error 'Anonymous downloads are not allowed. ServerPassword or InstallerToken may be needed.'
                    }
                }
            }
            if ($PSCmdlet.ShouldProcess($installer, 'DownloadFile')) {
                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Downloading agent installer' -PercentComplete 33 }
                Write-Debug "Downloading $InstallMSI from $installer"
                $Script:LTServiceNetWebClient.DownloadFile($installer, "$InstallBase\Installer\$InstallMSI")
                if (-not (Test-CWAADownloadIntegrity -FilePath "$InstallBase\Installer\$InstallMSI" -FileName $InstallMSI)) {
                    $serverResult = $null
                }
            }
            if ($serverResult) {
                if ($WhatIfPreference -eq $True) {
                    $GoodServer = $serverUrl
                }
                Elseif (Test-Path "$InstallBase\Installer\$InstallMSI") {
                    $GoodServer = $serverUrl
                    Write-Verbose "$InstallMSI downloaded successfully from server $serverUrl."
                    if (($PSCmdlet.ParameterSetName -eq 'installertoken') -and [System.Version]$serverVersion -ge [System.Version]$Script:CWAAVersionZipInstaller) {
                        Expand-Archive "$InstallBase\Installer\$InstallMSI" -DestinationPath "$InstallBase\Installer" -Force
                        Remove-Item "$InstallBase\Installer\$InstallMSI" -ErrorAction SilentlyContinue -Force -Confirm:$False
                        $InstallMSI = 'Agent_Install.msi'
                    }
                }
                else {
                    Write-Warning "Error encountered downloading from $serverUrl. No installation file was received."
                }
            }
        }
    }
    End {
        try {
            if ($GoodServer) {
                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Preparing installation environment' -PercentComplete 44 }
                if ($WhatIfPreference -eq $True -and (Get-PSCallStack)[1].Command -in @('Redo-CWAA', 'Redo-LTService', 'Reinstall-CWAA', 'Reinstall-LTService')) {
                    Write-Debug "Skipping Preinstall Check: Called by Redo-CWAA with -WhatIf"
                }
                else {
                    if ((Test-Path $Script:CWAAInstallPath -EA 0) -or (Test-Path "${env:windir}\temp\_ltupdate" -EA 0) -or (Test-Path registry::HKLM\Software\LabTech\Service -EA 0) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service -EA 0)) {
                        Write-Warning "Previous installation detected. Calling Uninstall-CWAA"
                        Uninstall-CWAA -Server $GoodServer -Force
                        Start-Sleep $Script:CWAAUninstallWaitSeconds
                    }
                }
                if ($WhatIfPreference -ne $True) {
                    if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Resolving TrayPort' -PercentComplete 55 }
                    # TrayPort conflict resolution: LTSvc.exe listens on a local TCP port (default 42000)
                    # for communication with LTTray.exe (system tray UI). The valid range is 42000-42009.
                    # If the requested port is occupied by another process, we scan sequentially through
                    # the range, wrapping from 42009 back to 42000, trying up to 10 alternatives.
                    $GoodTrayPort = $Null
                    $TestTrayPort = $TrayPort
                    For ($i = 0; $i -le 10; $i++) {
                        if (-not $GoodTrayPort) {
                            if (-not (Test-CWAAPort -TrayPort $TestTrayPort -Quiet)) {
                                $TestTrayPort++
                                if ($TestTrayPort -gt $Script:CWAATrayPortMax) { $TestTrayPort = $Script:CWAATrayPortMin }
                            }
                            else {
                                $GoodTrayPort = $TestTrayPort
                            }
                        }
                    }
                    if ($GoodTrayPort -and $GoodTrayPort -ne $TrayPort -and $GoodTrayPort -ge 1 -and $GoodTrayPort -le 65535) {
                        Write-Verbose "TrayPort $TrayPort is in use. Changing TrayPort to $GoodTrayPort"
                        $TrayPort = $GoodTrayPort
                    }
                    Write-Output 'Starting Install.'
                }
                # Build parameter string
                $installerArguments = ($(
                    "/i `"$InstallBase\Installer\$InstallMSI`""
                    "SERVERADDRESS=$GoodServer"
                    if (($PSCmdlet.ParameterSetName -eq 'installertoken') -and [System.Version]$serverVersion -ge [System.Version]$Script:CWAAVersionZipInstaller) { "TRANSFORMS=`"Agent_Install.mst`"" }
                    if ($ServerPassword -and $ServerPassword -match '.') { "SERVERPASS=`"$ServerPassword`"" }
                    if ($LocationID -and $LocationID -match '^\d+$') { "LOCATION=$LocationID" }
                    if ($TrayPort -and $TrayPort -ne $Script:CWAATrayPortDefault) { "SERVICEPORT=$TrayPort" }
                    "/qn"
                    "/l `"$InstallBase\$logfile.log`""
                ) | Where-Object { $_ }) -join ' '
                Try {
                    if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Running MSI installer' -PercentComplete 66 }
                    $installSuccess = Invoke-CWAAMsiInstaller -InstallerArguments $installerArguments
                    if (-not $installSuccess) { Return }
                    if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Waiting for services to start' -PercentComplete 77 }
                    if (($Script:LTProxy.Enabled) -eq $True) {
                        Write-Verbose 'Proxy Configuration Needed. Applying Proxy Settings to Agent Installation.'
                        if ($PSCmdlet.ShouldProcess($Script:LTProxy.ProxyServerURL, 'Configure Agent Proxy')) {
                            $serviceRunning = Wait-CWAACondition -Condition {
                                $count = ('LTService') | Get-Service -EA 0 | Where-Object { $_.Status -eq 'Running' } | Measure-Object | Select-Object -Expand Count
                                $count -eq 1
                            } -TimeoutSeconds $Script:CWAAServiceStartTimeoutSec -IntervalSeconds 2 -Activity 'LTService initial startup'
                            if ($serviceRunning) {
                                Write-Debug "LTService Initial Startup Successful."
                            }
                            else {
                                Write-Debug "LTService Initial Startup failed to complete within expected period."
                            }
                            Set-CWAAProxy -ProxyServerURL $Script:LTProxy.ProxyServerURL -ProxyUsername $Script:LTProxy.ProxyUsername -ProxyPassword $Script:LTProxy.ProxyPassword -Confirm:$False -WhatIf:$False
                        }
                    }
                    else {
                        Write-Verbose 'No Proxy Configuration has been specified - Continuing.'
                    }
                    if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Waiting for agent registration' -PercentComplete 88 }
                    if (-not $NoWait -and $PSCmdlet.ShouldProcess('LTService', 'Monitor For Successful Agent Registration')) {
                        $Null = Wait-CWAACondition -Condition {
                            $agentId = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand 'ID' -EA 0
                            $agentId -ge 1
                        } -TimeoutSeconds $Script:CWAARegistrationTimeoutSec -IntervalSeconds 5 -Activity 'Agent registration'
                        $Null = Get-CWAAProxy -ErrorAction Continue
                    }
                    if ($Hide) { Hide-CWAAAddRemove }
                }
                Catch {
                    Write-Error "There was an error during the install process. $_"
                    Write-CWAAEventLog -EventId 1002 -EntryType Error -Message "Agent installation failed. Error: $($_.Exception.Message)"
                    Return
                }
                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Completing installation' -PercentComplete 100 }
                if ($WhatIfPreference -ne $True) {
                    # Cleanup install files
                    Remove-Item "$InstallBase\Installer\$InstallMSI" -ErrorAction SilentlyContinue -Force -Confirm:$False
                    Remove-Item "$InstallBase\Installer\Agent_Install.mst" -ErrorAction SilentlyContinue -Force -Confirm:$False
                    @($curlog, "$Script:CWAAInstallPath\Install.log") | ForEach-Object {
                        if (Test-Path -PathType Leaf -LiteralPath $_) {
                            $logcontents = Get-Content -Path $_
                            $logcontents = $logcontents -replace '(?<=PreInstallPass:[^\r\n]+? (?:result|value)): [^\r\n]+', ': <REDACTED>'
                            if ($logcontents) { Set-Content -Path $_ -Value $logcontents -Force -Confirm:$False }
                        }
                    }
                    $tempServiceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
                    if ($tempServiceInfo) {
                        if (($tempServiceInfo | Select-Object -Expand 'ID' -EA 0) -ge 1) {
                            Write-Output "Automate agent has been installed successfully. Agent ID: $($tempServiceInfo | Select-Object -Expand 'ID' -EA 0) LocationID: $($tempServiceInfo | Select-Object -Expand 'LocationID' -EA 0)"
                            Write-CWAAEventLog -EventId 1000 -EntryType Information -Message "Agent installed successfully. Agent ID: $($tempServiceInfo | Select-Object -Expand 'ID' -EA 0), LocationID: $($tempServiceInfo | Select-Object -Expand 'LocationID' -EA 0)"
                        }
                        Elseif (-not $NoWait) {
                            Write-Error "Automate agent installation completed but agent failed to register within expected period." -ErrorAction Continue
                            Write-CWAAEventLog -EventId 1001 -EntryType Warning -Message "Agent installed but failed to register within expected period."
                        }
                        else {
                            Write-Warning "Automate agent installation completed but agent did not yet register." -WarningAction Continue
                        }
                    }
                    else {
                        if ($Error.Count -gt $errorCountAtStart -or (-not $NoWait)) {
                            Write-Error "There was an error installing Automate agent. Check the log, $InstallBase\$logfile.log"
                            Write-CWAAEventLog -EventId 1002 -EntryType Error -Message "Agent installation failed. Check log: $InstallBase\$logfile.log"
                            Return
                        }
                        else {
                            Write-Warning "Automate agent installation may not have succeeded." -WarningAction Continue
                        }
                    }
                }
                if ($Rename) { Rename-CWAAAddRemove -Name $Rename }
            }
            Elseif ($WhatIfPreference -ne $True) {
                Write-Error "No valid server was reached to use for the install."
            }
        }
        finally {
            if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Completed }
            Write-Debug "Exiting $($myInvocation.InvocationName)"
        }
    }
}
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
function Uninstall-CWAA {
    <#
    .SYNOPSIS
        Completely uninstalls the ConnectWise Automate Agent from the local computer.
    .DESCRIPTION
        Performs a comprehensive removal of the ConnectWise Automate Agent from a Windows computer.
        This function is more thorough than a standard MSI uninstall, as it also removes residual
        files, registry keys, and services that may not be cleaned up by the normal uninstall process.
        The uninstall process performs the following operations:
        1. Downloads official uninstaller files (Agent_Uninstall.msi and Agent_Uninstall.exe) from the server
        2. Optionally creates a backup of the current agent installation (if -Backup is specified)
        3. Stops all running agent services (LTService, LTSvcMon, LabVNC)
        4. Terminates any running agent processes
        5. Unregisters the wodVPN.dll component
        6. Runs the MSI uninstaller (Agent_Uninstall.msi)
        7. Runs the agent uninstaller executable (Agent_Uninstall.exe)
        8. Removes agent Windows services
        9. Removes all agent files from the installation directory
        10. Removes all agent-related registry keys (over 30 different registry locations)
        11. Verifies the uninstall was successful
        Probe Agent Protection: By default, this function will refuse to uninstall probe agents to
        prevent accidental removal of critical infrastructure. Use -Force to override this protection.
    .PARAMETER Server
        One or more ConnectWise Automate server URLs to download uninstaller files from.
        If not specified, reads the server URL from the agent's current registry configuration.
        If that fails, prompts interactively for a server URL.
        Example: https://automate.domain.com
    .PARAMETER Backup
        Creates a complete backup of the agent installation before uninstalling by calling New-CWAABackup.
    .PARAMETER Force
        Forces uninstallation even when a probe agent is detected. Use with extreme caution,
        as probe agents are typically critical infrastructure components.
    .PARAMETER SkipCertificateCheck
        Bypasses SSL/TLS certificate validation for server connections.
        Use in lab or test environments with self-signed certificates.
    .PARAMETER ShowProgress
        Displays a Write-Progress bar showing uninstall progress. Off by default
        to avoid interference with unattended execution (RMM tools, GPO scripts).
    .EXAMPLE
        Uninstall-CWAA
        Uninstalls the agent using the server URL from the agent's registry settings.
    .EXAMPLE
        Uninstall-CWAA -Backup
        Creates a backup of the agent installation before uninstalling.
    .EXAMPLE
        Uninstall-CWAA -Server "https://automate.company.com"
        Uninstalls using the specified server URL to download uninstaller files.
    .EXAMPLE
        Uninstall-CWAA -Server "https://primary.company.com","https://backup.company.com"
        Provides multiple server URLs with fallback. Tries each until uninstaller files download successfully.
    .EXAMPLE
        Uninstall-CWAA -Force
        Forces uninstallation even if a probe agent is detected.
    .EXAMPLE
        Uninstall-CWAA -WhatIf
        Simulates the uninstall process without making any actual changes.
    .EXAMPLE
        Get-CWAAInfo | Uninstall-CWAA
        Pipes the installed agent's Server property into Uninstall-CWAA via pipeline.
    .NOTES
        Author: Chris Taylor
        Alias: Uninstall-LTService
        Requires: Administrator privileges
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Uninstall-LTService')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [AllowNull()]
        [string[]]$Server,
        [switch]$Backup,
        [switch]$Force,
        [switch]$SkipCertificateCheck,
        [switch]$ShowProgress
    )
    Begin {
        Write-Debug "Starting $($myInvocation.InvocationName)"
        # Lazy initialization of SSL/TLS, WebClient, and proxy configuration.
        # Only runs once per session, skips immediately on subsequent calls.
        $Null = Initialize-CWAANetworking -SkipCertificateCheck:$SkipCertificateCheck
        if (-not ([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent() | Select-Object -Expand groups -EA 0) -match 'S-1-5-32-544'))) {
            Throw "Needs to be ran as Administrator"
        }
        $serviceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
        Assert-CWAANotProbeAgent -ServiceInfo $serviceInfo -ActionName 'UnInstall' -Force:$Force
        if ($Backup) {
            if ($PSCmdlet.ShouldProcess('LTService', 'Backup Current Service Settings')) {
                New-CWAABackup
            }
        }
        $BasePath = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand BasePath -EA 0
        if (-not $BasePath) { $BasePath = $Script:CWAAInstallPath }
        New-PSDrive HKU Registry HKEY_USERS -ErrorAction SilentlyContinue -WhatIf:$False -Confirm:$False -Debug:$False | Out-Null
        $regs = @( 'Registry::HKEY_LOCAL_MACHINE\Software\LabTechMSP',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\LabTech\Service',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\LabTech\LabVNC',
            'Registry::HKEY_LOCAL_MACHINE\Software\Wow6432Node\LabTech\Service',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\Managed\\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\D1003A85576B76D45A1AF09A0FC87FAC\InstallProperties',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{3426921d-9ad5-4237-9145-f15dee7e3004}',
            'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Group Policy\Appmgmt\{40bf8c82-ed0d-4f66-b73e-58a3d7ab6582}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Dependencies\{3426921d-9ad5-4237-9145-f15dee7e3004}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Dependencies\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{09DF1DCA-C076-498A-8370-AD6F878B6C6A}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{15DD3BF6-5A11-4407-8399-A19AC10C65D0}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{3C198C98-0E27-40E4-972C-FDC656EC30D7}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{459C65ED-AA9C-4CF1-9A24-7685505F919A}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{7BE3886B-0C12-4D87-AC0B-09A5CE4E6BD6}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{7E092B5C-795B-46BC-886A-DFFBBBC9A117}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{9D101D9C-18CC-4E78-8D78-389E48478FCA}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{B0B8CDD6-8AAA-4426-82E9-9455140124A1}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{B1B00A43-7A54-4A0F-B35D-B4334811FAA4}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{BBC521C8-2792-43FE-9C91-CCA7E8ACBCC9}',
            'Registry::HKEY_CLASSES_ROOT\CLSID\{C59A1D54-8CD7-4795-AEDD-F6F6E2DE1FE7}',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'Registry::HKEY_CLASSES_ROOT\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC',
            'Registry::HKEY_CURRENT_USER\SOFTWARE\LabTech\Service',
            'Registry::HKEY_CURRENT_USER\SOFTWARE\LabTech\LabVNC',
            'Registry::HKEY_CURRENT_USER\Software\Microsoft\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'HKU:\*\Software\Microsoft\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F'
        )
        if ($WhatIfPreference -ne $True) {
            Remove-Item 'Uninstall.exe', 'Uninstall.exe.config' -ErrorAction SilentlyContinue -Force -Confirm:$False
            New-Item "$Script:CWAAInstallerTempPath\Installer" -type directory -ErrorAction SilentlyContinue | Out-Null
        }
        $uninstallArguments = "/x ""$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi"" /qn"
    }
    Process {
        if (-not $Server) {
            $Server = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand 'Server' -EA 0
        }
        if (-not $Server) {
            $Server = Read-Host -Prompt 'Provide the URL to your Automate server (https://automate.domain.com):'
        }
        # Resolve the first reachable server and its advertised version
        $progressId = 2
        $progressActivity = 'Uninstalling ConnectWise Automate Agent'
        if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Resolving server address' -PercentComplete 12 }
        $serverResult = Resolve-CWAAServer -Server $Server
        if (-not $serverResult) { return }
        $serverUrl = $serverResult.ServerUrl
        if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Downloading uninstaller files' -PercentComplete 25 }
        Try {
            # Download the uninstall MSI (same URL for all server versions)
            $installer = "$serverUrl/LabTech/Service/LabTechRemoteAgent.msi"
            $installerTest = [System.Net.WebRequest]::Create($installer)
            if (($Script:LTProxy.Enabled) -eq $True) {
                Write-Debug "Proxy Configuration Needed. Applying Proxy Settings to request."
                $installerTest.Proxy = $Script:LTWebProxy
            }
            $installerTest.KeepAlive = $False
            $installerTest.ProtocolVersion = '1.0'
            $installerResult = $installerTest.GetResponse()
            $installerTest.Abort()
            if ($installerResult.StatusCode -ne 200) {
                Write-Warning "Unable to download Agent_Uninstall.msi from server $serverUrl."
                return
            }
            if ($PSCmdlet.ShouldProcess("$installer", 'DownloadFile')) {
                Write-Debug "Downloading Agent_Uninstall.msi from $installer"
                $Script:LTServiceNetWebClient.DownloadFile($installer, "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi")
                if (-not (Test-CWAADownloadIntegrity -FilePath "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi" -FileName 'Agent_Uninstall.msi')) {
                    return
                }
                $AlternateServer = $serverUrl
            }
            # Download the uninstall EXE (same URI for all versions)
            $uninstaller = "$serverUrl/LabTech/Service/LabUninstall.exe"
            $uninstallerTest = [System.Net.WebRequest]::Create($uninstaller)
            if (($Script:LTProxy.Enabled) -eq $True) {
                Write-Debug "Proxy Configuration Needed. Applying Proxy Settings to request."
                $uninstallerTest.Proxy = $Script:LTWebProxy
            }
            $uninstallerTest.KeepAlive = $False
            $uninstallerTest.ProtocolVersion = '1.0'
            $uninstallerResult = $uninstallerTest.GetResponse()
            $uninstallerTest.Abort()
            if ($uninstallerResult.StatusCode -ne 200) {
                Write-Warning "Unable to download Agent_Uninstall from server."
                return
            }
            if ($PSCmdlet.ShouldProcess("$uninstaller", 'DownloadFile')) {
                Write-Debug "Downloading Agent_Uninstall.exe from $uninstaller"
                $Script:LTServiceNetWebClient.DownloadFile($uninstaller, "${env:windir}\temp\Agent_Uninstall.exe")
                # Uninstall EXE is smaller than MSI — use 80 KB threshold
                if (-not (Test-CWAADownloadIntegrity -FilePath "${env:windir}\temp\Agent_Uninstall.exe" -FileName 'Agent_Uninstall.exe' -MinimumSizeKB 80)) {
                    return
                }
            }
            if ($WhatIfPreference -eq $True) {
                $GoodServer = $serverUrl
            }
            Elseif ((Test-Path "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi") -and (Test-Path "${env:windir}\temp\Agent_Uninstall.exe")) {
                $GoodServer = $serverUrl
                Write-Verbose "Successfully downloaded files from $serverUrl."
            }
            else {
                Write-Warning "Error encountered downloading from $serverUrl. Uninstall file(s) could not be received."
            }
        }
        Catch {
            Write-Warning "Error encountered downloading from $serverUrl."
        }
    }
    End {
        try {
        if ($GoodServer -match 'https?://.+' -or $AlternateServer -match 'https?://.+') {
            Try {
                Write-Output 'Starting Uninstall.'
                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Stopping services and processes' -PercentComplete 37 }
                Try { Stop-CWAA -ErrorAction SilentlyContinue } Catch { Write-Debug "Stop-CWAA encountered an error: $_" }
                # Kill all running processes from %ltsvcdir%
                if (Test-Path $BasePath) {
                    $Executables = (Get-ChildItem $BasePath -Filter *.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -Expand FullName)
                    if ($Executables) {
                        Write-Verbose "Terminating Automate agent processes from $BasePath if found running: $(($Executables) -replace [Regex]::Escape($BasePath),'' -replace '^\\','')"
                        Get-Process | Where-Object { $Executables -contains $_.Path } | ForEach-Object {
                            Write-Debug "Terminating Process $($_.ProcessName)"
                            $_ | Stop-Process -Force -ErrorAction SilentlyContinue
                        }
                        Get-ChildItem $BasePath -Filter labvnc.exe -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction 0
                    }
                    if ($PSCmdlet.ShouldProcess("$BasePath\wodVPN.dll", 'Unregister DLL')) {
                        Write-Debug "Executing Command ""regsvr32.exe /u $BasePath\wodVPN.dll /s"""
                        Try { & "$env:windir\system32\regsvr32.exe" /u "$BasePath\wodVPN.dll" /s 2>'' }
                        Catch { Write-Output 'Error calling regsvr32.exe.' }
                    }
                }
                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Running MSI uninstaller' -PercentComplete 50 }
                if ($PSCmdlet.ShouldProcess("msiexec.exe $uninstallArguments", 'Execute MSI Uninstall')) {
                    if (Test-Path "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi") {
                        Write-Verbose 'Launching MSI Uninstall.'
                        Write-Debug "Executing Command ""msiexec.exe $uninstallArguments"""
                        Start-Process -Wait -FilePath "$env:windir\system32\msiexec.exe" -ArgumentList $uninstallArguments -WorkingDirectory $env:TEMP
                        Start-Sleep -Seconds 5
                    }
                    else {
                        Write-Verbose "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi was not found."
                    }
                }
                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Running agent uninstaller' -PercentComplete 62 }
                if ($PSCmdlet.ShouldProcess("${env:windir}\temp\Agent_Uninstall.exe", 'Execute Agent Uninstall')) {
                    if (Test-Path "${env:windir}\temp\Agent_Uninstall.exe") {
                        # Remove previously extracted SFX files to prevent UnRAR overwrite prompts
                        Remove-Item "$env:TEMP\Uninstall.exe", "$env:TEMP\Uninstall.exe.config" -ErrorAction SilentlyContinue -Force -Confirm:$False
                        Write-Verbose 'Launching Agent Uninstaller'
                        Write-Debug "Executing Command ""${env:windir}\temp\Agent_Uninstall.exe"""
                        Start-Process -Wait -FilePath "${env:windir}\temp\Agent_Uninstall.exe" -WorkingDirectory $env:TEMP
                        Start-Sleep -Seconds 5
                    }
                    else {
                        Write-Verbose "${env:windir}\temp\Agent_Uninstall.exe was not found."
                    }
                }
                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Removing services' -PercentComplete 75 }
                Write-Verbose 'Removing Services if found.'
                $Script:CWAAAllServiceNames | ForEach-Object {
                    if (Get-Service $_ -EA 0) {
                        if ($PSCmdlet.ShouldProcess($_, 'Remove Service')) {
                            Write-Debug "Removing Service: $_"
                            Try {
                                & "$env:windir\system32\sc.exe" delete "$_" 2>''
                                if ($LASTEXITCODE -ne 0) {
                                    Write-Warning "sc.exe delete returned exit code $LASTEXITCODE for service '$_'."
                                }
                            }
                            Catch { Write-Output 'Error calling sc.exe.' }
                        }
                    }
                }
                if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Cleaning up files and registry' -PercentComplete 87 }
                Write-Verbose 'Cleaning Files remaining if found.'
                # Depth-first removal to get as much removed as possible if complete removal fails
                @($BasePath, "${env:windir}\temp\_ltupdate") | ForEach-Object {
                    if (Test-Path $_ -EA 0) {
                        Remove-CWAAFolderRecursive -Path $_
                    }
                }
                Write-Verbose 'Removing agent installation msi file.'
                if ($PSCmdlet.ShouldProcess('Agent_Uninstall.msi', 'Remove File')) {
                    $MsiPath = "$Script:CWAAInstallerTempPath\Installer\Agent_Uninstall.msi"
                    $tries = 0
                    Try {
                        Do {
                            $MsiExists = Test-Path $MsiPath
                            Start-Sleep -Seconds 10
                            Remove-Item $MsiPath -ErrorAction SilentlyContinue
                            $tries++
                        }
                        While ($MsiExists -and $tries -lt 4)
                    }
                    Catch {
                        Write-Verbose "Unable to remove Agent_Uninstall.msi: $($_.Exception.Message)"
                    }
                }
                Write-Verbose 'Cleaning Registry Keys if found.'
                # Depth First Value Removal, then Key Removal
                Foreach ($reg in $regs) {
                    if (Test-Path $reg -EA 0) {
                        Write-Debug "Found Registry Key: $reg"
                        if ($PSCmdlet.ShouldProcess($reg, 'Remove Registry Key')) {
                            Try {
                                Get-ChildItem -Path $reg -Recurse -Force -ErrorAction SilentlyContinue | Sort-Object { $_.name.length } -Descending | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                                Remove-Item -Recurse -Force -Path $reg -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                            }
                            Catch { Write-Debug "Error removing registry key '$reg': $($_.Exception.Message)" }
                        }
                    }
                }
            }
            Catch {
                Write-CWAAEventLog -EventId 1012 -EntryType Error -Message "Agent uninstall failed. Error: $($_.Exception.Message)"
                Write-Error "There was an error during the uninstall process. $($_.Exception.Message)" -ErrorAction Stop
            }
            if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Verifying uninstall' -PercentComplete 100 }
            if ($WhatIfPreference -ne $True) {
                # Post Uninstall Check
                If ((Test-Path $Script:CWAAInstallPath) -or (Test-Path "${env:windir}\temp\_ltupdate") -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)) {
                    Start-Sleep -Seconds 10
                }
                If ((Test-Path $Script:CWAAInstallPath) -or (Test-Path "${env:windir}\temp\_ltupdate") -or (Test-Path registry::HKLM\Software\LabTech\Service) -or (Test-Path registry::HKLM\Software\WOW6432Node\Labtech\Service)) {
                    Write-Error "Remnants of previous install still detected after uninstall attempt. Please reboot and try again."
                    Write-CWAAEventLog -EventId 1011 -EntryType Warning -Message 'Remnants of previous install detected after uninstall. Reboot recommended.'
                }
                else {
                    Write-Output 'Automate agent has been successfully uninstalled.'
                    Write-CWAAEventLog -EventId 1010 -EntryType Information -Message 'Agent uninstalled successfully.'
                }
            }
        }
        Elseif ($WhatIfPreference -ne $True) {
            Write-Error "No valid server was reached to use for the uninstall." -ErrorAction Stop
        }
        }
        finally {
            if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Completed }
            Write-Debug "Exiting $($myInvocation.InvocationName)"
        }
    }
}
function Update-CWAA {
    <#
    .SYNOPSIS
        Manually updates the ConnectWise Automate Agent to a specified version.
    .DESCRIPTION
        Downloads and applies an agent update from the ConnectWise Automate server. The function
        reads the current server configuration from the agent's registry settings, downloads the
        appropriate update package, extracts it, and runs the updater.
        If no version is specified, the function uses the version advertised by the server.
        The function validates that the requested version is higher than the currently installed
        version and not higher than the server version before proceeding.
        The update process:
        1. Reads current agent settings and server information
        2. Downloads the LabtechUpdate.exe for the target version
        3. Stops agent services
        4. Extracts and runs the update
        5. Restarts agent services
    .PARAMETER Version
        The target agent version to update to.
        Example: 120.240
        If omitted, the version advertised by the server will be used.
    .PARAMETER SkipCertificateCheck
        Bypasses SSL/TLS certificate validation for server connections.
        Use in lab or test environments with self-signed certificates.
    .PARAMETER ShowProgress
        Displays a Write-Progress bar showing update progress. Off by default
        to avoid interference with unattended execution (RMM tools, GPO scripts).
    .EXAMPLE
        Update-CWAA -Version 120.240
        Updates the agent to the specific version requested.
    .EXAMPLE
        Update-CWAA
        Updates the agent to the current version advertised by the server.
    .NOTES
        Author: Darren White
        Alias: Update-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Update-LTService')]
    Param(
        [parameter(Position = 0)]
        [AllowNull()]
        [string]$Version,
        [switch]$SkipCertificateCheck,
        [switch]$ShowProgress
    )
    Begin {
        Write-Debug "Starting $($myInvocation.InvocationName)"
        # Lazy initialization of SSL/TLS, WebClient, and proxy configuration.
        # Only runs once per session, skips immediately on subsequent calls.
        $Null = Initialize-CWAANetworking -SkipCertificateCheck:$SkipCertificateCheck
        $Settings = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False
        $updaterPath = [System.Environment]::ExpandEnvironmentVariables('%windir%\temp\_LTUpdate')
        $extractArguments = @("/o""$updaterPath""", '/y')
        $updaterArguments = @("""$updaterPath\Update.ini""")
    }
    Process {
        if (-not $Server) {
            if ($Settings) {
                $Server = $Settings | Select-Object -Expand 'Server' -EA 0
            }
        }
        # Resolve the first reachable server and its advertised version
        $progressId = 3
        $progressActivity = 'Updating ConnectWise Automate Agent'
        if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Resolving server address' -PercentComplete 14 }
        if (-not $Server) { return }
        $serverResult = Resolve-CWAAServer -Server $Server
        if ($serverResult) {
            $GoodServer = $serverResult.ServerUrl
            $serverVersion = $serverResult.ServerVersion
        }
        if ($GoodServer) {
            # Determine the target version and build the update download URL
            if ($Version -match '[1-9][0-9]{2}\.[0-9]{1,3}') {
                $updater = "$GoodServer/Labtech/Updates/LabtechUpdate_$Version.zip"
            }
            Elseif ([System.Version]$serverVersion -ge [System.Version]$Script:CWAAVersionUpdateMinimum) {
                $Version = $serverVersion
                Write-Verbose "Using detected version ($Version) from server: $GoodServer."
                $updater = "$GoodServer/Labtech/Updates/LabtechUpdate_$Version.zip"
            }
            # Kill all running processes from $updaterPath before cleanup
            if (Test-Path $updaterPath) {
                $Executables = (Get-ChildItem $updaterPath -Filter *.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -Expand FullName)
                if ($Executables) {
                    Write-Verbose "Terminating Automate agent processes from $updaterPath if found running: $(($Executables) -replace [Regex]::Escape($updaterPath),'' -replace '^\\','')"
                    Get-Process | Where-Object { $Executables -contains $_.Path } | ForEach-Object {
                        Write-Debug "Terminating Process $($_.ProcessName)"
                        $_ | Stop-Process -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            # Remove stale updater directory using depth-first removal
            if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Cleaning previous update files' -PercentComplete 28 }
            Remove-CWAAFolderRecursive -Path $updaterPath
            Try {
                if (-not (Test-Path -PathType Container -Path $updaterPath)) {
                    New-Item $updaterPath -type directory -ErrorAction SilentlyContinue | Out-Null
                }
                $updaterTest = [System.Net.WebRequest]::Create($updater)
                if (($Script:LTProxy.Enabled) -eq $True) {
                    Write-Debug "Proxy Configuration Needed. Applying Proxy Settings to request."
                    $updaterTest.Proxy = $Script:LTWebProxy
                }
                $updaterTest.KeepAlive = $False
                $updaterTest.ProtocolVersion = '1.0'
                $updaterResult = $updaterTest.GetResponse()
                $updaterTest.Abort()
                if ($updaterResult.StatusCode -ne 200) {
                    Write-Warning "Unable to download LabtechUpdate.exe version $Version from server $GoodServer."
                    $GoodServer = $null
                }
                else {
                    if ($PSCmdlet.ShouldProcess($updater, 'DownloadFile')) {
                        if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Downloading update package' -PercentComplete 42 }
                        Write-Debug "Downloading LabtechUpdate.exe from $updater"
                        $Script:LTServiceNetWebClient.DownloadFile($updater, "$updaterPath\LabtechUpdate.exe")
                        if (-not (Test-CWAADownloadIntegrity -FilePath "$updaterPath\LabtechUpdate.exe" -FileName 'LabtechUpdate.exe')) {
                            $GoodServer = $null
                        }
                    }
                    if ($GoodServer) {
                        if ($WhatIfPreference -ne $True -and -not (Test-Path "$updaterPath\LabtechUpdate.exe")) {
                            Write-Warning "Error encountered downloading from $GoodServer. No update file was received."
                            $GoodServer = $null
                        }
                        else {
                            Write-Verbose "LabtechUpdate.exe downloaded successfully from server $GoodServer."
                        }
                    }
                }
            }
            Catch {
                Write-Warning "Error encountered downloading $updater."
                $GoodServer = $null
            }
        }
    }
    End {
        try {
        $detectedVersion = $Settings | Select-Object -Expand 'Version' -EA 0
        if ($Null -eq $detectedVersion) {
            Write-Error "No existing installation was found." -ErrorAction Stop
            Return
        }
        if ([System.Version]$detectedVersion -ge [System.Version]$Version) {
            Write-Warning "Installed version detected ($detectedVersion) is higher than or equal to the requested version ($Version)."
            Return
        }
        if (-not $GoodServer) {
            Write-Warning "No valid server was detected."
            Return
        }
        if ([System.Version]$serverVersion -gt [System.Version]$Version) {
            Write-Warning "Server version detected ($serverVersion) is higher than the requested version ($Version)."
            Return
        }
        if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Stopping services' -PercentComplete 57 }
        Try {
            Stop-CWAA
        }
        Catch {
            Write-Error "There was an error stopping the services. $_"
            Write-CWAAEventLog -EventId 1032 -EntryType Error -Message "Agent update failed - unable to stop services. Error: $($_.Exception.Message)"
            Return
        }
        Write-Output "Updating Agent with the following information: Server $GoodServer, Version $Version"
        Try {
            if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Extracting update' -PercentComplete 71 }
            if ($PSCmdlet.ShouldProcess("LabtechUpdate.exe $extractArguments", 'Extracting update files')) {
                if (Test-Path "$updaterPath\LabtechUpdate.exe") {
                    Write-Verbose 'Launching LabtechUpdate Self-Extractor.'
                    Write-Debug "Executing Command ""LabtechUpdate.exe $extractArguments"""
                    Try {
                        Push-Location $updaterPath
                        & "$updaterPath\LabtechUpdate.exe" $extractArguments 2>''
                        Pop-Location
                    }
                    Catch { Write-Output 'Error calling LabtechUpdate.exe.' }
                    Start-Sleep -Seconds 5
                }
                else {
                    Write-Verbose "$updaterPath\LabtechUpdate.exe was not found."
                }
            }
            if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Applying update' -PercentComplete 85 }
            if ($PSCmdlet.ShouldProcess("Update.exe $updaterArguments", 'Launching Updater')) {
                if (Test-Path "$updaterPath\Update.exe") {
                    Write-Verbose 'Launching Labtech Updater'
                    Write-Debug "Executing Command ""Update.exe $updaterArguments"""
                    Try { & "$updaterPath\Update.exe" $updaterArguments 2>'' }
                    Catch { Write-Output 'Error calling Update.exe.' }
                    Start-Sleep -Seconds 5
                }
                else {
                    Write-Verbose "$updaterPath\Update.exe was not found."
                }
            }
        }
        Catch {
            Write-Error "There was an error during the update process. $_" -ErrorAction Continue
            Write-CWAAEventLog -EventId 1032 -EntryType Error -Message "Agent update process failed. Error: $($_.Exception.Message)"
        }
        if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Status 'Restarting services' -PercentComplete 100 }
        Try {
            Start-CWAA
        }
        Catch {
            Write-Error "There was an error starting the services. $_"
            Write-CWAAEventLog -EventId 1032 -EntryType Error -Message "Agent update completed but services failed to start. Error: $($_.Exception.Message)"
            Return
        }
        Write-CWAAEventLog -EventId 1030 -EntryType Information -Message "Agent updated successfully to version $Version."
        }
        finally {
            if ($ShowProgress) { Write-Progress -Id $progressId -Activity $progressActivity -Completed }
            Write-Debug "Exiting $($myInvocation.InvocationName)"
        }
    }
}
function Get-CWAAError {
    <#
    .SYNOPSIS
        Reads the ConnectWise Automate Agent error log into structured objects.
    .DESCRIPTION
        Parses the LTErrors.txt file from the agent install directory into objects with
        ServiceVersion, Timestamp, and Message properties. This enables filtering, sorting,
        and pipeline operations on agent error log entries.
        The log file location is determined from Get-CWAAInfo; if unavailable, falls back
        to the default install path at C:\Windows\LTSVC.
    .EXAMPLE
        Get-CWAAError | Where-Object {$_.Timestamp -gt (Get-Date).AddHours(-24)}
        Returns all agent errors from the last 24 hours.
    .EXAMPLE
        Get-CWAAError | Out-GridView
        Opens the error log in a sortable, searchable grid view window.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTErrors
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTErrors')]
    Param()
    Begin {
        $BasePath = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand BasePath -EA 0
        if (-not $BasePath) { $BasePath = $Script:CWAAInstallPath }
    }
    Process {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $logFilePath = "$BasePath\LTErrors.txt"
        if (-not (Test-Path -Path $logFilePath)) {
            Write-Error "Unable to find agent error log at '$logFilePath'."
            return
        }
        Try {
            $errors = Get-Content $logFilePath
            $errors = $errors -join ' ' -split '::: '
            foreach ($line in $errors) {
                $items = $line -split "`t" -replace ' - ', ''
                if ($items[1]) {
                    [PSCustomObject]@{
                        ServiceVersion = $items[0]
                        Timestamp      = $(Try { [datetime]::Parse($items[1]) } Catch { $null })
                        Message        = $items[2]
                    }
                }
            }
        }
        Catch {
            Write-Error "Failed to read agent error log at '$logFilePath'. Error: $($_.Exception.Message)"
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Get-CWAALogLevel {
    <#
    .SYNOPSIS
        Retrieves the current logging level for the ConnectWise Automate Agent.
    .DESCRIPTION
        Checks the agent's registry settings to determine the current logging verbosity level.
        The ConnectWise Automate Agent supports two logging levels: Normal (value 1) for standard
        operations, and Verbose (value 1000) for detailed diagnostic logging.
        The logging level is stored in the registry at HKLM:\SOFTWARE\LabTech\Service\Settings
        under the "Debuging" value.
    .EXAMPLE
        Get-CWAALogLevel
        Returns the current logging level (Normal or Verbose).
    .EXAMPLE
        Get-CWAALogLevel
        Set-CWAALogLevel -Level Verbose
        Get-CWAALogLevel
        Typical troubleshooting workflow: check level, enable verbose, verify the change.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTLogging
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTLogging')]
    Param ()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        Try {
            # "Debuging" is the vendor's original spelling in the registry -- not a typo in this code.
            $logLevel = Get-CWAASettings | Select-Object -Expand Debuging -EA 0
            if ($logLevel -eq 1000) {
                Write-Output 'Current logging level: Verbose'
            }
            elseif ($Null -eq $logLevel -or $logLevel -eq 1) {
                # Fresh installs may not have the Debuging value yet; treat as Normal
                Write-Output 'Current logging level: Normal'
            }
            else {
                Write-Error "Unknown logging level value '$logLevel' in registry."
            }
        }
        Catch {
            Write-Error "Failed to read logging level from registry. Error: $($_.Exception.Message)"
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Get-CWAAProbeError {
    <#
    .SYNOPSIS
        Reads the ConnectWise Automate Agent probe error log into structured objects.
    .DESCRIPTION
        Parses the LTProbeErrors.txt file from the agent install directory into objects with
        ServiceVersion, Timestamp, and Message properties. This enables filtering, sorting,
        and pipeline operations on agent probe error log entries.
        The log file location is determined from Get-CWAAInfo; if unavailable, falls back
        to the default install path at C:\Windows\LTSVC.
    .EXAMPLE
        Get-CWAAProbeError | Where-Object {$_.Timestamp -gt (Get-Date).AddHours(-24)}
        Returns all probe errors from the last 24 hours.
    .EXAMPLE
        Get-CWAAProbeError | Out-GridView
        Opens the probe error log in a sortable, searchable grid view window.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTProbeErrors
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTProbeErrors')]
    Param()
    Begin {
        $BasePath = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand BasePath -EA 0
        if (-not $BasePath) { $BasePath = $Script:CWAAInstallPath }
    }
    Process {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $logFilePath = "$BasePath\LTProbeErrors.txt"
        if (-not (Test-Path -Path $logFilePath)) {
            Write-Error "Unable to find probe error log at '$logFilePath'."
            return
        }
        Try {
            $errors = Get-Content $logFilePath
            $errors = $errors -join ' ' -split '::: '
            foreach ($line in $errors) {
                $items = $line -split "`t" -replace ' - ', ''
                if ($items[1]) {
                    [PSCustomObject]@{
                        ServiceVersion = $items[0]
                        Timestamp      = $(Try { [datetime]::Parse($items[1]) } Catch { $null })
                        Message        = $items[2]
                    }
                }
            }
        }
        Catch {
            Write-Error "Failed to read probe error log at '$logFilePath'. Error: $($_.Exception.Message)"
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Set-CWAALogLevel {
    <#
    .SYNOPSIS
        Sets the logging level for the ConnectWise Automate Agent.
    .DESCRIPTION
        Configures the agent's logging verbosity by updating the registry and restarting the
        agent services. Supports Normal (standard) and Verbose (detailed diagnostic) levels.
        The function stops the agent service, writes the new logging level to the registry at
        HKLM:\SOFTWARE\LabTech\Service\Settings under the "Debuging" value, then restarts the
        agent service. After applying the change, it outputs the current logging level.
    .PARAMETER Level
        The desired logging level. Valid values are 'Normal' (default) and 'Verbose'.
        Normal sets registry value 1; Verbose sets registry value 1000.
    .EXAMPLE
        Set-CWAALogLevel -Level Verbose
        Enables verbose diagnostic logging on the agent.
    .EXAMPLE
        Set-CWAALogLevel -Level Normal
        Returns the agent to standard logging.
    .EXAMPLE
        Set-CWAALogLevel -Level Verbose -WhatIf
        Shows what changes would be made without applying them.
    .EXAMPLE
        'Verbose' | Set-CWAALogLevel
        Sets the log level to Verbose via pipeline input.
    .NOTES
        Author: Chris Taylor
        Alias: Set-LTLogging
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Set-LTLogging')]
    Param (
        [Parameter(ValueFromPipeline = $True)]
        [ValidateSet('Normal', 'Verbose')]
        $Level = 'Normal'
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        Try {
            # "Debuging" is the vendor's original spelling in the registry -- not a typo in this code.
            $registryPath = "$Script:CWAARegistrySettings"
            $registryName = 'Debuging'
            if ($Level -eq 'Normal') {
                $registryValue = 1
            }
            else {
                $registryValue = 1000
            }
            if ($PSCmdlet.ShouldProcess("$registryPath\$registryName", "Set logging level to $Level (value: $registryValue)")) {
                Stop-CWAA
                Set-ItemProperty $registryPath -Name $registryName -Value $registryValue
                Start-CWAA
            }
            Get-CWAALogLevel
            Write-CWAAEventLog -EventId 3030 -EntryType Information -Message "Agent log level set to $Level."
        }
        Catch {
            Write-CWAAEventLog -EventId 3032 -EntryType Error -Message "Failed to set agent log level to '$Level'. Error: $($_.Exception.Message)"
            Write-Error "Failed to set logging level to '$Level'. Error: $($_.Exception.Message)" -ErrorAction Stop
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Get-CWAAProxy {
    <#
    .SYNOPSIS
        Retrieves the current agent proxy settings for module operations.
    .DESCRIPTION
        Reads the current Automate agent proxy settings from the installed agent (if present)
        and stores them in the module-scoped $Script:LTProxy object. The proxy URL,
        username, and password are decrypted using the agent's password string. The
        discovered settings are used by all module communication operations for the
        duration of the session, and returned as the function result.
    .EXAMPLE
        Get-CWAAProxy
        Retrieves and returns the current proxy configuration.
    .EXAMPLE
        $proxy = Get-CWAAProxy
        if ($proxy.Enabled) { Write-Host "Proxy: $($proxy.ProxyServerURL)" }
        Checks whether a proxy is configured and displays the URL.
    .NOTES
        Author: Darren White
        Alias: Get-LTProxy
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTProxy')]
    Param()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        Write-Verbose 'Discovering Proxy Settings used by the LT Agent.'
        # Decrypt agent passwords from registry. The decrypted PasswordString is used
        # below to decode proxy credentials. This logic was formerly in the private
        # Initialize-CWAAKeys function â€” inlined here because Get-CWAAProxy is the only
        # consumer, and key decryption is inherently the first step of proxy discovery.
        # The $serviceInfo result is reused in Process to avoid a redundant registry read.
        $serviceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
        if ($serviceInfo -and ($serviceInfo | Get-Member | Where-Object { $_.Name -eq 'ServerPassword' })) {
            Write-Debug "Decoding Server Password."
            $Script:LTServiceKeys.ServerPasswordString = ConvertFrom-CWAASecurity -InputString "$($serviceInfo.ServerPassword)"
            if ($Null -ne $serviceInfo -and ($serviceInfo | Get-Member | Where-Object { $_.Name -eq 'Password' })) {
                Write-Debug "Decoding Agent Password."
                $Script:LTServiceKeys.PasswordString = ConvertFrom-CWAASecurity -InputString "$($serviceInfo.Password)" -Key "$($Script:LTServiceKeys.ServerPasswordString)"
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
    Process {
        Try {
            # Reuse $serviceInfo from Begin block â€” eliminates a redundant Get-CWAAInfo call.
            if ($Null -ne $serviceInfo -and ($serviceInfo | Get-Member | Where-Object { $_.Name -eq 'ServerPassword' })) {
                $serviceSettings = Get-CWAASettings -EA 0 -Verbose:$False -WA 0 -Debug:$False
                if ($Null -ne $serviceSettings) {
                    if (($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyServerURL' }) -and ($($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0) -Match 'https?://.+')) {
                        Write-Debug "Proxy Detected. Setting ProxyServerURL to $($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0)"
                        $Script:LTProxy.Enabled = $True
                        $Script:LTProxy.ProxyServerURL = "$($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0)"
                    }
                    else {
                        Write-Debug 'Setting ProxyServerURL to empty.'
                        $Script:LTProxy.Enabled = $False
                        $Script:LTProxy.ProxyServerURL = ''
                    }
                    if ($Script:LTProxy.Enabled -eq $True -and ($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyUsername' }) -and ($serviceSettings | Select-Object -Expand ProxyUsername -EA 0)) {
                        $Script:LTProxy.ProxyUsername = "$(ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))"
                        Write-Debug "Setting ProxyUsername to $(Get-CWAARedactedValue $Script:LTProxy.ProxyUsername)"
                    }
                    else {
                        Write-Debug 'Setting ProxyUsername to empty.'
                        $Script:LTProxy.ProxyUsername = ''
                    }
                    if ($Script:LTProxy.Enabled -eq $True -and ($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyPassword' }) -and ($serviceSettings | Select-Object -Expand ProxyPassword -EA 0)) {
                        $Script:LTProxy.ProxyPassword = "$(ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))"
                        Write-Debug "Setting ProxyPassword to $(Get-CWAARedactedValue $Script:LTProxy.ProxyPassword)"
                    }
                    else {
                        Write-Debug 'Setting ProxyPassword to empty.'
                        $Script:LTProxy.ProxyPassword = ''
                    }
                }
            }
            else {
                Write-Verbose 'No Server password or settings exist. No Proxy information will be available.'
            }
        }
        Catch {
            Write-Error "There was a problem retrieving Proxy Information. $_"
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
        return $Script:LTProxy
    }
}
function Set-CWAAProxy {
    <#
    .SYNOPSIS
        Configures module proxy settings for all operations during the current session.
    .DESCRIPTION
        Sets or clears Proxy settings needed for module function and agent operations.
        If an agent is already installed, this function will update the ProxyUsername,
        ProxyPassword, and ProxyServerURL values in the agent registry settings.
        Agent services will be restarted for changes (if found) to be applied.
    .PARAMETER ProxyServerURL
        The URL and optional port to assign as the proxy server for module operations
        and for the installed agent (if present).
        Example: Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080'
        May be used with ProxyUsername/ProxyPassword or EncodedProxyUsername/EncodedProxyPassword.
    .PARAMETER ProxyUsername
        Plain text username for proxy authentication.
        Must be used with ProxyServerURL and ProxyPassword.
    .PARAMETER ProxyPassword
        Plain text password for proxy authentication.
        Must be used with ProxyServerURL and ProxyUsername.
    .PARAMETER EncodedProxyUsername
        Encoded username for proxy authentication, encrypted with the agent password.
        Will be decoded using the agent password. Must be used with ProxyServerURL
        and EncodedProxyPassword.
    .PARAMETER EncodedProxyPassword
        Encoded password for proxy authentication, encrypted with the agent password.
        Will be decoded using the agent password. Must be used with ProxyServerURL
        and EncodedProxyUsername.
    .PARAMETER DetectProxy
        Automatically detect system proxy settings for module operations.
        Discovered settings are applied to the installed agent (if present).
        Cannot be used with other parameters.
    .PARAMETER ProxyCredential
        A PSCredential object containing the proxy username and password.
        This is the preferred secure alternative to passing -ProxyUsername
        and -ProxyPassword separately. Must be used with -ProxyServerURL.
    .PARAMETER ResetProxy
        Clears any currently defined proxy settings for module operations.
        Changes are applied to the installed agent (if present).
        Cannot be used with other parameters.
    .PARAMETER SkipCertificateCheck
        Bypasses SSL/TLS certificate validation for server connections.
        Use in lab or test environments with self-signed certificates.
    .EXAMPLE
        Set-CWAAProxy -DetectProxy
        Automatically detects and configures the system proxy.
    .EXAMPLE
        Set-CWAAProxy -ResetProxy
        Clears all proxy settings.
    .EXAMPLE
        Set-CWAAProxy -ProxyServerURL 'proxyhostname.fqdn.com:8080'
        Sets the proxy server URL without authentication.
    .NOTES
        Author: Darren White
        Alias: Set-LTProxy
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Set-LTProxy')]
    Param(
        [parameter(Mandatory = $False, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0)]
        [string]$ProxyServerURL,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True, Position = 1)]
        [string]$ProxyUsername,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True, Position = 2)]
        [SecureString]$ProxyPassword,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [string]$EncodedProxyUsername,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [SecureString]$EncodedProxyPassword,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $ProxyCredential,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [alias('Detect')]
        [alias('AutoDetect')]
        [switch]$DetectProxy,
        [parameter(Mandatory = $False, ValueFromPipeline = $False, ValueFromPipelineByPropertyName = $True)]
        [alias('Clear')]
        [alias('Reset')]
        [alias('ClearProxy')]
        [switch]$ResetProxy,
        [switch]$SkipCertificateCheck
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        # Lazy initialization of SSL/TLS, WebClient, and proxy configuration.
        # Only runs once per session, skips immediately on subsequent calls.
        $Null = Initialize-CWAANetworking -SkipCertificateCheck:$SkipCertificateCheck
        try {
            $serviceSettings = Get-CWAASettings -EA 0 -Verbose:$False -WA 0 -Debug:$False
        }
        catch { Write-Debug "Failed to retrieve service settings. $_" }
    }
    Process {
        # If a PSCredential was provided, extract username and password.
        # This is the preferred secure alternative to passing plain text proxy credentials.
        if ($ProxyCredential) {
            $ProxyUsername = $ProxyCredential.UserName
            $ProxyPassword = $ProxyCredential.GetNetworkCredential().Password
        }
        if (
            (($ResetProxy -eq $True) -and (($DetectProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) -or
            (($DetectProxy -eq $True) -and (($ResetProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) -or
            ((($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword)) -and (($ResetProxy -eq $True) -or ($DetectProxy -eq $True))) -or
            ((($ProxyUsername) -or ($ProxyPassword)) -and (-not ($ProxyServerURL) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword) -or ($ResetProxy -eq $True) -or ($DetectProxy -eq $True))) -or
            ((($EncodedProxyUsername) -or ($EncodedProxyPassword)) -and (-not ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($ResetProxy -eq $True) -or ($DetectProxy -eq $True)))
        ) { Write-Error "Set-CWAAProxy: Invalid parameter combination specified." -ErrorAction Stop }
        if (-not (($ResetProxy -eq $True) -or ($DetectProxy -eq $True) -or ($ProxyServerURL) -or ($ProxyUsername) -or ($ProxyPassword) -or ($EncodedProxyUsername) -or ($EncodedProxyPassword))) {
            if ($Args.Count -gt 0) { Write-Error "Set-CWAAProxy: Unknown parameter specified." -ErrorAction Stop }
            else { Write-Error "Set-CWAAProxy: Required parameters missing." -ErrorAction Stop }
        }
        Try {
            if ($($ResetProxy) -eq $True) {
                Write-Verbose 'ResetProxy selected. Clearing Proxy Settings.'
                if ( $PSCmdlet.ShouldProcess('LTProxy', 'Clear') ) {
                    $Script:LTProxy.Enabled = $False
                    $Script:LTProxy.ProxyServerURL = ''
                    $Script:LTProxy.ProxyUsername = ''
                    $Script:LTProxy.ProxyPassword = ''
                    $Script:LTWebProxy = New-Object System.Net.WebProxy
                    $Script:LTServiceNetWebClient.Proxy = $Script:LTWebProxy
                }
            }
            Elseif ($($DetectProxy) -eq $True) {
                Write-Verbose 'DetectProxy selected. Attempting to Detect Proxy Settings.'
                if ( $PSCmdlet.ShouldProcess('LTProxy', 'Detect') ) {
                    $Script:LTWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
                    $Script:LTProxy.Enabled = $False
                    $Script:LTProxy.ProxyServerURL = ''
                    $Servers = @($("$($serviceSettings | Select-Object -Expand 'ServerAddress' -EA 0)|www.connectwise.com").Split('|') | ForEach-Object { $_.Trim() })
                    Foreach ($serverUrl In $Servers) {
                        if (-not ($Script:LTProxy.Enabled)) {
                            if ($serverUrl -match $Script:CWAAServerValidationRegex) {
                                $serverUrl = $serverUrl -replace 'https?://', ''
                                Try {
                                    $Script:LTProxy.ProxyServerURL = $Script:LTWebProxy.GetProxy("http://$($serverUrl)").Authority
                                }
                                catch { Write-Debug "Failed to get proxy for server $serverUrl. $_" }
                                if (($Null -ne $Script:LTProxy.ProxyServerURL) -and ($Script:LTProxy.ProxyServerURL -ne '') -and ($Script:LTProxy.ProxyServerURL -notcontains "$($serverUrl)")) {
                                    Write-Debug "Detected Proxy URL: $($Script:LTProxy.ProxyServerURL) on server $($serverUrl)"
                                    $Script:LTProxy.Enabled = $True
                                }
                            }
                        }
                    }
                    if (-not ($Script:LTProxy.Enabled)) {
                        if (($Script:LTProxy.ProxyServerURL -eq '') -or ($Script:LTProxy.ProxyServerURL -contains '$serverUrl')) {
                            $Script:LTProxy.ProxyServerURL = netsh winhttp show proxy | Select-String -Pattern '(?i)(?<=Proxyserver.*http\=)([^;\r\n]*)' -EA 0 | ForEach-Object { $_.matches } | Select-Object -Expand value
                        }
                        if (($Null -eq $Script:LTProxy.ProxyServerURL) -or ($Script:LTProxy.ProxyServerURL -eq '')) {
                            $Script:LTProxy.ProxyServerURL = ''
                            $Script:LTProxy.Enabled = $False
                        }
                        else {
                            $Script:LTProxy.Enabled = $True
                            Write-Debug "Detected Proxy URL: $($Script:LTProxy.ProxyServerURL)"
                        }
                    }
                    $Script:LTProxy.ProxyUsername = ''
                    $Script:LTProxy.ProxyPassword = ''
                    $Script:LTServiceNetWebClient.Proxy = $Script:LTWebProxy
                }
            }
            Elseif (($ProxyServerURL)) {
                if ( $PSCmdlet.ShouldProcess('LTProxy', 'Set') ) {
                    foreach ($ProxyURL in $ProxyServerURL) {
                        $Script:LTWebProxy = New-Object System.Net.WebProxy($ProxyURL, $true);
                        $Script:LTProxy.Enabled = $True
                        $Script:LTProxy.ProxyServerURL = $ProxyURL
                    }
                    Write-Verbose "Setting Proxy URL to: $($ProxyServerURL)"
                    if ((($ProxyUsername) -and ($ProxyPassword)) -or (($EncodedProxyUsername) -and ($EncodedProxyPassword))) {
                        if (($ProxyUsername)) {
                            foreach ($proxyUser in $ProxyUsername) {
                                $Script:LTProxy.ProxyUsername = $proxyUser
                            }
                        }
                        if (($EncodedProxyUsername)) {
                            foreach ($proxyUser in $EncodedProxyUsername) {
                                $Script:LTProxy.ProxyUsername = $(ConvertFrom-CWAASecurity -InputString "$($proxyUser)" -Key ("$($Script:LTServiceKeys.PasswordString)", ''))
                            }
                        }
                        if (($ProxyPassword)) {
                            foreach ($proxyPass in $ProxyPassword) {
                                $Script:LTProxy.ProxyPassword = $proxyPass
                                $passwd = ConvertTo-SecureString $proxyPass -AsPlainText -Force;
                            }
                        }
                        if (($EncodedProxyPassword)) {
                            foreach ($proxyPass in $EncodedProxyPassword) {
                                $Script:LTProxy.ProxyPassword = $(ConvertFrom-CWAASecurity -InputString "$($proxyPass)" -Key ("$($Script:LTServiceKeys.PasswordString)", ''))
                                $passwd = ConvertTo-SecureString $Script:LTProxy.ProxyPassword -AsPlainText -Force;
                            }
                        }
                        $Script:LTWebProxy.Credentials = New-Object System.Management.Automation.PSCredential ($Script:LTProxy.ProxyUsername, $passwd);
                    }
                    $Script:LTServiceNetWebClient.Proxy = $Script:LTWebProxy
                }
            }
            # Apply settings to agent registry if changes detected
            $settingsChanged = $False
            if ($Null -ne ($serviceSettings)) {
                if (($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyServerURL' })) {
                    if (($($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0) -replace 'https?://', '' -ne $Script:LTProxy.ProxyServerURL) -and (($($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0) -replace 'https?://', '' -eq '' -and $Script:LTProxy.Enabled -eq $True -and $Script:LTProxy.ProxyServerURL -match '.+\..+') -or ($($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0) -replace 'https?://', '' -ne '' -and ($Script:LTProxy.ProxyServerURL -ne '' -or $Script:LTProxy.Enabled -eq $False)))) {
                        Write-Debug "ProxyServerURL Changed: Old Value: $($serviceSettings | Select-Object -Expand ProxyServerURL -EA 0) New Value: $($Script:LTProxy.ProxyServerURL)"
                        $settingsChanged = $True
                    }
                    if (($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyUsername' }) -and ($serviceSettings | Select-Object -Expand ProxyUsername -EA 0)) {
                        if ($(ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)", '')) -ne $Script:LTProxy.ProxyUsername) {
                            Write-Debug "ProxyUsername Changed: Old Value: $(Get-CWAARedactedValue (ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyUsername -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))) New Value: $(Get-CWAARedactedValue $Script:LTProxy.ProxyUsername)"
                            $settingsChanged = $True
                        }
                    }
                    if ($Null -ne ($serviceSettings) -and ($serviceSettings | Get-Member | Where-Object { $_.Name -eq 'ProxyPassword' }) -and ($serviceSettings | Select-Object -Expand ProxyPassword -EA 0)) {
                        if ($(ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)", '')) -ne $Script:LTProxy.ProxyPassword) {
                            Write-Debug "ProxyPassword Changed: Old Value: $(Get-CWAARedactedValue (ConvertFrom-CWAASecurity -InputString "$($serviceSettings | Select-Object -Expand ProxyPassword -EA 0)" -Key ("$($Script:LTServiceKeys.PasswordString)",''))) New Value: $(Get-CWAARedactedValue $Script:LTProxy.ProxyPassword)"
                            $settingsChanged = $True
                        }
                    }
                }
                Elseif ($Script:LTProxy.Enabled -eq $True -and $Script:LTProxy.ProxyServerURL -match '(https?://)?.+\..+') {
                    Write-Debug "ProxyServerURL Changed: Old Value: NOT SET New Value: $($Script:LTProxy.ProxyServerURL)"
                    $settingsChanged = $True
                }
            }
            else {
                $runningServiceCount = ('LTService') | Get-Service -EA 0 | Where-Object { $_.Status -eq 'Running' } | Measure-Object | Select-Object -Expand Count
                if (($runningServiceCount -gt 0) -and ($($Script:LTProxy.ProxyServerURL) -match '.+')) {
                    $settingsChanged = $True
                }
            }
            if ($settingsChanged -eq $True) {
                $serviceRestartNeeded = $False
                if ((Get-Service $Script:CWAAServiceNames -ErrorAction SilentlyContinue | Where-Object { $_.Status -match 'Running' })) {
                    $serviceRestartNeeded = $True
                    try { Stop-CWAA -EA 0 -WA 0 } catch { Write-Debug "Failed to stop services before proxy update. $_" }
                }
                Write-Verbose 'Updating Automate agent proxy configuration.'
                if ( $PSCmdlet.ShouldProcess('LTService Registry', 'Update') ) {
                    $serverUrl = $($Script:LTProxy.ProxyServerURL); if (($serverUrl -ne '') -and ($serverUrl -notmatch 'https?://')) { $serverUrl = "http://$($serverUrl)" }
                    @{'ProxyServerURL'  = $serverUrl;
                        'ProxyUserName' = "$(ConvertTo-CWAASecurity -InputString "$($Script:LTProxy.ProxyUserName)" -Key "$($Script:LTServiceKeys.PasswordString)")";
                        'ProxyPassword' = "$(ConvertTo-CWAASecurity -InputString "$($Script:LTProxy.ProxyPassword)" -Key "$($Script:LTServiceKeys.PasswordString)")"
                    }.GetEnumerator() | ForEach-Object {
                        Write-Debug "Setting Registry value for $($_.Name) to `"$($_.Value)`""
                        Set-ItemProperty -Path $Script:CWAARegistrySettings -Name $($_.Name) -Value $($_.Value) -EA 0 -Confirm:$False
                    }
                }
                if ($serviceRestartNeeded -eq $True) {
                    try { Start-CWAA -EA 0 -WA 0 } catch { Write-Debug "Failed to restart services after proxy update. $_" }
                }
                Write-CWAAEventLog -EventId 3020 -EntryType Information -Message "Proxy settings updated. Enabled: $($Script:LTProxy.Enabled), Server: $($Script:LTProxy.ProxyServerURL)"
            }
        }
        Catch {
            Write-CWAAEventLog -EventId 3022 -EntryType Error -Message "Proxy configuration failed. Error: $($_.Exception.Message)"
            Write-Error "There was an error during the Proxy Configuration process. $_" -ErrorAction Stop
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Register-CWAAHealthCheckTask {
    <#
    .SYNOPSIS
        Creates or updates a scheduled task for periodic ConnectWise Automate agent health checks.
    .DESCRIPTION
        Creates a Windows scheduled task that runs Repair-CWAA at a configurable interval
        (default every 6 hours) to monitor agent health and automatically remediate issues.
        The task runs as SYSTEM with highest privileges, includes a random delay equal to the
        interval to stagger execution across multiple machines, and has a 1-hour execution timeout.
        If the task already exists and the InstallerToken has changed, the task is recreated
        with the new token. Use -Force to recreate unconditionally.
        A backup of the current agent configuration is created before task registration
        via New-CWAABackup.
    .PARAMETER InstallerToken
        The installer token for authenticated agent deployment. Embedded in the scheduled
        task action for use by Repair-CWAA.
    .PARAMETER Server
        Optional server URL. When provided, the scheduled task passes this to Repair-CWAA
        in Install mode (with Server, LocationID, and InstallerToken).
    .PARAMETER LocationID
        Optional location ID. Required when Server is provided.
    .PARAMETER TaskName
        Name of the scheduled task. Default: 'CWAAHealthCheck'.
    .PARAMETER IntervalHours
        Hours between health check runs. Default: 6.
    .PARAMETER Force
        Force recreation of the task even if it already exists with the same token.
    .EXAMPLE
        Register-CWAAHealthCheckTask -InstallerToken 'abc123def456'
        Creates a task that runs Repair-CWAA in Checkup mode every 6 hours.
    .EXAMPLE
        Register-CWAAHealthCheckTask -InstallerToken 'token' -Server 'https://automate.domain.com' -LocationID 42
        Creates a task that runs Repair-CWAA in Install mode (can install fresh if agent is missing).
    .EXAMPLE
        Register-CWAAHealthCheckTask -InstallerToken 'token' -IntervalHours 12 -TaskName 'MyHealthCheck'
        Creates a custom-named task running every 12 hours.
    .EXAMPLE
        Get-CWAAInfo | Register-CWAAHealthCheckTask -InstallerToken 'token'
        Uses Server and LocationID from the installed agent via pipeline to register a health check task.
    .NOTES
        Author: Chris Taylor
        Alias: Register-LTHealthCheckTask
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Register-LTHealthCheckTask')]
    Param(
        [Parameter(Mandatory = $True)]
        [ValidatePattern('(?s:^[0-9a-z]+$)')]
        [string]$InstallerToken,
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidatePattern('^[a-zA-Z0-9\.\-\:\/]+$')]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [int]$LocationID,
        [ValidatePattern('^[\w\-\. ]+$')]
        [string]$TaskName = 'CWAAHealthCheck',
        [ValidateRange(1, 168)]
        [int]$IntervalHours = 6,
        [switch]$Force
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        $created = $False
        $updated = $False
        # Check if the task already exists
        $existingTaskXml = $Null
        Try {
            [xml]$existingTaskXml = schtasks /QUERY /XML /TN $TaskName 2>$Null
        }
        Catch { Write-Debug "Task '$TaskName' not found or query failed: $($_.Exception.Message)" }
        # If the task exists and the token hasn't changed, skip recreation unless -Force
        if ($existingTaskXml -and -not $Force) {
            if ($existingTaskXml.Task.Actions.Exec.Arguments -match [regex]::Escape($InstallerToken)) {
                Write-Verbose "Scheduled task '$TaskName' already exists with the same InstallerToken. Use -Force to recreate."
                [PSCustomObject]@{
                    TaskName = $TaskName
                    Created  = $False
                    Updated  = $False
                }
                return
            }
            $updated = $True
        }
        if ($PSCmdlet.ShouldProcess("Scheduled Task '$TaskName'", 'Create health check task')) {
            # Back up agent settings before creating/updating the task
            Write-Verbose 'Backing up agent configuration.'
            New-CWAABackup -ErrorAction SilentlyContinue
            # Build the PowerShell command for the scheduled task action
            # Use Install mode if Server and LocationID are provided, otherwise Checkup mode
            if ($Server -and $LocationID) {
                # Build a proper PowerShell array literal for the Server argument.
                # Handles both single-server and multi-server arrays from Get-CWAAInfo pipeline.
                $serverArgument = ($Server | ForEach-Object { "'$_'" }) -join ','
                $repairCommand = "Import-Module ConnectWiseAutomateAgent; Repair-CWAA -Server $serverArgument -LocationID $LocationID -InstallerToken '$InstallerToken'"
            }
            else {
                $repairCommand = "Import-Module ConnectWiseAutomateAgent; Repair-CWAA -InstallerToken '$InstallerToken'"
            }
            # XML-escape special characters in the command for the task definition
            $escapedCommand = $repairCommand -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&apos;'
            # Delete existing task if present
            Try {
                $Null = schtasks /DELETE /TN $TaskName /F 2>&1
            }
            Catch { Write-Debug "Failed to delete existing task '$TaskName': $($_.Exception.Message)" }
            # Build the task XML definition
            # Runs as SYSTEM (S-1-5-18) with highest privileges
            # Repeats every $IntervalHours hours with randomized delay for staggering
            $intervalIso = "PT${IntervalHours}H"
            $startBoundary = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
            [xml]$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
        <Description>ConnectWise Automate agent health check and automatic remediation.</Description>
        <URI>\$TaskName</URI>
    </RegistrationInfo>
    <Principals>
        <Principal id="Author">
            <UserId>S-1-5-18</UserId>
            <RunLevel>HighestAvailable</RunLevel>
        </Principal>
    </Principals>
    <Settings>
        <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
        <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
        <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
        <IdleSettings>
            <Duration>PT10M</Duration>
            <WaitTimeout>PT1H</WaitTimeout>
            <StopOnIdleEnd>false</StopOnIdleEnd>
            <RestartOnIdle>false</RestartOnIdle>
        </IdleSettings>
        <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    </Settings>
    <Triggers>
        <TimeTrigger>
            <StartBoundary>$startBoundary</StartBoundary>
            <Repetition>
                <Interval>$intervalIso</Interval>
                <Duration>P7300D</Duration>
                <StopAtDurationEnd>true</StopAtDurationEnd>
            </Repetition>
            <RandomDelay>$intervalIso</RandomDelay>
        </TimeTrigger>
    </Triggers>
    <Actions Context="Author">
        <Exec>
            <Command>C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe</Command>
            <Arguments>-NoProfile -WindowStyle Hidden -Command "$escapedCommand"</Arguments>
        </Exec>
    </Actions>
</Task>
"@
            $taskFilePath = "$env:TEMP\CWAAHealthCheckTask.xml"
            Try {
                $taskXml.Save($taskFilePath)
                $schtasksOutput = schtasks /CREATE /TN $TaskName /XML $taskFilePath /RU SYSTEM 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "schtasks returned exit code $LASTEXITCODE. Output: $schtasksOutput"
                }
                $created = -not $updated
                $resultMessage = if ($updated) { "Scheduled task '$TaskName' updated." } else { "Scheduled task '$TaskName' created." }
                Write-Output $resultMessage
                Write-CWAAEventLog -EventId 4020 -EntryType Information -Message "$resultMessage Interval: every $IntervalHours hours."
            }
            Catch {
                Write-Error "Failed to create scheduled task '$TaskName'. Error: $($_.Exception.Message)"
                Write-CWAAEventLog -EventId 4022 -EntryType Error -Message "Failed to create scheduled task '$TaskName'. Error: $($_.Exception.Message)"
            }
            Finally {
                # Clean up the temporary XML file
                Remove-Item -Path $taskFilePath -Force -ErrorAction SilentlyContinue
            }
        }
        [PSCustomObject]@{
            TaskName = $TaskName
            Created  = $created
            Updated  = $updated
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Repair-CWAA {
    <#
    .SYNOPSIS
        Performs escalating remediation of the ConnectWise Automate agent.
    .DESCRIPTION
        Checks the health of the installed Automate agent and takes corrective action
        using an escalating strategy:
        1. If the agent is installed and healthy — no action taken.
        2. If the agent is installed but has not checked in within HoursRestart — restarts
           services and waits up to 2 minutes for the agent to recover.
        3. If the agent is still not checking in after HoursReinstall — reinstalls the agent
           using Redo-CWAA.
        4. If the agent configuration is unreadable — uninstalls and reinstalls.
        5. If the installed agent points to the wrong server — reinstalls with the correct server.
        6. If the agent is not installed — performs a fresh install from provided parameters
           or from backup settings.
        All remediation actions are logged to the Windows Event Log (Application log,
        source ConnectWiseAutomateAgent) for visibility in unattended scheduled task runs.
        Designed to be called periodically via Register-CWAAHealthCheckTask or any
        external scheduler.
    .PARAMETER Server
        The ConnectWise Automate server URL for fresh installs or server mismatch correction.
        Required when using the Install parameter set.
    .PARAMETER LocationID
        The LocationID for fresh agent installs. Required with the Install parameter set.
    .PARAMETER InstallerToken
        An installer token for authenticated agent deployment. Required for both parameter sets.
    .PARAMETER HoursRestart
        Hours since last check-in before a service restart is attempted. Expressed as a
        negative number (e.g., -2 means 2 hours ago). Default: -2.
    .PARAMETER HoursReinstall
        Hours since last check-in before a full reinstall is attempted. Expressed as a
        negative number (e.g., -120 means 120 hours / 5 days ago). Default: -120.
    .EXAMPLE
        Repair-CWAA -InstallerToken 'abc123def456'
        Checks the installed agent and repairs if needed (Checkup mode).
    .EXAMPLE
        Repair-CWAA -Server 'https://automate.domain.com' -LocationID 42 -InstallerToken 'token'
        Checks agent health. If the agent is missing or pointed at the wrong server,
        installs or reinstalls with the specified settings.
    .EXAMPLE
        Repair-CWAA -InstallerToken 'token' -HoursRestart -4 -HoursReinstall -240
        Uses custom thresholds: restart after 4 hours offline, reinstall after 10 days.
    .NOTES
        Author: Chris Taylor
        Alias: Repair-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Repair-LTService')]
    Param(
        [Parameter(ParameterSetName = 'Install', Mandatory = $True, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
            if ($_ -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$') { $true }
            else { throw "Server address '$_' is not valid. Expected format: https://automate.domain.com" }
        })]
        [string]$Server,
        [Parameter(ParameterSetName = 'Install', Mandatory = $True, ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$LocationID,
        [Parameter(ParameterSetName = 'Install', Mandatory = $True)]
        [Parameter(ParameterSetName = 'Checkup', Mandatory = $True)]
        [ValidatePattern('(?s:^[0-9a-z]+$)')]
        [string]$InstallerToken,
        [int]$HoursRestart = -2,
        [int]$HoursReinstall = -120
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        # Kill duplicate Repair-CWAA processes to prevent overlapping remediation
        # Uses CIM for reliable command-line matching (Get-Process cannot filter by arguments)
        if ($PSCmdlet.ShouldProcess('Duplicate Repair-CWAA processes', 'Terminate')) {
            Try {
                Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
                    $_.Name -eq 'powershell.exe' -and
                    $_.CommandLine -match 'Repair-CWAA' -and
                    $_.ProcessId -ne $PID
                } | ForEach-Object {
                    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
                }
            }
            Catch {
                Write-Debug "Unable to check for duplicate processes: $($_.Exception.Message)"
            }
        }
    }
    Process {
        $actionTaken = 'None'
        $success = $True
        $resultMessage = ''
        # Determine if the agent service is installed
        $agentServiceExists = [bool](Get-Service 'LTService' -ErrorAction SilentlyContinue)
        if ($agentServiceExists) {
            #region Agent is installed — check health and remediate
            # Verify we can read agent configuration
            $agentInfo = $Null
            Try {
                $agentInfo = Get-CWAAInfo -EA Stop -Verbose:$False -WhatIf:$False -Confirm:$False
            }
            Catch {
                # Agent config is unreadable — uninstall so we can reinstall cleanly
                Write-Warning "Unable to read agent configuration. Uninstalling for clean reinstall."
                Write-CWAAEventLog -EventId 4009 -EntryType Warning -Message "Agent configuration unreadable. Uninstalling for clean reinstall. Error: $($_.Exception.Message)"
                $backupSettings = Get-CWAAInfoBackup -EA 0
                Try {
                    Get-Process 'Agent_Uninstall' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                    if ($PSCmdlet.ShouldProcess('LTService', 'Uninstall agent with unreadable config')) {
                        Uninstall-CWAA -Force -Server ($backupSettings.Server[0])
                    }
                }
                Catch {
                    Write-Error "Failed to uninstall agent with unreadable config. Error: $($_.Exception.Message)"
                    Write-CWAAEventLog -EventId 4009 -EntryType Error -Message "Failed to uninstall agent with unreadable config. Error: $($_.Exception.Message)"
                }
                $resultMessage = 'Uninstalled agent with unreadable config. Restart machine and run again.'
                $actionTaken = 'Uninstall'
                $success = $False
                [PSCustomObject]@{
                    ActionTaken = $actionTaken
                    Success     = $success
                    Message     = $resultMessage
                }
                return
            }
            # If Server parameter was provided, check that it matches the installed agent
            if ($Server) {
                $currentServers = ($agentInfo | Select-Object -Expand 'Server' -EA 0)
                $cleanExpectedServer = $Server -replace 'https?://', '' -replace '/$', ''
                $serverMatches = $False
                foreach ($currentServer in $currentServers) {
                    $cleanCurrent = $currentServer -replace 'https?://', '' -replace '/$', ''
                    if ($cleanCurrent -eq $cleanExpectedServer) {
                        $serverMatches = $True
                        break
                    }
                }
                if (-not $serverMatches) {
                    Write-Warning "Wrong install server ($($currentServers -join ', ')). Expected '$Server'. Reinstalling."
                    Write-CWAAEventLog -EventId 4004 -EntryType Warning -Message "Server mismatch detected. Installed: $($currentServers -join ', '). Expected: $Server. Reinstalling."
                    if ($PSCmdlet.ShouldProcess('LTService', "Reinstall agent for server mismatch (current: $($currentServers -join ', '), expected: $Server)")) {
                        Clear-CWAAInstallerArtifacts
                        Try {
                            Redo-CWAA -Server $Server -LocationID $LocationID -InstallerToken $InstallerToken
                            $actionTaken = 'Reinstall'
                            $resultMessage = "Reinstalled agent to correct server: $Server"
                            Write-CWAAEventLog -EventId 4004 -EntryType Information -Message $resultMessage
                        }
                        Catch {
                            $actionTaken = 'Reinstall'
                            $success = $False
                            $resultMessage = "Failed to reinstall agent for server mismatch. Error: $($_.Exception.Message)"
                            Write-Error $resultMessage
                            Write-CWAAEventLog -EventId 4009 -EntryType Error -Message $resultMessage
                        }
                    }
                    [PSCustomObject]@{
                        ActionTaken = $actionTaken
                        Success     = $success
                        Message     = $resultMessage
                    }
                    return
                }
            }
            # Get last contact timestamp (try LastSuccessStatus, fall back to HeartbeatLastReceived)
            $lastContact = $Null
            Try {
                [datetime]$lastContact = $agentInfo.LastSuccessStatus
            }
            Catch {
                Try {
                    [datetime]$lastContact = $agentInfo.HeartbeatLastReceived
                }
                Catch {
                    # No valid contact timestamp — treat as very old
                    [datetime]$lastContact = (Get-Date).AddYears(-1)
                }
            }
            # Get last heartbeat timestamp
            $lastHeartbeat = $Null
            Try {
                [datetime]$lastHeartbeat = $agentInfo.HeartbeatLastSent
            }
            Catch {
                [datetime]$lastHeartbeat = (Get-Date).AddYears(-1)
            }
            Write-Verbose "Last check-in: $lastContact"
            Write-Verbose "Last heartbeat: $lastHeartbeat"
            # Determine the server address for connectivity checks
            $activeServer = $Null
            if ($Server) {
                $activeServer = $Server
            }
            else {
                Try { $activeServer = ($agentInfo | Select-Object -Expand 'Server' -EA 0)[0] }
                Catch {
                    Try { $activeServer = (Get-CWAAInfoBackup -EA 0).Server[0] }
                    Catch { Write-Debug "Unable to retrieve server from backup settings: $($_.Exception.Message)" }
                }
            }
            # Check if the agent is offline beyond the restart threshold
            $restartThreshold = (Get-Date).AddHours($HoursRestart)
            $reinstallThreshold = (Get-Date).AddHours($HoursReinstall)
            if ($lastContact -lt $restartThreshold -or $lastHeartbeat -lt $restartThreshold) {
                Write-Verbose "Agent has NOT checked in within the last $([Math]::Abs($HoursRestart)) hour(s)."
                Write-CWAAEventLog -EventId 4001 -EntryType Warning -Message "Agent offline. Last contact: $lastContact. Last heartbeat: $lastHeartbeat. Threshold: $([Math]::Abs($HoursRestart)) hours."
                # Verify the server is reachable before attempting remediation
                if ($activeServer) {
                    $serverAvailable = Test-CWAAServerConnectivity -Server $activeServer -Quiet
                    if (-not $serverAvailable) {
                        $resultMessage = "Server '$activeServer' is not reachable. Cannot remediate."
                        Write-Error $resultMessage
                        Write-CWAAEventLog -EventId 4008 -EntryType Error -Message $resultMessage
                        [PSCustomObject]@{
                            ActionTaken = 'None'
                            Success     = $False
                            Message     = $resultMessage
                        }
                        return
                    }
                }
                # Step 1: Restart services
                if ($PSCmdlet.ShouldProcess('LTService, LTSvcMon', 'Restart services to recover agent check-in')) {
                    Write-Verbose 'Restarting Automate agent services.'
                    Restart-CWAA
                    # Wait up to 2 minutes for the agent to check in after restart
                    Write-Verbose 'Waiting for agent check-in after restart.'
                    $waitStart = Get-Date
                    while ($lastContact -lt $restartThreshold -and $waitStart.AddMinutes(2) -gt (Get-Date)) {
                        Start-Sleep -Seconds 2
                        Try {
                            [datetime]$lastContact = (Get-CWAAInfo -EA Stop -Verbose:$False -WhatIf:$False -Confirm:$False).LastSuccessStatus
                        }
                        Catch {
                            Write-Debug "Unable to re-read LastSuccessStatus during wait loop: $($_.Exception.Message)"
                        }
                    }
                }
                # Did the restart fix it?
                if ($lastContact -ge $restartThreshold) {
                    $actionTaken = 'Restart'
                    $resultMessage = "Services restarted. Agent recovered. Last contact: $lastContact"
                    Write-Verbose $resultMessage
                    Write-CWAAEventLog -EventId 4001 -EntryType Information -Message $resultMessage
                }
                # Step 2: Reinstall if still offline beyond reinstall threshold
                elseif ($lastContact -lt $reinstallThreshold) {
                    Write-Verbose "Agent still not connecting after restart. Offline beyond $([Math]::Abs($HoursReinstall))-hour threshold. Reinstalling."
                    Write-CWAAEventLog -EventId 4002 -EntryType Warning -Message "Agent still offline after restart. Last contact: $lastContact. Attempting reinstall."
                    if ($PSCmdlet.ShouldProcess('LTService', 'Reinstall agent after failed restart recovery')) {
                        Clear-CWAAInstallerArtifacts
                        Try {
                            if ($InstallerToken -and $Server -and $LocationID) {
                                Redo-CWAA -Server $Server -LocationID $LocationID -InstallerToken $InstallerToken -Hide
                            }
                            else {
                                Redo-CWAA -Hide -InstallerToken $InstallerToken
                            }
                            $actionTaken = 'Reinstall'
                            $resultMessage = 'Agent reinstalled after extended offline period.'
                            Write-CWAAEventLog -EventId 4002 -EntryType Information -Message $resultMessage
                        }
                        Catch {
                            $actionTaken = 'Reinstall'
                            $success = $False
                            $resultMessage = "Agent reinstall failed. Error: $($_.Exception.Message)"
                            Write-Error $resultMessage
                            Write-CWAAEventLog -EventId 4009 -EntryType Error -Message $resultMessage
                        }
                    }
                }
                else {
                    # Restart was attempted but agent hasn't recovered yet. Not yet at reinstall threshold.
                    $actionTaken = 'Restart'
                    $success = $True
                    $resultMessage = "Services restarted. Agent has not recovered yet but is within reinstall threshold ($([Math]::Abs($HoursReinstall)) hours)."
                    Write-Verbose $resultMessage
                }
            }
            else {
                # Agent is healthy
                $resultMessage = "Agent is healthy. Last contact: $lastContact. Last heartbeat: $lastHeartbeat."
                Write-Verbose $resultMessage
                Write-CWAAEventLog -EventId 4000 -EntryType Information -Message $resultMessage
            }
            #endregion
        }
        else {
            #region Agent is NOT installed — attempt install
            Write-Verbose 'Agent service not found. Attempting installation.'
            Write-CWAAEventLog -EventId 4003 -EntryType Warning -Message 'Agent not installed. Attempting installation.'
            Try {
                if ($Server -and $LocationID -and $InstallerToken) {
                    # Full install parameters provided
                    if ($PSCmdlet.ShouldProcess('LTService', "Install agent (Server: $Server, LocationID: $LocationID)")) {
                        Write-Verbose "Installing agent with provided parameters (Server: $Server, LocationID: $LocationID)."
                        Clear-CWAAInstallerArtifacts
                        Redo-CWAA -Server $Server -LocationID $LocationID -InstallerToken $InstallerToken
                        $actionTaken = 'Install'
                        $resultMessage = "Fresh agent install completed (Server: $Server, LocationID: $LocationID)."
                        Write-CWAAEventLog -EventId 4003 -EntryType Information -Message $resultMessage
                    }
                }
                else {
                    # Try to recover from existing settings or backup
                    $settings = $Null
                    $hasBackup = $False
                    Try {
                        $settings = Get-CWAAInfo -EA Stop -Verbose:$False -WhatIf:$False -Confirm:$False
                        $hasBackup = $True
                    }
                    Catch {
                        $settings = Get-CWAAInfoBackup -EA 0
                        $hasBackup = $False
                    }
                    if ($settings) {
                        if ($hasBackup) {
                            Write-Verbose 'Backing up current settings before reinstall.'
                            New-CWAABackup -ErrorAction SilentlyContinue
                        }
                        $reinstallServer = ($settings | Select-Object -Expand 'Server' -EA 0)[0]
                        $reinstallLocationID = $settings | Select-Object -Expand 'LocationID' -EA 0
                        if ($PSCmdlet.ShouldProcess('LTService', "Reinstall from backup settings (Server: $reinstallServer)")) {
                            Write-Verbose "Reinstalling agent from backup settings (Server: $reinstallServer)."
                            Clear-CWAAInstallerArtifacts
                            Redo-CWAA -Server $reinstallServer -LocationID $reinstallLocationID -Hide -InstallerToken $InstallerToken
                            $actionTaken = 'Install'
                            $resultMessage = "Agent reinstalled from backup settings (Server: $reinstallServer)."
                            Write-CWAAEventLog -EventId 4003 -EntryType Information -Message $resultMessage
                        }
                    }
                    else {
                        $success = $False
                        $resultMessage = 'Unable to find install settings. Provide -Server, -LocationID, and -InstallerToken parameters.'
                        Write-Error $resultMessage
                        Write-CWAAEventLog -EventId 4009 -EntryType Error -Message $resultMessage
                    }
                }
            }
            Catch {
                $actionTaken = 'Install'
                $success = $False
                $resultMessage = "Agent installation failed. Error: $($_.Exception.Message)"
                Write-Error $resultMessage
                Write-CWAAEventLog -EventId 4009 -EntryType Error -Message $resultMessage
            }
            #endregion
        }
        [PSCustomObject]@{
            ActionTaken = $actionTaken
            Success     = $success
            Message     = $resultMessage
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Restart-CWAA {
    <#
    .SYNOPSIS
        Restarts the ConnectWise Automate agent services.
    .DESCRIPTION
        Verifies that the Automate agent services (LTService, LTSvcMon) are present, then
        calls Stop-CWAA followed by Start-CWAA to perform a full service restart.
    .EXAMPLE
        Restart-CWAA
        Restarts the ConnectWise Automate agent services.
    .EXAMPLE
        Restart-CWAA -WhatIf
        Shows what would happen without actually restarting the services.
    .NOTES
        Author: Chris Taylor
        Alias: Restart-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Restart-LTService')]
    Param()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        if (-not (Test-CWAAServiceExists -WriteErrorOnMissing)) { return }
        if ($PSCmdlet.ShouldProcess('LTService, LTSvcMon', 'Restart Service')) {
            Try {
                Stop-CWAA
            }
            Catch {
                Write-Error "There was an error stopping the services. $_"
                Write-CWAAEventLog -EventId 2022 -EntryType Error -Message "Agent restart failed during stop phase. Error: $($_.Exception.Message)"
                return
            }
            Try {
                Start-CWAA
            }
            Catch {
                Write-Error "There was an error starting the services. $_"
                Write-CWAAEventLog -EventId 2022 -EntryType Error -Message "Agent restart failed during start phase. Error: $($_.Exception.Message)"
                return
            }
            Write-Output 'Services restarted successfully.'
            Write-CWAAEventLog -EventId 2020 -EntryType Information -Message 'Agent services restarted successfully.'
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Start-CWAA {
    <#
    .SYNOPSIS
        Starts the ConnectWise Automate agent services.
    .DESCRIPTION
        Verifies that the Automate agent services (LTService, LTSvcMon) are present. Checks
        for any process using the LTTray port (default 42000) and kills it. If a
        protected application holds the port, increments the TrayPort (wrapping from
        42009 back to 42000). Sets services to Automatic startup and starts them via
        sc.exe. Waits up to one minute for LTService to reach the Running state, then
        issues a Send Status command for immediate check-in.
    .EXAMPLE
        Start-CWAA
        Starts the ConnectWise Automate agent services.
    .EXAMPLE
        Start-CWAA -WhatIf
        Shows what would happen without actually starting the services.
    .NOTES
        Author: Chris Taylor
        Alias: Start-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Start-LTService')]
    Param()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        # Identify processes that are using the tray port
        [array]$processes = @()
        $Port = (Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand TrayPort -EA 0)
        if (-not ($Port)) { $Port = '42000' }
        $startedSvcCount = 0
    }
    Process {
        if (-not (Test-CWAAServiceExists -WriteErrorOnMissing)) { return }
        Try {
            if ((('LTService') | Get-Service -EA 0 | Where-Object { $_.Status -eq 'Stopped' } | Measure-Object | Select-Object -Expand Count) -gt 0) {
                Try { $netstat = & "$env:windir\system32\netstat.exe" -a -o -n 2>'' | Select-String -Pattern " .*[0-9\.]+:$($Port).*[0-9\.]+:[0-9]+ .*?([0-9]+)" -EA 0 }
                Catch { Write-Debug 'Failed to call netstat.exe.'; $netstat = $null }
                Foreach ($line in $netstat) {
                    $processes += ($line -split ' {4,}')[-1]
                }
                $processes = $processes | Where-Object { $_ -gt 0 -and $_ -match '^\d+$' } | Sort-Object | Get-Unique
                if ($processes) {
                    Foreach ($processId in $processes) {
                        Write-Output "Process ID:$processId is using port $Port. Killing process."
                        Try { Stop-Process -Id $processId -Force -Verbose -EA Stop }
                        Catch {
                            Write-Warning "There was an issue killing process: $processId"
                            Write-Warning "This generally means that a 'protected application' is using this port."
                            # TrayPort wraps within the 42000-42009 range. If a protected process holds
                            # the current port, increment and wrap back to 42000 after 42009.
                            $newPort = [int]$Port + 1
                            if ($newPort -gt $Script:CWAATrayPortMax) { $newPort = $Script:CWAATrayPortMin }
                            Write-Warning "Setting tray port to $newPort."
                            New-ItemProperty -Path $Script:CWAARegistryRoot -Name TrayPort -PropertyType String -Value $newPort -Force -WhatIf:$False -Confirm:$False | Out-Null
                        }
                    }
                }
            }
            if ($PSCmdlet.ShouldProcess('LTService, LTSvcMon', 'Start Service')) {
                $Script:CWAAServiceNames | ForEach-Object {
                    if (Get-Service $_ -EA 0) {
                        Set-Service $_ -StartupType Automatic -EA 0 -Confirm:$False -WhatIf:$False
                        $Null = & "$env:windir\system32\sc.exe" start "$($_)" 2>''
                        if ($LASTEXITCODE -ne 0) {
                            Write-Warning "sc.exe start returned exit code $LASTEXITCODE for service '$_'."
                        }
                        $startedSvcCount++
                        Write-Debug "Executed Start Service for $($_)"
                    }
                }
                # Wait for services if we issued start commands
                $stoppedServiceCount = ('LTService') | Get-Service -EA 0 | Where-Object { $_.Status -ne 'Running' } | Measure-Object | Select-Object -Expand Count
                if ($stoppedServiceCount -gt 0 -and $startedSvcCount -eq 2) {
                    $Null = Wait-CWAACondition -Condition {
                        $count = ('LTService') | Get-Service -EA 0 | Where-Object { $_.Status -ne 'Running' } | Measure-Object | Select-Object -Expand Count
                        $count -eq 0
                    } -TimeoutSeconds $Script:CWAAServiceWaitTimeoutSec -IntervalSeconds 2 -Activity 'Services starting'
                    $stoppedServiceCount = ('LTService') | Get-Service -EA 0 | Where-Object { $_.Status -ne 'Running' } | Measure-Object | Select-Object -Expand Count
                }
                # Report final state
                if ($stoppedServiceCount -eq 0) {
                    Write-Output 'Services started successfully.'
                    Write-CWAAEventLog -EventId 2000 -EntryType Information -Message 'Agent services started successfully.'
                    $Null = Invoke-CWAACommand 'Send Status' -EA 0 -Confirm:$False
                }
                elseif ($startedSvcCount -gt 0) {
                    Write-Output 'Service Start was issued but LTService has not reached Running state.'
                    Write-CWAAEventLog -EventId 2001 -EntryType Warning -Message 'Agent services failed to reach Running state after start.'
                }
                else {
                    Write-Output 'Service Start was not issued.'
                }
            }
        }
        Catch {
            Write-Error "There was an error starting the Automate agent services. $_"
            Write-CWAAEventLog -EventId 2002 -EntryType Error -Message "Agent service start failed. Error: $($_.Exception.Message)"
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Stop-CWAA {
    <#
    .SYNOPSIS
        Stops the ConnectWise Automate agent services.
    .DESCRIPTION
        Verifies that the Automate agent services (LTService, LTSvcMon) are present, then
        attempts to stop them gracefully via sc.exe. Waits up to one minute for the
        services to reach a Stopped state. If they do not stop in time, remaining
        Automate agent processes (LTTray, LTSVC, LTSvcMon) are forcefully terminated.
    .EXAMPLE
        Stop-CWAA
        Stops the ConnectWise Automate agent services.
    .EXAMPLE
        Stop-CWAA -WhatIf
        Shows what would happen without actually stopping the services.
    .NOTES
        Author: Chris Taylor
        Alias: Stop-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Stop-LTService')]
    Param()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        if (-not (Test-CWAAServiceExists -WriteErrorOnMissing)) { return }
        if ($PSCmdlet.ShouldProcess('LTService, LTSvcMon', 'Stop-Service')) {
            $Null = Invoke-CWAACommand ('Kill VNC', 'Kill Trays') -EA 0 -WhatIf:$False -Confirm:$False
            Write-Verbose 'Stopping Automate agent services.'
            Try {
                $Script:CWAAServiceNames | ForEach-Object {
                    Try {
                        $Null = & "$env:windir\system32\sc.exe" stop "$($_)" 2>''
                        if ($LASTEXITCODE -ne 0) {
                            Write-Warning "sc.exe stop returned exit code $LASTEXITCODE for service '$_'."
                        }
                    }
                    Catch { Write-Debug "Failed to call sc.exe stop for service $_." }
                }
                $servicesStopped = Wait-CWAACondition -Condition {
                    $count = $Script:CWAAServiceNames | Get-Service -EA 0 | Where-Object { $_.Status -ne 'Stopped' } | Measure-Object | Select-Object -Expand Count
                    $count -eq 0
                } -TimeoutSeconds $Script:CWAAServiceWaitTimeoutSec -IntervalSeconds 2 -Activity 'Services stopping'
                if (-not $servicesStopped) {
                    Write-Verbose 'Services did not stop in time. Terminating processes.'
                }
                Get-Process | Where-Object { $Script:CWAAAgentProcessNames -contains $_.ProcessName } | Stop-Process -Force -ErrorAction Stop -WhatIf:$False -Confirm:$False
                # Verify final state and report
                $remainingCount = $Script:CWAAServiceNames | Get-Service -EA 0 | Where-Object { $_.Status -ne 'Stopped' } | Measure-Object | Select-Object -Expand Count
                if ($remainingCount -eq 0) {
                    Write-Output 'Services stopped successfully.'
                    Write-CWAAEventLog -EventId 2010 -EntryType Information -Message 'Agent services stopped successfully.'
                }
                else {
                    Write-Warning 'Services have not stopped completely.'
                    Write-CWAAEventLog -EventId 2011 -EntryType Warning -Message 'Agent services did not stop completely.'
                }
            }
            Catch {
                Write-Error "There was an error stopping the Automate agent processes. $_"
                Write-CWAAEventLog -EventId 2012 -EntryType Error -Message "Agent service stop failed. Error: $($_.Exception.Message)"
            }
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Test-CWAAHealth {
    <#
    .SYNOPSIS
        Performs a read-only health assessment of the ConnectWise Automate agent.
    .DESCRIPTION
        Checks the overall health of the installed Automate agent without taking any
        remediation action. Returns a status object with details about the agent's
        installation state, service status, last check-in times, and server connectivity.
        This function never modifies the agent, services, or registry. It is safe to call
        at any time for monitoring or diagnostic purposes.
        Health assessment criteria:
        - Agent is installed (LTService exists)
        - Services are running (LTService and LTSvcMon)
        - Agent has checked in recently (LastSuccessStatus or HeartbeatLastSent within threshold)
        - Server is reachable (optional, tested when Server param is provided or auto-discovered)
        The Healthy property is True only when the agent is installed, services are running,
        and LastContact is not null.
    .PARAMETER Server
        An Automate server URL to validate against the installed agent's configured server.
        If provided, the ServerMatch property indicates whether the installed agent points
        to this server. If omitted, ServerMatch is null.
    .PARAMETER TestServerConnectivity
        When specified, tests whether the agent's server is reachable via the agent.aspx
        endpoint. Adds a brief network call. The ServerReachable property is null when
        this switch is not used.
    .EXAMPLE
        Test-CWAAHealth
        Returns a health status object for the installed agent.
    .EXAMPLE
        Test-CWAAHealth -Server 'https://automate.domain.com' -TestServerConnectivity
        Checks agent health, validates the server address matches, and tests server connectivity.
    .EXAMPLE
        if ((Test-CWAAHealth).Healthy) { Write-Output 'Agent is healthy' }
        Uses the Healthy boolean for conditional logic.
    .EXAMPLE
        Get-CWAAInfo | Test-CWAAHealth
        Pipes the installed agent's Server property into Test-CWAAHealth via pipeline.
    .NOTES
        Author: Chris Taylor
        Alias: Test-LTHealth
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Test-LTHealth')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [string[]]$Server,
        [switch]$TestServerConnectivity
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        # Defaults — populated progressively as checks succeed
        $agentInstalled = $False
        $servicesRunning = $False
        $lastContact = $Null
        $lastHeartbeat = $Null
        $serverAddress = $Null
        $serverMatch = $Null
        $serverReachable = $Null
        $healthy = $False
        # Check if the agent service exists
        $ltService = Get-Service 'LTService' -ErrorAction SilentlyContinue
        if ($ltService) {
            $agentInstalled = $True
            # Check if both services are running
            $ltSvcMon = Get-Service 'LTSvcMon' -ErrorAction SilentlyContinue
            $servicesRunning = (
                $ltService.Status -eq 'Running' -and
                $ltSvcMon -and $ltSvcMon.Status -eq 'Running'
            )
            # Read agent configuration from registry
            $agentInfo = $Null
            Try {
                $agentInfo = Get-CWAAInfo -EA Stop -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
            }
            Catch {
                Write-Verbose "Unable to read agent info from registry: $($_.Exception.Message)"
            }
            if ($agentInfo) {
                # Extract server address
                $serverAddress = ($agentInfo | Select-Object -Expand 'Server' -EA 0) -join '|'
                # Parse last contact timestamp
                Try {
                    [datetime]$lastContact = $agentInfo.LastSuccessStatus
                }
                Catch {
                    Write-Verbose 'LastSuccessStatus not available or not a valid datetime.'
                }
                # Parse last heartbeat timestamp
                Try {
                    [datetime]$lastHeartbeat = $agentInfo.HeartbeatLastSent
                }
                Catch {
                    Write-Verbose 'HeartbeatLastSent not available or not a valid datetime.'
                }
                # If a Server was provided, check if any matches the installed configuration.
                # Server is string[] to handle Get-CWAAInfo pipeline output (which returns Server as an array).
                if ($Server) {
                    $installedServers = @($agentInfo | Select-Object -Expand 'Server' -EA 0)
                    $cleanProvided = @($Server | ForEach-Object { $_ -replace 'https?://', '' -replace '/$', '' })
                    $serverMatch = $False
                    foreach ($installedServer in $installedServers) {
                        $cleanInstalled = $installedServer -replace 'https?://', '' -replace '/$', ''
                        if ($cleanProvided -contains $cleanInstalled) {
                            $serverMatch = $True
                            break
                        }
                    }
                }
                # Optionally test server connectivity
                if ($TestServerConnectivity) {
                    $serversToTest = @($agentInfo | Select-Object -Expand 'Server' -EA 0)
                    if ($serversToTest) {
                        $serverReachable = Test-CWAAServerConnectivity -Server $serversToTest[0] -Quiet
                    }
                    else {
                        $serverReachable = $False
                    }
                }
            }
            # Overall health: installed, running, and has a recent contact timestamp
            $healthy = $agentInstalled -and $servicesRunning -and ($Null -ne $lastContact)
        }
        [PSCustomObject]@{
            AgentInstalled  = $agentInstalled
            ServicesRunning = $servicesRunning
            LastContact     = $lastContact
            LastHeartbeat   = $lastHeartbeat
            ServerAddress   = $serverAddress
            ServerMatch     = $serverMatch
            ServerReachable = $serverReachable
            Healthy         = $healthy
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Unregister-CWAAHealthCheckTask {
    <#
    .SYNOPSIS
        Removes the ConnectWise Automate agent health check scheduled task.
    .DESCRIPTION
        Deletes the Windows scheduled task created by Register-CWAAHealthCheckTask.
        If the task does not exist, writes a warning and returns gracefully.
    .PARAMETER TaskName
        Name of the scheduled task to remove. Default: 'CWAAHealthCheck'.
    .EXAMPLE
        Unregister-CWAAHealthCheckTask
        Removes the default CWAAHealthCheck scheduled task.
    .EXAMPLE
        Unregister-CWAAHealthCheckTask -TaskName 'MyHealthCheck'
        Removes a custom-named health check task.
    .NOTES
        Author: Chris Taylor
        Alias: Unregister-LTHealthCheckTask
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Unregister-LTHealthCheckTask')]
    Param(
        [string]$TaskName = 'CWAAHealthCheck'
    )
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }
    Process {
        $removed = $False
        # Check if the task exists
        $taskExists = $False
        Try {
            $Null = schtasks /QUERY /TN $TaskName 2>$Null
            if ($LASTEXITCODE -eq 0) {
                $taskExists = $True
            }
        }
        Catch { Write-Debug "Task '$TaskName' query failed: $($_.Exception.Message)" }
        if (-not $taskExists) {
            Write-Warning "Scheduled task '$TaskName' does not exist."
            [PSCustomObject]@{
                TaskName = $TaskName
                Removed  = $False
            }
            return
        }
        if ($PSCmdlet.ShouldProcess("Scheduled Task '$TaskName'", 'Remove health check task')) {
            Try {
                $schtasksOutput = schtasks /DELETE /TN $TaskName /F 2>&1
                if ($LASTEXITCODE -ne 0) {
                    throw "schtasks returned exit code $LASTEXITCODE. Output: $schtasksOutput"
                }
                $removed = $True
                Write-Output "Scheduled task '$TaskName' has been removed."
                Write-CWAAEventLog -EventId 4030 -EntryType Information -Message "Scheduled task '$TaskName' removed."
            }
            Catch {
                Write-Error "Failed to remove scheduled task '$TaskName'. Error: $($_.Exception.Message)"
                Write-CWAAEventLog -EventId 4032 -EntryType Error -Message "Failed to remove scheduled task '$TaskName'. Error: $($_.Exception.Message)"
            }
        }
        [PSCustomObject]@{
            TaskName = $TaskName
            Removed  = $removed
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Get-CWAAInfo {
    <#
    .SYNOPSIS
        Retrieves ConnectWise Automate agent configuration from the registry.
    .DESCRIPTION
        Reads all agent configuration values from the Automate agent service registry key and
        returns them as a single object. Resolves the BasePath from the service image path
        if not present in the registry, expands environment variables in BasePath, and parses
        the pipe-delimited Server Address into a clean Server array.
        This function supports ShouldProcess because many internal callers pass
        -WhatIf:$False -Confirm:$False to suppress prompts during automated operations.
    .EXAMPLE
        Get-CWAAInfo
        Returns an object containing all agent registry properties including ID, Server,
        LocationID, BasePath, and other configuration values.
    .EXAMPLE
        Get-CWAAInfo -WhatIf:$False -Confirm:$False
        Retrieves agent info with ShouldProcess suppressed, as used by internal callers.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTServiceInfo
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True, ConfirmImpact = 'Low')]
    [Alias('Get-LTServiceInfo')]
    Param ()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $exclude = 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', 'PSPath'
    }
    Process {
        if (-not (Test-Path $Script:CWAARegistryRoot)) {
            Write-Error "Unable to find information on LTSvc. Make sure the agent is installed."
            return $Null
        }
        if ($PSCmdlet.ShouldProcess('LTService', 'Retrieving Service Registry Values')) {
            Write-Verbose 'Checking for LT Service registry keys.'
            Try {
                $key = Get-ItemProperty $Script:CWAARegistryRoot -ErrorAction Stop | Select-Object * -Exclude $exclude
                if ($Null -ne $key -and -not ($key | Get-Member -EA 0 | Where-Object { $_.Name -match 'BasePath' })) {
                    $BasePath = $Script:CWAAInstallPath
                    if (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\LTService') {
                        Try {
                            $BasePath = Get-Item $(
                                Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\LTService' -ErrorAction Stop |
                                    Select-Object -Expand ImagePath |
                                    Select-String -Pattern '^[^"][^ ]+|(?<=^")[^"]+' |
                                    Select-Object -Expand Matches -First 1 |
                                    Select-Object -Expand Value -EA 0 -First 1
                            ) | Select-Object -Expand DirectoryName -EA 0
                        }
                        Catch {
                            Write-Debug "Could not resolve BasePath from service ImagePath, using default: $_"
                        }
                    }
                    Add-Member -InputObject $key -MemberType NoteProperty -Name BasePath -Value $BasePath
                }
                $key.BasePath = [System.Environment]::ExpandEnvironmentVariables(
                    $($key | Select-Object -Expand BasePath -EA 0)
                ) -replace '\\\\', '\'
                if ($Null -ne $key -and ($key | Get-Member | Where-Object { $_.Name -match 'Server Address' })) {
                    $Servers = ($key | Select-Object -Expand 'Server Address' -EA 0).Split('|') |
                        ForEach-Object { $_.Trim() -replace '~', '' } |
                        Where-Object { $_ -match '.+' }
                    Add-Member -InputObject $key -MemberType NoteProperty -Name 'Server' -Value $Servers -Force
                }
                return $key
            }
            Catch {
                Write-Error "There was a problem reading the registry keys. $_"
            }
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Get-CWAAInfoBackup {
    <#
    .SYNOPSIS
        Retrieves backed-up ConnectWise Automate agent configuration from the registry.
    .DESCRIPTION
        Reads all agent configuration values from the LabTechBackup registry key
        and returns them as a single object. This backup is created by New-CWAABackup and
        stores a snapshot of the agent configuration at the time of backup.
        Expands environment variables in BasePath and parses the pipe-delimited Server
        Address into a clean Server array, matching the behavior of Get-CWAAInfo.
    .EXAMPLE
        Get-CWAAInfoBackup
        Returns an object containing all backed-up agent registry properties.
    .EXAMPLE
        Get-CWAAInfoBackup | Select-Object -ExpandProperty Server
        Returns only the server addresses from the backup configuration.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTServiceInfoBackup
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTServiceInfoBackup')]
    Param ()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $exclude = 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', 'PSPath'
    }
    Process {
        if (-not (Test-Path $Script:CWAARegistryBackup)) {
            Write-Error "Unable to find backup information on LTSvc. Use New-CWAABackup to create a settings backup."
            return
        }
        Try {
            $key = Get-ItemProperty $Script:CWAARegistryBackup -ErrorAction Stop | Select-Object * -Exclude $exclude
            if ($Null -ne $key -and ($key | Get-Member | Where-Object { $_.Name -match 'BasePath' })) {
                $key.BasePath = [System.Environment]::ExpandEnvironmentVariables($key.BasePath) -replace '\\\\', '\'
            }
            if ($Null -ne $key -and ($key | Get-Member | Where-Object { $_.Name -match 'Server Address' })) {
                $Servers = ($key | Select-Object -Expand 'Server Address' -EA 0).Split('|') |
                    ForEach-Object { $_.Trim() -replace '~', '' } |
                    Where-Object { $_ -match '.+' }
                Add-Member -InputObject $key -MemberType NoteProperty -Name 'Server' -Value $Servers -Force
            }
            return $key
        }
        Catch {
            Write-Error "There was a problem reading the backup registry keys. $_"
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Get-CWAASettings {
    <#
    .SYNOPSIS
        Retrieves ConnectWise Automate agent settings from the registry.
    .DESCRIPTION
        Reads agent settings from the Automate agent service Settings registry subkey
        (HKLM:\SOFTWARE\LabTech\Service\Settings) and returns them as an object.
        These settings are separate from the main agent configuration returned by
        Get-CWAAInfo and include proxy configuration (ProxyServerURL, ProxyUsername,
        ProxyPassword), logging level, and other operational parameters written by
        the agent or Set-CWAAProxy.
    .EXAMPLE
        Get-CWAASettings
        Returns an object containing all agent settings registry properties.
    .EXAMPLE
        (Get-CWAASettings).ProxyServerURL
        Returns just the configured proxy URL, if any.
    .NOTES
        Author: Chris Taylor
        Alias: Get-LTServiceSettings
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Get-LTServiceSettings')]
    Param ()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $exclude = 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider', 'PSPath'
    }
    Process {
        if (-not (Test-Path $Script:CWAARegistrySettings)) {
            Write-Error "Unable to find LTSvc settings. Make sure the agent is installed."
            return
        }
        Try {
            return Get-ItemProperty $Script:CWAARegistrySettings -ErrorAction Stop | Select-Object * -Exclude $exclude
        }
        Catch {
            Write-Error "There was a problem reading the registry keys. $_"
        }
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function New-CWAABackup {
    <#
    .SYNOPSIS
        Creates a complete backup of the ConnectWise Automate agent installation.
    .DESCRIPTION
        Creates a comprehensive backup of the currently installed ConnectWise Automate agent
        by copying all files from the agent installation directory and exporting all related
        registry keys. This backup can be used to restore the agent configuration if needed,
        or to preserve settings before performing maintenance operations.
        The backup process performs the following operations:
        1. Locates the agent installation directory (typically C:\Windows\LTSVC)
        2. Creates a Backup subdirectory within the agent installation path
        3. Copies all files from the installation directory to the Backup folder
        4. Exports registry keys from HKLM\SOFTWARE\LabTech to a .reg file
        5. Modifies the exported registry data to use the LabTechBackup key name
        6. Imports the modified registry data to HKLM\SOFTWARE\LabTechBackup
    .EXAMPLE
        New-CWAABackup
        Creates a complete backup of the agent installation files and registry settings.
    .EXAMPLE
        New-CWAABackup -WhatIf
        Shows what the backup operation would do without actually creating the backup.
    .NOTES
        Author: Chris Taylor
        Alias: New-LTServiceBackup
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('New-LTServiceBackup')]
    Param ()
    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $agentPath = "$(Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand BasePath -EA 0)"
        if (-not $agentPath) {
            Write-Error "Unable to find LTSvc folder path." -ErrorAction Stop
        }
        $BackupPath = Join-Path $agentPath 'Backup'
        $Keys = 'HKLM\SOFTWARE\LabTech'
        $RegPath = "$BackupPath\LTBackup.reg"
        Write-Verbose 'Checking for registry keys.'
        if (-not (Test-Path ($Keys -replace '^(H[^\\]*)', '$1:'))) {
            Write-Error "Unable to find registry information on LTSvc. Make sure the agent is installed." -ErrorAction Stop
        }
        if (-not (Test-Path -Path $agentPath -PathType Container)) {
            Write-Error "Unable to find LTSvc folder path $agentPath" -ErrorAction Stop
        }
    }
    Process {
        if ($PSCmdlet.ShouldProcess($BackupPath, 'Create backup directory')) {
            New-Item $BackupPath -Type Directory -ErrorAction SilentlyContinue | Out-Null
            if (-not (Test-Path -Path $BackupPath -PathType Container)) {
                Write-Error "Unable to create backup folder path $BackupPath" -ErrorAction Stop
            }
        }
        if ($PSCmdlet.ShouldProcess($agentPath, 'Copy agent files to backup')) {
            Try {
                # Copy each top-level item individually, excluding the Backup directory
                # itself to prevent recursive copy loop (Backup is inside the agent path)
                Get-ChildItem $agentPath -Exclude 'Backup' | Copy-Item -Destination $BackupPath -Recurse -Force
            }
            Catch {
                Write-Error "There was a problem backing up the LTSvc folder. $_"
                Write-CWAAEventLog -EventId 3012 -EntryType Error -Message "Agent backup failed (file copy). Error: $($_.Exception.Message)"
            }
        }
        if ($PSCmdlet.ShouldProcess($Keys, 'Export and backup registry keys')) {
            Try {
                Write-Debug 'Exporting registry data'
                $Null = & "$env:windir\system32\reg.exe" export "$Keys" "$RegPath" /y 2>''
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "reg.exe export returned exit code $LASTEXITCODE. Registry backup may be incomplete."
                }
                Write-Debug 'Loading and modifying registry key name'
                $Reg = Get-Content $RegPath
                $Reg = $Reg -replace [Regex]::Escape('[HKEY_LOCAL_MACHINE\SOFTWARE\LabTech'), '[HKEY_LOCAL_MACHINE\SOFTWARE\LabTechBackup'
                Write-Debug 'Writing modified registry data'
                $Reg | Out-File $RegPath
                Write-Debug 'Importing registry data to backup path'
                $Null = & "$env:windir\system32\reg.exe" import "$RegPath" 2>''
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "reg.exe import returned exit code $LASTEXITCODE. Registry backup restoration may have failed."
                }
                $True | Out-Null
            }
            Catch {
                Write-Error "There was a problem backing up the LTSvc registry keys. $_"
                Write-CWAAEventLog -EventId 3012 -EntryType Error -Message "Agent backup failed (registry export). Error: $($_.Exception.Message)"
            }
        }
        Write-Output 'The Automate agent backup has been created.'
        Write-CWAAEventLog -EventId 3010 -EntryType Information -Message "Agent backup created at $BackupPath."
    }
    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
function Reset-CWAA {
    <#
    .SYNOPSIS
        Removes local agent identity settings to force re-registration.
    .DESCRIPTION
        Removes some of the agent's local settings: ID, MAC, and/or LocationID. The function
        stops the services, removes the specified registry values, then restarts the services.
        Resetting all three values forces the agent to check in as a new agent. If MAC filtering
        is enabled on the server, the agent should check back in with the same ID.
        This function is useful for resolving duplicate agent entries. If no switches are
        specified, all three values (ID, Location, MAC) are reset.
        Probe agents are protected from reset unless the -Force switch is used.
    .PARAMETER ID
        Resets the AgentID of the computer.
    .PARAMETER Location
        Resets the LocationID of the computer.
    .PARAMETER MAC
        Resets the MAC address of the computer.
    .PARAMETER Force
        Forces the reset operation on an agent detected as a probe.
    .PARAMETER NoWait
        Skips the post-reset health check that waits for the agent to re-register.
    .EXAMPLE
        Reset-CWAA
        Resets the ID, MAC, and LocationID on the agent, then waits for re-registration.
    .EXAMPLE
        Reset-CWAA -ID
        Resets only the AgentID of the agent.
    .EXAMPLE
        Reset-CWAA -Force -NoWait
        Resets all values on a probe agent without waiting for re-registration.
    .NOTES
        Author: Chris Taylor
        Alias: Reset-LTService
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
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
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        if (-not $PSBoundParameters.ContainsKey('ID') -and -not $PSBoundParameters.ContainsKey('Location') -and -not $PSBoundParameters.ContainsKey('MAC')) {
            $ID = $True
            $Location = $True
            $MAC = $True
        }
        $serviceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
        Assert-CWAANotProbeAgent -ServiceInfo $serviceInfo -ActionName 'Reset' -Force:$Force
        Write-Output "OLD ID: $($serviceInfo | Select-Object -Expand ID -EA 0) LocationID: $($serviceInfo | Select-Object -Expand LocationID -EA 0) MAC: $($serviceInfo | Select-Object -Expand MAC -EA 0)"
    }
    Process {
        if (-not (Test-CWAAServiceExists -WriteErrorOnMissing)) { return }
        Try {
            if ($ID -or $Location -or $MAC) {
                Stop-CWAA
                if ($ID) {
                    Write-Output '.Removing ID'
                    Remove-ItemProperty -Name ID -Path $Script:CWAARegistryRoot -ErrorAction SilentlyContinue
                }
                if ($Location) {
                    Write-Output '.Removing LocationID'
                    Remove-ItemProperty -Name LocationID -Path $Script:CWAARegistryRoot -ErrorAction SilentlyContinue
                }
                if ($MAC) {
                    Write-Output '.Removing MAC'
                    Remove-ItemProperty -Name MAC -Path $Script:CWAARegistryRoot -ErrorAction SilentlyContinue
                }
                Start-CWAA
            }
        }
        Catch {
            Write-CWAAEventLog -EventId 3002 -EntryType Error -Message "Agent reset failed. Error: $($_.Exception.Message)"
            Write-Error "There was an error during the reset process. $_" -ErrorAction Stop
        }
    }
    End {
        if (-not $NoWait -and $PSCmdlet.ShouldProcess('LTService', 'Discover new settings after Service Start')) {
            $Null = Wait-CWAACondition -Condition {
                $svcInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
                ($svcInfo | Select-Object -Expand ID -EA 0) -and
                ($svcInfo | Select-Object -Expand LocationID -EA 0) -and
                ($svcInfo | Select-Object -Expand MAC -EA 0)
            } -TimeoutSeconds $Script:CWAARegistrationTimeoutSec -IntervalSeconds 2 -Activity 'Agent re-registration'
            $serviceInfo = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False
            Write-Output "NEW ID: $($serviceInfo | Select-Object -Expand ID -EA 0) LocationID: $($serviceInfo | Select-Object -Expand LocationID -EA 0) MAC: $($serviceInfo | Select-Object -Expand MAC -EA 0)"
            Write-CWAAEventLog -EventId 3000 -EntryType Information -Message "Agent reset successfully. New ID: $($serviceInfo | Select-Object -Expand ID -EA 0), LocationID: $($serviceInfo | Select-Object -Expand LocationID -EA 0)"
        }
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
Initialize-CWAA
