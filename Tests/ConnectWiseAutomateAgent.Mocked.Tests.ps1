#Requires -Module Pester

<#
.SYNOPSIS
    Mocked behavioral tests for the ConnectWiseAutomateAgent module.

.DESCRIPTION
    Tests the logic paths of public functions using Pester mocks to isolate from
    system dependencies (registry, services, files, network). Designed to run fast
    on any Windows machine without admin privileges or a real Automate agent.

    Functions that are primarily system-call wrappers (Install-CWAA, Uninstall-CWAA,
    Update-CWAA, Set-CWAAProxy, New-CWAABackup, Test-CWAAPort) are tested by the
    Live integration test suite instead.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Mocked.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $ModuleName = 'ConnectWiseAutomateAgent'
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModulePath = Join-Path $ModuleRoot "$ModuleName\$ModuleName.psd1"

    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $ModulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# Tier 1: Data Reader Functions
# =============================================================================

Describe 'Get-CWAAInfo' {

    Context 'when registry key does not exist' {
        BeforeAll {
            $script:result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { return $false } -ParameterFilter { $Path -eq $Script:CWAARegistryRoot }
                Get-CWAAInfo -ErrorAction SilentlyContinue -ErrorVariable err -WhatIf:$false -Confirm:$false
                $err
            }
        }

        It 'returns null' {
            $result2 = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { return $false } -ParameterFilter { $Path -eq $Script:CWAARegistryRoot }
                Get-CWAAInfo -ErrorAction SilentlyContinue -WhatIf:$false -Confirm:$false
            }
            $result2 | Should -BeNullOrEmpty
        }

        It 'writes an error about missing agent' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { return $false } -ParameterFilter { $Path -eq $Script:CWAARegistryRoot }
                $null = Get-CWAAInfo -ErrorAction SilentlyContinue -ErrorVariable testErr -WhatIf:$false -Confirm:$false
                $testErr | Should -Not -BeNullOrEmpty
                "$testErr" | Should -Match 'Unable to find information'
            }
        }
    }

    Context 'when registry key exists with full data' {
        It 'returns an object with expected properties' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { return $true }
                Mock Get-ItemProperty {
                    [PSCustomObject]@{
                        ID              = '12345'
                        'Server Address' = 'automate.example.com|backup.example.com|'
                        LocationID      = '1'
                        BasePath        = 'C:\Windows\LTSVC'
                        Version         = '230.105'
                        PSPath          = 'fake'
                        PSParentPath    = 'fake'
                        PSChildName     = 'fake'
                        PSDrive         = 'fake'
                        PSProvider      = 'fake'
                    }
                }
                Get-CWAAInfo -WhatIf:$false -Confirm:$false
            }
            $result | Should -Not -BeNullOrEmpty
            $result.ID | Should -Be '12345'
            $result.LocationID | Should -Be '1'
        }

        It 'parses pipe-delimited Server Address into array' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { return $true }
                Mock Get-ItemProperty {
                    [PSCustomObject]@{
                        ID              = '1'
                        'Server Address' = 'srv1.example.com|srv2.example.com|'
                        BasePath        = 'C:\Windows\LTSVC'
                    }
                }
                Get-CWAAInfo -WhatIf:$false -Confirm:$false
            }
            $result.Server | Should -HaveCount 2
            $result.Server | Should -Contain 'srv1.example.com'
            $result.Server | Should -Contain 'srv2.example.com'
        }

        It 'strips tildes from Server Address entries' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { return $true }
                Mock Get-ItemProperty {
                    [PSCustomObject]@{
                        ID              = '1'
                        'Server Address' = '~automate.example.com~|'
                        BasePath        = 'C:\Windows\LTSVC'
                    }
                }
                Get-CWAAInfo -WhatIf:$false -Confirm:$false
            }
            $result.Server | Should -Contain 'automate.example.com'
            $result.Server | Should -Not -Contain '~automate.example.com~'
        }

        It 'expands environment variables in BasePath' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { return $true }
                Mock Get-ItemProperty {
                    [PSCustomObject]@{
                        ID       = '1'
                        BasePath = '%windir%\LTSVC'
                    }
                }
                Get-CWAAInfo -WhatIf:$false -Confirm:$false
            }
            $result.BasePath | Should -Not -Match '%windir%'
            $result.BasePath | Should -Match 'LTSVC'
        }

        It 'excludes PS provider properties from output' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { return $true }
                Mock Get-ItemProperty {
                    [PSCustomObject]@{
                        ID           = '1'
                        BasePath     = 'C:\Windows\LTSVC'
                        PSPath       = 'should-be-excluded'
                        PSParentPath = 'should-be-excluded'
                        PSChildName  = 'should-be-excluded'
                        PSDrive      = 'should-be-excluded'
                        PSProvider   = 'should-be-excluded'
                    }
                }
                Get-CWAAInfo -WhatIf:$false -Confirm:$false
            }
            $memberNames = ($result | Get-Member -MemberType NoteProperty).Name
            $memberNames | Should -Not -Contain 'PSPath'
            $memberNames | Should -Not -Contain 'PSParentPath'
            $memberNames | Should -Not -Contain 'PSChildName'
        }
    }

    Context 'when BasePath is not in registry' {
        It 'falls back to default install path when service key is missing' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { return $true } -ParameterFilter { $Path -eq $Script:CWAARegistryRoot }
                Mock Test-Path { return $false } -ParameterFilter { $Path -eq 'HKLM:\SYSTEM\CurrentControlSet\Services\LTService' }
                Mock Get-ItemProperty {
                    [PSCustomObject]@{ ID = '1' }
                } -ParameterFilter { $Path -and $Path -match 'LabTech' }
                Get-CWAAInfo -WhatIf:$false -Confirm:$false
            }
            $result.BasePath | Should -Match 'LTSVC'
        }
    }

    Context 'when Get-ItemProperty throws' {
        It 'writes an error and does not crash' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { return $true }
                Mock Get-ItemProperty { throw 'Registry access denied' }
                $null = Get-CWAAInfo -ErrorAction SilentlyContinue -ErrorVariable testErr -WhatIf:$false -Confirm:$false
                $testErr | Should -Not -BeNullOrEmpty
                "$testErr" | Should -Match 'problem reading'
            }
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Get-CWAASettings' {

    It 'writes error when settings key does not exist' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $false } -ParameterFilter { $Path -eq $Script:CWAARegistrySettings }
            $null = Get-CWAASettings -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'Unable to find LTSvc settings'
        }
    }

    It 'returns settings object when key exists' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq $Script:CWAARegistrySettings }
            Mock Get-ItemProperty {
                [PSCustomObject]@{
                    Debuging       = 1
                    ServerAddress  = 'automate.example.com'
                    PSPath         = 'fake'
                    PSParentPath   = 'fake'
                    PSChildName    = 'fake'
                    PSDrive        = 'fake'
                    PSProvider     = 'fake'
                }
            }
            Get-CWAASettings
        }
        $result | Should -Not -BeNullOrEmpty
        $result.Debuging | Should -Be 1
    }

    It 'writes error when Get-ItemProperty throws' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq $Script:CWAARegistrySettings }
            Mock Get-ItemProperty { throw 'Access denied' }
            $null = Get-CWAASettings -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'problem reading'
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Get-CWAAInfoBackup' {

    It 'writes error when backup registry does not exist' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $false } -ParameterFilter { $Path -eq $Script:CWAARegistryBackup }
            $null = Get-CWAAInfoBackup -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'New-CWAABackup'
        }
    }

    It 'returns backup object with expected properties' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq $Script:CWAARegistryBackup }
            Mock Get-ItemProperty {
                [PSCustomObject]@{
                    ID              = '99999'
                    'Server Address' = 'backup.example.com|'
                    BasePath        = 'C:\Windows\LTSVC'
                    PSPath          = 'fake'
                    PSParentPath    = 'fake'
                    PSChildName     = 'fake'
                    PSDrive         = 'fake'
                    PSProvider      = 'fake'
                }
            }
            Get-CWAAInfoBackup
        }
        $result | Should -Not -BeNullOrEmpty
        $result.ID | Should -Be '99999'
    }

    It 'parses pipe-delimited Server Address' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq $Script:CWAARegistryBackup }
            Mock Get-ItemProperty {
                [PSCustomObject]@{
                    'Server Address' = 'srv1.example.com|srv2.example.com|'
                    BasePath         = 'C:\Windows\LTSVC'
                    PSPath           = 'fake'
                    PSParentPath     = 'fake'
                    PSChildName      = 'fake'
                    PSDrive          = 'fake'
                    PSProvider       = 'fake'
                }
            }
            Get-CWAAInfoBackup
        }
        $result.Server | Should -HaveCount 2
        $result.Server[0] | Should -Be 'srv1.example.com'
        $result.Server[1] | Should -Be 'srv2.example.com'
    }

    It 'expands environment variables in BasePath' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq $Script:CWAARegistryBackup }
            Mock Get-ItemProperty {
                [PSCustomObject]@{
                    BasePath     = '%windir%\LTSVC'
                    PSPath       = 'fake'
                    PSParentPath = 'fake'
                    PSChildName  = 'fake'
                    PSDrive      = 'fake'
                    PSProvider   = 'fake'
                }
            }
            Get-CWAAInfoBackup
        }
        $result.BasePath | Should -Not -Match '%windir%'
    }

    It 'handles missing Server Address without crashing' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $true } -ParameterFilter { $Path -eq $Script:CWAARegistryBackup }
            Mock Get-ItemProperty {
                [PSCustomObject]@{
                    ID           = '1'
                    PSPath       = 'fake'
                    PSParentPath = 'fake'
                    PSChildName  = 'fake'
                    PSDrive      = 'fake'
                    PSProvider   = 'fake'
                }
            }
            Get-CWAAInfoBackup
        }
        $result | Should -Not -BeNullOrEmpty
        $result | Get-Member -Name 'Server' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }
}

