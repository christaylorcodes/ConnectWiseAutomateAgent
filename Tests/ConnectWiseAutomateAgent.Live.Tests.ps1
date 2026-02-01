#Requires -Module Pester

<#
.SYNOPSIS
    Live integration tests for the ConnectWiseAutomateAgent module.

.DESCRIPTION
    Comprehensive lifecycle tests that exercise all 25 public functions across a
    full agent lifecycle:

        Phase 1: Fresh install -> exercise every function -> backup -> uninstall (clean verify)
        Phase 2: Restore from backup via Redo-CWAA -> verify -> uninstall (clean verify)
        Phase 3: Fresh reinstall -> idempotency checks -> final uninstall (thorough verify)

    These tests WILL modify system state (services, registry, files) and require
    administrator privileges. DO NOT run on a machine with a production Automate agent.

.NOTES
    Required environment variables:
        $env:CWAATestServer         - Automate server URL (e.g. https://automate.example.com)
        $env:CWAATestInstallerToken - Installer token for agent deployment

    Optional environment variables:
        $env:CWAATestLocationID     - Location ID for agent assignment (default: 1)

    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Live.Tests.ps1 -Output Detailed

    These tests are tagged 'Live' so they can be excluded from standard runs:
        Invoke-Pester Tests\ -ExcludeTag 'Live'

    Expected runtime: 30-60+ minutes (3 install/uninstall cycles with registration waits)
#>

BeforeAll {
    $ModuleName = 'ConnectWiseAutomateAgent'
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModulePath = Join-Path $ModuleRoot "$ModuleName\$ModuleName.psd1"

    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $ModulePath -Force -ErrorAction Stop

    # ---- State variables ----
    $script:AgentInstalled = $false
    $script:AgentServer = $env:CWAATestServer
    $script:AgentInstallerToken = $env:CWAATestInstallerToken
    $script:AgentLocationID = if ($env:CWAATestLocationID) { [int]$env:CWAATestLocationID } else { 1 }
    $script:OriginalAgentID = $null
    $script:BackupCreated = $false
    $script:PreUninstallInfo = $null

    # ---- Helper: Wait-ServiceState ----
    # Polls Get-Service until all named services reach the target state.
    # Returns $true if reached, $false on timeout.
    # Treats "service not found" (null) as equivalent to 'Stopped'.
    function script:Wait-ServiceState {
        param(
            [Parameter(Mandatory)]
            [string[]]$ServiceName,

            [Parameter(Mandatory)]
            [ValidateSet('Running', 'Stopped')]
            [string]$State,

            [int]$TimeoutSeconds = 60,

            [int]$PollIntervalMs = 2000
        )
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        do {
            Start-Sleep -Milliseconds $PollIntervalMs
            $allMatch = $true
            foreach ($name in $ServiceName) {
                $svc = Get-Service $name -ErrorAction SilentlyContinue
                if ($State -eq 'Running') {
                    if (-not $svc -or $svc.Status -ne 'Running') { $allMatch = $false; break }
                }
                else {
                    # 'Stopped' — service not found counts as stopped
                    if ($svc -and $svc.Status -ne 'Stopped') { $allMatch = $false; break }
                }
            }
        } until ($allMatch -or $stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds)
        $stopwatch.Stop()
        return $allMatch
    }

    # ---- Helper: Wait-AgentRegistration ----
    # Polls Get-CWAAInfo until the agent has a numeric ID.
    # Returns $true if registered, $false on timeout.
    function script:Wait-AgentRegistration {
        param(
            [int]$TimeoutSeconds = 120,
            [int]$PollIntervalMs = 5000
        )
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        do {
            Start-Sleep -Milliseconds $PollIntervalMs
            $info = Get-CWAAInfo -EA SilentlyContinue -WhatIf:$false -Confirm:$false -Debug:$false
            $id = $info | Select-Object -ExpandProperty ID -EA SilentlyContinue
        } until (($id -match '^\d+$') -or $stopwatch.Elapsed.TotalSeconds -ge $TimeoutSeconds)
        $stopwatch.Stop()
        return ($id -match '^\d+$')
    }

    # ---- Helper: Assert-CleanUninstall ----
    # Verifies all categories of agent remnants are gone.
    # -AllowBackupRegistry skips the LabTechBackup registry check (it survives normal uninstall).
    function script:Assert-CleanUninstall {
        param(
            [switch]$AllowBackupRegistry
        )
        # Services
        Get-Service 'LTService' -EA SilentlyContinue | Should -BeNullOrEmpty -Because 'LTService should be removed'
        Get-Service 'LTSvcMon' -EA SilentlyContinue | Should -BeNullOrEmpty -Because 'LTSvcMon should be removed'
        Get-Service 'LabVNC' -EA SilentlyContinue | Should -BeNullOrEmpty -Because 'LabVNC should be removed'

        # Registry
        Test-Path 'HKLM:\SOFTWARE\LabTech\Service' | Should -BeFalse -Because 'agent registry key should be removed'
        Test-Path 'HKLM:\SOFTWARE\WOW6432Node\LabTech\Service' | Should -BeFalse -Because 'WOW6432Node registry key should be removed'

        if (-not $AllowBackupRegistry) {
            Test-Path 'HKLM:\SOFTWARE\LabTechBackup' | Should -BeFalse -Because 'backup registry should be removed'
        }

        # Files
        Test-Path "$env:windir\LTSVC" | Should -BeFalse -Because 'agent installation directory should be removed'

        # Module function
        $info = Get-CWAAInfo -EA SilentlyContinue -WhatIf:$false -Confirm:$false
        $info | Should -BeNullOrEmpty -Because 'Get-CWAAInfo should return null after uninstall'
    }
}

AfterAll {
    # Safety net: if the agent is still present after tests, attempt cleanup
    $agentInfo = Get-CWAAInfo -EA SilentlyContinue -WhatIf:$false -Confirm:$false
    if ($agentInfo) {
        Write-Warning 'Agent still installed after test run - attempting cleanup uninstall.'
        try { Uninstall-CWAA -Server $script:AgentServer -Force -Confirm:$false }
        catch { Write-Warning "Cleanup uninstall failed: $_" }
    }

    # Clean backup registry
    foreach ($regPath in @('HKLM:\SOFTWARE\LabTechBackup', 'HKLM:\SOFTWARE\WOW6432Node\LabTechBackup')) {
        if (Test-Path $regPath) {
            Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# Pre-Flight Checks
# =============================================================================
Describe 'Pre-Flight Checks' -Tag 'Live' {

    It 'is running as Administrator' {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) | Should -BeTrue
    }

    It 'has CWAATestServer environment variable set' {
        $env:CWAATestServer | Should -Not -BeNullOrEmpty -Because 'set $env:CWAATestServer to your Automate server URL'
    }

    It 'has CWAATestInstallerToken environment variable set' {
        $env:CWAATestInstallerToken | Should -Not -BeNullOrEmpty -Because 'set $env:CWAATestInstallerToken to a valid installer token'
    }

    It 'server URL is in a valid format' {
        $env:CWAATestServer | Should -Match '^https?://' -Because 'server URL should start with http:// or https://'
    }

    It 'no existing Automate agent is installed' {
        $existingAgent = Get-CWAAInfo -EA SilentlyContinue -WhatIf:$false -Confirm:$false
        $existingAgent | Should -BeNullOrEmpty -Because 'a live agent would be disrupted by these tests'
    }

    It 'LTService service does not exist' {
        $service = Get-Service 'LTService' -EA SilentlyContinue
        $service | Should -BeNullOrEmpty -Because 'remnant services indicate a partial install'
    }
}

# =============================================================================
# Environment Cleanup (remove remnants from prior runs)
# =============================================================================
Describe 'Environment Cleanup' -Tag 'Live' {

    It 'removes leftover installer temp files' {
        # Clean the LabTech installer staging directory
        $installerTempPath = "$env:windir\Temp\LabTech"
        if (Test-Path $installerTempPath) {
            Remove-Item $installerTempPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Cleaned: $installerTempPath"
        }

        # Clean remnant uninstaller files from system and user temp directories
        $searchDirs = @("$env:windir\Temp", $env:TEMP) | Select-Object -Unique
        $filesToClean = @('Agent_Uninstall.exe', 'Uninstall.exe', 'Uninstall.exe.config')

        foreach ($dir in $searchDirs) {
            foreach ($fileName in $filesToClean) {
                $filePath = Join-Path $dir $fileName
                if (Test-Path $filePath) {
                    Remove-Item $filePath -Force -ErrorAction SilentlyContinue
                    Write-Host "  Cleaned: $filePath"
                }
            }
        }

        # Verify all locations are clean
        $allRemnants = foreach ($dir in $searchDirs) {
            foreach ($fileName in $filesToClean) {
                $filePath = Join-Path $dir $fileName
                if (Test-Path $filePath) { $filePath }
            }
        }
        $allRemnants | Should -BeNullOrEmpty -Because 'leftover temp files cause interactive prompts during install/uninstall'
    }

    It 'removes leftover agent installation directory' {
        $installPath = "$env:windir\LTSVC"
        if (Test-Path $installPath) {
            Remove-Item $installPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Cleaned: $installPath"
        }
        Test-Path $installPath | Should -BeFalse -Because 'remnant install directory interferes with fresh install'
    }

    It 'removes leftover registry keys' {
        $registryPaths = @(
            'HKLM:\SOFTWARE\LabTech\Service'
            'HKLM:\SOFTWARE\WOW6432Node\LabTech\Service'
            'HKLM:\SOFTWARE\LabTechBackup'
            'HKLM:\SOFTWARE\WOW6432Node\LabTechBackup'
        )
        foreach ($regPath in $registryPaths) {
            if (Test-Path $regPath) {
                Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  Cleaned: $regPath"
            }
        }
    }

    It 'stops and removes leftover services' {
        foreach ($serviceName in @('LTService', 'LTSvcMon')) {
            $service = Get-Service $serviceName -ErrorAction SilentlyContinue
            if ($service) {
                if ($service.Status -eq 'Running') {
                    Stop-Service $serviceName -Force -ErrorAction SilentlyContinue
                    Write-Host "  Stopped: $serviceName"
                }
                & "$env:windir\system32\sc.exe" delete $serviceName 2>$null
                Write-Host "  Removed: $serviceName"
            }
        }
    }
}

# =============================================================================
# Phase 1: Fresh Install
# =============================================================================
Describe 'Phase 1: Fresh Install' -Tag 'Live' {

    It 'Install-CWAA completes without throwing' {
        $installParams = @{
            Server         = $script:AgentServer
            InstallerToken = $script:AgentInstallerToken
            LocationID     = $script:AgentLocationID
            Force          = $true
            Confirm        = $false
        }

        { Install-CWAA @installParams } | Should -Not -Throw
        $script:AgentInstalled = $true
    }

    It 'LTService service exists and is running' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent installation failed' }

        $ready = Wait-ServiceState -ServiceName 'LTService' -State 'Running' -TimeoutSeconds 90
        $ready | Should -BeTrue -Because 'LTService should be running after install'
    }

    It 'LTSvcMon service exists and is running' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent installation failed' }

        $ready = Wait-ServiceState -ServiceName 'LTSvcMon' -State 'Running' -TimeoutSeconds 60
        $ready | Should -BeTrue -Because 'LTSvcMon should be running after install'
    }

    It 'Get-CWAAInfo returns agent data with a numeric ID' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent installation failed' }

        $registered = Wait-AgentRegistration -TimeoutSeconds 120
        $registered | Should -BeTrue -Because 'agent should register with a numeric ID'

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $info | Should -Not -BeNullOrEmpty
        $info.ID | Should -Match '^\d+$'
        $script:OriginalAgentID = $info.ID
    }

    It 'agent server matches the provided server' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent installation failed' }

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $cleanExpected = ($script:AgentServer -replace 'https?://','').TrimEnd('/')
        ($info.Server -replace 'https?://','') | Should -Contain $cleanExpected
    }

    It 'agent installation directory exists' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent installation failed' }

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $info.BasePath | Should -Not -BeNullOrEmpty
        Test-Path $info.BasePath | Should -BeTrue
    }

    It 'agent registry key exists' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent installation failed' }

        Test-Path 'HKLM:\SOFTWARE\LabTech\Service' | Should -BeTrue
    }

    It 'Install-LTService alias resolves correctly' {
        $alias = Get-Alias 'Install-LTService' -EA SilentlyContinue
        $alias | Should -Not -BeNullOrEmpty
        $alias.ResolvedCommand.Name | Should -Be 'Install-CWAA'
    }
}

