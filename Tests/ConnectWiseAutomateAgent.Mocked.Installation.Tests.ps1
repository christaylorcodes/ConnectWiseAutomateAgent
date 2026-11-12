#Requires -Module Pester

<#
.SYNOPSIS
    Mocked behavioral tests for installation, health, and configuration functions.

.DESCRIPTION
    Tests Install-CWAA, Uninstall-CWAA, Update-CWAA, Repair-CWAA, Test-CWAAHealth,
    Register/Unregister-CWAAHealthCheckTask, Test-CWAAServerConnectivity, Test-CWAAPort,
    Set-CWAAProxy, and New-CWAABackup using Pester mocks.

    Supports dual-mode testing via $env:CWAA_TEST_LOAD_METHOD.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Mocked.Installation.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# Tier 4: Installation Functions (Batch A)
# =============================================================================

Describe 'Install-CWAA' {

    Context 'parameter validation' {
        It 'rejects an invalid server address format' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Install-CWAA -Server 'not a valid server!@#' -LocationID 1 -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw
        }

        It 'rejects InstallerToken with invalid characters' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Install-CWAA -Server 'automate.example.com' -InstallerToken 'INVALID-TOKEN!' -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw
        }
    }

    Context 'when services are already installed' {
        It 'writes a terminating error without -Force' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Mock Initialize-CWAANetworking {}
                    Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                    Install-CWAA -Server 'automate.example.com' -InstallerToken 'abc123' -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw '*already installed*'
        }
    }

    # Note: Tests requiring admin bypass (e.g., download, msiexec) are not feasible
    # in mocked tests because Install-CWAA uses [System.Security.Principal.WindowsIdentity]::GetCurrent()
    # which is a .NET static method that cannot be Pester-mocked. Those paths are covered
    # by the Live integration test suite instead.
    Context 'when not running as administrator' {
        It 'throws Needs to be ran as Administrator when services are not detected' {
            # When no services are found and not running elevated, the admin check fires
            $isAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent() |
                Select-Object -Expand groups -EA 0) -match 'S-1-5-32-544')
            if ($isAdmin) {
                Set-ItResult -Skipped -Because 'Test requires non-admin context'
            }
            else {
                {
                    InModuleScope 'ConnectWiseAutomateAgent' {
                        Mock Initialize-CWAANetworking {}
                        Mock Get-Service { return $null }
                        Install-CWAA -Server 'automate.example.com' -InstallerToken 'abc123' -SkipDotNet -Confirm:$false -ErrorAction Stop
                    }
                } | Should -Throw '*Administrator*'
            }
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Uninstall-CWAA' {

    # Note: Uninstall-CWAA uses [System.Security.Principal.WindowsIdentity]::GetCurrent()
    # which is a .NET static method that cannot be Pester-mocked. Tests that need to get past
    # the admin check are conditioned on actually running elevated, or skipped.

    Context 'when not running as administrator' {
        It 'throws Needs to be ran as Administrator' {
            $isAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent() |
                Select-Object -Expand groups -EA 0) -match 'S-1-5-32-544')
            if ($isAdmin) {
                Set-ItResult -Skipped -Because 'Test requires non-admin context'
            }
            else {
                {
                    InModuleScope 'ConnectWiseAutomateAgent' {
                        Mock Initialize-CWAANetworking {}
                        Mock Get-CWAAInfo { return $null }
                        Uninstall-CWAA -Server 'automate.example.com' -Confirm:$false -ErrorAction Stop
                    }
                } | Should -Throw '*Administrator*'
            }
        }
    }

    Context 'parameter validation' {
        It 'rejects an invalid server address format' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Uninstall-CWAA -Server 'not a valid server!@#' -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw
        }
    }

    Context 'probe detection logic via Redo-CWAA integration' {
        # Since Uninstall-CWAA requires admin, we test probe detection through Redo-CWAA
        # which calls Uninstall-CWAA internally and does its own probe check first.
        It 'Redo-CWAA refuses probe uninstall without -Force (tests same probe logic)' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Mock Get-CWAAInfo { [PSCustomObject]@{ Probe = '1'; Server = @('automate.example.com'); LocationID = '1' } }
                    Mock Get-CWAAInfoBackup { return $null }
                    Redo-CWAA -InstallerToken 'abc123' -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw '*Probe*Denied*'
        }

        It 'Redo-CWAA proceeds with -Force past probe detection' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ Probe = '1'; Server = @('automate.example.com'); LocationID = '1' } }
                Mock Get-CWAAInfoBackup { return $null }
                Mock Uninstall-CWAA {}
                Mock Install-CWAA {}
                Mock Start-Sleep {}

                { Redo-CWAA -InstallerToken 'abc123' -Force -Confirm:$false -ErrorAction SilentlyContinue } | Should -Not -Throw
            }
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Update-CWAA' {

    Context 'when no existing installation is found' {
        It 'writes a terminating error' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Mock Initialize-CWAANetworking {}
                    Mock Get-CWAAInfo { return $null }

                    Update-CWAA -Version '200.100' -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw '*No existing installation*'
        }
    }

    Context 'when installed version is higher than requested' {
        It 'writes a warning and returns' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAAInfo { [PSCustomObject]@{ Version = '220.100'; Server = @('automate.example.com') } }
                Mock Test-Path { return $false }

                # Capture warnings via -WarningVariable. The Process block emits download warnings,
                # then the End block emits the version comparison warning.
                $null = Update-CWAA -Version '200.100' -Confirm:$false -ErrorAction SilentlyContinue -WarningVariable testWarn
                "$testWarn" | Should -Match 'higher than or equal'
            }
        }
    }

    Context 'when installed version equals requested version' {
        It 'writes a warning about equal version' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAAInfo { [PSCustomObject]@{ Version = '200.100'; Server = @('automate.example.com') } }
                Mock Test-Path { return $false }

                $null = Update-CWAA -Version '200.100' -Confirm:$false -ErrorAction SilentlyContinue -WarningVariable testWarn
                "$testWarn" | Should -Match 'higher than or equal'
            }
        }
    }

    Context 'when no -Version is given and no server can supply one' {
        It 'warns that no valid server was detected instead of throwing' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAAInfo { [PSCustomObject]@{ Version = '200.100'; Server = @('automate.example.com') } }
                Mock Resolve-CWAAServer { return $null }
                Mock Test-Path { return $false }

                { $null = Update-CWAA -Confirm:$false -WarningAction SilentlyContinue -WarningVariable testWarn } | Should -Not -Throw
                $null = Update-CWAA -Confirm:$false -WarningAction SilentlyContinue -WarningVariable testWarn
                "$testWarn" | Should -Match 'No valid server was detected'
            }
        }
    }

    Context 'when no -Version is given and the server is too old to offer updates' {
        It 'warns about the server version and never probes a download URL' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAAInfo { [PSCustomObject]@{ Version = '90.100'; Server = @('automate.example.com') } }
                Mock Resolve-CWAAServer { [PSCustomObject]@{ ServerUrl = 'https://automate.example.com'; ServerVersion = '100.100' } }
                Mock Test-Path { return $false }
                Mock Remove-CWAAFolderRecursive {}
                Mock Test-CWAAUrlAvailable { return $true }

                $null = Update-CWAA -Confirm:$false -WarningAction SilentlyContinue -WarningVariable testWarn
                "$testWarn" | Should -Match 'below the minimum for agent updates'
                "$testWarn" | Should -Not -Match 'No valid server was detected'
                Should -Invoke Test-CWAAUrlAvailable -Times 0 -Scope It
            }
        }
    }
}

# =============================================================================
# Tier 5: Health & Connectivity Functions (Batch B)
# =============================================================================