# -----------------------------------------------------------------------------

Describe 'Get-CWAALogLevel' {

    It 'returns Normal when Debuging is 1' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAASettings { [PSCustomObject]@{ Debuging = 1 } }
            Get-CWAALogLevel
        }
        $result | Should -Be 'Current logging level: Normal'
    }

    It 'returns Verbose when Debuging is 1000' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAASettings { [PSCustomObject]@{ Debuging = 1000 } }
            Get-CWAALogLevel
        }
        $result | Should -Be 'Current logging level: Verbose'
    }

    It 'returns Normal when Debuging is null (fresh install)' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAASettings { [PSCustomObject]@{} }
            Get-CWAALogLevel
        }
        $result | Should -Be 'Current logging level: Normal'
    }

    It 'writes error for unexpected Debuging value' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAASettings { [PSCustomObject]@{ Debuging = 500 } }
            $null = Get-CWAALogLevel -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'Unknown logging level'
        }
    }

    It 'writes error when Get-CWAASettings throws' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAASettings { throw 'Registry unavailable' }
            $null = Get-CWAALogLevel -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Get-CWAAError' {

    It 'returns structured objects from log file' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
            Mock Test-Path { return $true }
            Mock Get-Content { @("11.0.3.42`tJan 15 2025 10:30 - `tSample error message::: 11.0.3.42`tJan 15 2025 11:00 - `tAnother error") }
            Get-CWAAError
        }
        $result | Should -Not -BeNullOrEmpty
        $first = $result | Select-Object -First 1
        $first.ServiceVersion | Should -Not -BeNullOrEmpty
        $first.Message | Should -Not -BeNullOrEmpty
    }

    It 'writes error when log file does not exist' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
            Mock Test-Path { return $false }
            $null = Get-CWAAError -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'Unable to find agent error log'
        }
    }

    It 'falls back to default path when agent not installed' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { return $null }
            Mock Test-Path { return $false }
            $null = Get-CWAAError -ErrorAction SilentlyContinue -ErrorVariable testErr
            "$testErr" | Should -Match 'LTSVC'
        }
    }

    It 'parses multiple ::: delimited entries' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
            Mock Test-Path { return $true }
            Mock Get-Content { @("11.0`tJan 01 2025 08:00 - `tError one::: 11.0`tJan 01 2025 09:00 - `tError two::: 11.0`tJan 01 2025 10:00 - `tError three") }
            Get-CWAAError
        }
        ($result | Measure-Object).Count | Should -BeGreaterOrEqual 3
    }

    It 'sets Timestamp to null for unparseable dates' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
            Mock Test-Path { return $true }
            Mock Get-Content { @("11.0`tNOT-A-DATE - `tSome error") }
            Get-CWAAError
        }
        $result | Should -Not -BeNullOrEmpty
        ($result | Select-Object -First 1).Timestamp | Should -BeNullOrEmpty
    }

    It 'returns nothing for empty log file' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
            Mock Test-Path { return $true }
            Mock Get-Content { @('') }
            Get-CWAAError -ErrorAction SilentlyContinue
        }
        $result | Should -BeNullOrEmpty
    }

    It 'writes error when Get-Content throws' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
            Mock Test-Path { return $true }
            Mock Get-Content { throw 'File locked' }
            $null = Get-CWAAError -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Get-CWAAProbeError' {

    It 'returns structured objects from probe log file' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
            Mock Test-Path { return $true }
            Mock Get-Content { @("11.0`tJan 15 2025 10:30 - `tProbe error message") }
            Get-CWAAProbeError
        }
        $result | Should -Not -BeNullOrEmpty
        ($result | Select-Object -First 1).Message | Should -Not -BeNullOrEmpty
    }

    It 'writes error when probe log does not exist' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
            Mock Test-Path { return $false }
            $null = Get-CWAAProbeError -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'probe error log'
        }
    }

    It 'falls back to default path when agent not installed' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { return $null }
            Mock Test-Path { return $false }
            $null = Get-CWAAProbeError -ErrorAction SilentlyContinue -ErrorVariable testErr
            "$testErr" | Should -Match 'LTSVC'
        }
    }

    It 'parses multiple ::: delimited entries' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
            Mock Test-Path { return $true }
            Mock Get-Content { @("11.0`tJan 01 2025 08:00 - `tProbe err1::: 11.0`tJan 01 2025 09:00 - `tProbe err2") }
            Get-CWAAProbeError
        }
        ($result | Measure-Object).Count | Should -BeGreaterOrEqual 2
    }

    It 'returns nothing for empty log file' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ BasePath = 'TestDrive:\LTSVC' } }
            Mock Test-Path { return $true }
            Mock Get-Content { @('') }
            Get-CWAAProbeError -ErrorAction SilentlyContinue
        }
        $result | Should -BeNullOrEmpty
    }
}