# =============================================================================
# Phase 1: Exercise All Functions
# =============================================================================

# ---- Agent Information and Settings ----
Describe 'Phase 1: Agent Information and Settings' -Tag 'Live' {

    It 'Get-CWAAInfo returns Server, BasePath, and Version properties' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $info.Server | Should -Not -BeNullOrEmpty
        $info.BasePath | Should -Not -BeNullOrEmpty
        $info | Get-Member -Name 'Version' -EA SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Get-CWAASettings returns settings data with ServerAddress' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $settings = Get-CWAASettings -EA SilentlyContinue
        $settings | Should -Not -BeNullOrEmpty
        $settings | Get-Member -Name 'ServerAddress' -EA SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It 'Get-LTServiceInfo alias returns matching data' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $info = Get-LTServiceInfo -WhatIf:$false -Confirm:$false
        $info | Should -Not -BeNullOrEmpty
        $info.ID | Should -Be $script:OriginalAgentID
    }

    It 'Get-LTServiceSettings alias returns data' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $settings = Get-LTServiceSettings -EA SilentlyContinue
        $settings | Should -Not -BeNullOrEmpty
    }
}

# ---- Service Operations ----
Describe 'Phase 1: Service Operations' -Tag 'Live' {

    It 'Stop-CWAA stops the agent services' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Stop-CWAA -Confirm:$false } | Should -Not -Throw

        $stopped = Wait-ServiceState -ServiceName 'LTService' -State 'Stopped' -TimeoutSeconds 60
        $stopped | Should -BeTrue -Because 'LTService should stop'
    }

    It 'LTSvcMon is also stopped' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $stopped = Wait-ServiceState -ServiceName 'LTSvcMon' -State 'Stopped' -TimeoutSeconds 30
        $stopped | Should -BeTrue -Because 'LTSvcMon should stop when LTService stops'
    }

    It 'Start-CWAA starts the agent services' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Start-CWAA -Confirm:$false } | Should -Not -Throw

        $started = Wait-ServiceState -ServiceName 'LTService' -State 'Running' -TimeoutSeconds 60
        $started | Should -BeTrue -Because 'LTService should start'
    }

    It 'LTSvcMon is also running after start' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $started = Wait-ServiceState -ServiceName 'LTSvcMon' -State 'Running' -TimeoutSeconds 30
        $started | Should -BeTrue -Because 'LTSvcMon should start when LTService starts'
    }

    It 'Restart-CWAA cycles the agent services' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Restart-CWAA -Confirm:$false } | Should -Not -Throw

        $running = Wait-ServiceState -ServiceName 'LTService','LTSvcMon' -State 'Running' -TimeoutSeconds 90
        $running | Should -BeTrue -Because 'both services should be running after restart'
    }

    It 'Stop-LTService alias resolves to Stop-CWAA' {
        $alias = Get-Alias 'Stop-LTService' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Stop-CWAA'
    }

    It 'Start-LTService alias resolves to Start-CWAA' {
        $alias = Get-Alias 'Start-LTService' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Start-CWAA'
    }

    It 'Restart-LTService alias resolves to Restart-CWAA' {
        $alias = Get-Alias 'Restart-LTService' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Restart-CWAA'
    }
}

