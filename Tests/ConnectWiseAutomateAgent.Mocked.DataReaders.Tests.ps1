#Requires -Module Pester

<#
.SYNOPSIS
    Mocked behavioral tests for data reader functions.

.DESCRIPTION
    Tests Get-CWAAInfo, Get-CWAASettings, Get-CWAAInfoBackup, Get-CWAALogLevel,
    Get-CWAAError, and Get-CWAAProbeError using Pester mocks.

    Supports dual-mode testing via $env:CWAA_TEST_LOAD_METHOD.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Mocked.DataReaders.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
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