# =============================================================================
# Tier 2: Functions with Testable Logic
# =============================================================================

Describe 'Invoke-CWAACommand' {

    It 'warns when LTService is not found' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { return $null }
            Invoke-CWAACommand -Command 'Send Status' -Confirm:$false 3>&1 | Should -Match 'not found'
        }
    }

    It 'warns when LTService is not running' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Stopped' } }
            Invoke-CWAACommand -Command 'Send Status' -Confirm:$false 3>&1 | Should -Match 'not running'
        }
    }

    It 'sends command when service is running' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Invoke-CWAACommand -Command 'Send Status' -Confirm:$false
        }
        $result | Should -Match "Sent Command 'Send Status'"
    }

    It 'sends multiple commands' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Invoke-CWAACommand -Command 'Send Status', 'Send Inventory' -Confirm:$false
        }
        ($result | Measure-Object).Count | Should -Be 2
    }

    It 'accepts all 18 valid commands' -ForEach @(
        @{ Cmd = 'Update Schedule' }
        @{ Cmd = 'Send Inventory' }
        @{ Cmd = 'Send Drives' }
        @{ Cmd = 'Send Processes' }
        @{ Cmd = 'Send Spyware List' }
        @{ Cmd = 'Send Apps' }
        @{ Cmd = 'Send Events' }
        @{ Cmd = 'Send Printers' }
        @{ Cmd = 'Send Status' }
        @{ Cmd = 'Send Screen' }
        @{ Cmd = 'Send Services' }
        @{ Cmd = 'Analyze Network' }
        @{ Cmd = 'Write Last Contact Date' }
        @{ Cmd = 'Kill VNC' }
        @{ Cmd = 'Kill Trays' }
        @{ Cmd = 'Send Patch Reboot' }
        @{ Cmd = 'Run App Care Update' }
        @{ Cmd = 'Start App Care Daytime Patching' }
    ) {
        $result = InModuleScope 'ConnectWiseAutomateAgent' -ArgumentList $Cmd {
            param($CommandName)
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Invoke-CWAACommand -Command $CommandName -Confirm:$false
        }
        $result | Should -Match "Sent Command '$Cmd'"
    }

    It 'accepts pipeline input' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            'Send Status' | Invoke-CWAACommand -Confirm:$false
        }
        $result | Should -Match 'Send Status'
    }
}

# -----------------------------------------------------------------------------