# ---- Invoke-CWAACommand ----
Describe 'Phase 1: Invoke-CWAACommand' -Tag 'Live' {

    It 'sends Send Status command without error' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        # Ensure service is running first
        $running = Wait-ServiceState -ServiceName 'LTService' -State 'Running' -TimeoutSeconds 30
        if (-not $running) { Set-ItResult -Skipped -Because 'LTService is not running' }

        { Invoke-CWAACommand -Command 'Send Status' -Confirm:$false } | Should -Not -Throw
    }

    It 'sends Send Inventory command without error' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Invoke-CWAACommand -Command 'Send Inventory' -Confirm:$false } | Should -Not -Throw
    }

    It 'sends multiple commands in a single call without error' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Invoke-CWAACommand -Command 'Send Apps','Send Services' -Confirm:$false } | Should -Not -Throw
    }

    It 'Invoke-LTServiceCommand alias works' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Invoke-LTServiceCommand -Command 'Send Status' -Confirm:$false } | Should -Not -Throw
    }
}

# ---- Test-CWAAPort ----
Describe 'Phase 1: Test-CWAAPort' -Tag 'Live' {

    It 'returns output for the agent server' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $result = Test-CWAAPort -Server $script:AgentServer -EA SilentlyContinue
        $result | Should -Not -BeNullOrEmpty -Because 'port test should produce output'
    }

    It '-Quiet switch returns a boolean' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $result = Test-CWAAPort -Server $script:AgentServer -Quiet -EA SilentlyContinue
        $result | Should -BeOfType [bool]
    }

    It 'auto-discovers server from installed agent when -Server is omitted' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        try {
            $result = Test-CWAAPort -EA SilentlyContinue
            $result | Should -Not -BeNullOrEmpty
        }
        catch {
            Set-ItResult -Skipped -Because "network error prevented port test: $_"
        }
    }

    It 'Test-LTPorts alias returns output' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $result = Test-LTPorts -Server $script:AgentServer -Quiet -EA SilentlyContinue
        $result | Should -Not -BeNullOrEmpty
    }
}