Describe 'Repair-CWAA' {

    Context 'when agent is healthy' {
        It 'returns ActionTaken=None with success' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server              = @('automate.example.com')
                        LastSuccessStatus   = (Get-Date).AddMinutes(-30).ToString()
                        HeartbeatLastSent   = (Get-Date).AddMinutes(-15).ToString()
                        HeartbeatLastReceived = (Get-Date).AddMinutes(-15).ToString()
                    }
                }
                Mock Write-CWAAEventLog {}

                Repair-CWAA -InstallerToken 'abc123' -Confirm:$false
            }
            $result.ActionTaken | Should -Be 'None'
            $result.Success | Should -BeTrue
            $result.Message | Should -Match 'healthy'
        }
    }

    Context 'when agent is offline beyond restart threshold' {
        It 'restarts services and reports recovery' {
            $script:callCount = 0
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                # First call returns old LastSuccessStatus, subsequent calls return recent
                Mock Get-CWAAInfo {
                    $script:callCount++
                    if ($script:callCount -le 1) {
                        [PSCustomObject]@{
                            Server            = @('automate.example.com')
                            LastSuccessStatus = (Get-Date).AddHours(-3).ToString()
                            HeartbeatLastSent = (Get-Date).AddHours(-3).ToString()
                            HeartbeatLastReceived = (Get-Date).AddHours(-3).ToString()
                        }
                    }
                    else {
                        [PSCustomObject]@{
                            Server            = @('automate.example.com')
                            LastSuccessStatus = (Get-Date).AddMinutes(-1).ToString()
                            HeartbeatLastSent = (Get-Date).AddMinutes(-1).ToString()
                            HeartbeatLastReceived = (Get-Date).AddMinutes(-1).ToString()
                        }
                    }
                }
                Mock Test-CWAAServerConnectivity { return $true }
                Mock Restart-CWAA {}
                Mock Start-Sleep {}
                Mock Write-CWAAEventLog {}

                Repair-CWAA -InstallerToken 'abc123' -Confirm:$false
            }
            $result.ActionTaken | Should -Be 'Restart'
            $result.Message | Should -Match 'recovered'
        }

        It 'does not report recovery while the heartbeat is still stale' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                # Check-in is current, heartbeat never catches up
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server                = @('automate.example.com')
                        LastSuccessStatus     = [datetime]::Now.AddMinutes(-1).ToString()
                        HeartbeatLastSent     = [datetime]::Now.AddHours(-3).ToString()
                        HeartbeatLastReceived = [datetime]::Now.AddMinutes(-1).ToString()
                    }
                }
                Mock Get-CWAAInfoBackup { return $null }
                Mock Uninstall-CWAA {}
                Mock Redo-CWAA {}
                Mock Test-CWAAServerConnectivity { return $true }
                Mock Restart-CWAA {}
                Mock Write-CWAAEventLog {}
                # Each mocked sleep moves the clock a minute so the 2-minute wait ends at once.
                # [datetime]::Now, not Get-Date: a mock cannot call the command it replaces.
                $script:repairClockOffsetSeconds = 0
                Mock Start-Sleep { $script:repairClockOffsetSeconds += 60 }
                Mock Get-Date { [datetime]::Now.AddSeconds($script:repairClockOffsetSeconds) }

                Repair-CWAA -InstallerToken 'abc123' -Confirm:$false
            }
            $result.ActionTaken | Should -Be 'Restart'
            $result.Message | Should -Match 'has not recovered yet'
        }

        It 'does not log a restart for a stale heartbeat under -WhatIf' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server                = @('automate.example.com')
                        LastSuccessStatus     = (Get-Date).AddMinutes(-1).ToString()
                        HeartbeatLastSent     = (Get-Date).AddHours(-3).ToString()
                        HeartbeatLastReceived = (Get-Date).AddMinutes(-1).ToString()
                    }
                }
                Mock Get-CWAAInfoBackup { return $null }
                Mock Uninstall-CWAA {}
                Mock Redo-CWAA {}
                Mock Test-CWAAServerConnectivity { return $true }
                Mock Restart-CWAA {}
                Mock Start-Sleep {}
                Mock Write-CWAAEventLog {}

                $result = Repair-CWAA -InstallerToken 'abc123' -WhatIf

                $result.ActionTaken | Should -Be 'None'
                $result.Message | Should -Match 'Services were not restarted'
                Should -Invoke Restart-CWAA -Times 0 -Scope It
                Should -Invoke Write-CWAAEventLog -Times 0 -Scope It -ParameterFilter { $Message -match 'Services restarted' }
            }
        }
    }

    Context 'when another repair is already running' {
        It 'terminates duplicates under either host and either command name, and nothing else' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance {
                    [PSCustomObject]@{ Name = 'powershell.exe'; ProcessId = 111111; CommandLine = 'powershell.exe -Command Repair-CWAA' }
                    [PSCustomObject]@{ Name = 'pwsh.exe'; ProcessId = 222222; CommandLine = 'pwsh.exe -Command Repair-LTService' }
                    [PSCustomObject]@{ Name = 'pwsh.exe'; ProcessId = 333333; CommandLine = 'pwsh.exe -File Unrelated.ps1' }
                    [PSCustomObject]@{ Name = 'notepad.exe'; ProcessId = 444444; CommandLine = 'notepad.exe Repair-CWAA.txt' }
                }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server                = @('automate.example.com')
                        LastSuccessStatus     = (Get-Date).AddMinutes(-5).ToString()
                        HeartbeatLastSent     = (Get-Date).AddMinutes(-5).ToString()
                        HeartbeatLastReceived = (Get-Date).AddMinutes(-5).ToString()
                    }
                }
                Mock Write-CWAAEventLog {}

                $null = Repair-CWAA -InstallerToken 'abc123' -Confirm:$false

                Should -Invoke Stop-Process -Times 1 -Exactly -Scope It -ParameterFilter { $Id -eq 111111 }
                Should -Invoke Stop-Process -Times 1 -Exactly -Scope It -ParameterFilter { $Id -eq 222222 }
                Should -Invoke Stop-Process -Times 2 -Exactly -Scope It
            }
        }

        It 'never terminates the processes that launched it' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                # This process was started by 555555, which was started by 666666; both carry the command text.
                Mock Get-CimInstance {
                    [PSCustomObject]@{ Name = 'pwsh.exe'; ProcessId = $PID; ParentProcessId = 555555; CommandLine = 'pwsh.exe -Command Repair-CWAA' }
                    [PSCustomObject]@{ Name = 'powershell.exe'; ProcessId = 555555; ParentProcessId = 666666; CommandLine = 'powershell.exe -Command "pwsh -Command Repair-CWAA"' }
                    [PSCustomObject]@{ Name = 'pwsh.exe'; ProcessId = 666666; ParentProcessId = 4; CommandLine = 'pwsh.exe -File Wrapper.ps1 Repair-LTService' }
                    [PSCustomObject]@{ Name = 'powershell.exe'; ProcessId = 777777; ParentProcessId = 4; CommandLine = 'powershell.exe -Command Repair-CWAA' }
                }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server                = @('automate.example.com')
                        LastSuccessStatus     = (Get-Date).AddMinutes(-5).ToString()
                        HeartbeatLastSent     = (Get-Date).AddMinutes(-5).ToString()
                        HeartbeatLastReceived = (Get-Date).AddMinutes(-5).ToString()
                    }
                }
                Mock Write-CWAAEventLog {}

                $null = Repair-CWAA -InstallerToken 'abc123' -Confirm:$false

                Should -Invoke Stop-Process -Times 1 -Exactly -Scope It -ParameterFilter { $Id -eq 777777 }
                Should -Invoke Stop-Process -Times 1 -Exactly -Scope It
            }
        }
    }

    Context 'when agent is offline beyond reinstall threshold' {
        It 'triggers reinstall after failed restart' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                # Return old date consistently. The wait loop calls Get-CWAAInfo
                # for up to 2 minutes. To prevent spinning for 120s, mock Get-Date
                # to jump past the 2-minute window after initial threshold calculations.
                $Script:RepairDateCallCount = 0
                Mock Get-Date {
                    $Script:RepairDateCallCount++
                    if ($Script:RepairDateCallCount -le 4) {
                        return [datetime]::Now
                    }
                    else {
                        return [datetime]::Now.AddMinutes(5)
                    }
                }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server            = @('automate.example.com')
                        LastSuccessStatus = [datetime]::Now.AddDays(-10).ToString()
                        HeartbeatLastSent = [datetime]::Now.AddDays(-10).ToString()
                        HeartbeatLastReceived = [datetime]::Now.AddDays(-10).ToString()
                    }
                }
                Mock Test-CWAAServerConnectivity { return $true }
                Mock Restart-CWAA {}
                Mock Start-Sleep {}
                Mock Redo-CWAA {}
                Mock Clear-CWAAInstallerArtifacts {}
                Mock Write-CWAAEventLog {}

                Repair-CWAA -InstallerToken 'abc123' -Confirm:$false
            }
            $result.ActionTaken | Should -Be 'Reinstall'
        }
    }

    Context 'when agent is not installed' {
        It 'attempts a fresh install with provided parameters' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { return $null }
                Mock Redo-CWAA {}
                Mock Clear-CWAAInstallerArtifacts {}
                Mock Write-CWAAEventLog {}

                Repair-CWAA -Server 'automate.example.com' -LocationID 42 -InstallerToken 'abc123' -Confirm:$false
            }
            $result.ActionTaken | Should -Be 'Install'
            $result.Message | Should -Match 'Fresh agent install'
        }

        It 'reports error when no install settings are available' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { return $null }
                Mock Get-CWAAInfo { throw 'Not installed' }
                Mock Get-CWAAInfoBackup { return $null }
                Mock Write-CWAAEventLog {}

                Repair-CWAA -InstallerToken 'abc123' -Confirm:$false -ErrorAction SilentlyContinue
            }
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'Unable to find install settings'
        }
    }

    Context 'when server is not reachable' {
        It 'returns error about unreachable server' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server            = @('automate.example.com')
                        LastSuccessStatus = (Get-Date).AddHours(-3).ToString()
                        HeartbeatLastSent = (Get-Date).AddHours(-3).ToString()
                        HeartbeatLastReceived = (Get-Date).AddHours(-3).ToString()
                    }
                }
                Mock Test-CWAAServerConnectivity { return $false }
                Mock Write-CWAAEventLog {}

                Repair-CWAA -InstallerToken 'abc123' -Confirm:$false -ErrorAction SilentlyContinue
            }
            $result.Success | Should -BeFalse
            $result.Message | Should -Match 'not reachable'
        }
    }

    Context 'when agent points to wrong server' {
        It 'reinstalls with the correct server' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server            = @('wrong.example.com')
                        LastSuccessStatus = (Get-Date).AddMinutes(-30).ToString()
                        HeartbeatLastSent = (Get-Date).AddMinutes(-15).ToString()
                    }
                }
                Mock Redo-CWAA {}
                Mock Clear-CWAAInstallerArtifacts {}
                Mock Write-CWAAEventLog {}

                Repair-CWAA -Server 'correct.example.com' -LocationID 42 -InstallerToken 'abc123' -Confirm:$false
            }
            $result.ActionTaken | Should -Be 'Reinstall'
            $result.Message | Should -Match 'correct server'
        }
    }

    Context 'WMI dependency service' {
        It 'ensures the dependency service before remediation' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
                Mock Confirm-CWAADependencyService {}
                Mock Stop-Process {}
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server              = @('automate.example.com')
                        LastSuccessStatus   = (Get-Date).AddMinutes(-30).ToString()
                        HeartbeatLastSent   = (Get-Date).AddMinutes(-15).ToString()
                        HeartbeatLastReceived = (Get-Date).AddMinutes(-15).ToString()
                    }
                }
                Mock Write-CWAAEventLog {}

                Repair-CWAA -InstallerToken 'abc123' -Confirm:$false

                Should -Invoke Confirm-CWAADependencyService -Scope It -Times 1
            }
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Test-CWAAHealth' {

    Context 'when agent is fully healthy' {
        It 'returns a health object with Healthy=$true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    param($Name)
                    [PSCustomObject]@{ Name = $Name; Status = 'Running' }
                }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server              = @('automate.example.com')
                        LastSuccessStatus   = (Get-Date).AddMinutes(-30).ToString()
                        HeartbeatLastSent   = (Get-Date).AddMinutes(-15).ToString()
                    }
                }

                Test-CWAAHealth
            }
            $result.AgentInstalled | Should -BeTrue
            $result.ServicesRunning | Should -BeTrue
            $result.Healthy | Should -BeTrue
            $result.LastContact | Should -Not -BeNullOrEmpty
        }

        It 'returns correct object structure with all expected properties' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    param($Name)
                    [PSCustomObject]@{ Name = $Name; Status = 'Running' }
                }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server              = @('automate.example.com')
                        LastSuccessStatus   = (Get-Date).AddMinutes(-30).ToString()
                        HeartbeatLastSent   = (Get-Date).AddMinutes(-15).ToString()
                    }
                }

                Test-CWAAHealth
            }
            $memberNames = ($result | Get-Member -MemberType NoteProperty).Name
            $memberNames | Should -Contain 'AgentInstalled'
            $memberNames | Should -Contain 'ServicesRunning'
            $memberNames | Should -Contain 'LastContact'
            $memberNames | Should -Contain 'LastHeartbeat'
            $memberNames | Should -Contain 'ServerAddress'
            $memberNames | Should -Contain 'ServerMatch'
            $memberNames | Should -Contain 'ServerReachable'
            $memberNames | Should -Contain 'Healthy'
        }
    }

    Context 'when services are stopped' {
        It 'returns Healthy=$false' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    param($Name)
                    [PSCustomObject]@{ Name = $Name; Status = 'Stopped' }
                }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server            = @('automate.example.com')
                        LastSuccessStatus = (Get-Date).AddMinutes(-30).ToString()
                    }
                }

                Test-CWAAHealth
            }
            $result.AgentInstalled | Should -BeTrue
            $result.ServicesRunning | Should -BeFalse
            $result.Healthy | Should -BeFalse
        }
    }

    Context 'when agent is not installed' {
        It 'returns AgentInstalled=$false and Healthy=$false' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service { return $null }

                Test-CWAAHealth
            }
            $result.AgentInstalled | Should -BeFalse
            $result.ServicesRunning | Should -BeFalse
            $result.Healthy | Should -BeFalse
            $result.LastContact | Should -BeNullOrEmpty
        }
    }

    Context 'when -Server parameter is provided' {
        It 'sets ServerMatch=$true when server matches' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    param($Name)
                    [PSCustomObject]@{ Name = $Name; Status = 'Running' }
                }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server            = @('automate.example.com')
                        LastSuccessStatus = (Get-Date).ToString()
                    }
                }

                Test-CWAAHealth -Server 'automate.example.com'
            }
            $result.ServerMatch | Should -BeTrue
        }

        It 'sets ServerMatch=$false when server does not match' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    param($Name)
                    [PSCustomObject]@{ Name = $Name; Status = 'Running' }
                }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server            = @('other.example.com')
                        LastSuccessStatus = (Get-Date).ToString()
                    }
                }

                Test-CWAAHealth -Server 'automate.example.com'
            }
            $result.ServerMatch | Should -BeFalse
        }
    }

    Context 'when -TestServerConnectivity is used' {
        It 'sets ServerReachable from Test-CWAAServerConnectivity' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    param($Name)
                    [PSCustomObject]@{ Name = $Name; Status = 'Running' }
                }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server            = @('automate.example.com')
                        LastSuccessStatus = (Get-Date).ToString()
                    }
                }
                Mock Test-CWAAServerConnectivity { return $true }

                Test-CWAAHealth -TestServerConnectivity
            }
            $result.ServerReachable | Should -BeTrue
        }
    }

    Context 'when agent info cannot be read' {
        It 'returns Healthy=$false with null timestamps' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    param($Name)
                    [PSCustomObject]@{ Name = $Name; Status = 'Running' }
                }
                Mock Get-CWAAInfo { throw 'Registry read error' }

                Test-CWAAHealth
            }
            $result.AgentInstalled | Should -BeTrue
            $result.LastContact | Should -BeNullOrEmpty
            $result.Healthy | Should -BeFalse
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Register-CWAAHealthCheckTask' {

    BeforeAll {
        # Builds the schtasks /QUERY /XML output for an existing health-check task.
        # Defaults match what Register-CWAAHealthCheckTask builds for -InstallerToken 'abc123'
        # with no Server/LocationID and the default IntervalHours (6 -> PT6H).
        function New-TestTaskXml {
            param(
                [string]$RepairArguments = "-InstallerToken 'abc123'",
                [string]$Interval = 'PT6H'
            )
            "<Task><Actions><Exec><Arguments>-NoProfile -WindowStyle Hidden -Command `"Import-Module ConnectWiseAutomateAgent; Repair-CWAA $RepairArguments`"</Arguments></Exec></Actions><Triggers><TimeTrigger><Repetition><Interval>$Interval</Interval></Repetition></TimeTrigger></Triggers></Task>"
        }
    }

    Context 'when task does not exist' {
        It 'creates a new scheduled task and returns Created=$true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY' -and $args -contains '/XML') { throw 'Task not found' }
                    elseif ($args -contains '/CREATE') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                    elseif ($args -contains '/QUERY') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                }
                Mock New-CWAABackup {}
                Mock Write-CWAAEventLog {}

                Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Confirm:$false
            }
            $result.Created | Should -BeTrue
            $result.Updated | Should -BeFalse
            $result.TaskName | Should -Be 'AAutomate'
        }
    }

    Context 'when task exists with matching configuration' {
        It 'skips recreation and returns Created=$false, Updated=$false' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' -Parameters @{ TaskXml = (New-TestTaskXml) } {
                param($TaskXml)
                Mock schtasks {
                    if ($args -contains '/QUERY') { return $TaskXml }
                }

                Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Confirm:$false
            }
            $result.Created | Should -BeFalse
            $result.Updated | Should -BeFalse
        }
    }

    Context 'when task exists but must be recreated' {
        It 'recreates the task when <Case>' -ForEach @(
            @{
                Case        = 'the token matches but the interval differs (PT12H vs default PT6H)'
                TaskXmlArgs = @{ Interval = 'PT12H' }
                Parameters  = @{ InstallerToken = 'abc123' }
            }
            @{
                Case        = 'token/interval match but the LocationID differs (99 vs 42)'
                TaskXmlArgs = @{ RepairArguments = "-Server 'https://automate.example.com' -LocationID 99 -InstallerToken 'abc123'" }
                Parameters  = @{ Server = 'https://automate.example.com'; LocationID = 42; InstallerToken = 'abc123' }
            }
            @{
                Case        = 'the token differs by a suffix (abc1234 vs abc123)'
                TaskXmlArgs = @{ RepairArguments = "-InstallerToken 'abc1234'" }
                Parameters  = @{ InstallerToken = 'abc123' }
            }
            @{
                Case        = 'the Server differs'
                TaskXmlArgs = @{ RepairArguments = "-Server 'https://old.example.com' -LocationID 42 -InstallerToken 'abc123'" }
                Parameters  = @{ Server = 'https://automate.example.com'; LocationID = 42; InstallerToken = 'abc123' }
            }
            @{
                Case        = '-Force is used with a matching task'
                TaskXmlArgs = @{}
                Parameters  = @{ InstallerToken = 'abc123'; Force = $true }
            }
        ) {
            $result = InModuleScope 'ConnectWiseAutomateAgent' -Parameters @{ TaskXml = (New-TestTaskXml @TaskXmlArgs); TaskParameters = $Parameters } {
                param($TaskXml, $TaskParameters)
                Mock schtasks {
                    if ($args -contains '/QUERY' -and $args -contains '/XML') { return $TaskXml }
                    elseif ($args -contains '/CREATE') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                    elseif ($args -contains '/QUERY') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                }
                Mock New-CWAABackup {}
                Mock Write-CWAAEventLog {}

                Register-CWAAHealthCheckTask @TaskParameters -Confirm:$false

                # Replaced in place: a failed create must not leave the machine without a task
                Should -Invoke schtasks -Times 1 -Exactly -ParameterFilter { $args -contains '/CREATE' -and $args -contains '/F' }
                Should -Not -Invoke schtasks -ParameterFilter { $args -contains '/DELETE' }
            }
            # An existing task was replaced, with or without -Force: an update, not a creation
            $result.Created | Should -BeFalse
            $result.Updated | Should -BeTrue
        }

        It 'reports Created=$false, Updated=$false and logs event <EventId> when <Case>' -ForEach @(
            @{ Case = 'the replacement cannot be created'; CreateExit = 1; VerifyExit = 0; EventId = 4022 }
            @{ Case = 'the replacement is missing on verification'; CreateExit = 0; VerifyExit = 1; EventId = 4023 }
        ) {
            $result = InModuleScope 'ConnectWiseAutomateAgent' -Parameters @{ TaskXml = (New-TestTaskXml -Interval 'PT12H'); CreateExit = $CreateExit; VerifyExit = $VerifyExit; ExpectedEventId = $EventId } {
                param($TaskXml, $CreateExit, $VerifyExit, $ExpectedEventId)
                Mock schtasks {
                    if ($args -contains '/QUERY' -and $args -contains '/XML') { return $TaskXml }
                    elseif ($args -contains '/CREATE') { $global:LASTEXITCODE = $CreateExit; return 'CREATE' }
                    elseif ($args -contains '/QUERY') { $global:LASTEXITCODE = $VerifyExit; return 'VERIFY' }
                }
                Mock New-CWAABackup {}
                Mock Write-CWAAEventLog {}

                Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Confirm:$false -ErrorAction SilentlyContinue

                Should -Invoke Write-CWAAEventLog -Times 1 -Exactly -ParameterFilter { $EventId -eq $ExpectedEventId } -Because 'the failure is logged once'
                Should -Not -Invoke Write-CWAAEventLog -ParameterFilter { $EventId -eq 4020 }
                Should -Not -Invoke schtasks -ParameterFilter { $args -contains '/DELETE' }
            }
            $result.Created | Should -BeFalse
            $result.Updated | Should -BeFalse
        }

        It 'changes nothing and reports Created=$false, Updated=$false with -WhatIf' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' -Parameters @{ TaskXml = (New-TestTaskXml -Interval 'PT12H') } {
                param($TaskXml)
                Mock schtasks { if ($args -contains '/QUERY' -and $args -contains '/XML') { return $TaskXml } }
                Mock New-CWAABackup {}
                Mock Write-CWAAEventLog {}

                Register-CWAAHealthCheckTask -InstallerToken 'abc123' -WhatIf

                Should -Not -Invoke schtasks -ParameterFilter { $args -contains '/CREATE' -or $args -contains '/DELETE' }
                Should -Not -Invoke New-CWAABackup
                Should -Not -Invoke Write-CWAAEventLog
            }
            $result.Created | Should -BeFalse
            $result.Updated | Should -BeFalse
        }
    }

    Context 'when custom parameters are provided' {
        It 'accepts custom TaskName and IntervalHours' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY' -and $args -contains '/XML') { throw 'Task not found' }
                    elseif ($args -contains '/CREATE') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                    elseif ($args -contains '/QUERY') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                }
                Mock New-CWAABackup {}
                Mock Write-CWAAEventLog {}

                Register-CWAAHealthCheckTask -InstallerToken 'abc123' -TaskName 'MyHealthCheck' -IntervalHours 12 -Confirm:$false
            }
            $result.TaskName | Should -Be 'MyHealthCheck'
        }

        It 'registers a SYSTEM task with the requested command and interval, and removes its temporary file' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY' -and $args -contains '/XML') { throw 'Task not found' }
                    elseif ($args -contains '/CREATE') {
                        $script:CWAATestTaskFile = $args[[array]::IndexOf($args, '/XML') + 1]
                        $script:CWAATestTaskXml = [xml](Get-Content -LiteralPath $script:CWAATestTaskFile -Raw)
                        $global:LASTEXITCODE = 0
                        return 'SUCCESS'
                    }
                    elseif ($args -contains '/QUERY') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                }
                Mock New-CWAABackup {}
                Mock Write-CWAAEventLog {}

                $null = Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Server 'https://a.example.com', 'https://b.example.com' -LocationID 42 -IntervalHours 12 -Confirm:$false

                $task = $script:CWAATestTaskXml.Task
                $task.Actions.Exec.Arguments | Should -Be "-NoProfile -WindowStyle Hidden -Command `"Import-Module ConnectWiseAutomateAgent; Repair-CWAA -Server 'https://a.example.com','https://b.example.com' -LocationID 42 -InstallerToken 'abc123'`""
                $task.Triggers.TimeTrigger.Repetition.Interval | Should -Be 'PT12H'
                $task.Triggers.TimeTrigger.RandomDelay | Should -Be 'PT12H'
                $task.Principals.Principal.UserId | Should -Be 'S-1-5-18'
                # The file holds the installer token
                $script:CWAATestTaskFile | Should -Not -Exist
            }
        }
    }

    Context 'when task creation succeeds but post-create verification fails' {
        It 'logs an error event, does not report success, and returns Created=$false' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY' -and $args -contains '/XML') { throw 'Task not found' }
                    elseif ($args -contains '/CREATE') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                    # Task is reported as created by schtasks but is gone by the time we verify it —
                    # simulates AV/policy removing it immediately after creation.
                    elseif ($args -contains '/QUERY') { $global:LASTEXITCODE = 1; return 'ERROR: The system cannot find the file specified.' }
                }
                Mock New-CWAABackup {}
                Mock Write-CWAAEventLog {}

                $taskResult = Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Confirm:$false -ErrorAction SilentlyContinue

                Should -Invoke Write-CWAAEventLog -ParameterFilter { $EventId -eq 4023 }
                Should -Not -Invoke Write-CWAAEventLog -ParameterFilter { $EventId -eq 4020 }

                $taskResult
            }
            $result.Created | Should -BeFalse
        }
    }

    Context 'when task creation fails' {
        It 'writes the failure event log when the error is silenced under $ErrorActionPreference = Stop' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY' -and $args -contains '/XML') { throw 'Task not found' }
                    elseif ($args -contains '/CREATE') { $global:LASTEXITCODE = 1; return 'FAILURE' }
                }
                Mock New-CWAABackup {}
                Mock Write-CWAAEventLog {}

                $ErrorActionPreference = 'Stop'
                Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Confirm:$false -ErrorAction SilentlyContinue

                Should -Invoke Write-CWAAEventLog -ParameterFilter { $EventId -eq 4022 }
            }
        }

        It 'writes the failure event log and then throws for a caller using -ErrorAction Stop' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY' -and $args -contains '/XML') { throw 'Task not found' }
                    elseif ($args -contains '/CREATE') { $global:LASTEXITCODE = 1; return 'FAILURE' }
                }
                Mock New-CWAABackup {}
                Mock Write-CWAAEventLog {}

                { Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Confirm:$false -ErrorAction Stop } |
                    Should -Throw '*Failed to create scheduled task*'

                Should -Invoke Write-CWAAEventLog -Times 1 -Exactly -ParameterFilter { $EventId -eq 4022 }
            }
        }

        It 'still throws under -ErrorAction Stop for a later pipeline record' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $script:CWAATestCreateCalls = 0
                Mock schtasks {
                    if ($args -contains '/QUERY' -and $args -contains '/XML') { throw 'Task not found' }
                    elseif ($args -contains '/CREATE') {
                        $script:CWAATestCreateCalls++
                        # First record succeeds, second fails
                        $global:LASTEXITCODE = [int]($script:CWAATestCreateCalls -gt 1)
                        return 'CREATE'
                    }
                    elseif ($args -contains '/QUERY') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                }
                Mock New-CWAABackup {}
                Mock Write-CWAAEventLog {}

                $records = @(
                    [PSCustomObject]@{ Server = 'https://one.example.com'; LocationID = 1 }
                    [PSCustomObject]@{ Server = 'https://two.example.com'; LocationID = 2 }
                )
                { $records | Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Confirm:$false -ErrorAction Stop } |
                    Should -Throw '*Failed to create scheduled task*'
                $script:CWAATestCreateCalls | Should -Be 2 -Because 'the first record succeeds and the second fails'
            }
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Unregister-CWAAHealthCheckTask' {

    Context 'when task exists' {
        It 'removes the task and returns Removed=$true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY') { $global:LASTEXITCODE = 0; return 'TaskInfo' }
                    elseif ($args -contains '/DELETE') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                }
                Mock Write-CWAAEventLog {}

                Unregister-CWAAHealthCheckTask -Confirm:$false
            }
            $result.Removed | Should -BeTrue
            $result.TaskName | Should -Be 'AAutomate'
        }
    }

    Context 'when task does not exist' {
        It 'writes a warning and returns Removed=$false' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY') { $global:LASTEXITCODE = 1; return $null }
                }

                Unregister-CWAAHealthCheckTask -Confirm:$false 3>&1 | Out-Null
                Unregister-CWAAHealthCheckTask -Confirm:$false
            }
            $result.Removed | Should -BeFalse
        }
    }

    Context 'when custom TaskName is provided' {
        It 'targets the correct task name' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY') { $global:LASTEXITCODE = 0; return 'TaskInfo' }
                    elseif ($args -contains '/DELETE') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                }
                Mock Write-CWAAEventLog {}

                Unregister-CWAAHealthCheckTask -TaskName 'CustomTask' -Confirm:$false
            }
            $result.TaskName | Should -Be 'CustomTask'
            $result.Removed | Should -BeTrue
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Test-CWAAServerConnectivity' {

    Context 'when server responds with valid agent pattern' {
        It 'returns Available=$true with version' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                # The agent.aspx response pattern requires 6+ consecutive pipes before the version
                Mock Invoke-RestMethod { return '||||||220.105' }

                Test-CWAAServerConnectivity -Server 'automate.example.com'
            }
            $result.Available | Should -BeTrue
            $result.Version | Should -Be '220.105'
            $result.ErrorMessage | Should -BeNullOrEmpty
        }
    }

    Context 'when server responds with unexpected format' {
        It 'returns Available=$false with error message' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Invoke-RestMethod { return 'not a valid response' }

                Test-CWAAServerConnectivity -Server 'automate.example.com'
            }
            $result.Available | Should -BeFalse
            $result.ErrorMessage | Should -Match 'unexpected format'
        }
    }

    Context 'when server is unreachable' {
        It 'returns Available=$false with error message' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Invoke-RestMethod { throw 'Connection refused' }

                Test-CWAAServerConnectivity -Server 'automate.example.com'
            }
            $result.Available | Should -BeFalse
            $result.ErrorMessage | Should -Match 'Connection refused'
        }
    }

    Context 'when -Quiet mode is used' {
        It 'returns $true when server is reachable' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Invoke-RestMethod { return '||||||220.105' }

                Test-CWAAServerConnectivity -Server 'automate.example.com' -Quiet
            }
            $result | Should -BeTrue
        }

        It 'returns $false when server is unreachable' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Invoke-RestMethod { throw 'Connection refused' }

                Test-CWAAServerConnectivity -Server 'automate.example.com' -Quiet
            }
            $result | Should -BeFalse
        }
    }

    Context 'when no server is provided' {
        It 'discovers server from agent config' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ Server = @('discovered.example.com') } }
                Mock Get-CWAAInfoBackup { return $null }
                Mock Invoke-RestMethod { return '||||||220.105' }

                Test-CWAAServerConnectivity
            }
            $result.Server | Should -Be 'discovered.example.com'
            $result.Available | Should -BeTrue
        }

        It 'falls back to backup when agent config has no server' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                # Return an object without a Server property so Select-Object -Expand 'Server' returns nothing
                Mock Get-CWAAInfo { [PSCustomObject]@{ ID = '1' } }
                Mock Get-CWAAInfoBackup { [PSCustomObject]@{ Server = @('backup.example.com') } }
                Mock Invoke-RestMethod { return '||||||220.105' }

                Test-CWAAServerConnectivity
            }
            $result.Server | Should -Be 'backup.example.com'
        }

        It 'writes error when no server can be determined' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                # Return objects without a Server property so the function sees no server
                Mock Get-CWAAInfo { [PSCustomObject]@{ ID = '1' } }
                Mock Get-CWAAInfoBackup { [PSCustomObject]@{ ID = '1' } }

                $null = Test-CWAAServerConnectivity -ErrorAction SilentlyContinue -ErrorVariable testErr
                $testErr | Should -Not -BeNullOrEmpty
                "$testErr" | Should -Match 'No server could be determined'
            }
        }
    }
}