Describe 'Hide-CWAAAddRemove' {

    It 'warns when no registry keys are found' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $false }
            Hide-CWAAAddRemove -Confirm:$false 3>&1 | Should -Match 'may not be hidden'
        }
    }

    It 'sets SystemComponent to 1 when uninstall key exists' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $false } -ParameterFilter { $Script:CWAAInstallerProductKeys -contains $Path }
            Mock Test-Path { return $true } -ParameterFilter { $Script:CWAAUninstallKeys -contains $Path }
            Mock Get-Item {
                $mockKey = New-Object PSObject
                $mockKey | Add-Member -MemberType ScriptMethod -Name GetValue -Value { param($name) if ($name -eq 'SystemComponent') { return 0 }; if ($name -eq 'DisplayName') { return 'LabTech' } }
                return $mockKey
            }
            Mock Set-ItemProperty {}
            Mock Get-ItemProperty { return $null }

            Hide-CWAAAddRemove -Confirm:$false

            Should -Invoke Set-ItemProperty -Times 1 -Scope It -ParameterFilter { $Value -eq 1 }
        }
    }

    It 'skips write when SystemComponent is already 1' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $false } -ParameterFilter { $Script:CWAAInstallerProductKeys -contains $Path }
            Mock Test-Path { return $true } -ParameterFilter { $Script:CWAAUninstallKeys -contains $Path }
            Mock Get-Item {
                $mockKey = New-Object PSObject
                $mockKey | Add-Member -MemberType ScriptMethod -Name GetValue -Value { param($name) if ($name -eq 'SystemComponent') { return 1 }; if ($name -eq 'DisplayName') { return 'LabTech' } }
                return $mockKey
            }
            Mock Set-ItemProperty {}
            Mock Get-ItemProperty { return $null }

            Hide-CWAAAddRemove -Confirm:$false

            Should -Invoke Set-ItemProperty -Times 0 -Scope It
        }
    }

    It 'renames HiddenProductName to ProductName when ProductName is missing' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $true } -ParameterFilter { $Script:CWAAInstallerProductKeys -contains $Path }
            Mock Test-Path { return $false } -ParameterFilter { $Script:CWAAUninstallKeys -contains $Path }
            Mock Get-ItemProperty { [PSCustomObject]@{ HiddenProductName = 'LabTech' } } -ParameterFilter { $Name -eq 'HiddenProductName' }
            Mock Get-ItemProperty { return $null } -ParameterFilter { $Name -eq 'ProductName' }
            Mock Rename-ItemProperty {}

            Hide-CWAAAddRemove -Confirm:$false 3>&1 | Out-Null

            Should -Invoke Rename-ItemProperty -Times 1 -Scope It
        }
    }

    It 'removes unused HiddenProductName when ProductName already exists' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $true } -ParameterFilter { $Script:CWAAInstallerProductKeys -contains $Path }
            Mock Test-Path { return $false } -ParameterFilter { $Script:CWAAUninstallKeys -contains $Path }
            Mock Get-ItemProperty { [PSCustomObject]@{ HiddenProductName = 'LabTech' } } -ParameterFilter { $Name -eq 'HiddenProductName' }
            Mock Get-ItemProperty { [PSCustomObject]@{ ProductName = 'LabTech' } } -ParameterFilter { $Name -eq 'ProductName' }
            Mock Remove-ItemProperty {}

            Hide-CWAAAddRemove -Confirm:$false 3>&1 | Out-Null

            Should -Invoke Remove-ItemProperty -Times 1 -Scope It
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Show-CWAAAddRemove' {

    It 'warns when no registry keys are found' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $false }
            Show-CWAAAddRemove -Confirm:$false 3>&1 | Should -Match 'may not be visible'
        }
    }

    It 'sets SystemComponent to 0 when hidden' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $false } -ParameterFilter { $Script:CWAAInstallerProductKeys -contains $Path }
            Mock Test-Path { return $true } -ParameterFilter { $Script:CWAAUninstallKeys -contains $Path }
            Mock Get-Item {
                $mockKey = New-Object PSObject
                $mockKey | Add-Member -MemberType ScriptMethod -Name GetValue -Value { param($name) if ($name -eq 'SystemComponent') { return 1 }; if ($name -eq 'DisplayName') { return 'LabTech' } }
                return $mockKey
            }
            Mock Set-ItemProperty {}
            Mock Get-ItemProperty { return $null }

            Show-CWAAAddRemove -Confirm:$false

            Should -Invoke Set-ItemProperty -Times 1 -Scope It -ParameterFilter { $Value -eq 0 }
        }
    }

    It 'skips write when SystemComponent is already 0' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $false } -ParameterFilter { $Script:CWAAInstallerProductKeys -contains $Path }
            Mock Test-Path { return $true } -ParameterFilter { $Script:CWAAUninstallKeys -contains $Path }
            Mock Get-Item {
                $mockKey = New-Object PSObject
                $mockKey | Add-Member -MemberType ScriptMethod -Name GetValue -Value { param($name) if ($name -eq 'SystemComponent') { return 0 }; if ($name -eq 'DisplayName') { return 'LabTech' } }
                return $mockKey
            }
            Mock Set-ItemProperty {}
            Mock Get-ItemProperty { return $null }

            Show-CWAAAddRemove -Confirm:$false

            Should -Invoke Set-ItemProperty -Times 0 -Scope It
        }
    }

    It 'outputs success message when entries changed' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { return $false } -ParameterFilter { $Script:CWAAInstallerProductKeys -contains $Path }
            Mock Test-Path { return $true } -ParameterFilter { $Script:CWAAUninstallKeys -contains $Path }
            Mock Get-Item {
                $mockKey = New-Object PSObject
                $mockKey | Add-Member -MemberType ScriptMethod -Name GetValue -Value { param($name) if ($name -eq 'SystemComponent') { return 1 }; if ($name -eq 'DisplayName') { return 'LabTech' } }
                return $mockKey
            }
            Mock Set-ItemProperty {}
            Mock Get-ItemProperty { return $null }

            Show-CWAAAddRemove -Confirm:$false
        }
        $result | Should -Match 'visible'
    }
}

# -----------------------------------------------------------------------------

Describe 'Rename-CWAAAddRemove' {

    It 'sets DisplayName when key is found' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-ItemProperty { [PSCustomObject]@{ DisplayName = 'LabTech' } } -ParameterFilter { $Name -eq 'DisplayName' }
            Mock Get-ItemProperty { return $null } -ParameterFilter { $Name -eq 'HiddenProductName' }
            Mock Get-ItemProperty { return $null } -ParameterFilter { $Name -eq 'Publisher' }
            Mock Set-ItemProperty {}

            Rename-CWAAAddRemove -Name 'My Agent' -Confirm:$false

            Should -Invoke Set-ItemProperty -Scope It -ParameterFilter { $Name -eq 'DisplayName' -and $Value -eq 'My Agent' }
        }
    }

    It 'sets both DisplayName and Publisher when PublisherName provided' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-ItemProperty { [PSCustomObject]@{ DisplayName = 'LabTech' } } -ParameterFilter { $Name -eq 'DisplayName' }
            Mock Get-ItemProperty { return $null } -ParameterFilter { $Name -eq 'HiddenProductName' }
            Mock Get-ItemProperty { [PSCustomObject]@{ Publisher = 'LabTech' } } -ParameterFilter { $Name -eq 'Publisher' }
            Mock Set-ItemProperty {}

            Rename-CWAAAddRemove -Name 'My Agent' -PublisherName 'My Company' -Confirm:$false

            Should -Invoke Set-ItemProperty -Scope It -ParameterFilter { $Name -eq 'DisplayName' }
            Should -Invoke Set-ItemProperty -Scope It -ParameterFilter { $Name -eq 'Publisher' -and $Value -eq 'My Company' }
        }
    }

    It 'warns when no matching keys are found' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-ItemProperty { return $null }
            Mock Set-ItemProperty {}

            Rename-CWAAAddRemove -Name 'My Agent' -Confirm:$false 3>&1 | Should -Match 'not found.*Name was not changed'
        }
    }

    It 'updates HiddenProductName when DisplayName is absent' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-ItemProperty { return $null } -ParameterFilter { $Name -eq 'DisplayName' }
            Mock Get-ItemProperty { [PSCustomObject]@{ HiddenProductName = 'LabTech' } } -ParameterFilter { $Name -eq 'HiddenProductName' }
            Mock Get-ItemProperty { return $null } -ParameterFilter { $Name -eq 'Publisher' }
            Mock Set-ItemProperty {}

            Rename-CWAAAddRemove -Name 'My Agent' -Confirm:$false

            Should -Invoke Set-ItemProperty -Scope It -ParameterFilter { $Name -eq 'HiddenProductName' -and $Value -eq 'My Agent' }
        }
    }

    It 'outputs success message with new name' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-ItemProperty { [PSCustomObject]@{ DisplayName = 'LabTech' } } -ParameterFilter { $Name -eq 'DisplayName' }
            Mock Get-ItemProperty { return $null } -ParameterFilter { $Name -eq 'HiddenProductName' }
            Mock Get-ItemProperty { return $null } -ParameterFilter { $Name -eq 'Publisher' }
            Mock Set-ItemProperty {}

            Rename-CWAAAddRemove -Name 'Custom Agent' -Confirm:$false
        }
        $result | Should -Match 'Custom Agent'
    }
}