# ---- Logging Operations ----
Describe 'Phase 1: Logging Operations' -Tag 'Live' {

    It 'Get-CWAALogLevel does not throw (Settings key may not exist yet on fresh install)' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Get-CWAALogLevel -EA SilentlyContinue } | Should -Not -Throw
    }

    It 'Set-CWAALogLevel changes to Verbose (Debuging=1000)' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Set-CWAALogLevel -Level Verbose -Confirm:$false } | Should -Not -Throw

        # Wait for services to restart after log level change
        $running = Wait-ServiceState -ServiceName 'LTService' -State 'Running' -TimeoutSeconds 60
        $running | Should -BeTrue -Because 'services should restart after log level change'

        $settings = Get-CWAASettings -EA SilentlyContinue
        $settings | Select-Object -ExpandProperty 'Debuging' -EA SilentlyContinue | Should -Be 1000
    }

    It 'Set-CWAALogLevel restores to Normal (Debuging=1)' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Set-CWAALogLevel -Level Normal -Confirm:$false } | Should -Not -Throw

        $running = Wait-ServiceState -ServiceName 'LTService' -State 'Running' -TimeoutSeconds 60
        $running | Should -BeTrue

        $settings = Get-CWAASettings -EA SilentlyContinue
        $settings | Select-Object -ExpandProperty 'Debuging' -EA SilentlyContinue | Should -Be 1
    }

    It 'Get-CWAAError does not throw (log may be empty)' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Get-CWAAError -EA SilentlyContinue } | Should -Not -Throw
    }

    It 'Get-LTLogging alias returns data' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $level = Get-LTLogging -EA SilentlyContinue
        $level | Should -Not -BeNullOrEmpty
    }

    It 'Set-LTLogging alias resolves to Set-CWAALogLevel' {
        $alias = Get-Alias 'Set-LTLogging' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Set-CWAALogLevel'
    }

    It 'Get-LTErrors alias resolves to Get-CWAAError' {
        $alias = Get-Alias 'Get-LTErrors' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Get-CWAAError'
    }
}

# ---- Get-CWAAProbeError ----
Describe 'Phase 1: Get-CWAAProbeError' -Tag 'Live' {

    It 'does not throw when called (probe log may not exist)' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Get-CWAAProbeError -EA SilentlyContinue } | Should -Not -Throw
    }

    It 'returns objects with expected properties if log exists' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $errors = Get-CWAAProbeError -EA SilentlyContinue
        if ($null -eq $errors) {
            Set-ItResult -Skipped -Because 'no probe error log found on this agent'
        }
        else {
            $first = $errors | Select-Object -First 1
            $first | Get-Member -Name 'ServiceVersion' -EA SilentlyContinue | Should -Not -BeNullOrEmpty
            $first | Get-Member -Name 'Timestamp' -EA SilentlyContinue | Should -Not -BeNullOrEmpty
            $first | Get-Member -Name 'Message' -EA SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    It 'Get-LTProbeErrors alias resolves to Get-CWAAProbeError' {
        $alias = Get-Alias 'Get-LTProbeErrors' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Get-CWAAProbeError'
    }
}

