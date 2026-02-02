#Requires -Module Pester

<#
.SYNOPSIS
    Cross-version compatibility tests for the ConnectWiseAutomateAgent module.

.DESCRIPTION
    Verifies that the module loads and core functions work correctly under every
    PowerShell version available on the test machine. Each version is tested by
    spawning a child process (powershell.exe for 5.1, pwsh.exe for 7+).

    Tests three loading methods per PowerShell version:
    - Module Import: Import-Module from .psd1 manifest (PSGallery install path)
    - SingleFile Dot-Source: . .\ConnectWiseAutomateAgent.ps1 (local file execution)
    - SingleFile Invoke-Expression: Get-Content | IEX (web download path — the primary
      method for systems without gallery access: Invoke-RestMethod <url> | IEX)

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

    # Check if single-file build exists (needed for SingleFile contexts)
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $script:SingleFileExists = Test-Path (Join-Path $repoRoot 'output\ConnectWiseAutomateAgent.ps1')
}

BeforeAll {
    $ModuleName = 'ConnectWiseAutomateAgent'
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $script:ModulePsd1 = Join-Path $ModuleRoot "source\$ModuleName.psd1"
    $script:SingleFilePath = Join-Path $ModuleRoot "output\$ModuleName.ps1"

    # Helper: Run a verification script in a child process and parse JSON output.
    # Defined inside BeforeAll so Pester 5 scoping makes it available to test blocks.
    function script:Invoke-ChildProcessTest {
        param(
            [string]$Executable,
            [string]$Script
        )

        $rawOutput = & $Executable -NoProfile -NonInteractive -Command $Script 2>&1

        # Extract the JSON object (compressed JSON is a single line starting with {)
        $allOutput = ($rawOutput | Out-String).Trim()
        $jsonLine = ($allOutput -split "`n" | Where-Object { $_.Trim() -match '^\{' } | Select-Object -Last 1)

        if ($jsonLine) {
            return ($jsonLine.Trim() | ConvertFrom-Json)
        }
        else {
            return [PSCustomObject]@{
                Success       = $false
                LoadMethod    = 'Unknown'
                ModuleLoaded  = $false
                ImportError   = "No JSON in child output: $allOutput"
                PSVersion     = 'Unknown'
                PSEdition     = 'Unknown'
                FunctionCount = 0
                AliasCount    = 0
                Functions     = @()
                Aliases       = @()
                EncryptDecrypt = $false
                TestErrors    = @()
            }
        }
    }
}

# =============================================================================
# Cross-Version Module Import (PSGallery path)
# =============================================================================
Describe 'Cross-Version Compatibility - Module Import' {

    Context '<Name> - Module Import' -ForEach $script:PSVersions {

        BeforeAll {
            $currentExe = $Exe
            $modulePath = $script:ModulePsd1

            $verifyScript = @"
`$ErrorActionPreference = 'Stop'
`$results = [ordered]@{
    Success        = `$false
    LoadMethod     = 'Module'
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

            $script:Result = Invoke-ChildProcessTest -Executable $currentExe -Script $verifyScript
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
# Cross-Version SingleFile Dot-Source (local file execution)
# =============================================================================
Describe 'Cross-Version Compatibility - SingleFile Dot-Source' -Skip:(-not $script:SingleFileExists) {

    Context '<Name> - Dot-Source' -ForEach $script:PSVersions {

        BeforeAll {
            $currentExe = $Exe
            $singleFile = $script:SingleFilePath

            # Dot-source the single file in a child process — this is how users run
            # the file locally when they don't have gallery access.
            $verifyScript = @"
`$ErrorActionPreference = 'Stop'
`$results = [ordered]@{
    Success        = `$false
    LoadMethod     = 'DotSource'
    PSVersion      = `$PSVersionTable.PSVersion.ToString()
    PSEdition      = `$PSVersionTable.PSEdition
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
    . '$($singleFile -replace "'","''")'
    `$results.Success = `$true

    # In dot-source mode, functions are in the session scope — find CWAA functions
    `$cwaaFuncs = @(Get-Command -CommandType Function | Where-Object {
        `$_.Name -match '^(Get|Set|New|Install|Uninstall|Start|Stop|Restart|Test|Invoke|ConvertTo|ConvertFrom|Hide|Show|Rename|Redo|Reset|Update|Register|Unregister|Repair)-CWAA'
    })
    `$results.Functions = @(`$cwaaFuncs.Name | Sort-Object)
    `$results.FunctionCount = `$results.Functions.Count

    # Find LT aliases
    `$ltAliases = @(Get-Alias -ErrorAction SilentlyContinue | Where-Object {
        `$_.Name -match '-LT' -or `$_.Name -match 'Reinstall-'
    })
    `$results.Aliases = @(`$ltAliases.Name | Sort-Object)
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
}
Catch {
    `$results.ImportError = `$_.Exception.Message
}

`$results | ConvertTo-Json -Depth 3 -Compress
"@

            $script:Result = Invoke-ChildProcessTest -Executable $currentExe -Script $verifyScript
        }

        It 'reports its PowerShell version' {
            $script:Result.PSVersion | Should -Not -BeNullOrEmpty
        }

        It 'loads the single file without errors' {
            $script:Result.Success | Should -BeTrue -Because $script:Result.ImportError
        }

        It 'makes all 30 public functions available' {
            if (-not $script:Result.Success) { Set-ItResult -Skipped -Because 'single file failed to load' }
            $script:Result.FunctionCount | Should -BeGreaterOrEqual 30
        }

        It 'has the ConvertTo-CWAASecurity function' {
            if (-not $script:Result.Success) { Set-ItResult -Skipped -Because 'single file failed to load' }
            $script:Result.Functions | Should -Contain 'ConvertTo-CWAASecurity'
        }

        It 'has the Install-CWAA function' {
            if (-not $script:Result.Success) { Set-ItResult -Skipped -Because 'single file failed to load' }
            $script:Result.Functions | Should -Contain 'Install-CWAA'
        }

        It 'has legacy aliases available' {
            if (-not $script:Result.Success) { Set-ItResult -Skipped -Because 'single file failed to load' }
            $script:Result.Aliases | Should -Contain 'Install-LTService'
            $script:Result.Aliases | Should -Contain 'ConvertTo-LTSecurity'
        }

        It 'encrypt/decrypt round-trip succeeds' {
            if (-not $script:Result.Success) { Set-ItResult -Skipped -Because 'single file failed to load' }
            $errorDetail = if ($script:Result.TestErrors) { $script:Result.TestErrors -join '; ' } else { 'no errors' }
            $script:Result.EncryptDecrypt | Should -BeTrue -Because $errorDetail
        }
    }
}

