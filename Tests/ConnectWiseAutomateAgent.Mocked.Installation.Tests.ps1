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
}

# =============================================================================
# Tier 5: Health & Connectivity Functions (Batch B)
# =============================================================================

Describe 'Repair-CWAA' {

    Context 'when agent is healthy' {
        It 'returns ActionTaken=None with success' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
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
    }

    Context 'when agent is offline beyond reinstall threshold' {
        It 'triggers reinstall after failed restart' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CimInstance { @() }
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

    Context 'when task does not exist' {
        It 'creates a new scheduled task and returns Created=$true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY') { throw 'Task not found' }
                    elseif ($args -contains '/DELETE') { return $null }
                    elseif ($args -contains '/CREATE') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                }
                Mock New-CWAABackup {}
                Mock Remove-Item {}
                Mock Write-CWAAEventLog {}

                Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Confirm:$false
            }
            $result.Created | Should -BeTrue
            $result.Updated | Should -BeFalse
            $result.TaskName | Should -Be 'CWAAHealthCheck'
        }
    }

    Context 'when task exists with matching token' {
        It 'skips recreation and returns Created=$false, Updated=$false' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY') {
                        # Return XML that contains the token in the Arguments element
                        return '<Task><Actions><Exec><Arguments>-Command "Repair-CWAA -InstallerToken abc123"</Arguments></Exec></Actions></Task>'
                    }
                }

                Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Confirm:$false
            }
            $result.Created | Should -BeFalse
            $result.Updated | Should -BeFalse
        }
    }

    Context 'when -Force is used with existing task' {
        It 'recreates the task' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY') {
                        return '<Task><Actions><Exec><Arguments>-Command "Repair-CWAA -InstallerToken abc123"</Arguments></Exec></Actions></Task>'
                    }
                    elseif ($args -contains '/DELETE') { return $null }
                    elseif ($args -contains '/CREATE') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                }
                Mock New-CWAABackup {}
                Mock Remove-Item {}
                Mock Write-CWAAEventLog {}

                Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Force -Confirm:$false
            }
            ($result.Created -or $result.Updated) | Should -BeTrue
        }
    }

    Context 'when custom parameters are provided' {
        It 'accepts custom TaskName and IntervalHours' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks {
                    if ($args -contains '/QUERY') { throw 'Task not found' }
                    elseif ($args -contains '/DELETE') { return $null }
                    elseif ($args -contains '/CREATE') { $global:LASTEXITCODE = 0; return 'SUCCESS' }
                }
                Mock New-CWAABackup {}
                Mock Remove-Item {}
                Mock Write-CWAAEventLog {}

                Register-CWAAHealthCheckTask -InstallerToken 'abc123' -TaskName 'MyHealthCheck' -IntervalHours 12 -Confirm:$false
            }
            $result.TaskName | Should -Be 'MyHealthCheck'
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
            $result.TaskName | Should -Be 'CWAAHealthCheck'
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
                # netstat returns no matching output for the port
                $env_windir = $env:windir
                Mock Invoke-Expression { return $null }
                # Mock netstat by ensuring no process is found on the port
                function netstat { return @() }
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
                # Mock netstat to return a line matching the port with a PID
                $Script:MockNetstatOutput = "  TCP    0.0.0.0:42000         0.0.0.0:0              LISTENING       1234"

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
                # Mock reg.exe operations
                $env_windir = $env:windir
                Mock Get-Content { @('[HKEY_LOCAL_MACHINE\SOFTWARE\LabTech]', '"Key"="Value"') }
                Mock Out-File {}
                Mock Write-CWAAEventLog {}

                $result = New-CWAABackup -Confirm:$false -ErrorAction SilentlyContinue

                Should -Invoke New-Item -Scope It
            }
        }
    }
}