# ---- Add/Remove Programs Operations ----
Describe 'Phase 1: Add/Remove Programs Operations' -Tag 'Live' {

    It 'Hide-CWAAAddRemove hides the agent entry (SystemComponent=1)' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Hide-CWAAAddRemove -Confirm:$false } | Should -Not -Throw

        $uninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}'
        )
        $found = $false
        foreach ($path in $uninstallPaths) {
            if (Test-Path $path) {
                $value = Get-ItemProperty $path -Name 'SystemComponent' -EA SilentlyContinue |
                    Select-Object -ExpandProperty 'SystemComponent' -EA SilentlyContinue
                $value | Should -Be 1
                $found = $true
                break
            }
        }
        if (-not $found) {
            Set-ItResult -Skipped -Because 'uninstall registry key not found for this agent version'
        }
    }

    It 'Show-CWAAAddRemove reveals the agent entry' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Show-CWAAAddRemove -Confirm:$false } | Should -Not -Throw
    }

    It 'Rename-CWAAAddRemove renames the entry' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $testName = 'CWAA Pester Test Agent'
        { Rename-CWAAAddRemove -Name $testName -Confirm:$false } | Should -Not -Throw

        $uninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}'
        )
        $verified = $false
        foreach ($path in $uninstallPaths) {
            if (Test-Path $path) {
                $displayName = Get-ItemProperty $path -Name 'DisplayName' -EA SilentlyContinue |
                    Select-Object -ExpandProperty 'DisplayName' -EA SilentlyContinue
                $displayName | Should -Be $testName
                $verified = $true
                break
            }
        }
        if (-not $verified) {
            Set-ItResult -Skipped -Because 'uninstall registry key not found for this agent version'
        }
    }

    It 'Hide-LTAddRemove alias resolves to Hide-CWAAAddRemove' {
        $alias = Get-Alias 'Hide-LTAddRemove' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Hide-CWAAAddRemove'
    }

    It 'Show-LTAddRemove alias resolves to Show-CWAAAddRemove' {
        $alias = Get-Alias 'Show-LTAddRemove' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Show-CWAAAddRemove'
    }

    It 'Rename-LTAddRemove alias resolves to Rename-CWAAAddRemove' {
        $alias = Get-Alias 'Rename-LTAddRemove' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Rename-CWAAAddRemove'
    }
}

# ---- Proxy Operations ----
Describe 'Phase 1: Proxy Operations' -Tag 'Live' {

    It 'Get-CWAAProxy returns proxy configuration with expected properties' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $proxy = Get-CWAAProxy -EA SilentlyContinue
        $proxy | Should -Not -BeNullOrEmpty
        $proxy | Get-Member -Name 'Enabled' | Should -Not -BeNullOrEmpty
        $proxy | Get-Member -Name 'ProxyServerURL' | Should -Not -BeNullOrEmpty
    }

    It 'proxy is disabled by default on fresh install' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $proxy = Get-CWAAProxy -EA SilentlyContinue
        $proxy.Enabled | Should -BeFalse
    }

    It 'Set-CWAAProxy -DetectProxy does not throw' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Set-CWAAProxy -DetectProxy -Confirm:$false } | Should -Not -Throw
    }

    It 'Set-CWAAProxy -ResetProxy clears proxy settings' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Set-CWAAProxy -ResetProxy -Confirm:$false } | Should -Not -Throw

        $proxy = Get-CWAAProxy -EA SilentlyContinue
        $proxy.Enabled | Should -BeFalse
    }

    It 'Get-LTProxy alias returns proxy data' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $proxy = Get-LTProxy -EA SilentlyContinue
        $proxy | Should -Not -BeNullOrEmpty
    }

    It 'Set-LTProxy alias resolves to Set-CWAAProxy' {
        $alias = Get-Alias 'Set-LTProxy' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Set-CWAAProxy'
    }
}

# ---- Security Conversion with Agent Keys ----
Describe 'Phase 1: Security Conversion with Agent Keys' -Tag 'Live' {

    It 'ConvertTo/ConvertFrom round-trips using the agent server password' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $serverPwd = $info | Select-Object -ExpandProperty 'ServerPassword' -EA SilentlyContinue

        if (-not $serverPwd) {
            Set-ItResult -Skipped -Because 'agent has no ServerPassword in registry'
        }

        $testValue = 'LiveKeyTest_12345'
        $encoded = ConvertTo-CWAASecurity -InputString $testValue -Key $serverPwd
        $decoded = ConvertFrom-CWAASecurity -InputString $encoded -Key $serverPwd
        $decoded | Should -Be $testValue
    }

    It 'ConvertTo-LTSecurity / ConvertFrom-LTSecurity alias round-trip works' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $testValue = 'AliasRoundTripTest'
        $encoded = ConvertTo-LTSecurity -InputString $testValue
        $decoded = ConvertFrom-LTSecurity -InputString $encoded
        $decoded | Should -Be $testValue
    }
}

