#Requires -Module Pester

<#
.SYNOPSIS
    Mocked behavioral tests for cross-cutting features.

.DESCRIPTION
    Tests pipeline support, PSCredential parameters, module constants,
    Test-CWAAServiceExists, and Assert-CWAANotProbeAgent using Pester mocks.

    Supports dual-mode testing via $env:CWAA_TEST_LOAD_METHOD.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Mocked.CrossCutting.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# Pipeline Support Tests
# =============================================================================

Describe 'Pipeline Support' {

    Context 'ConvertTo-CWAASecurity pipeline input' {

        It 'accepts a single string from pipeline' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                'TestValue' | ConvertTo-CWAASecurity
            }
            $result | Should -Not -BeNullOrEmpty
        }

        It 'accepts multiple strings from pipeline' {
            $results = InModuleScope 'ConnectWiseAutomateAgent' {
                'Value1', 'Value2', 'Value3' | ConvertTo-CWAASecurity
            }
            $results | Should -HaveCount 3
            $results[0] | Should -Not -Be $results[1]
        }

        It 'round-trips through pipeline with ConvertFrom-CWAASecurity' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                'PipelineRoundTrip' | ConvertTo-CWAASecurity | ConvertFrom-CWAASecurity
            }
            $result | Should -Be 'PipelineRoundTrip'
        }

        It 'round-trips multiple values through pipeline' {
            $results = InModuleScope 'ConnectWiseAutomateAgent' {
                'Alpha', 'Bravo', 'Charlie' | ConvertTo-CWAASecurity | ConvertFrom-CWAASecurity
            }
            $results | Should -HaveCount 3
            $results[0] | Should -Be 'Alpha'
            $results[1] | Should -Be 'Bravo'
            $results[2] | Should -Be 'Charlie'
        }
    }

    Context 'Rename-CWAAAddRemove pipeline input' {

        It 'accepts Name from pipeline' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-ItemProperty { [PSCustomObject]@{ DisplayName = 'LabTech' } } -ParameterFilter { $Name -eq 'DisplayName' }
                Mock Get-ItemProperty { return $null } -ParameterFilter { $Name -eq 'HiddenProductName' }
                Mock Get-ItemProperty { return $null } -ParameterFilter { $Name -eq 'Publisher' }
                Mock Set-ItemProperty {}

                'Piped Agent Name' | Rename-CWAAAddRemove -Confirm:$false

                Should -Invoke Set-ItemProperty -Scope It -ParameterFilter { $Name -eq 'DisplayName' -and $Value -eq 'Piped Agent Name' }
            }
        }
    }

    Context 'Repair-CWAA Server ValueFromPipelineByPropertyName' {

        It 'accepts Server and LocationID from piped object' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service { [PSCustomObject]@{ Status = 'Running'; Name = 'LTService' } }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server              = 'https://automate.example.com'
                        LastSuccessStatus   = (Get-Date).ToString()
                        HeartbeatLastSent   = (Get-Date).ToString()
                        HeartbeatLastReceived = (Get-Date).ToString()
                    }
                }
                Mock Write-CWAAEventLog {}
                Mock Get-CimInstance { return @() }

                # Pipe an object with Server and LocationID — bind via ValueFromPipelineByPropertyName
                # InstallerToken is provided explicitly (it wouldn't come from Get-CWAAInfo output)
                $inputObject = [PSCustomObject]@{
                    Server     = 'https://automate.example.com'
                    LocationID = 1
                }
                $result = $inputObject | Repair-CWAA -InstallerToken 'abc123' -Confirm:$false -WarningAction SilentlyContinue
                $result | Should -Not -BeNullOrEmpty
                $result.ActionTaken | Should -Be 'None'
            }
        }
    }

    Context 'Invoke-CWAACommand multiple values from pipeline' {

        It 'processes multiple commands piped as an array' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service { [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' } }
                'Send Inventory', 'Send Apps' | Invoke-CWAACommand -Confirm:$false
            }
            ($result | Measure-Object).Count | Should -Be 2
            $result[0] | Should -Match 'Send Inventory'
            $result[1] | Should -Match 'Send Apps'
        }
    }

    Context 'Set-CWAALogLevel pipeline input' {

        It 'accepts Level from pipeline' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Stop-CWAA {}
                Mock Start-CWAA {}
                Mock Set-ItemProperty {}
                Mock Get-CWAALogLevel { 'Current logging level: Verbose' }

                'Verbose' | Set-CWAALogLevel -Confirm:$false

                Should -Invoke Set-ItemProperty -Scope It -ParameterFilter { $Name -eq 'Debuging' -and $Value -eq 1000 }
            }
        }
    }

    Context 'Test-CWAAServerConnectivity property-based pipeline' {

        It 'accepts Server from piped PSCustomObject' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Invoke-RestMethod { return '||||||220.105' }

                [PSCustomObject]@{ Server = 'automate.example.com' } | Test-CWAAServerConnectivity
            }
            $result.Available | Should -BeTrue
            $result.Version | Should -Be '220.105'
        }
    }

    Context 'Test-CWAAHealth property-based pipeline' {

        It 'accepts Server from piped PSCustomObject' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    param($Name)
                    [PSCustomObject]@{ Name = $Name; Status = 'Running' }
                }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server            = @('automate.example.com')
                        LastSuccessStatus = (Get-Date).AddMinutes(-30).ToString()
                        HeartbeatLastSent = (Get-Date).AddMinutes(-15).ToString()
                    }
                }

                [PSCustomObject]@{ Server = 'automate.example.com' } | Test-CWAAHealth
            }
            $result.AgentInstalled | Should -BeTrue
            $result.Healthy | Should -BeTrue
        }
    }

    Context 'Test-CWAAPort property-based pipeline' {

        It 'accepts Server and TrayPort from piped PSCustomObject' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-CWAAInfo { [PSCustomObject]@{ TrayPort = '42000' } }
                Mock Invoke-Expression { return $null }
                function netstat { return @() }

                [PSCustomObject]@{ Server = 'automate.example.com'; TrayPort = 42000 } | Test-CWAAPort -Quiet
            }
            $result | Should -BeTrue
        }
    }

    Context 'Multi-server array pipeline binding' {

        It 'Test-CWAAHealth accepts Server as string[] from pipeline and matches correctly' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    param($Name)
                    [PSCustomObject]@{ Name = $Name; Status = 'Running' }
                }
                Mock Get-CWAAInfo {
                    [PSCustomObject]@{
                        Server            = @('primary.example.com', 'backup.example.com')
                        LastSuccessStatus = (Get-Date).AddMinutes(-30).ToString()
                        HeartbeatLastSent = (Get-Date).AddMinutes(-15).ToString()
                    }
                }

                # Pipe an object with Server as a multi-element array (matching Get-CWAAInfo output)
                [PSCustomObject]@{ Server = @('primary.example.com', 'backup.example.com') } | Test-CWAAHealth
            }
            $result.Healthy | Should -BeTrue
            $result.ServerMatch | Should -BeTrue
        }

        It 'Test-CWAAServerConnectivity accepts Server as string[] from pipeline' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Invoke-RestMethod { return '||||||220.105' }

                [PSCustomObject]@{ Server = @('primary.example.com', 'backup.example.com') } | Test-CWAAServerConnectivity
            }
            # Should return results for both servers
            ($result | Measure-Object).Count | Should -Be 2
        }

        It 'Register-CWAAHealthCheckTask accepts Server as string[] and builds valid command' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock schtasks { return $null }
                Mock New-CWAABackup {}

                [PSCustomObject]@{
                    Server     = @('primary.example.com', 'backup.example.com')
                    LocationID = 42
                } | Register-CWAAHealthCheckTask -InstallerToken 'abc123' -Confirm:$false
            }
            $result | Should -Not -BeNullOrEmpty
            $result.Created | Should -BeTrue
        }
    }
}

