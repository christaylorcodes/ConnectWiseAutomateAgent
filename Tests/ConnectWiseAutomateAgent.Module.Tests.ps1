#Requires -Module Pester

<#
.SYNOPSIS
    Module structure, quality, and function validation tests.

.DESCRIPTION
    Tests module manifest, import, exports, aliases, function structure,
    parameter validation, and single-file build validation.

    Supports dual-mode testing via $env:CWAA_TEST_LOAD_METHOD:
    - 'Module' (default): Import-Module from .psd1 manifest
    - 'SingleFile': Load concatenated .ps1 via dynamic module

    Module-only tests are automatically skipped in SingleFile mode.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Module.Tests.ps1 -Output Detailed
#>

BeforeDiscovery {
    $script:IsSingleFileMode = ($env:CWAA_TEST_LOAD_METHOD -eq 'SingleFile')
    $script:IsModuleMode = -not $script:IsSingleFileMode
}

BeforeAll {
    $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
    $script:IsSingleFileMode = ($script:BootstrapResult.LoadMethod -eq 'SingleFile')
    $script:IsModuleMode = -not $script:IsSingleFileMode
    $ModuleName = $script:BootstrapResult.ModuleName
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# Module Quality Tests
# =============================================================================
Describe 'Module: ConnectWiseAutomateAgent' {

    Context 'Module Manifest' -Skip:$script:IsSingleFileMode {
        BeforeAll {
            $ModuleRoot = Split-Path -Parent $PSScriptRoot
            $ManifestPath = Join-Path $ModuleRoot 'ConnectWiseAutomateAgent\ConnectWiseAutomateAgent.psd1'
            $Manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        }

        It 'has a valid module manifest' {
            $Manifest | Should -Not -BeNullOrEmpty
        }

        It 'has a valid root module' {
            $Manifest.RootModule | Should -Be 'ConnectWiseAutomateAgent.psm1'
        }

        It 'has the expected module version' {
            $expectedVersion = (Import-PowerShellDataFile $ManifestPath).ModuleVersion
            $Manifest.Version.ToString() | Should -Be $expectedVersion
        }

        It 'has a valid GUID' {
            $Manifest.GUID.ToString() | Should -Be '37424fc5-48d4-4d15-8b19-e1c2bf4bab67'
        }

        It 'requires PowerShell 3.0 or higher' {
            $Manifest.PowerShellVersion | Should -Be '3.0'
        }

        It 'has a project URI' {
            $Manifest.PrivateData.PSData.ProjectUri | Should -Not -BeNullOrEmpty
        }

        It 'exports no variables' {
            $Manifest.ExportedVariables.Keys | Should -HaveCount 0
        }

        It 'exports no cmdlets' {
            $Manifest.ExportedCmdlets.Keys | Should -HaveCount 0
        }
    }

    Context 'Module Import' {
        It 'imports without errors' {
            { Get-Module 'ConnectWiseAutomateAgent' } | Should -Not -Throw
        }

        It 'is loaded in the session' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $module | Should -Not -BeNullOrEmpty
            $module.Name | Should -Be 'ConnectWiseAutomateAgent'
        }
    }

    Context 'Lazy Initialization' {
        It 'does not initialize networking on module import' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $initialized = & $module { $Script:CWAANetworkInitialized }
            $initialized | Should -Be $False
        }

        It 'has CWAA constants defined after import' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $registryRoot = & $module { $Script:CWAARegistryRoot }
            $registryRoot | Should -Be 'HKLM:\SOFTWARE\LabTech\Service'
        }

        It 'has CWAARegistrySettings constant defined' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $registrySettings = & $module { $Script:CWAARegistrySettings }
            $registrySettings | Should -Be 'HKLM:\SOFTWARE\LabTech\Service\Settings'
        }

        It 'has CWAAInstallPath constant defined' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $installPath = & $module { $Script:CWAAInstallPath }
            $installPath | Should -Match 'LTSVC$'
        }

        It 'has CWAAServiceNames constant defined' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $serviceNames = & $module { $Script:CWAAServiceNames }
            $serviceNames | Should -Contain 'LTService'
            $serviceNames | Should -Contain 'LTSvcMon'
        }

        It 'has empty LTServiceKeys after import' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $keys = & $module { $Script:LTServiceKeys }
            $keys | Should -Not -BeNullOrEmpty
            $keys.ServerPasswordString | Should -Be ''
            $keys.PasswordString | Should -Be ''
        }

        It 'has empty LTProxy after import' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $proxy = & $module { $Script:LTProxy }
            $proxy | Should -Not -BeNullOrEmpty
            $proxy.Enabled | Should -Be $False
            $proxy.ProxyServerURL | Should -Be ''
        }

        It 'has LTWebProxy undefined before networking init' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $webProxy = & $module { $Script:LTWebProxy }
            $webProxy | Should -BeNullOrEmpty
        }

        It 'has LTServiceNetWebClient undefined before networking init' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $webClient = & $module { $Script:LTServiceNetWebClient }
            $webClient | Should -BeNullOrEmpty
        }

        It 'has Initialize-CWAANetworking as a recognized command' {
            $module = Get-Module 'ConnectWiseAutomateAgent'
            $cmd = & $module { Get-Command 'Initialize-CWAANetworking' -ErrorAction SilentlyContinue }
            $cmd | Should -Not -BeNullOrEmpty
        }

        It 'does not export Initialize-CWAANetworking as a public function' -Skip:$script:IsSingleFileMode {
            $exported = (Get-Module 'ConnectWiseAutomateAgent').ExportedFunctions.Keys
            $exported | Should -Not -Contain 'Initialize-CWAANetworking'
        }
    }

    Context 'Exported Functions' {
        BeforeAll {
            $ExpectedFunctions = @(
                'Hide-CWAAAddRemove'
                'Rename-CWAAAddRemove'
                'Show-CWAAAddRemove'
                'Install-CWAA'
                'Redo-CWAA'
                'Uninstall-CWAA'
                'Update-CWAA'
                'Get-CWAAError'
                'Get-CWAALogLevel'
                'Get-CWAAProbeError'
                'Set-CWAALogLevel'
                'Get-CWAAProxy'
                'Set-CWAAProxy'
                'Restart-CWAA'
                'Start-CWAA'
                'Stop-CWAA'
                'Get-CWAAInfo'
                'Get-CWAAInfoBackup'
                'Get-CWAASettings'
                'New-CWAABackup'
                'Reset-CWAA'
                'ConvertFrom-CWAASecurity'
                'ConvertTo-CWAASecurity'
                'Invoke-CWAACommand'
                'Test-CWAAPort'
                'Test-CWAAServerConnectivity'
                'Test-CWAAHealth'
                'Repair-CWAA'
                'Register-CWAAHealthCheckTask'
                'Unregister-CWAAHealthCheckTask'
            )
            $ExportedFunctions = (Get-Module 'ConnectWiseAutomateAgent').ExportedFunctions.Keys
        }

        It 'exports exactly 30 functions' -Skip:$script:IsSingleFileMode {
            $ExportedFunctions | Should -HaveCount 30
        }

        It 'exports at least 30 functions (includes private in single-file mode)' -Skip:$script:IsModuleMode {
            $ExportedFunctions.Count | Should -BeGreaterOrEqual 30
        }

        It 'exports <_>' -ForEach $ExpectedFunctions {
            $_ | Should -BeIn $ExportedFunctions
        }
    }

    Context 'Exported Aliases' {
        BeforeAll {
            $ExpectedAliases = @(
                'Hide-LTAddRemove'
                'Rename-LTAddRemove'
                'Show-LTAddRemove'
                'Install-LTService'
                'Redo-LTService'
                'Reinstall-CWAA'
                'Reinstall-LTService'
                'Uninstall-LTService'
                'Update-LTService'
                'Get-LTErrors'
                'Get-LTLogging'
                'Get-LTProbeErrors'
                'Set-LTLogging'
                'Get-LTProxy'
                'Set-LTProxy'
                'Restart-LTService'
                'Start-LTService'
                'Stop-LTService'
                'Get-LTServiceInfo'
                'Get-LTServiceInfoBackup'
                'Get-LTServiceSettings'
                'New-LTServiceBackup'
                'Reset-LTService'
                'ConvertFrom-LTSecurity'
                'ConvertTo-LTSecurity'
                'Invoke-LTServiceCommand'
                'Test-LTPorts'
                'Test-LTServerConnectivity'
                'Test-LTHealth'
                'Repair-LTService'
                'Register-LTHealthCheckTask'
                'Unregister-LTHealthCheckTask'
            )
            $ExportedAliases = (Get-Module 'ConnectWiseAutomateAgent').ExportedAliases.Keys
        }

        It 'exports exactly 32 aliases' -Skip:$script:IsSingleFileMode {
            $ExportedAliases | Should -HaveCount 32
        }

        It 'exports at least 32 aliases' -Skip:$script:IsModuleMode {
            $ExportedAliases.Count | Should -BeGreaterOrEqual 32
        }

        It 'exports alias <_>' -ForEach $ExpectedAliases {
            $_ | Should -BeIn $ExportedAliases
        }
    }

    Context 'Function-to-File Mapping' -Skip:$script:IsSingleFileMode {
        BeforeAll {
            $ModuleRoot = Split-Path -Parent $PSScriptRoot
            $PublicPath = Join-Path $ModuleRoot 'ConnectWiseAutomateAgent\Public'
            $PublicFiles = Get-ChildItem -Path $PublicPath -Filter '*.ps1' -Recurse |
                Select-Object -ExpandProperty BaseName
        }

        It 'has a .ps1 file for each exported function' {
            $ExportedFunctions = (Get-Module 'ConnectWiseAutomateAgent').ExportedFunctions.Keys
            foreach ($function in $ExportedFunctions) {
                $function | Should -BeIn $PublicFiles -Because "$function should have a matching .ps1 file"
            }
        }

        It 'every public .ps1 file corresponds to an exported function' {
            $ExportedFunctions = (Get-Module 'ConnectWiseAutomateAgent').ExportedFunctions.Keys
            foreach ($file in $PublicFiles) {
                $file | Should -BeIn $ExportedFunctions -Because "$file.ps1 should be exported"
            }
        }
    }

    Context 'Single-File Build Validation' -Skip:$script:IsModuleMode {
        BeforeAll {
            $RepoRoot = Split-Path -Parent $PSScriptRoot
            $SingleFilePath = Join-Path $RepoRoot 'ConnectWiseAutomateAgent.ps1'
        }

        It 'single-file build exists' {
            $SingleFilePath | Should -Exist
        }

        It 'single-file ends with Initialize-CWAA call' {
            $lastLines = Get-Content $SingleFilePath -Tail 5
            ($lastLines -join "`n") | Should -Match 'Initialize-CWAA' -Because 'single-file must call initialization at the end'
        }

        It 'private helper functions are available' {
            $exported = (Get-Module 'ConnectWiseAutomateAgent').ExportedFunctions.Keys
            $exported | Should -Contain 'Initialize-CWAA'
            $exported | Should -Contain 'Initialize-CWAANetworking'
        }
    }
}