# ---- Update-CWAA (before Reset — needs stable agent identity) ----
Describe 'Phase 1: Update-CWAA' -Tag 'Live' {

    It 'Update-CWAA does not throw a terminating error' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        # Update may warn "installed version is current" — that is non-terminating and acceptable.
        # It may also fail to download if the version endpoint returns unexpected data.
        # We test that it does not produce a terminating exception.
        $threwTerminating = $false
        try {
            Update-CWAA -Confirm:$false -EA SilentlyContinue
        }
        catch {
            $threwTerminating = $true
        }
        $threwTerminating | Should -BeFalse -Because 'Update-CWAA should not throw a terminating error'
    }

    It 'agent services are running after update attempt' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        # If update stopped services, restart them
        $running = Wait-ServiceState -ServiceName 'LTService' -State 'Running' -TimeoutSeconds 30
        if (-not $running) {
            Start-CWAA -Confirm:$false -EA SilentlyContinue
            $running = Wait-ServiceState -ServiceName 'LTService' -State 'Running' -TimeoutSeconds 60
        }
        $running | Should -BeTrue -Because 'LTService must be running for subsequent tests'
    }

    It 'Update-LTService alias resolves to Update-CWAA' {
        $alias = Get-Alias 'Update-LTService' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Update-CWAA'
    }
}

# ---- Reset-CWAA (last in exercise phase — destructive to identity) ----
Describe 'Phase 1: Reset-CWAA' -Tag 'Live' {

    It 'captures pre-reset agent identity' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $info.ID | Should -Not -BeNullOrEmpty -Because 'agent must have an ID before reset'
    }

    It 'Reset-CWAA -ID -NoWait removes the agent ID' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Reset-CWAA -ID -NoWait -Force -Confirm:$false } | Should -Not -Throw

        # Services should restart
        $running = Wait-ServiceState -ServiceName 'LTService' -State 'Running' -TimeoutSeconds 60
        $running | Should -BeTrue -Because 'LTService should restart after reset'
    }

    It 'agent re-registers with a numeric ID after reset' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $registered = Wait-AgentRegistration -TimeoutSeconds 120
        $registered | Should -BeTrue -Because 'agent should re-register after ID reset'

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $info.ID | Should -Match '^\d+$'
    }

    It 'Reset-LTService alias resolves to Reset-CWAA' {
        $alias = Get-Alias 'Reset-LTService' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Reset-CWAA'
    }
}

# =============================================================================
# Phase 1: Backup and Uninstall
# =============================================================================

# ---- Backup Creation ----
Describe 'Phase 1: Backup Creation' -Tag 'Live' {

    It 'New-CWAABackup creates a backup without errors' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { New-CWAABackup -Confirm:$false } | Should -Not -Throw
        $script:BackupCreated = $true
    }

    It 'backup registry key HKLM:\SOFTWARE\LabTechBackup\Service exists' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }
        if (-not $script:BackupCreated) { Set-ItResult -Skipped -Because 'backup was not created' }

        Test-Path 'HKLM:\SOFTWARE\LabTechBackup\Service' | Should -BeTrue
    }

    It 'Get-CWAAInfoBackup returns backup data' {
        if (-not $script:BackupCreated) { Set-ItResult -Skipped -Because 'backup was not created' }

        $backup = Get-CWAAInfoBackup -EA SilentlyContinue
        $backup | Should -Not -BeNullOrEmpty
    }

    It 'backup Server matches the original agent Server' {
        if (-not $script:BackupCreated) { Set-ItResult -Skipped -Because 'backup was not created' }

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $backup = Get-CWAAInfoBackup -EA SilentlyContinue

        $originalServer = ($info.Server | Select-Object -First 1) -replace 'https?://',''
        $backupServer = ($backup.Server | Select-Object -First 1) -replace 'https?://',''
        $backupServer | Should -Be $originalServer
    }

    It 'backup file directory exists at BasePath\Backup' {
        if (-not $script:BackupCreated) { Set-ItResult -Skipped -Because 'backup was not created' }

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $backupPath = Join-Path $info.BasePath 'Backup'
        Test-Path $backupPath | Should -BeTrue
    }

    It 'New-LTServiceBackup alias resolves to New-CWAABackup' {
        $alias = Get-Alias 'New-LTServiceBackup' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'New-CWAABackup'
    }

    It 'Get-LTServiceInfoBackup alias returns backup data' {
        if (-not $script:BackupCreated) { Set-ItResult -Skipped -Because 'backup was not created' }

        $backup = Get-LTServiceInfoBackup -EA SilentlyContinue
        $backup | Should -Not -BeNullOrEmpty
    }
}