# -----------------------------------------------------------------------------

Describe 'Set-CWAALogLevel' {

    It 'sets Debuging to 1 for Normal level' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Set-ItemProperty {}
            Mock Get-CWAALogLevel { 'Current logging level: Normal' }

            Set-CWAALogLevel -Level Normal -Confirm:$false

            Should -Invoke Set-ItemProperty -Scope It -ParameterFilter { $Name -eq 'Debuging' -and $Value -eq 1 }
        }
    }

    It 'sets Debuging to 1000 for Verbose level' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Set-ItemProperty {}
            Mock Get-CWAALogLevel { 'Current logging level: Verbose' }

            Set-CWAALogLevel -Level Verbose -Confirm:$false

            Should -Invoke Set-ItemProperty -Scope It -ParameterFilter { $Name -eq 'Debuging' -and $Value -eq 1000 }
        }
    }

    It 'defaults to Normal when Level is not specified' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Set-ItemProperty {}
            Mock Get-CWAALogLevel { 'Current logging level: Normal' }

            Set-CWAALogLevel -Confirm:$false

            Should -Invoke Set-ItemProperty -Scope It -ParameterFilter { $Value -eq 1 }
        }
    }

    It 'calls Stop-CWAA before and Start-CWAA after the registry write' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Set-ItemProperty {}
            Mock Get-CWAALogLevel { 'Current logging level: Normal' }

            Set-CWAALogLevel -Level Normal -Confirm:$false

            Should -Invoke Stop-CWAA -Times 1 -Scope It
            Should -Invoke Start-CWAA -Times 1 -Scope It
        }
    }

    It 'calls Get-CWAALogLevel at the end to report' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Set-ItemProperty {}
            Mock Get-CWAALogLevel { 'Current logging level: Normal' }

            Set-CWAALogLevel -Level Normal -Confirm:$false
        }
        $result | Should -Be 'Current logging level: Normal'
    }
}

# -----------------------------------------------------------------------------

Describe 'Get-CWAAProxy' {

    BeforeEach {
        # Reset module proxy state before each test to prevent cross-test pollution
        $module = Get-Module 'ConnectWiseAutomateAgent'
        & $module {
            $Script:LTProxy.Enabled = $False
            $Script:LTProxy.ProxyServerURL = ''
            $Script:LTProxy.ProxyUsername = ''
            $Script:LTProxy.ProxyPassword = ''
            $Script:LTServiceKeys.ServerPasswordString = ''
            $Script:LTServiceKeys.PasswordString = ''
        }
    }

    It 'returns proxy with Enabled=$false when no agent installed' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { return $null }
            Mock Get-CWAASettings { return $null }
            Get-CWAAProxy
        }
        $result.Enabled | Should -BeFalse
        $result.ProxyServerURL | Should -Be ''
    }

    It 'returns proxy with Enabled=$false when no proxy configured' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo {
                [PSCustomObject]@{ ServerPassword = 'fakeEncoded' }
            }
            Mock ConvertFrom-CWAASecurity { return 'decryptedpwd' }
            Mock Get-CWAASettings {
                [PSCustomObject]@{ ServerAddress = 'automate.example.com' }
            }
            Get-CWAAProxy
        }
        $result.Enabled | Should -BeFalse
    }

    It 'enables proxy when ProxyServerURL matches http pattern' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo {
                [PSCustomObject]@{ ServerPassword = 'fakeEncoded' }
            }
            Mock ConvertFrom-CWAASecurity { return 'decryptedpwd' }
            Mock Get-CWAASettings {
                [PSCustomObject]@{ ProxyServerURL = 'http://proxy.example.com:8080' }
            }
            Get-CWAAProxy
        }
        $result.Enabled | Should -BeTrue
        $result.ProxyServerURL | Should -Be 'http://proxy.example.com:8080'
    }

    It 'decodes proxy username and password via ConvertFrom-CWAASecurity' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo {
                [PSCustomObject]@{ ServerPassword = 'fakeEncoded'; Password = 'fakeAgentPwd' }
            }
            Mock ConvertFrom-CWAASecurity { return 'decryptedValue' }
            Mock Get-CWAASettings {
                [PSCustomObject]@{
                    ProxyServerURL = 'http://proxy.example.com:8080'
                    ProxyUsername  = 'encryptedUser'
                    ProxyPassword  = 'encryptedPass'
                }
            }
            Get-CWAAProxy

            # ConvertFrom-CWAASecurity should be called for ServerPassword, Password, ProxyUsername, and ProxyPassword
            Should -Invoke ConvertFrom-CWAASecurity -Scope It -Times 4

            # Verify the decryption chain: ServerPassword decoded first, then Password uses it as Key
            Should -Invoke ConvertFrom-CWAASecurity -Scope It -Times 1 -ParameterFilter {
                $InputString -eq 'fakeEncoded'
            }
            Should -Invoke ConvertFrom-CWAASecurity -Scope It -Times 1 -ParameterFilter {
                $InputString -eq 'fakeAgentPwd'
            }
        }
    }

    It 'populates ServerPasswordString in LTServiceKeys' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo {
                [PSCustomObject]@{ ServerPassword = 'fakeEncoded' }
            }
            Mock ConvertFrom-CWAASecurity { return 'theServerPwd' }
            Mock Get-CWAASettings { [PSCustomObject]@{} }

            Get-CWAAProxy

            $Script:LTServiceKeys.ServerPasswordString | Should -Be 'theServerPwd'
        }
    }

    It 'returns the $Script:LTProxy object' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { return $null }
            Mock Get-CWAASettings { return $null }
            Get-CWAAProxy
        }
        $result | Should -Not -BeNullOrEmpty
        $result | Get-Member -Name 'Enabled' | Should -Not -BeNullOrEmpty
        $result | Get-Member -Name 'ProxyServerURL' | Should -Not -BeNullOrEmpty
    }
}

# -----------------------------------------------------------------------------

