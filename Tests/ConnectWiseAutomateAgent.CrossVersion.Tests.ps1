#Requires -Module Pester

<#
.SYNOPSIS
    Cross-version compatibility tests for the ConnectWiseAutomateAgent module.

.DESCRIPTION
    Verifies that the module loads and core functions work correctly under every
    PowerShell version available on the test machine. Each version is tested by
    spawning a child process (powershell.exe for 5.1, pwsh.exe for 7+) that
    imports the module and returns structured results as JSON.

    The module targets PowerShell 3.0+ but these tests exercise whichever
    versions are installed. Versions not present are skipped automatically.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.CrossVersion.Tests.ps1 -Output Detailed

    This test file is designed to run from PowerShell 7 (pwsh) as the test host.
#>

# BeforeDiscovery runs at discovery time so -ForEach data is available for test generation.
BeforeDiscovery {
    $script:PSVersions = @()

    # Windows PowerShell 5.1
    $ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path $ps51) {
        $script:PSVersions += @{ Name = 'Windows PowerShell 5.1'; Exe = $ps51 }
    }

    # PowerShell 7 (stable)
    $ps7 = Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Source -First 1
    if ($ps7 -and (Test-Path $ps7)) {
        $script:PSVersions += @{ Name = 'PowerShell 7 stable'; Exe = $ps7 }
    }

    # PowerShell 7 (preview) — only if it's a different binary from stable
    $ps7preview = Join-Path $env:ProgramFiles 'PowerShell\7-preview\pwsh.exe'
    if ((Test-Path $ps7preview) -and $ps7preview -ne $ps7) {
        $script:PSVersions += @{ Name = 'PowerShell 7 preview'; Exe = $ps7preview }
    }
}

BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $script:ModulePsd1 = Join-Path $ModuleRoot 'ConnectWiseAutomateAgent\ConnectWiseAutomateAgent.psd1'
}

