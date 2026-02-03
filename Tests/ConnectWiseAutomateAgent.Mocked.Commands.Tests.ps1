#Requires -Module Pester

<#
.SYNOPSIS
    Mocked behavioral tests for command and settings functions.

.DESCRIPTION
    Tests Invoke-CWAACommand, Hide-CWAAAddRemove, Show-CWAAAddRemove,
    Rename-CWAAAddRemove, and Set-CWAALogLevel using Pester mocks.

    Supports dual-mode testing via $env:CWAA_TEST_LOAD_METHOD.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Mocked.Commands.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
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