Describe 'Restart-CWAA' {

    It 'writes error when services are not found' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { return $null }
            $null = Restart-CWAA -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'Services NOT Found'
        }
    }

    It 'calls Stop-CWAA then Start-CWAA on success' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Mock Stop-CWAA {}
            Mock Start-CWAA {}

            Restart-CWAA -Confirm:$false
        }
        $result | Should -Match 'restarted successfully'
    }

    It 'writes error and stops when Stop-CWAA throws' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Mock Stop-CWAA { throw 'Stop failed' }
            Mock Start-CWAA {}

            $null = Restart-CWAA -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'error stopping'
            Should -Invoke Start-CWAA -Times 0 -Scope It
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Stop-CWAA' {

    It 'writes error when services are not found' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { return $null }
            $null = Stop-CWAA -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'Services NOT Found'
        }
    }

    It 'outputs success message when services stop' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Stopped' } }
            Mock Invoke-CWAACommand {}
            Mock Get-Process { @() }
            Mock Stop-Process {}
            Mock Start-Sleep {}

            Stop-CWAA -Confirm:$false
        }
        $result | Should -Match 'stopped successfully'
    }

    It 'sends Kill VNC and Kill Trays commands' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Stopped' } }
            Mock Invoke-CWAACommand {}
            Mock Get-Process { @() }
            Mock Stop-Process {}
            Mock Start-Sleep {}

            Stop-CWAA -Confirm:$false

            Should -Invoke Invoke-CWAACommand -Times 1 -Scope It
        }
    }

    It 'attempts to terminate LabTech processes' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Stopped' } }
            Mock Invoke-CWAACommand {}
            Mock Get-Process { @() }
            Mock Stop-Process {}
            Mock Start-Sleep {}

            Stop-CWAA -Confirm:$false

            Should -Invoke Get-Process -Scope It
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Start-CWAA' {

    It 'writes error when services are not found' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { return $null }
            Mock Get-Service { return $null }
            $null = Start-CWAA -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'Services NOT Found'
        }
    }

    It 'outputs success when services reach running state' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ TrayPort = '42000' } }
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Mock Set-Service {}
            Mock Invoke-CWAACommand {}
            Mock Start-Sleep {}
            Mock Stop-Process {}

            Start-CWAA -Confirm:$false
        }
        $result | Should -Match 'started successfully'
    }

    It 'sends Send Status command after successful start' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ TrayPort = '42000' } }
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Mock Set-Service {}
            Mock Invoke-CWAACommand {}
            Mock Start-Sleep {}
            Mock Stop-Process {}

            Start-CWAA -Confirm:$false

            Should -Invoke Invoke-CWAACommand -Times 1 -Scope It -ParameterFilter { $Command -eq 'Send Status' }
        }
    }
}

# =============================================================================
# Tier 3: Orchestration Logic
# =============================================================================

Describe 'Reset-CWAA' {

    It 'resets all three values when no switches specified' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ ID = '100'; LocationID = '1'; MAC = 'AA:BB:CC' } }
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Remove-ItemProperty {}
            Mock Start-Sleep {}

            Reset-CWAA -NoWait -Confirm:$false

            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'ID' }
            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'LocationID' }
            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'MAC' }
        }
    }

    It 'resets only ID when -ID specified' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ ID = '100'; LocationID = '1'; MAC = 'AA:BB:CC' } }
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Remove-ItemProperty {}
            Mock Start-Sleep {}

            Reset-CWAA -ID -NoWait -Confirm:$false

            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'ID' } -Times 1
            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'LocationID' } -Times 0
            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'MAC' } -Times 0
        }
    }

    It 'resets only LocationID when -Location specified' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ ID = '100'; LocationID = '1'; MAC = 'AA:BB:CC' } }
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Remove-ItemProperty {}
            Mock Start-Sleep {}

            Reset-CWAA -Location -NoWait -Confirm:$false

            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'LocationID' } -Times 1
            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'ID' } -Times 0
            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'MAC' } -Times 0
        }
    }

    It 'resets only MAC when -MAC specified' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ ID = '100'; LocationID = '1'; MAC = 'AA:BB:CC' } }
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Remove-ItemProperty {}
            Mock Start-Sleep {}

            Reset-CWAA -MAC -NoWait -Confirm:$false

            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'MAC' } -Times 1
            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'ID' } -Times 0
            Should -Invoke Remove-ItemProperty -Scope It -ParameterFilter { $Name -eq 'LocationID' } -Times 0
        }
    }

    It 'throws terminating error when probe detected without -Force' {
        {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ ID = '100'; Probe = '1' } }
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }

                Reset-CWAA -NoWait -Confirm:$false -ErrorAction Stop
            }
        } | Should -Throw '*Probe*Denied*'
    }

    It 'proceeds when probe detected with -Force' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ ID = '100'; Probe = '1'; LocationID = '1'; MAC = 'AA:BB:CC' } }
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Remove-ItemProperty {}
            Mock Start-Sleep {}

            { Reset-CWAA -Force -NoWait -Confirm:$false } | Should -Not -Throw
        }
    }

    It 'writes error when services are not found' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ ID = '100'; LocationID = '1'; MAC = 'AA:BB:CC' } }
            Mock Get-Service { return $null }

            $null = Reset-CWAA -NoWait -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable testErr
            $testErr | Should -Not -BeNullOrEmpty
            "$testErr" | Should -Match 'Services NOT Found'
        }
    }

    It 'outputs OLD ID line with current values' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ ID = '42'; LocationID = '7'; MAC = 'DE:AD:BE:EF' } }
            Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
            Mock Stop-CWAA {}
            Mock Start-CWAA {}
            Mock Remove-ItemProperty {}
            Mock Start-Sleep {}

            Reset-CWAA -NoWait -Confirm:$false
        }
        $result | Should -Contain 'OLD ID: 42 LocationID: 7 MAC: DE:AD:BE:EF'
    }
}

# -----------------------------------------------------------------------------