# =============================================================================
# Cross-Version Module Loading
# =============================================================================
Describe 'Cross-Version Compatibility' {

    Context '<Name>' -ForEach $script:PSVersions {

        BeforeAll {
            $currentExe = $Exe
            $modulePath = $script:ModulePsd1

            # Build the verification script as a here-string with the module path baked in.
            # This script runs inside the child process, imports the module, and returns JSON.
            $verifyScript = @"
`$ErrorActionPreference = 'Stop'
`$results = [ordered]@{
    Success        = `$false
    PSVersion      = `$PSVersionTable.PSVersion.ToString()
    PSEdition      = `$PSVersionTable.PSEdition
    ModuleLoaded   = `$false
    ModuleVersion  = ''
    FunctionCount  = 0
    AliasCount     = 0
    Functions      = @()
    Aliases        = @()
    EncryptDecrypt = `$false
    ImportError    = ''
    TestErrors     = @()
}
if (-not `$results.PSEdition) { `$results.PSEdition = 'Desktop' }

Try {
    Import-Module '$($modulePath -replace "'","''")' -Force -ErrorAction Stop
    `$results.ModuleLoaded = `$true

    `$mod = Get-Module 'ConnectWiseAutomateAgent'
    `$results.ModuleVersion = `$mod.Version.ToString()
    `$results.Functions = @(`$mod.ExportedFunctions.Keys | Sort-Object)
    `$results.FunctionCount = `$results.Functions.Count
    `$results.Aliases = @(`$mod.ExportedAliases.Keys | Sort-Object)
    `$results.AliasCount = `$results.Aliases.Count

    Try {
        `$encoded = ConvertTo-CWAASecurity -InputString 'CrossVersionTest'
        `$decoded = ConvertFrom-CWAASecurity -InputString `$encoded
        `$results.EncryptDecrypt = (`$decoded -eq 'CrossVersionTest')
        if (-not `$results.EncryptDecrypt) {
            `$results.TestErrors += "Round-trip mismatch: got '`$decoded'"
        }
    }
    Catch {
        `$results.TestErrors += "Crypto error: `$(`$_.Exception.Message)"
    }

    `$results.Success = `$true
}
Catch {
    `$results.ImportError = `$_.Exception.Message
}

`$results | ConvertTo-Json -Depth 3 -Compress
"@

            # Spawn the child process and capture output
            $rawOutput = & $currentExe -NoProfile -NonInteractive -Command $verifyScript 2>&1

            # The output may contain warnings/progress before the JSON line.
            # Extract the JSON object (the compressed JSON will be a single line starting with {).
            $allOutput = ($rawOutput | Out-String).Trim()
            $jsonLine = ($allOutput -split "`n" | Where-Object { $_.Trim() -match '^\{' } | Select-Object -Last 1)

            if ($jsonLine) {
                $script:Result = $jsonLine.Trim() | ConvertFrom-Json
            }
            else {
                $script:Result = [PSCustomObject]@{
                    Success        = $false
                    ModuleLoaded   = $false
                    ImportError    = "No JSON in child output: $allOutput"
                    PSVersion      = 'Unknown'
                    PSEdition      = 'Unknown'
                    FunctionCount  = 0
                    AliasCount     = 0
                    Functions      = @()
                    Aliases        = @()
                    EncryptDecrypt = $false
                    TestErrors     = @()
                }
            }
        }

        It 'reports its PowerShell version' {
            $script:Result.PSVersion | Should -Not -BeNullOrEmpty
        }

        It 'imports the module without errors' {
            $script:Result.ModuleLoaded | Should -BeTrue -Because $script:Result.ImportError
        }

        It 'reports the expected module version' {
            if (-not $script:Result.ModuleLoaded) { Set-ItResult -Skipped -Because 'module failed to import' }
            $expectedVersion = (Import-PowerShellDataFile $script:ModulePsd1).ModuleVersion
            $script:Result.ModuleVersion | Should -Be $expectedVersion
        }

        It 'exports all 30 functions' {
            if (-not $script:Result.ModuleLoaded) { Set-ItResult -Skipped -Because 'module failed to import' }
            $script:Result.FunctionCount | Should -Be 30
        }

        It 'exports all 32 aliases' {
            if (-not $script:Result.ModuleLoaded) { Set-ItResult -Skipped -Because 'module failed to import' }
            $script:Result.AliasCount | Should -Be 32
        }

        It 'exports the ConvertTo-CWAASecurity function' {
            if (-not $script:Result.ModuleLoaded) { Set-ItResult -Skipped -Because 'module failed to import' }
            $script:Result.Functions | Should -Contain 'ConvertTo-CWAASecurity'
        }

        It 'exports the ConvertFrom-CWAASecurity function' {
            if (-not $script:Result.ModuleLoaded) { Set-ItResult -Skipped -Because 'module failed to import' }
            $script:Result.Functions | Should -Contain 'ConvertFrom-CWAASecurity'
        }

        It 'exports the Install-CWAA function' {
            if (-not $script:Result.ModuleLoaded) { Set-ItResult -Skipped -Because 'module failed to import' }
            $script:Result.Functions | Should -Contain 'Install-CWAA'
        }

        It 'exports the Uninstall-CWAA function' {
            if (-not $script:Result.ModuleLoaded) { Set-ItResult -Skipped -Because 'module failed to import' }
            $script:Result.Functions | Should -Contain 'Uninstall-CWAA'
        }

        It 'exports the Install-LTService alias' {
            if (-not $script:Result.ModuleLoaded) { Set-ItResult -Skipped -Because 'module failed to import' }
            $script:Result.Aliases | Should -Contain 'Install-LTService'
        }

        It 'exports the ConvertTo-LTSecurity alias' {
            if (-not $script:Result.ModuleLoaded) { Set-ItResult -Skipped -Because 'module failed to import' }
            $script:Result.Aliases | Should -Contain 'ConvertTo-LTSecurity'
        }

        It 'encrypt/decrypt round-trip succeeds' {
            if (-not $script:Result.ModuleLoaded) { Set-ItResult -Skipped -Because 'module failed to import' }
            $errorDetail = if ($script:Result.TestErrors) { $script:Result.TestErrors -join '; ' } else { 'no errors' }
            $script:Result.EncryptDecrypt | Should -BeTrue -Because $errorDetail
        }
    }
}

# =============================================================================
# Version Coverage Summary
# =============================================================================
Describe 'Version Coverage' {

    It 'powershell.exe (5.1) is available on this machine' {
        $ps51 = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        Test-Path $ps51 | Should -BeTrue -Because 'Windows PowerShell 5.1 should be present'
    }

    It 'pwsh.exe (7+) is available on this machine' {
        $ps7 = Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue
        $ps7 | Should -Not -BeNullOrEmpty -Because 'PowerShell 7 should be installed for cross-version testing'
    }
}