# =============================================================================
# Cross-Version SingleFile Invoke-Expression (web download path)
# This is the primary method for systems without gallery access:
#   Invoke-RestMethod 'https://.../ConnectWiseAutomateAgent.ps1' | Invoke-Expression
# =============================================================================
Describe 'Cross-Version Compatibility - SingleFile Invoke-Expression' -Skip:(-not $script:SingleFileExists) {

    Context '<Name> - Invoke-Expression' -ForEach $script:PSVersions {

        BeforeAll {
            $currentExe = $Exe
            $singleFile = $script:SingleFilePath

            # Simulate the IEX web-download path: Get-Content | Invoke-Expression
            # This is different from dot-sourcing — $MyInvocation has no file context,
            # matching how Invoke-RestMethod | Invoke-Expression behaves in production.
            $verifyScript = @"
`$ErrorActionPreference = 'Stop'
`$results = [ordered]@{
    Success        = `$false
    LoadMethod     = 'InvokeExpression'
    PSVersion      = `$PSVersionTable.PSVersion.ToString()
    PSEdition      = `$PSVersionTable.PSEdition
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
    # Read file content as string and execute via IEX — simulates web download
    `$scriptContent = Get-Content '$($singleFile -replace "'","''")' -Raw
    Invoke-Expression `$scriptContent
    `$results.Success = `$true

    # In IEX mode, functions are in the session scope — same as dot-source
    `$cwaaFuncs = @(Get-Command -CommandType Function | Where-Object {
        `$_.Name -match '^(Get|Set|New|Install|Uninstall|Start|Stop|Restart|Test|Invoke|ConvertTo|ConvertFrom|Hide|Show|Rename|Redo|Reset|Update|Register|Unregister|Repair)-CWAA'
    })
    `$results.Functions = @(`$cwaaFuncs.Name | Sort-Object)
    `$results.FunctionCount = `$results.Functions.Count

    # Find LT aliases
    `$ltAliases = @(Get-Alias -ErrorAction SilentlyContinue | Where-Object {
        `$_.Name -match '-LT' -or `$_.Name -match 'Reinstall-'
    })
    `$results.Aliases = @(`$ltAliases.Name | Sort-Object)
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
}
Catch {
    `$results.ImportError = `$_.Exception.Message
}

`$results | ConvertTo-Json -Depth 3 -Compress
"@

            $script:Result = Invoke-ChildProcessTest -Executable $currentExe -Script $verifyScript
        }

        It 'reports its PowerShell version' {
            $script:Result.PSVersion | Should -Not -BeNullOrEmpty
        }

        It 'executes via Invoke-Expression without errors' {
            $script:Result.Success | Should -BeTrue -Because $script:Result.ImportError
        }

        It 'makes all 30 public functions available' {
            if (-not $script:Result.Success) { Set-ItResult -Skipped -Because 'IEX execution failed' }
            $script:Result.FunctionCount | Should -BeGreaterOrEqual 30
        }

        It 'has the ConvertTo-CWAASecurity function' {
            if (-not $script:Result.Success) { Set-ItResult -Skipped -Because 'IEX execution failed' }
            $script:Result.Functions | Should -Contain 'ConvertTo-CWAASecurity'
        }

        It 'has the Install-CWAA function' {
            if (-not $script:Result.Success) { Set-ItResult -Skipped -Because 'IEX execution failed' }
            $script:Result.Functions | Should -Contain 'Install-CWAA'
        }

        It 'has legacy aliases available' {
            if (-not $script:Result.Success) { Set-ItResult -Skipped -Because 'IEX execution failed' }
            $script:Result.Aliases | Should -Contain 'Install-LTService'
            $script:Result.Aliases | Should -Contain 'ConvertTo-LTSecurity'
        }

        It 'encrypt/decrypt round-trip succeeds' {
            if (-not $script:Result.Success) { Set-ItResult -Skipped -Because 'IEX execution failed' }
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

    It 'single-file build exists for SingleFile tests' {
        $script:SingleFilePath | Should -Exist -Because 'Run ./build.ps1 -Tasks build to create the single-file distribution'
    }
}