# =============================================================================
# Credential Hardening Tests
# =============================================================================

Describe 'PSCredential Parameter Support' {

    Context 'Install-CWAA Credential parameter' {

        It 'has a Credential parameter of type PSCredential' {
            $cmd = Get-Command Install-CWAA
            $param = $cmd.Parameters['Credential']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType.Name | Should -Be 'PSCredential'
        }

        It 'Credential parameter is in the deployment parameter set' {
            $cmd = Get-Command Install-CWAA
            $param = $cmd.Parameters['Credential']
            $param.ParameterSets.Keys | Should -Contain 'deployment'
        }
    }

    Context 'Set-CWAAProxy ProxyCredential parameter' {

        It 'has a ProxyCredential parameter of type PSCredential' {
            $cmd = Get-Command Set-CWAAProxy
            $param = $cmd.Parameters['ProxyCredential']
            $param | Should -Not -BeNullOrEmpty
            $param.ParameterType.Name | Should -Be 'PSCredential'
        }
    }
}

# =============================================================================
# Phase 1+2 Constants and Helpers
# =============================================================================

Describe 'Initialize-CWAA constants (Phase 1)' {

    Context 'version threshold constants' {

        It 'defines CWAAVersionZipInstaller' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $Script:CWAAVersionZipInstaller | Should -Be '240.331'
            }
        }

        It 'defines CWAAVersionAnonymousChange' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $Script:CWAAVersionAnonymousChange | Should -Be '110.374'
            }
        }

        It 'defines CWAAVersionVulnerabilityFix' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $Script:CWAAVersionVulnerabilityFix | Should -Be '200.197'
            }
        }

        It 'defines CWAAVersionUpdateMinimum' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $Script:CWAAVersionUpdateMinimum | Should -Be '105.001'
            }
        }
    }

    Context 'service and process name constants' {

        It 'defines CWAAAgentProcessNames with 3 entries' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $Script:CWAAAgentProcessNames | Should -HaveCount 3
                $Script:CWAAAgentProcessNames | Should -Contain 'LTTray'
                $Script:CWAAAgentProcessNames | Should -Contain 'LTSVC'
                $Script:CWAAAgentProcessNames | Should -Contain 'LTSvcMon'
            }
        }

        It 'defines CWAAAllServiceNames with 3 entries including LabVNC' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $Script:CWAAAllServiceNames | Should -HaveCount 3
                $Script:CWAAAllServiceNames | Should -Contain 'LTService'
                $Script:CWAAAllServiceNames | Should -Contain 'LTSvcMon'
                $Script:CWAAAllServiceNames | Should -Contain 'LabVNC'
            }
        }
    }

    Context 'timeout constants' {

        It 'defines CWAAServiceWaitTimeoutSec as 60' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $Script:CWAAServiceWaitTimeoutSec | Should -Be 60
            }
        }

        It 'defines CWAARedoSettleDelaySeconds as 20' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $Script:CWAARedoSettleDelaySeconds | Should -Be 20
            }
        }
    }
}