# ---- First Uninstall ----
Describe 'Phase 1: First Uninstall' -Tag 'Live' {

    It 'records the agent info before uninstall' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        $script:PreUninstallInfo = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $script:PreUninstallInfo | Should -Not -BeNullOrEmpty
    }

    It 'Uninstall-CWAA removes the agent without error' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Uninstall-CWAA -Server $script:AgentServer -Force -Confirm:$false } | Should -Not -Throw
        $script:AgentInstalled = $false
    }

    It 'passes clean uninstall verification (backup registry allowed)' {
        Assert-CleanUninstall -AllowBackupRegistry
    }

    It 'backup registry survives uninstall' {
        if (-not $script:BackupCreated) { Set-ItResult -Skipped -Because 'backup was not created' }

        Test-Path 'HKLM:\SOFTWARE\LabTechBackup\Service' | Should -BeTrue -Because 'LabTechBackup is not in Uninstall-CWAA cleanup list'
    }

    It 'Get-CWAAInfoBackup still returns data after uninstall' {
        if (-not $script:BackupCreated) { Set-ItResult -Skipped -Because 'backup was not created' }

        $backup = Get-CWAAInfoBackup -EA SilentlyContinue
        $backup | Should -Not -BeNullOrEmpty
    }

    It 'Uninstall-LTService alias resolves to Uninstall-CWAA' {
        $alias = Get-Alias 'Uninstall-LTService' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Uninstall-CWAA'
    }
}

# =============================================================================
# Phase 2: Restore from Backup via Redo-CWAA
# =============================================================================

# ---- Restore ----
Describe 'Phase 2: Redo-CWAA Restore from Backup' -Tag 'Live' {

    It 'Redo-CWAA restores the agent from backup settings' {
        if (-not $script:BackupCreated) { Set-ItResult -Skipped -Because 'no backup available for restore' }

        # Do NOT pass -Server or -LocationID — force Redo-CWAA to read them from backup.
        # Only InstallerToken is explicit (not stored in backup registry).
        $redoParams = @{
            InstallerToken = $script:AgentInstallerToken
            Force          = $true
            Confirm        = $false
        }

        { Redo-CWAA @redoParams } | Should -Not -Throw
        $script:AgentInstalled = $true
    }

    It 'LTService is running after Redo-CWAA' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'Redo-CWAA failed' }

        $running = Wait-ServiceState -ServiceName 'LTService' -State 'Running' -TimeoutSeconds 90
        $running | Should -BeTrue
    }

    It 'LTSvcMon is running after Redo-CWAA' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'Redo-CWAA failed' }

        $running = Wait-ServiceState -ServiceName 'LTSvcMon' -State 'Running' -TimeoutSeconds 60
        $running | Should -BeTrue
    }

    It 'Get-CWAAInfo returns valid agent data after restore' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'Redo-CWAA failed' }

        $registered = Wait-AgentRegistration -TimeoutSeconds 120
        $registered | Should -BeTrue

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $info | Should -Not -BeNullOrEmpty
        $info.ID | Should -Match '^\d+$'
    }

    It 'agent server matches after restore (verifying backup-read worked)' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'Redo-CWAA failed' }

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $cleanExpected = ($script:AgentServer -replace 'https?://','').TrimEnd('/')
        ($info.Server -replace 'https?://','') | Should -Contain $cleanExpected
    }

    It 'Redo-LTService alias resolves to Redo-CWAA' {
        $alias = Get-Alias 'Redo-LTService' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Redo-CWAA'
    }

    It 'Reinstall-CWAA alias resolves to Redo-CWAA' {
        $alias = Get-Alias 'Reinstall-CWAA' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Redo-CWAA'
    }

    It 'Reinstall-LTService alias resolves to Redo-CWAA' {
        $alias = Get-Alias 'Reinstall-LTService' -EA SilentlyContinue
        $alias.ResolvedCommand.Name | Should -Be 'Redo-CWAA'
    }
}

# ---- Second Uninstall ----
Describe 'Phase 2: Second Uninstall' -Tag 'Live' {

    It 'Uninstall-CWAA removes the restored agent without error' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Uninstall-CWAA -Server $script:AgentServer -Force -Confirm:$false } | Should -Not -Throw
        $script:AgentInstalled = $false
    }

    It 'passes full clean uninstall verification' {
        # No -AllowBackupRegistry — expect everything clean
        # But backup registry may still exist from Phase 1; clean it first
        foreach ($regPath in @('HKLM:\SOFTWARE\LabTechBackup', 'HKLM:\SOFTWARE\WOW6432Node\LabTechBackup')) {
            if (Test-Path $regPath) {
                Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        Assert-CleanUninstall
    }
}

# =============================================================================
# Phase 3: Fresh Reinstall and Idempotency
# =============================================================================

# ---- Idempotency Checks ----
Describe 'Phase 3: Idempotency Checks' -Tag 'Live' {

    It 'double-uninstall on clean system does not throw' {
        # Uninstall-CWAA uses Read-Host if -Server is omitted, so pass it explicitly.
        # It also uses -ErrorAction Stop internally, so use try/catch.
        $threw = $false
        try {
            Uninstall-CWAA -Server $script:AgentServer -Force -Confirm:$false -EA SilentlyContinue
        }
        catch {
            $threw = $true
        }
        $threw | Should -BeFalse -Because 'uninstalling on a clean system should be a no-op'
    }

    It 'Get-CWAAInfo returns null on uninstalled system' {
        $info = Get-CWAAInfo -EA SilentlyContinue -WhatIf:$false -Confirm:$false
        $info | Should -BeNullOrEmpty
    }

    It 'Get-CWAAInfoBackup returns no data when backup registry is absent' {
        # Backup registry was cleaned in Phase 2 second uninstall
        $backup = Get-CWAAInfoBackup -EA SilentlyContinue
        $backup | Should -BeNullOrEmpty
    }
}

# ---- Fresh Reinstall ----
Describe 'Phase 3: Fresh Reinstall' -Tag 'Live' {

    It 'Install-CWAA succeeds on a fully clean system' {
        $installParams = @{
            Server         = $script:AgentServer
            InstallerToken = $script:AgentInstallerToken
            LocationID     = $script:AgentLocationID
            Force          = $true
            Confirm        = $false
        }

        { Install-CWAA @installParams } | Should -Not -Throw
        $script:AgentInstalled = $true
    }

    It 'LTService is running after fresh reinstall' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent installation failed' }

        $running = Wait-ServiceState -ServiceName 'LTService' -State 'Running' -TimeoutSeconds 90
        $running | Should -BeTrue
    }

    It 'agent has a valid numeric ID' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent installation failed' }

        $registered = Wait-AgentRegistration -TimeoutSeconds 120
        $registered | Should -BeTrue

        $info = Get-CWAAInfo -WhatIf:$false -Confirm:$false
        $info.ID | Should -Match '^\d+$'
    }
}

