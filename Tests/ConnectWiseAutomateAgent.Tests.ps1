#Requires -Module Pester

BeforeAll {
    $ModuleName = 'ConnectWiseAutomateAgent'
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModulePath = Join-Path $ModuleRoot "$ModuleName\$ModuleName.psd1"

    # Remove module if already loaded, then import fresh
    Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -Force
    Import-Module $ModulePath -Force -ErrorAction Stop
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# Module Quality Tests
# =============================================================================
Describe 'Module: ConnectWiseAutomateAgent' {

    Context 'Module Manifest' {
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

        It 'does not export Initialize-CWAANetworking as a public function' {
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

        It 'exports exactly 30 functions' {
            $ExportedFunctions | Should -HaveCount 30
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

        It 'exports exactly 32 aliases' {
            $ExportedAliases | Should -HaveCount 32
        }

        It 'exports alias <_>' -ForEach $ExpectedAliases {
            $_ | Should -BeIn $ExportedAliases
        }
    }

    Context 'Function-to-File Mapping' {
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
# ConvertTo-CWAASecurity Unit Tests
# =============================================================================
Describe 'ConvertTo-CWAASecurity' {

    It 'returns a non-empty string for valid input' {
        $result = ConvertTo-CWAASecurity -InputString 'TestValue'
        $result | Should -Not -BeNullOrEmpty
    }

    It 'returns a valid Base64-encoded string' {
        $result = ConvertTo-CWAASecurity -InputString 'TestValue'
        # Base64 strings contain only [A-Za-z0-9+/=]
        $result | Should -Match '^[A-Za-z0-9+/=]+$'
    }

    It 'produces consistent output for the same input' {
        $result1 = ConvertTo-CWAASecurity -InputString 'ConsistencyTest'
        $result2 = ConvertTo-CWAASecurity -InputString 'ConsistencyTest'
        $result1 | Should -Be $result2
    }

    It 'produces different output for different inputs' {
        $result1 = ConvertTo-CWAASecurity -InputString 'Value1'
        $result2 = ConvertTo-CWAASecurity -InputString 'Value2'
        $result1 | Should -Not -Be $result2
    }

    It 'produces different output with different keys' {
        $result1 = ConvertTo-CWAASecurity -InputString 'TestValue' -Key 'Key1'
        $result2 = ConvertTo-CWAASecurity -InputString 'TestValue' -Key 'Key2'
        $result1 | Should -Not -Be $result2
    }

    It 'handles an empty string input' {
        $result = ConvertTo-CWAASecurity -InputString ''
        $result | Should -Not -BeNullOrEmpty
    }

    It 'handles long string input' {
        $longString = 'A' * 1000
        $result = ConvertTo-CWAASecurity -InputString $longString
        $result | Should -Not -BeNullOrEmpty
    }

    It 'handles special characters' {
        $result = ConvertTo-CWAASecurity -InputString '!@#$%^&*()_+-={}[]|;:<>?,./~`'
        $result | Should -Not -BeNullOrEmpty
    }

    It 'works with a custom key' {
        $result = ConvertTo-CWAASecurity -InputString 'TestValue' -Key 'MyCustomKey'
        $result | Should -Not -BeNullOrEmpty
    }

    It 'works via the legacy alias ConvertTo-LTSecurity' {
        $result = ConvertTo-LTSecurity -InputString 'AliasTest'
        $result | Should -Not -BeNullOrEmpty
    }
}

# =============================================================================
# ConvertFrom-CWAASecurity Unit Tests
# =============================================================================
Describe 'ConvertFrom-CWAASecurity' {

    It 'decodes a previously encoded string' {
        $encoded = ConvertTo-CWAASecurity -InputString 'HelloWorld'
        $decoded = ConvertFrom-CWAASecurity -InputString $encoded
        $decoded | Should -Be 'HelloWorld'
    }

    It 'returns null for invalid Base64 input' {
        $result = ConvertFrom-CWAASecurity -InputString 'NotValidBase64!!!' -Force:$False
        $result | Should -BeNullOrEmpty
    }

    It 'decodes with a custom key' {
        $customKey = 'MySecretKey123'
        $encoded = ConvertTo-CWAASecurity -InputString 'CustomKeyTest' -Key $customKey
        $decoded = ConvertFrom-CWAASecurity -InputString $encoded -Key $customKey
        $decoded | Should -Be 'CustomKeyTest'
    }

    It 'fails to decode with the wrong key (Force disabled)' {
        $encoded = ConvertTo-CWAASecurity -InputString 'WrongKeyTest' -Key 'CorrectKey'
        $decoded = ConvertFrom-CWAASecurity -InputString $encoded -Key 'WrongKey' -Force:$False
        $decoded | Should -BeNullOrEmpty
    }

    It 'works via the legacy alias ConvertFrom-LTSecurity' {
        $encoded = ConvertTo-CWAASecurity -InputString 'AliasTest'
        $decoded = ConvertFrom-LTSecurity -InputString $encoded
        $decoded | Should -Be 'AliasTest'
    }

    It 'accepts pipeline input' {
        $encoded = ConvertTo-CWAASecurity -InputString 'PipelineTest'
        $decoded = $encoded | ConvertFrom-CWAASecurity
        $decoded | Should -Be 'PipelineTest'
    }
}

# =============================================================================
# Security Round-Trip Tests
# =============================================================================
Describe 'Security Encode/Decode Round-Trip' {

    It 'round-trips "<TestString>" with default key' -ForEach @(
        @{ TestString = 'SimpleText' }
        @{ TestString = 'Hello World with spaces' }
        @{ TestString = 'Special!@#$%^&*()chars' }
        @{ TestString = '12345' }
        @{ TestString = '' }
        @{ TestString = 'https://automate.example.com' }
        @{ TestString = 'P@$$w0rd!#Complex' }
    ) {
        $encoded = ConvertTo-CWAASecurity -InputString $TestString
        $decoded = ConvertFrom-CWAASecurity -InputString $encoded
        $decoded | Should -Be $TestString
    }

    It 'round-trips with custom key "<Key>"' -ForEach @(
        @{ Key = 'ShortKey' }
        @{ Key = 'A much longer encryption key for testing purposes' }
        @{ Key = '!@#$%' }
        @{ Key = '12345678901234567890' }
    ) {
        $testValue = 'RoundTripValue'
        $encoded = ConvertTo-CWAASecurity -InputString $testValue -Key $Key
        $decoded = ConvertFrom-CWAASecurity -InputString $encoded -Key $Key
        $decoded | Should -Be $testValue
    }

    It 'encoded value differs between default key and custom key' {
        $input = 'CompareKeys'
        $defaultEncoded = ConvertTo-CWAASecurity -InputString $input
        $customEncoded = ConvertTo-CWAASecurity -InputString $input -Key 'CustomKey'
        $defaultEncoded | Should -Not -Be $customEncoded
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

# =============================================================================
# Documentation Structure Tests
# =============================================================================
Describe 'Documentation Structure' {

    BeforeAll {
        $ModuleRoot = Split-Path -Parent $PSScriptRoot
        $DocsRoot = Join-Path $ModuleRoot 'Docs'
        $DocsHelp = Join-Path $DocsRoot 'Help'
        $BuildScript = Join-Path $ModuleRoot 'Build\Build-Documentation.ps1'
        $ExportedFunctions = (Get-Module 'ConnectWiseAutomateAgent').ExportedFunctions.Keys
    }

    Context 'Folder layout' {
        It 'has a Docs directory' {
            $DocsRoot | Should -Exist
        }

        It 'has a Docs/Help directory for auto-generated reference docs' {
            $DocsHelp | Should -Exist
        }

        It 'has no auto-generated function docs in Docs root' {
            $handWrittenGuides = @(
                'Architecture.md',
                'CommonParameters.md',
                'FAQ.md',
                'Migration.md',
                'Security.md',
                'Troubleshooting.md'
            )
            $rootMdFiles = Get-ChildItem $DocsRoot -Filter '*.md' -File |
                Where-Object { $_.Name -notin $handWrittenGuides }
            $rootMdFiles | Should -HaveCount 0 -Because 'function docs belong in Docs/Help/, only hand-written guides in Docs/'
        }

        It 'has Architecture.md in Docs root (hand-written)' {
            Join-Path $DocsRoot 'Architecture.md' | Should -Exist
        }
    }

    Context 'Auto-generated function reference' {
        It 'has a module overview page' {
            Join-Path $DocsHelp 'ConnectWiseAutomateAgent.md' | Should -Exist
        }

        It 'has a markdown doc for each exported function' {
            foreach ($function in $ExportedFunctions) {
                $docPath = Join-Path $DocsHelp "$function.md"
                $docPath | Should -Exist -Because "$function should have a corresponding doc in Docs/Help/"
            }
        }

        It 'each function doc has PlatyPS YAML frontmatter' {
            foreach ($function in $ExportedFunctions) {
                $docPath = Join-Path $DocsHelp "$function.md"
                if (Test-Path $docPath) {
                    $firstLine = (Get-Content $docPath -TotalCount 1)
                    $firstLine | Should -Be '---' -Because "$function.md should start with YAML frontmatter"
                }
            }
        }
    }

    Context 'MAML help' {
        It 'has a compiled MAML XML help file' {
            $mamlPath = Join-Path $ModuleRoot 'ConnectWiseAutomateAgent\en-US\ConnectWiseAutomateAgent-help.xml'
            $mamlPath | Should -Exist
        }

        It 'has an about help topic' {
            $aboutPath = Join-Path $ModuleRoot 'ConnectWiseAutomateAgent\en-US\about_ConnectWiseAutomateAgent.help.txt'
            $aboutPath | Should -Exist
        }
    }

    Context 'Build script' {
        It 'Build-Documentation.ps1 exists' {
            $BuildScript | Should -Exist
        }

        It 'Build-Documentation.ps1 defaults output to Docs/Help' {
            $scriptContent = Get-Content $BuildScript -Raw
            $scriptContent | Should -Match "Join-Path.*'Help'" -Because 'default output path should target Docs/Help'
        }
    }
}