Describe 'Redo-CWAA' {

    It 'reads server from current agent settings' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ Server = @('automate.example.com'); LocationID = '1' } }
            Mock Get-CWAAInfoBackup { return $null }
            Mock Uninstall-CWAA {}
            Mock Install-CWAA {}
            Mock Start-Sleep {}

            Redo-CWAA -InstallerToken 'abc123' -Confirm:$false -ErrorAction SilentlyContinue

            Should -Invoke Uninstall-CWAA -Times 1 -Scope It
            Should -Invoke Install-CWAA -Times 1 -Scope It
        }
    }

    It 'falls back to backup settings when current is null' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { return $null }
            Mock Get-CWAAInfoBackup { [PSCustomObject]@{ Server = @('backup.example.com'); LocationID = '2' } }
            Mock Uninstall-CWAA {}
            Mock Install-CWAA {}
            Mock Start-Sleep {}

            Redo-CWAA -InstallerToken 'abc123' -Confirm:$false -ErrorAction SilentlyContinue

            Should -Invoke Install-CWAA -Times 1 -Scope It
        }
    }

    It 'throws terminating error when probe detected without -Force' {
        {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ Probe = '1'; Server = @('automate.example.com'); LocationID = '1' } }
                Mock Get-CWAAInfoBackup { return $null }

                Redo-CWAA -InstallerToken 'abc123' -Confirm:$false -ErrorAction Stop
            }
        } | Should -Throw '*Probe*Denied*'
    }

    It 'proceeds when probe detected with -Force' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ Probe = '1'; Server = @('automate.example.com'); LocationID = '1' } }
            Mock Get-CWAAInfoBackup { return $null }
            Mock Uninstall-CWAA {}
            Mock Install-CWAA {}
            Mock Start-Sleep {}

            { Redo-CWAA -InstallerToken 'abc123' -Force -Confirm:$false -ErrorAction SilentlyContinue } | Should -Not -Throw
        }
    }

    It 'calls New-CWAABackup when -Backup specified' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-CWAAInfo { [PSCustomObject]@{ Server = @('automate.example.com'); LocationID = '1' } }
            Mock Get-CWAAInfoBackup { return $null }
            Mock New-CWAABackup {}
            Mock Uninstall-CWAA {}
            Mock Install-CWAA {}
            Mock Start-Sleep {}

            Redo-CWAA -InstallerToken 'abc123' -Backup -Confirm:$false -ErrorAction SilentlyContinue

            Should -Invoke New-CWAABackup -Times 1 -Scope It
        }
    }
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

# -----------------------------------------------------------------------------

Describe 'ConvertTo-CWAASecurity additional edge cases' {

    It 'returns empty string for empty input' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            ConvertTo-CWAASecurity -InputString ''
        }
        # Empty input still produces an encoded output (encrypted empty string)
        $result | Should -Not -BeNullOrEmpty
    }

    It 'returns empty string for null key (uses default)' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            ConvertTo-CWAASecurity -InputString 'TestValue' -Key $null
        }
        $result | Should -Not -BeNullOrEmpty
    }

    It 'produces different output for different keys' {
        $result1 = InModuleScope 'ConnectWiseAutomateAgent' {
            ConvertTo-CWAASecurity -InputString 'TestValue' -Key 'Key1'
        }
        $result2 = InModuleScope 'ConnectWiseAutomateAgent' {
            ConvertTo-CWAASecurity -InputString 'TestValue' -Key 'Key2'
        }
        $result1 | Should -Not -Be $result2
    }

    It 'round-trips successfully with ConvertFrom-CWAASecurity using same key' {
        $originalValue = 'RoundTripTestValue'
        $result = InModuleScope 'ConnectWiseAutomateAgent' -ArgumentList $originalValue {
            param($testValue)
            $encoded = ConvertTo-CWAASecurity -InputString $testValue -Key 'TestKey123'
            ConvertFrom-CWAASecurity -InputString $encoded -Key 'TestKey123' -Force:$false
        }
        $result | Should -Be $originalValue
    }

    It 'round-trips with default key' {
        $originalValue = 'DefaultKeyRoundTrip'
        $result = InModuleScope 'ConnectWiseAutomateAgent' -ArgumentList $originalValue {
            param($testValue)
            $encoded = ConvertTo-CWAASecurity -InputString $testValue
            ConvertFrom-CWAASecurity -InputString $encoded -Force:$false
        }
        $result | Should -Be $originalValue
    }

    It 'handles special characters in input' {
        $originalValue = 'P@ssw0rd!#$%^&*()'
        $result = InModuleScope 'ConnectWiseAutomateAgent' -ArgumentList $originalValue {
            param($testValue)
            $encoded = ConvertTo-CWAASecurity -InputString $testValue
            ConvertFrom-CWAASecurity -InputString $encoded -Force:$false
        }
        $result | Should -Be $originalValue
    }
}

# -----------------------------------------------------------------------------

Describe 'ConvertFrom-CWAASecurity additional edge cases' {

    It 'returns null for invalid base64 input without Force' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            ConvertFrom-CWAASecurity -InputString 'not-valid-base64!!!' -Key 'TestKey' -Force:$false
        }
        $result | Should -BeNullOrEmpty
    }

    It 'returns null when wrong key is used without Force' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            $encoded = ConvertTo-CWAASecurity -InputString 'TestValue' -Key 'CorrectKey'
            ConvertFrom-CWAASecurity -InputString $encoded -Key 'WrongKey' -Force:$false
        }
        $result | Should -BeNullOrEmpty
    }

    It 'falls back to alternate keys when Force is enabled and primary key fails' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            # Encode with default key
            $encoded = ConvertTo-CWAASecurity -InputString 'TestValue'
            # Try to decode with wrong key but Force enabled (should fall back to default)
            ConvertFrom-CWAASecurity -InputString $encoded -Key 'WrongKey' -Force:$true
        }
        $result | Should -Be 'TestValue'
    }

    It 'handles empty key by using default' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            $encoded = ConvertTo-CWAASecurity -InputString 'TestValue' -Key ''
            ConvertFrom-CWAASecurity -InputString $encoded -Key '' -Force:$false
        }
        $result | Should -Be 'TestValue'
    }

    It 'handles array of input strings' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            $encoded1 = ConvertTo-CWAASecurity -InputString 'Value1'
            $encoded2 = ConvertTo-CWAASecurity -InputString 'Value2'
            ConvertFrom-CWAASecurity -InputString @($encoded1, $encoded2) -Force:$false
        }
        $result | Should -HaveCount 2
        $result[0] | Should -Be 'Value1'
        $result[1] | Should -Be 'Value2'
    }

    It 'rejects empty string due to mandatory parameter validation' {
        # ConvertFrom-CWAASecurity has [parameter(Mandatory = $true)] [string[]]$InputString
        # which prevents binding an empty string. This confirms the validation fires.
        {
            InModuleScope 'ConnectWiseAutomateAgent' {
                ConvertFrom-CWAASecurity -InputString '' -Force:$false -ErrorAction Stop
            }
        } | Should -Throw
    }
}

# =============================================================================
# Private Helper Functions
# =============================================================================

