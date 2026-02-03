#Requires -Module Pester

<#
.SYNOPSIS
    Documentation structure tests.

.DESCRIPTION
    Tests the documentation folder layout, auto-generated function reference,
    and MAML help.

    Supports dual-mode testing via $env:CWAA_TEST_LOAD_METHOD.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Documentation.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# Documentation Structure Tests
# =============================================================================
Describe 'Documentation Structure' {

    BeforeAll {
        $ModuleRoot = Split-Path -Parent $PSScriptRoot
        $DocsRoot = Join-Path $ModuleRoot 'Docs'
        $DocsHelp = Join-Path $DocsRoot 'Help'
        # Use the known list of public functions for doc checks. In built module mode,
        # ExportedFunctions includes private helpers that don't have docs in Docs/Help/.
        $PublicFunctions = @(
            'Hide-CWAAAddRemove', 'Rename-CWAAAddRemove', 'Show-CWAAAddRemove',
            'Install-CWAA', 'Redo-CWAA', 'Uninstall-CWAA', 'Update-CWAA',
            'Get-CWAAError', 'Get-CWAALogLevel', 'Get-CWAAProbeError', 'Set-CWAALogLevel',
            'Get-CWAAProxy', 'Set-CWAAProxy',
            'Restart-CWAA', 'Start-CWAA', 'Stop-CWAA', 'Repair-CWAA',
            'Test-CWAAHealth', 'Register-CWAAHealthCheckTask', 'Unregister-CWAAHealthCheckTask',
            'Get-CWAAInfo', 'Get-CWAAInfoBackup', 'Get-CWAASettings', 'New-CWAABackup', 'Reset-CWAA',
            'ConvertFrom-CWAASecurity', 'ConvertTo-CWAASecurity',
            'Invoke-CWAACommand', 'Test-CWAAPort', 'Test-CWAAServerConnectivity'
        )
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

        It 'has a markdown doc for each public function' {
            foreach ($function in $PublicFunctions) {
                $docPath = Join-Path $DocsHelp "$function.md"
                $docPath | Should -Exist -Because "$function should have a corresponding doc in Docs/Help/"
            }
        }

        It 'each function doc has PlatyPS YAML frontmatter' {
            foreach ($function in $PublicFunctions) {
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
            $mamlPath = Join-Path $ModuleRoot 'source\en-US\ConnectWiseAutomateAgent-help.xml'
            $mamlPath | Should -Exist
        }

        It 'has an about help topic' {
            $aboutPath = Join-Path $ModuleRoot 'source\en-US\about_ConnectWiseAutomateAgent.help.txt'
            $aboutPath | Should -Exist
        }
    }

}