# =============================================================================
# Function Structure Tests
# =============================================================================
Describe 'Function Structure' {

    Context '<_> has proper structure' -ForEach @(
        'Hide-CWAAAddRemove'
        'Rename-CWAAAddRemove'
        'Show-CWAAAddRemove'
        'Install-CWAA'
        'Redo-CWAA'
        'Uninstall-CWAA'
        'Update-CWAA'
        'Get-CWAAError'
        'Get-CWAALogLevel'
        'Get-CWAAProbeError'
        'Set-CWAALogLevel'
        'Get-CWAAProxy'
        'Set-CWAAProxy'
        'Restart-CWAA'
        'Start-CWAA'
        'Stop-CWAA'
        'Get-CWAAInfo'
        'Get-CWAAInfoBackup'
        'Get-CWAASettings'
        'New-CWAABackup'
        'Reset-CWAA'
        'ConvertFrom-CWAASecurity'
        'ConvertTo-CWAASecurity'
        'Invoke-CWAACommand'
        'Test-CWAAPort'
    ) {
        It 'is a recognized command' {
            Get-Command $_ -Module 'ConnectWiseAutomateAgent' | Should -Not -BeNullOrEmpty
        }

        It 'has CmdletBinding attribute' {
            $cmd = Get-Command $_ -Module 'ConnectWiseAutomateAgent'
            $cmd.CmdletBinding | Should -BeTrue
        }

        It 'has comment-based help with a synopsis' {
            $help = Get-Help $_ -ErrorAction SilentlyContinue
            $help.Synopsis | Should -Not -BeNullOrEmpty
            # Synopsis should not just be the function name (indicates missing help)
            $help.Synopsis.Trim() | Should -Not -Be $_
        }
    }

    Context 'Legacy alias mapping' {
        BeforeAll {
            # Map of CWAA function -> expected LT alias(es)
            $AliasMap = @{
                'Hide-CWAAAddRemove'    = @('Hide-LTAddRemove')
                'Rename-CWAAAddRemove'  = @('Rename-LTAddRemove')
                'Show-CWAAAddRemove'    = @('Show-LTAddRemove')
                'Install-CWAA'          = @('Install-LTService')
                'Redo-CWAA'             = @('Redo-LTService', 'Reinstall-CWAA', 'Reinstall-LTService')
                'Uninstall-CWAA'        = @('Uninstall-LTService')
                'Update-CWAA'           = @('Update-LTService')
                'Get-CWAAError'         = @('Get-LTErrors')
                'Get-CWAALogLevel'      = @('Get-LTLogging')
                'Get-CWAAProbeError'    = @('Get-LTProbeErrors')
                'Set-CWAALogLevel'      = @('Set-LTLogging')
                'Get-CWAAProxy'         = @('Get-LTProxy')
                'Set-CWAAProxy'         = @('Set-LTProxy')
                'Restart-CWAA'          = @('Restart-LTService')
                'Start-CWAA'            = @('Start-LTService')
                'Stop-CWAA'             = @('Stop-LTService')
                'Get-CWAAInfo'          = @('Get-LTServiceInfo')
                'Get-CWAAInfoBackup'    = @('Get-LTServiceInfoBackup')
                'Get-CWAASettings'      = @('Get-LTServiceSettings')
                'New-CWAABackup'        = @('New-LTServiceBackup')
                'Reset-CWAA'            = @('Reset-LTService')
                'ConvertFrom-CWAASecurity' = @('ConvertFrom-LTSecurity')
                'ConvertTo-CWAASecurity'   = @('ConvertTo-LTSecurity')
                'Invoke-CWAACommand'    = @('Invoke-LTServiceCommand')
                'Test-CWAAPort'         = @('Test-LTPorts')
            }
        }

        It '<Key> resolves from alias <Value>' -ForEach (
            @(
                @{ Key = 'Hide-CWAAAddRemove';    Value = 'Hide-LTAddRemove' }
                @{ Key = 'Rename-CWAAAddRemove';  Value = 'Rename-LTAddRemove' }
                @{ Key = 'Show-CWAAAddRemove';    Value = 'Show-LTAddRemove' }
                @{ Key = 'Install-CWAA';          Value = 'Install-LTService' }
                @{ Key = 'Redo-CWAA';             Value = 'Redo-LTService' }
                @{ Key = 'Redo-CWAA';             Value = 'Reinstall-CWAA' }
                @{ Key = 'Redo-CWAA';             Value = 'Reinstall-LTService' }
                @{ Key = 'Uninstall-CWAA';        Value = 'Uninstall-LTService' }
                @{ Key = 'Update-CWAA';           Value = 'Update-LTService' }
                @{ Key = 'Get-CWAAError';         Value = 'Get-LTErrors' }
                @{ Key = 'Get-CWAALogLevel';      Value = 'Get-LTLogging' }
                @{ Key = 'Get-CWAAProbeError';    Value = 'Get-LTProbeErrors' }
                @{ Key = 'Set-CWAALogLevel';      Value = 'Set-LTLogging' }
                @{ Key = 'Get-CWAAProxy';         Value = 'Get-LTProxy' }
                @{ Key = 'Set-CWAAProxy';         Value = 'Set-LTProxy' }
                @{ Key = 'Restart-CWAA';          Value = 'Restart-LTService' }
                @{ Key = 'Start-CWAA';            Value = 'Start-LTService' }
                @{ Key = 'Stop-CWAA';             Value = 'Stop-LTService' }
                @{ Key = 'Get-CWAAInfo';          Value = 'Get-LTServiceInfo' }
                @{ Key = 'Get-CWAAInfoBackup';    Value = 'Get-LTServiceInfoBackup' }
                @{ Key = 'Get-CWAASettings';      Value = 'Get-LTServiceSettings' }
                @{ Key = 'New-CWAABackup';        Value = 'New-LTServiceBackup' }
                @{ Key = 'Reset-CWAA';            Value = 'Reset-LTService' }
                @{ Key = 'ConvertFrom-CWAASecurity'; Value = 'ConvertFrom-LTSecurity' }
                @{ Key = 'ConvertTo-CWAASecurity';   Value = 'ConvertTo-LTSecurity' }
                @{ Key = 'Invoke-CWAACommand';    Value = 'Invoke-LTServiceCommand' }
                @{ Key = 'Test-CWAAPort';         Value = 'Test-LTPorts' }
            )
        ) {
            $alias = Get-Alias $Value -ErrorAction SilentlyContinue
            $alias | Should -Not -BeNullOrEmpty -Because "alias '$Value' should exist"
            $alias.ResolvedCommand.Name | Should -Be $Key
        }
    }

    Context 'ShouldProcess on destructive functions' {
        # Functions that perform destructive or state-changing operations should declare SupportsShouldProcess
        It '<_> supports ShouldProcess' -ForEach @(
            'Install-CWAA'
            'Uninstall-CWAA'
            'Redo-CWAA'
            'Update-CWAA'
            'Reset-CWAA'
            'Restart-CWAA'
            'Start-CWAA'
            'Stop-CWAA'
        ) {
            $cmd = Get-Command $_ -Module 'ConnectWiseAutomateAgent'
            $cmd.Parameters.Keys | Should -Contain 'WhatIf' -Because "$_ is destructive and should support -WhatIf"
        }
    }
}