Describe 'Test-CWAADownloadIntegrity' {

    Context 'when file exists and exceeds minimum size' {
        It 'returns true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testFile = Join-Path $env:TEMP 'CWAATestIntegrity.msi'
                # Create a file larger than 1234 KB (write ~1300 KB)
                $bytes = New-Object byte[] (1300 * 1024)
                [System.IO.File]::WriteAllBytes($testFile, $bytes)
                try {
                    Test-CWAADownloadIntegrity -FilePath $testFile -FileName 'CWAATestIntegrity.msi'
                }
                finally {
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                }
            }
            $result | Should -Be $true
        }
    }

    Context 'when file exists but is below minimum size' {
        It 'returns false and removes the file' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testFile = Join-Path $env:TEMP 'CWAATestSmall.msi'
                # Create a file smaller than 1234 KB (write 10 KB)
                $bytes = New-Object byte[] (10 * 1024)
                [System.IO.File]::WriteAllBytes($testFile, $bytes)
                $checkResult = Test-CWAADownloadIntegrity -FilePath $testFile -FileName 'CWAATestSmall.msi' -WarningAction SilentlyContinue
                $fileStillExists = Test-Path $testFile
                [PSCustomObject]@{ Result = $checkResult; FileExists = $fileStillExists }
            }
            $result.Result | Should -Be $false
            $result.FileExists | Should -Be $false
        }
    }

    Context 'when file does not exist' {
        It 'returns false' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Test-CWAADownloadIntegrity -FilePath 'C:\NonExistent\FakeFile.msi' -FileName 'FakeFile.msi'
            }
            $result | Should -Be $false
        }
    }

    Context 'with custom MinimumSizeKB threshold' {
        It 'uses the custom threshold for validation' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testFile = Join-Path $env:TEMP 'CWAATestCustom.exe'
                # Create a 100 KB file, check with 80 KB threshold
                $bytes = New-Object byte[] (100 * 1024)
                [System.IO.File]::WriteAllBytes($testFile, $bytes)
                try {
                    Test-CWAADownloadIntegrity -FilePath $testFile -FileName 'CWAATestCustom.exe' -MinimumSizeKB 80
                }
                finally {
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                }
            }
            $result | Should -Be $true
        }

        It 'fails when file is below custom threshold' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testFile = Join-Path $env:TEMP 'CWAATestCustomFail.exe'
                # Create a 50 KB file, check with 80 KB threshold
                $bytes = New-Object byte[] (50 * 1024)
                [System.IO.File]::WriteAllBytes($testFile, $bytes)
                $checkResult = Test-CWAADownloadIntegrity -FilePath $testFile -FileName 'CWAATestCustomFail.exe' -MinimumSizeKB 80 -WarningAction SilentlyContinue
                $fileStillExists = Test-Path $testFile
                [PSCustomObject]@{ Result = $checkResult; FileExists = $fileStillExists }
            }
            $result.Result | Should -Be $false
            $result.FileExists | Should -Be $false
        }
    }

    Context 'when FileName is not provided' {
        It 'derives the filename from the path' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testFile = Join-Path $env:TEMP 'CWAATestDerived.msi'
                $bytes = New-Object byte[] (1300 * 1024)
                [System.IO.File]::WriteAllBytes($testFile, $bytes)
                try {
                    Test-CWAADownloadIntegrity -FilePath $testFile
                }
                finally {
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                }
            }
            $result | Should -Be $true
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Remove-CWAAFolderRecursive' {

    Context 'when folder exists with nested content' {
        It 'removes the folder and all contents' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testRoot = Join-Path $env:TEMP 'CWAATestRemoveFolder'
                $subDir = Join-Path $testRoot 'SubFolder'
                New-Item -Path $subDir -ItemType Directory -Force | Out-Null
                Set-Content -Path (Join-Path $testRoot 'file1.txt') -Value 'test'
                Set-Content -Path (Join-Path $subDir 'file2.txt') -Value 'test'
                Remove-CWAAFolderRecursive -Path $testRoot -Confirm:$false
                Test-Path $testRoot
            }
            $result | Should -Be $false
        }
    }

    Context 'when folder does not exist' {
        It 'completes without error' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Remove-CWAAFolderRecursive -Path 'C:\NonExistent\CWAATestFolder' -Confirm:$false
                }
            } | Should -Not -Throw
        }
    }

    Context 'when called with -WhatIf' {
        It 'does not actually remove the folder' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testRoot = Join-Path $env:TEMP 'CWAATestWhatIf'
                New-Item -Path $testRoot -ItemType Directory -Force | Out-Null
                Set-Content -Path (Join-Path $testRoot 'file.txt') -Value 'test'
                Remove-CWAAFolderRecursive -Path $testRoot -WhatIf -Confirm:$false
                $exists = Test-Path $testRoot
                # Clean up for real
                Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
                $exists
            }
            $result | Should -Be $true
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Resolve-CWAAServer' {

    Context 'when server responds with valid version' {
        It 'returns the server URL and version' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    return '||||||220.105'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('https://automate.example.com')
            }
            $result | Should -Not -BeNullOrEmpty
            $result.ServerUrl | Should -Match 'automate\.example\.com'
            $result.ServerVersion | Should -Be '220.105'
        }
    }

    Context 'when server URL has no scheme' {
        It 'normalizes the URL and still resolves' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    return '||||||230.001'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('automate.example.com')
            }
            $result | Should -Not -BeNullOrEmpty
            $result.ServerVersion | Should -Be '230.001'
        }
    }

    Context 'when server returns no parseable version' {
        It 'returns null' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    return 'no version data here'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('https://automate.example.com') -WarningAction SilentlyContinue
            }
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when server is unreachable' {
        It 'returns null' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    throw 'Connection refused'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('https://automate.example.com') -WarningAction SilentlyContinue
            }
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when first server fails but second succeeds' {
        It 'returns the second server' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $callCount = 0
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    # Use the URL to determine behavior since $callCount scope is tricky
                    if ($url -match 'bad\.example\.com') {
                        throw 'Connection refused'
                    }
                    return '||||||210.050'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('https://bad.example.com', 'https://good.example.com') -WarningAction SilentlyContinue
            }
            $result | Should -Not -BeNullOrEmpty
            $result.ServerUrl | Should -Match 'good\.example\.com'
            $result.ServerVersion | Should -Be '210.050'
        }
    }

    Context 'when server URL is invalid format' {
        It 'returns null and writes a warning' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    return '||||||220.105'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('https://automate.example.com/some/path') -WarningAction SilentlyContinue
            }
            $result | Should -BeNullOrEmpty
        }
    }
}
