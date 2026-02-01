#Requires -Module Pester

<#
.SYNOPSIS
    Documentation structure and build script tests.

.DESCRIPTION
    Tests the documentation folder layout, auto-generated function reference,
    MAML help, and build script functionality including Extract-ChangelogEntry.

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
        $BuildScript = Join-Path $ModuleRoot 'Build\Build-Documentation.ps1'
        # Use the known list of public functions for doc checks. In single-file mode,
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

        It 'Extract-ChangelogEntry.ps1 exists' {
            $extractScript = Join-Path $ModuleRoot 'Build\Extract-ChangelogEntry.ps1'
            $extractScript | Should -Exist
        }

        It 'Extract-ChangelogEntry.ps1 has comment-based help' {
            $extractScript = Join-Path $ModuleRoot 'Build\Extract-ChangelogEntry.ps1'
            $scriptContent = Get-Content $extractScript -Raw
            $scriptContent | Should -Match '\.SYNOPSIS' -Because 'build scripts should have comment-based help'
        }

        It 'Extract-ChangelogEntry.ps1 requires -Version parameter' {
            $extractScript = Join-Path $ModuleRoot 'Build\Extract-ChangelogEntry.ps1'
            $scriptContent = Get-Content $extractScript -Raw
            $scriptContent | Should -Match '\[Parameter\(Mandatory' -Because 'Version should be mandatory'
        }
    }
}

# =============================================================================
# Extract-ChangelogEntry Functional Tests
# =============================================================================
Describe 'Extract-ChangelogEntry.ps1' {

    BeforeAll {
        $ModuleRoot = Split-Path -Parent $PSScriptRoot
        $ExtractScript = Join-Path $ModuleRoot 'Build\Extract-ChangelogEntry.ps1'
    }

    Context 'Extracts known versions from CHANGELOG.md' {
        It 'extracts the 1.0.0-alpha001 entry' {
            $result = & $ExtractScript -Version '1.0.0-alpha001'
            $joined = $result -join "`n"
            $joined | Should -Match 'Health check and auto-remediation system' -Because 'the alpha001 entry contains health check content'
            $joined | Should -Not -Match '## \[0\.1\.4\.0\]' -Because 'extraction should stop before the next version heading'
        }

        It 'extracts the 0.1.4.0 entry' {
            $result = & $ExtractScript -Version '0.1.4.0'
            $joined = $result -join "`n"
            $joined | Should -Match 'Initial public release' -Because 'the 0.1.4.0 entry describes the initial release'
            $joined | Should -Not -Match '1\.0\.0-alpha001' -Because 'extraction should not include content from other versions'
        }

        It 'preserves nested ### headings within the entry' {
            $result = & $ExtractScript -Version '1.0.0-alpha001'
            $joined = $result -join "`n"
            $joined | Should -Match '### Added' -Because 'subsection headings should be preserved'
            $joined | Should -Match '### Changed' -Because 'subsection headings should be preserved'
        }
    }

    Context 'Error handling' {
        It 'fails for a nonexistent version' {
            { & $ExtractScript -Version '9.9.9' -ErrorAction Stop } | Should -Throw
        }

        It 'fails for a nonexistent changelog path' {
            { & $ExtractScript -Version '1.0.0' -ChangelogPath 'C:\nonexistent\CHANGELOG.md' -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'OutputPath parameter' {
        It 'writes to a file when -OutputPath is specified' {
            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "changelog-test-$(Get-Random).md"
            try {
                & $ExtractScript -Version '1.0.0-alpha001' -OutputPath $tempFile
                $tempFile | Should -Exist
                $content = Get-Content $tempFile -Raw
                $content | Should -Match 'Health check and auto-remediation system'
            }
            finally {
                if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
            }
        }
    }
}