# =============================================================================
# Tier 6: Remaining Functions (Batch C)
# =============================================================================

Describe 'Test-CWAAPort' {

    Context 'when TrayPort is available in Quiet mode' {
        It 'returns $true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ TrayPort = '42000' } }
                # No process is using the TrayPort: netstat returns nothing matching it.
                Mock Get-CWAANetstat { @() }
                Test-CWAAPort -TrayPort 42000 -Quiet
            }
            $result | Should -BeTrue
        }
    }

    Context 'when TrayPort is in use in non-Quiet mode' {
        It 'outputs a message about the port being in use' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ TrayPort = '42000'; Server = @('automate.example.com') } }
                Mock Get-CWAAInfoBackup { return $null }
                Mock Get-Process { [PSCustomObject]@{ ProcessName = 'LTSvc'; Id = 1234 } }
                Mock Test-Connection { return $true }
                # netstat reports a process (PID 1234) listening on the TrayPort.
                Mock Get-CWAANetstat { '  TCP    0.0.0.0:42000         0.0.0.0:0              LISTENING       1234' }

                # We need to test the output message
                Test-CWAAPort -TrayPort 42000 -Server 'automate.example.com' 2>&1
            }
            # The function produces port-related output
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Set-CWAAProxy' {

    BeforeAll {
        # -DetectProxy asks the real system proxy about these two hosts, and GetSystemWebProxy is a
        # static call Pester cannot mock. The detection tests skip on a machine that really proxies them.
        # With no proxy, GetProxy returns nothing (PowerShell 7) or the host itself (Windows PowerShell).
        $script:SystemProxyInUse = $false
        foreach ($probeHost in 'automate.example.com', 'www.connectwise.com') {
            $systemProxyUri = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy([uri]"http://$probeHost")
            if ($systemProxyUri -and $systemProxyUri.Authority -ne $probeHost) { $script:SystemProxyInUse = $true }
        }
    }

    BeforeEach {
        # Reset module proxy state and ensure LTServiceNetWebClient exists before each test.
        # Set-CWAAProxy assigns to $Script:LTServiceNetWebClient.Proxy which requires a real
        # object with a Proxy property (WebClient). When Initialize-CWAANetworking is mocked,
        # this object may not be initialized.
        $module = Get-Module 'ConnectWiseAutomateAgent'
        & $module {
            $Script:LTProxy.Enabled = $False
            $Script:LTProxy.ProxyServerURL = ''
            $Script:LTProxy.ProxyUsername = ''
            $Script:LTProxy.ProxyPassword = ''
            if (-not $Script:LTServiceNetWebClient) {
                $Script:LTServiceNetWebClient = New-Object System.Net.WebClient
            }
            if (-not $Script:LTWebProxy) {
                $Script:LTWebProxy = New-Object System.Net.WebProxy
            }
        }
    }

    Context 'when -ResetProxy is used' {
        It 'clears proxy settings' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings { return $null }
                Mock Get-Service { return $null }

                # Set proxy first
                $Script:LTProxy.Enabled = $True
                $Script:LTProxy.ProxyServerURL = 'http://proxy.example.com:8080'

                Set-CWAAProxy -ResetProxy -Confirm:$false

                $Script:LTProxy.Enabled | Should -BeFalse
                $Script:LTProxy.ProxyServerURL | Should -Be ''
            }
        }
    }

    Context 'when -ProxyServerURL is provided' {
        It 'sets the proxy URL and enables proxy' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings { return $null }
                Mock Get-Service { return $null }

                Set-CWAAProxy -ProxyServerURL 'http://proxy.example.com:8080' -Confirm:$false

                $Script:LTProxy.Enabled | Should -BeTrue
                $Script:LTProxy.ProxyServerURL | Should -Be 'http://proxy.example.com:8080'
            }
        }
    }

    Context 'when invalid parameter combinations are used' {
        It 'throws error for ResetProxy with ProxyServerURL' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Mock Initialize-CWAANetworking {}
                    Mock Get-CWAASettings { return $null }

                    Set-CWAAProxy -ResetProxy -ProxyServerURL 'http://proxy.example.com' -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw '*Invalid parameter combination*'
        }

        It 'throws error for DetectProxy with ProxyServerURL' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Mock Initialize-CWAANetworking {}
                    Mock Get-CWAASettings { return $null }

                    Set-CWAAProxy -DetectProxy -ProxyServerURL 'http://proxy.example.com' -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw '*Invalid parameter combination*'
        }
    }

    Context 'when proxy changes require service restart' {
        It 'restarts services when settings change and services are running' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings {
                    [PSCustomObject]@{
                        ProxyServerURL = 'http://old-proxy.example.com:8080'
                        ProxyUsername  = ''
                        ProxyPassword  = ''
                    }
                }
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                Mock Stop-CWAA {}
                Mock Start-CWAA {}
                Mock Set-ItemProperty {}
                Mock ConvertTo-CWAASecurity { return 'encoded' }
                Mock ConvertFrom-CWAASecurity { return '' }
                Mock Write-CWAAEventLog {}

                Set-CWAAProxy -ProxyServerURL 'http://new-proxy.example.com:8080' -Confirm:$false

                Should -Invoke Stop-CWAA -Scope It
                Should -Invoke Start-CWAA -Scope It
            }
        }
    }

    Context 'when proxy credentials are provided' {
        It 'keeps the real password when given -ProxyPassword' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings { return $null }
                Mock Get-Service { return $null }
                $securePassword = ConvertTo-SecureString 'S3cret!Pass' -AsPlainText -Force

                Set-CWAAProxy -ProxyServerURL 'http://proxy.example.com:8080' -ProxyUsername 'proxyuser' -ProxyPassword $securePassword -Confirm:$false

                $Script:LTProxy.ProxyUsername | Should -Be 'proxyuser'
                $Script:LTProxy.ProxyPassword | Should -Be 'S3cret!Pass'
                $Script:LTWebProxy.Credentials.UserName | Should -Be 'proxyuser'
                $Script:LTWebProxy.Credentials.Password | Should -Be 'S3cret!Pass'
            }
        }

        It 'accepts -ProxyCredential and keeps the real password' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings { return $null }
                Mock Get-Service { return $null }
                $credential = New-Object System.Management.Automation.PSCredential ('creduser', (ConvertTo-SecureString 'Cred!Pass9' -AsPlainText -Force))

                Set-CWAAProxy -ProxyServerURL 'http://proxy.example.com:8080' -ProxyCredential $credential -Confirm:$false

                $Script:LTProxy.ProxyUsername | Should -Be 'creduser'
                $Script:LTProxy.ProxyPassword | Should -Be 'Cred!Pass9'
                $Script:LTWebProxy.Credentials.Password | Should -Be 'Cred!Pass9'
            }
        }

        It 'decodes -EncodedProxyUsername and -EncodedProxyPassword with the agent key' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings { return $null }
                Mock Get-Service { return $null }
                $originalAgentKey = $Script:LTServiceKeys.PasswordString
                try {
                    $Script:LTServiceKeys.PasswordString = 'AgentKeyForTest'
                    $encodedUser = ConvertTo-CWAASecurity -InputString 'encuser' -Key 'AgentKeyForTest'
                    $encodedPassword = ConvertTo-SecureString (ConvertTo-CWAASecurity -InputString 'Enc!Pass7' -Key 'AgentKeyForTest') -AsPlainText -Force

                    Set-CWAAProxy -ProxyServerURL 'http://proxy.example.com:8080' -EncodedProxyUsername $encodedUser -EncodedProxyPassword $encodedPassword -Confirm:$false

                    $Script:LTProxy.ProxyUsername | Should -Be 'encuser'
                    $Script:LTProxy.ProxyPassword | Should -Be 'Enc!Pass7'
                }
                finally {
                    $Script:LTServiceKeys.PasswordString = $originalAgentKey
                }
            }
        }

        It 'splits a DOMAIN\user name into domain and user for the proxy credential' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings { return $null }
                Mock Get-Service { return $null }

                Set-CWAAProxy -ProxyServerURL 'http://proxy.example.com:8080' -ProxyUsername 'CORP\svcproxy' -ProxyPassword (ConvertTo-SecureString 'Dom!Pass3' -AsPlainText -Force) -Confirm:$false

                $Script:LTProxy.ProxyUsername | Should -Be 'CORP\svcproxy'
                $Script:LTWebProxy.Credentials.Domain | Should -Be 'CORP'
                $Script:LTWebProxy.Credentials.UserName | Should -Be 'svcproxy'
            }
        }

        It 'fails and leaves the proxy unchanged when encoded credentials cannot be decoded' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings { return $null }
                Mock Get-Service { return $null }
                Mock ConvertFrom-CWAASecurity { return $null }
                Mock Write-CWAAEventLog {}
                $notDecodable = ConvertTo-SecureString 'bm90LWVuY29kZWQ=' -AsPlainText -Force

                { Set-CWAAProxy -ProxyServerURL 'http://proxy.example.com:8080' -EncodedProxyUsername 'bm90LWVuY29kZWQ=' -EncodedProxyPassword $notDecodable -Confirm:$false } |
                    Should -Throw '*could not be decoded*'

                $Script:LTProxy.Enabled | Should -BeFalse
                $Script:LTProxy.ProxyServerURL | Should -Be ''
                Should -Invoke Write-CWAAEventLog -Times 1 -Exactly -Scope It -ParameterFilter { $EventId -eq 3022 }
            }
        }
    }

    Context 'when a proxy URL is set without credentials' {
        It 'clears credentials left over from a previous proxy' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings { return $null }
                Mock Get-Service { return $null }
                $Script:LTProxy.ProxyUsername = 'olduser'
                $Script:LTProxy.ProxyPassword = 'OldPass!1'

                Set-CWAAProxy -ProxyServerURL 'http://other-proxy.example.com:8080' -Confirm:$false

                $Script:LTProxy.ProxyUsername | Should -Be ''
                $Script:LTProxy.ProxyPassword | Should -Be ''
                $Script:LTWebProxy.Credentials | Should -BeNullOrEmpty
            }
        }
    }

    Context 'when -DetectProxy falls back to the WinHTTP proxy' {
        It 'reads the proxy from netsh output written as <Format>' -ForEach @(
            @{ Format = 'one proxy for all protocols'; NetshLine = '    Proxy Server(s) :  proxy.corp.example:8080'; Expected = 'proxy.corp.example:8080' }
            @{ Format = 'per-protocol entries'; NetshLine = '    Proxy Server(s) :  http=proxy.corp.example:8080;https=secure.corp.example:8443'; Expected = 'proxy.corp.example:8080' }
            @{ Format = 'an https entry only'; NetshLine = '    Proxy Server(s) :  https=secure.corp.example:8443'; Expected = 'secure.corp.example:8443' }
            @{ Format = 'a translated label (German)'; NetshLine = '    Proxyserver:  http=proxy.corp.example:8080;https=secure.corp.example:8443'; Expected = 'proxy.corp.example:8080' }
        ) {
            if ($script:SystemProxyInUse) {
                Set-ItResult -Skipped -Because 'this machine routes the test hosts through a system proxy'
                return
            }
            InModuleScope 'ConnectWiseAutomateAgent' -Parameters @{ NetshLine = $NetshLine; Expected = $Expected } {
                param($NetshLine, $Expected)
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings { [PSCustomObject]@{ ServerAddress = 'automate.example.com' } }
                Mock Get-Service { return $null }
                # Mock bodies cannot see the test's local variables, so hand the line over in module scope
                $script:netshProxyLine = $NetshLine
                try {
                    Mock netsh { 'Current WinHTTP proxy settings:', '', $script:netshProxyLine, '    Bypass List     :  (none)' }

                    Set-CWAAProxy -DetectProxy -Confirm:$false

                    $Script:LTProxy.Enabled | Should -BeTrue
                    $Script:LTProxy.ProxyServerURL | Should -Be $Expected
                    # The module's own requests have to go through the detected proxy too
                    $Script:LTWebProxy.Address.Authority | Should -Be $Expected
                }
                finally {
                    Remove-Variable -Name netshProxyLine -Scope Script -ErrorAction SilentlyContinue
                }
            }
        }
    }

    Context 'when -DetectProxy finds no proxy' {
        It 'leaves the proxy disabled instead of using the server as its own proxy' {
            if ($script:SystemProxyInUse) {
                Set-ItResult -Skipped -Because 'this machine routes the test hosts through a system proxy'
                return
            }
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings { [PSCustomObject]@{ ServerAddress = 'automate.example.com' } }
                Mock Get-Service { return $null }
                Mock netsh { 'Current WinHTTP proxy settings:', '', '    Direct access (no proxy server).' }

                Set-CWAAProxy -DetectProxy -Confirm:$false

                $Script:LTProxy.Enabled | Should -BeFalse
                $Script:LTProxy.ProxyServerURL | Should -Be ''
                Should -Invoke netsh -Times 1 -Exactly -Scope It
            }
        }
    }

    Context 'when run with -WhatIf' {
        It 'does not log the proxy-updated event' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Initialize-CWAANetworking {}
                Mock Get-CWAASettings {
                    [PSCustomObject]@{
                        ProxyServerURL = 'http://old-proxy.example.com:8080'
                        ProxyUsername  = ''
                        ProxyPassword  = ''
                    }
                }
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                Mock Stop-CWAA {}
                Mock Start-CWAA {}
                Mock Set-ItemProperty {}
                Mock ConvertFrom-CWAASecurity { return '' }
                Mock Write-CWAAEventLog {}

                Set-CWAAProxy -ProxyServerURL 'http://new-proxy.example.com:8080' -WhatIf

                Should -Invoke Set-ItemProperty -Times 0 -Scope It
                Should -Invoke Write-CWAAEventLog -Times 0 -Scope It -ParameterFilter { $EventId -eq 3020 }
            }
        }
    }

    Context 'when no parameters are provided' {
        It 'writes error about missing parameters' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Mock Initialize-CWAANetworking {}
                    Mock Get-CWAASettings { return $null }

                    Set-CWAAProxy -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw '*parameters missing*'
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'New-CWAABackup' {

    Context 'when agent is not installed' {
        It 'writes terminating error when BasePath is not found' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Mock Get-CWAAInfo { return $null }

                    New-CWAABackup -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw '*Unable to find LTSvc folder path*'
        }
    }

    Context 'when registry key is missing' {
        It 'writes terminating error about missing registry' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
                    Mock Test-Path { return $false }

                    New-CWAABackup -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw '*Unable to find registry*'
        }
    }

    Context 'when agent is properly installed' {
        It 'creates backup directory and copies files' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
                # First call for HKLM registry check, second for agent path
                Mock Test-Path { return $true }
                Mock New-Item {}
                Mock Get-ChildItem { @() }
                Mock Copy-Item {}
                Mock Invoke-CWAARegExe { return 0 }
                Mock Get-Content { @('[HKEY_LOCAL_MACHINE\SOFTWARE\LabTech]', '"Key"="Value"') }
                Mock Out-File {}
                Mock Write-CWAAEventLog {}

                $result = New-CWAABackup -Confirm:$false -ErrorAction SilentlyContinue

                Should -Invoke New-Item -Scope It
            }
        }

        It 'reports success and logs event 3010 when the copy and both reg.exe steps succeed' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
                Mock Test-Path { return $true }
                Mock New-Item {}
                Mock Get-ChildItem { [PSCustomObject]@{ FullName = 'TestDrive:\LTSVC\LTSvc.exe' } }
                Mock Copy-Item {}
                Mock Invoke-CWAARegExe { return 0 }
                Mock Get-Content { @('[HKEY_LOCAL_MACHINE\SOFTWARE\LabTech]', '"Key"="Value"') }
                Mock Out-File {}
                Mock Write-CWAAEventLog {}

                $result = New-CWAABackup -Confirm:$false

                "$result" | Should -Match 'backup has been created'
                Should -Invoke Invoke-CWAARegExe -Times 1 -Exactly -Scope It -ParameterFilter { $Arguments[0] -eq 'export' }
                Should -Invoke Invoke-CWAARegExe -Times 1 -Exactly -Scope It -ParameterFilter { $Arguments[0] -eq 'import' }
                Should -Invoke Write-CWAAEventLog -Times 1 -Exactly -Scope It -ParameterFilter { $EventId -eq 3010 }
            }
        }

        It 'stops before the import and does not report success when reg.exe export fails' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
                Mock Test-Path { return $true }
                Mock New-Item {}
                Mock Get-ChildItem { @() }
                Mock Copy-Item {}
                Mock Invoke-CWAARegExe { return 1 }
                Mock Get-Content { @('[HKEY_LOCAL_MACHINE\SOFTWARE\LabTech]', '"Key"="Value"') }
                Mock Out-File {}
                Mock Write-CWAAEventLog {}

                $result = New-CWAABackup -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable testError

                "$testError" | Should -Match 'reg\.exe export returned exit code 1'
                "$result" | Should -Not -Match 'backup has been created'
                Should -Invoke Invoke-CWAARegExe -Times 0 -Scope It -ParameterFilter { $Arguments[0] -eq 'import' }
                Should -Invoke Out-File -Times 0 -Scope It
                Should -Invoke Write-CWAAEventLog -Times 1 -Exactly -Scope It -ParameterFilter { $EventId -eq 3012 }
                Should -Invoke Write-CWAAEventLog -Times 0 -Scope It -ParameterFilter { $EventId -eq 3010 }
            }
        }

        It 'does not report success when some files could not be copied' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
                Mock Test-Path { return $true }
                Mock New-Item {}
                Mock Get-ChildItem { [PSCustomObject]@{ FullName = 'TestDrive:\LTSVC\LTSvc.exe' } }
                # A locked file is a non-terminating error, as the real Copy-Item reports it
                Mock Copy-Item { Write-Error 'The process cannot access the file because it is being used by another process.' }
                Mock Invoke-CWAARegExe { return 0 }
                Mock Get-Content { @('[HKEY_LOCAL_MACHINE\SOFTWARE\LabTech]', '"Key"="Value"') }
                Mock Out-File {}
                Mock Write-CWAAEventLog {}

                $result = New-CWAABackup -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable testError

                "$testError" | Should -Match 'could not be copied'
                "$result" | Should -Not -Match 'backup has been created'
                Should -Invoke Write-CWAAEventLog -Times 1 -Exactly -Scope It -ParameterFilter { $EventId -eq 3012 -and $Message -match 'could not be copied' }
                Should -Invoke Write-CWAAEventLog -Times 0 -Scope It -ParameterFilter { $EventId -eq 3010 }
            }
        }

        It 'does not report success when the file copy fails' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
                Mock Test-Path { return $true }
                Mock New-Item {}
                Mock Get-ChildItem { throw 'Access to the path is denied.' }
                Mock Copy-Item {}
                Mock Invoke-CWAARegExe { return 0 }
                Mock Get-Content { @('[HKEY_LOCAL_MACHINE\SOFTWARE\LabTech]', '"Key"="Value"') }
                Mock Out-File {}
                Mock Write-CWAAEventLog {}

                $result = New-CWAABackup -Confirm:$false -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

                "$result" | Should -Not -Match 'backup has been created'
                Should -Invoke Write-CWAAEventLog -Times 1 -Exactly -Scope It -ParameterFilter { $EventId -eq 3012 }
                Should -Invoke Write-CWAAEventLog -Times 0 -Scope It -ParameterFilter { $EventId -eq 3010 }
            }
        }

        It 'does not report success under -WhatIf' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
                Mock Test-Path { return $true }
                Mock New-Item {}
                Mock Copy-Item {}
                Mock Write-CWAAEventLog {}

                $result = New-CWAABackup -WhatIf

                "$result" | Should -Not -Match 'backup has been created'
                Should -Invoke Copy-Item -Times 0 -Scope It
                Should -Invoke Write-CWAAEventLog -Times 0 -Scope It
            }
        }
    }
}