Describe 'Test-CWAAServiceExists' {

    Context 'when services exist' {

        It 'returns $true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' }
                }
                Test-CWAAServiceExists
            }
            $result | Should -Be $true
        }

        It 'does not write an error' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {
                    [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' }
                }
                $err = $null
                $null = Test-CWAAServiceExists -WriteErrorOnMissing -ErrorVariable err -ErrorAction SilentlyContinue
                $err | Should -BeNullOrEmpty
            }
        }
    }

    Context 'when services do not exist' {

        It 'returns $false' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {}
                Test-CWAAServiceExists
            }
            $result | Should -Be $false
        }

        It 'does not write error without -WriteErrorOnMissing' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {}
                $err = $null
                $null = Test-CWAAServiceExists -ErrorVariable err -ErrorAction SilentlyContinue
                $err | Should -BeNullOrEmpty
            }
        }

        It 'writes error with -WriteErrorOnMissing' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {}
                $err = $null
                $null = Test-CWAAServiceExists -WriteErrorOnMissing -ErrorVariable err -ErrorAction SilentlyContinue
                $err | Should -Not -BeNullOrEmpty
                "$err" | Should -Match 'Services NOT Found'
            }
        }

        It 'writes WhatIf-prefixed error when WhatIfPreference is true' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-Service {}
                $WhatIfPreference = $true
                $err = $null
                $null = Test-CWAAServiceExists -WriteErrorOnMissing -ErrorVariable err -ErrorAction SilentlyContinue
                "$err" | Should -Match 'What If.*Services NOT Found'
            }
        }
    }
}

Describe 'Assert-CWAANotProbeAgent' {

    Context 'when ServiceInfo is null' {

        It 'does not throw' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                { Assert-CWAANotProbeAgent -ServiceInfo $null -ActionName 'Test' } | Should -Not -Throw
            }
        }
    }

    Context 'when agent is not a probe' {

        It 'does not throw' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $info = [PSCustomObject]@{ Probe = '0' }
                { Assert-CWAANotProbeAgent -ServiceInfo $info -ActionName 'Test' } | Should -Not -Throw
            }
        }
    }

    Context 'when agent is a probe without -Force' {

        It 'throws with action name in message' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    $info = [PSCustomObject]@{ Probe = '1' }
                    Assert-CWAANotProbeAgent -ServiceInfo $info -ActionName 'UnInstall'
                }
            } | Should -Throw '*Probe Agent Detected*UnInstall Denied*'
        }

        It 'uses Reset action name' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    $info = [PSCustomObject]@{ Probe = '1' }
                    Assert-CWAANotProbeAgent -ServiceInfo $info -ActionName 'Reset'
                }
            } | Should -Throw '*Reset Denied*'
        }
    }

    Context 'when agent is a probe with -Force' {

        It 'does not throw' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $info = [PSCustomObject]@{ Probe = '1' }
                { Assert-CWAANotProbeAgent -ServiceInfo $info -ActionName 'UnInstall' -Force } | Should -Not -Throw
            }
        }

        It 'writes Forced output message' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $info = [PSCustomObject]@{ Probe = '1' }
                Assert-CWAANotProbeAgent -ServiceInfo $info -ActionName 'Re-Install' -Force
            }
            $result | Should -Match 'Probe Agent Detected.*Re-Install Forced'
        }
    }

    Context 'when ServiceInfo has no Probe property' {

        It 'does not throw' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $info = [PSCustomObject]@{ Server = 'test.com' }
                { Assert-CWAANotProbeAgent -ServiceInfo $info -ActionName 'Test' } | Should -Not -Throw
            }
        }
    }
}