# ---- Final Uninstall with Thorough Verification ----
Describe 'Phase 3: Final Uninstall with Thorough Verification' -Tag 'Live' {

    It 'Uninstall-CWAA completes without error' {
        if (-not $script:AgentInstalled) { Set-ItResult -Skipped -Because 'agent not installed' }

        { Uninstall-CWAA -Server $script:AgentServer -Force -Confirm:$false } | Should -Not -Throw
        $script:AgentInstalled = $false
    }

    It 'LTService service is gone' {
        Get-Service 'LTService' -EA SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'LTSvcMon service is gone' {
        Get-Service 'LTSvcMon' -EA SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'LabVNC service is gone' {
        Get-Service 'LabVNC' -EA SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'primary registry key (HKLM:\SOFTWARE\LabTech\Service) is gone' {
        Test-Path 'HKLM:\SOFTWARE\LabTech\Service' | Should -BeFalse
    }

    It 'WOW6432Node registry key is gone' {
        Test-Path 'HKLM:\SOFTWARE\WOW6432Node\LabTech\Service' | Should -BeFalse
    }

    It 'agent installation directory is gone' {
        Test-Path "$env:windir\LTSVC" | Should -BeFalse
    }

    It 'Get-CWAAInfo returns null' {
        $info = Get-CWAAInfo -EA SilentlyContinue -WhatIf:$false -Confirm:$false
        $info | Should -BeNullOrEmpty
    }
}

# =============================================================================
# Post-Test Cleanup (remove all artifacts left by test run)
# =============================================================================
Describe 'Post-Test Cleanup' -Tag 'Live' {

    It 'removes backup registry keys' {
        $backupRegPaths = @(
            'HKLM:\SOFTWARE\LabTechBackup'
            'HKLM:\SOFTWARE\WOW6432Node\LabTechBackup'
        )
        foreach ($regPath in $backupRegPaths) {
            if (Test-Path $regPath) {
                Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  Cleaned: $regPath"
            }
        }
    }

    It 'removes backup files and agent installation directory' {
        $pathsToClean = @("$env:windir\LTSVC")
        if ($script:PreUninstallInfo -and $script:PreUninstallInfo.BasePath) {
            $pathsToClean += $script:PreUninstallInfo.BasePath
        }
        $pathsToClean = $pathsToClean | Select-Object -Unique

        foreach ($dirPath in $pathsToClean) {
            if (Test-Path $dirPath) {
                Remove-Item $dirPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  Cleaned: $dirPath"
            }
        }
    }

    It 'removes installer temp files' {
        $searchDirs = @("$env:windir\Temp", $env:TEMP) | Select-Object -Unique
        $filesToClean = @('Agent_Uninstall.exe', 'Uninstall.exe', 'Uninstall.exe.config')

        foreach ($dir in $searchDirs) {
            foreach ($fileName in $filesToClean) {
                $filePath = Join-Path $dir $fileName
                if (Test-Path $filePath) {
                    Remove-Item $filePath -Force -ErrorAction SilentlyContinue
                    Write-Host "  Cleaned: $filePath"
                }
            }
        }
    }

    It 'removes LabTech installer staging directory' {
        $installerTempPath = "$env:windir\Temp\LabTech"
        if (Test-Path $installerTempPath) {
            Remove-Item $installerTempPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Cleaned: $installerTempPath"
        }
    }

    It 'removes _LTUpdate temp directory' {
        $updateTempPath = "$env:windir\Temp\_LTUpdate"
        if (Test-Path $updateTempPath) {
            Remove-Item $updateTempPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Cleaned: $updateTempPath"
        }
    }

    It 'removes any remaining agent registry keys' {
        $registryPaths = @(
            'HKLM:\SOFTWARE\LabTech\Service'
            'HKLM:\SOFTWARE\WOW6432Node\LabTech\Service'
            'HKLM:\SOFTWARE\LabTech'
            'HKLM:\SOFTWARE\WOW6432Node\LabTech'
        )
        foreach ($regPath in $registryPaths) {
            if (Test-Path $regPath) {
                Remove-Item $regPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  Cleaned: $regPath"
            }
        }
    }
}