# =============================================================================
# Parameter Validation Tests
# =============================================================================
Describe 'Parameter Validation' {

    Context 'Install-CWAA parameters' {
        BeforeAll {
            $cmd = Get-Command Install-CWAA -Module 'ConnectWiseAutomateAgent'
        }

        It 'has a Server parameter' {
            $cmd.Parameters.Keys | Should -Contain 'Server'
        }

        It 'has an InstallerToken parameter' {
            $cmd.Parameters.Keys | Should -Contain 'InstallerToken'
        }
    }

    Context 'Test-CWAAPort parameters' {
        BeforeAll {
            $cmd = Get-Command Test-CWAAPort -Module 'ConnectWiseAutomateAgent'
        }

        It 'has a Server parameter' {
            $cmd.Parameters.Keys | Should -Contain 'Server'
        }

        It 'has a TrayPort parameter' {
            $cmd.Parameters.Keys | Should -Contain 'TrayPort'
        }

        It 'has a Quiet switch parameter' {
            $cmd.Parameters.Keys | Should -Contain 'Quiet'
            $cmd.Parameters['Quiet'].SwitchParameter | Should -BeTrue
        }
    }

    Context 'Get-CWAALogLevel parameters' {
        BeforeAll {
            $cmd = Get-Command Get-CWAALogLevel -Module 'ConnectWiseAutomateAgent'
        }

        It 'is a recognized command' {
            $cmd | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Set-CWAALogLevel parameters' {
        BeforeAll {
            $cmd = Get-Command Set-CWAALogLevel -Module 'ConnectWiseAutomateAgent'
        }

        It 'has a Level parameter' {
            $cmd.Parameters.Keys | Should -Contain 'Level'
        }
    }
}
