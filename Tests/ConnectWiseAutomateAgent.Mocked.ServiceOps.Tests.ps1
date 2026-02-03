#Requires -Module Pester

<#
.SYNOPSIS
    Mocked behavioral tests for service operation functions.

.DESCRIPTION
    Tests Get-CWAAProxy, Restart-CWAA, Stop-CWAA, Start-CWAA, Reset-CWAA,
    and Redo-CWAA using Pester mocks.

    Supports dual-mode testing via $env:CWAA_TEST_LOAD_METHOD.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Mocked.ServiceOps.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# ---

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
