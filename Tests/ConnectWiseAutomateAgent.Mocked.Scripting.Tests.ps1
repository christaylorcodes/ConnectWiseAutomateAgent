#Requires -Module Pester

<#
.SYNOPSIS
    Mocked behavioral tests for Scripting helper functions.

.DESCRIPTION
    Tests ConvertTo-CWAAScriptOutput, New-CWAAScriptOutput, Write-CWAAScriptLog,
    Initialize-CWAAScriptLog, New-CWAARemoteMonitor, Invoke-CWAAScript, and
    Invoke-CWAAPwsh using Pester mocks.

    Supports dual-mode testing via $env:CWAA_TEST_LOAD_METHOD.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Mocked.Scripting.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# =============================================================================
# ConvertTo-CWAAScriptOutput
# =============================================================================

Describe 'ConvertTo-CWAAScriptOutput' {

    It 'serializes a PSCustomObject to pipe-delimited format' {
        $obj = [PSCustomObject]@{ Status = 'Success'; Result = 'Done' }
        $result = ConvertTo-CWAAScriptOutput -InputObject $obj
        $result | Should -Match 'Status=Success'
        $result | Should -Match 'Result=Done'
        $result | Should -Match '\|'
    }

    It 'serializes a hashtable to pipe-delimited format' {
        $ht = @{ Status = 'Error'; Result = 'Disk full' }
        $result = ConvertTo-CWAAScriptOutput -InputObject $ht
        $result | Should -Match 'Status=Error'
        $result | Should -Match 'Result=Disk full'
    }

    It 'serializes an ordered dictionary in key order' {
        $result = ConvertTo-CWAAScriptOutput -InputObject ([ordered]@{ Status = 'Error'; Result = 'X'; Data = 'Y' })
        $result | Should -Be 'Status=Error|Result=X|Data=Y'
    }

    It 'excludes PSTypeName from CWAAScriptOutput objects' {
        $obj = [PSCustomObject]@{
            PSTypeName = 'CWAAScriptOutput'
            Status     = 'Success'
            Result     = 'Test'
            LogPath    = ''
            Data       = ''
        }
        $result = ConvertTo-CWAAScriptOutput -InputObject $obj
        $result | Should -Not -Match 'PSTypeName'
        $result | Should -Match 'Status=Success'
    }

    It 'handles empty property values' {
        $obj = [PSCustomObject]@{ Status = 'Success'; Result = '' }
        $result = ConvertTo-CWAAScriptOutput -InputObject $obj
        $result | Should -Match 'Result='
    }

    It 'accepts pipeline input' {
        $obj = [PSCustomObject]@{ Status = 'Failed'; Result = 'Nope' }
        $result = $obj | ConvertTo-CWAAScriptOutput
        $result | Should -Match 'Status=Failed'
    }

    It 'preserves values containing equals signs' {
        $obj = [PSCustomObject]@{ Status = 'Success'; Data = 'Key=Value' }
        $result = ConvertTo-CWAAScriptOutput -InputObject $obj
        $result | Should -Match 'Data=Key=Value'
    }

    It 'preserves values containing pipe characters' {
        $obj = [PSCustomObject]@{ Status = 'Success'; Result = 'line1|line2' }
        $result = ConvertTo-CWAAScriptOutput -InputObject $obj
        # The raw value is embedded as-is — pipe inside a value is not escaped
        $result | Should -Match 'Result=line1\|line2'
    }
}

# =============================================================================
# Aliases
# =============================================================================

Describe 'Scripting aliases' {

    It '<Alias> resolves to <Command>' -ForEach @(
        @{ Alias = 'ConvertTo-AutomateOutput'; Command = 'ConvertTo-CWAAScriptOutput' }
        @{ Alias = 'New-AutomateOutput'; Command = 'New-CWAAScriptOutput' }
        @{ Alias = 'Write-AutomateLog'; Command = 'Write-CWAAScriptLog' }
        @{ Alias = 'Initialize-AutomateLogging'; Command = 'Initialize-CWAAScriptLog' }
        @{ Alias = 'New-CWARemoteMonitor'; Command = 'New-CWAARemoteMonitor' }
        @{ Alias = 'Invoke-CWAScript'; Command = 'Invoke-CWAAScript' }
        @{ Alias = 'Invoke-LTPwsh'; Command = 'Invoke-CWAAPwsh' }
    ) {
        (Get-Alias -Name $Alias -ErrorAction Stop).ReferencedCommand.Name | Should -Be $Command
    }
}

# =============================================================================
# New-CWAAScriptOutput
# =============================================================================

Describe 'New-CWAAScriptOutput' {

    It 'creates an object with default values' {
        $output = New-CWAAScriptOutput
        $output.Status | Should -Be 'Success'
        $output.Result | Should -Be ''
        $output.LogPath | Should -Be ''
        $output.Data | Should -Be ''
    }

    It 'creates an object with specified values' {
        $output = New-CWAAScriptOutput -Status 'Failed' -Result 'Bad' -LogPath 'C:\log.txt' -Data 'key=val'
        $output.Status | Should -Be 'Failed'
        $output.Result | Should -Be 'Bad'
        $output.LogPath | Should -Be 'C:\log.txt'
        $output.Data | Should -Be 'key=val'
    }

    It 'has a ToString ScriptMethod that returns pipe-delimited output' {
        $output = New-CWAAScriptOutput -Status 'Success' -Result 'OK'
        $str = $output.ToString()
        $str | Should -Match 'Status=Success'
        $str | Should -Match 'Result=OK'
        $str | Should -Match '\|'
    }

    It 'has CWAAScriptOutput PSTypeName' {
        $output = New-CWAAScriptOutput
        $output.PSTypeNames | Should -Contain 'CWAAScriptOutput'
    }

    It 'allows mutable properties' {
        $output = New-CWAAScriptOutput
        $output.Status = 'Error'
        $output.Result = 'Something broke'
        $output.Status | Should -Be 'Error'
        $output.Result | Should -Be 'Something broke'
    }

    It 'rejects invalid Status values via parameter validation' {
        { New-CWAAScriptOutput -Status 'Invalid' } | Should -Throw
    }
}

# =============================================================================
# Write-CWAAScriptLog
# =============================================================================

Describe 'Write-CWAAScriptLog' {

    It 'appends a timestamped entry to the log file' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Add-Content {} -ParameterFilter { $LiteralPath -eq 'TestDrive:\test.log' }

            Write-CWAAScriptLog -Message 'Hello world' -LogPath 'TestDrive:\test.log'

            Should -Invoke Add-Content -Times 1
        }
    }

    It 'includes the correct log level in the entry' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            $script:captured = $null
            Mock Add-Content -MockWith { $script:captured = $Value }

            Write-CWAAScriptLog -Message 'Warning msg' -Level WARNING -LogPath 'TestDrive:\test.log'

            $script:captured | Should -Match '\[WARNING\]'
        }
    }

    It 'defaults to INFO level' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            $script:captured = $null
            Mock Add-Content -MockWith { $script:captured = $Value }

            Write-CWAAScriptLog -Message 'Info msg' -LogPath 'TestDrive:\test.log'

            $script:captured | Should -Match '\[INFO\]'
        }
    }

    It 'includes the message text' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            $script:captured = $null
            Mock Add-Content -MockWith { $script:captured = $Value }

            Write-CWAAScriptLog -Message 'Specific message here' -LogPath 'TestDrive:\test.log'

            $script:captured | Should -Match 'Specific message here'
        }
    }

    It 'writes error when file write fails' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Add-Content { throw 'Access denied' }

            { Write-CWAAScriptLog -Message 'Test' -LogPath 'TestDrive:\bad.log' -ErrorAction Stop } |
                Should -Throw
        }
    }

    It 'reports a wrapped error for a real (non-mocked) write failure' {
        $badPath = Join-Path $TestDrive 'missing-dir\x.log'
        { Write-CWAAScriptLog -Message 'Test' -LogPath $badPath -ErrorAction Stop } |
            Should -Throw '*Failed to write to log file*'
    }

    It 'writes to paths containing wildcard characters literally' {
        $path = Join-Path $TestDrive 'Patch[1].log'
        Write-CWAAScriptLog -Message 'bracket' -LogPath $path
        Get-Content -LiteralPath $path | Should -Match 'bracket'
    }
}

# =============================================================================
# Initialize-CWAAScriptLog
# =============================================================================

Describe 'Initialize-CWAAScriptLog' {

    BeforeEach {
        Mock Get-PSCallStack -ModuleName 'ConnectWiseAutomateAgent' { @(
            [PSCustomObject]@{ Command = 'Initialize-CWAAScriptLog' },
            [PSCustomObject]@{ Command = 'TestCaller' }
        )}
    }

    It 'creates a log file and returns its path' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { $true }
            Mock New-Item { [PSCustomObject]@{ FullName = 'TestDrive:\logs\test.log' } }
            Mock Add-Content {}

            $result = Initialize-CWAAScriptLog -LogDirectory 'TestDrive:\logs'

            $result | Should -Not -BeNullOrEmpty
            $result | Should -Match 'TestCaller'
            $result | Should -Match '\.log$'
        }
    }

    It 'creates the log directory when it does not exist' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { $false } -ParameterFilter { $Path -and $Path -notmatch '\.log$' }
            Mock New-Item { [PSCustomObject]@{ FullName = 'TestDrive:\newdir\test.log' } }
            Mock Add-Content {}

            Initialize-CWAAScriptLog -LogDirectory 'TestDrive:\newdir'

            Should -Invoke New-Item -ParameterFilter { $ItemType -eq 'Directory' } -Times 1
        }
    }

    It 'uses custom LogName when provided' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { $true }
            Mock New-Item { [PSCustomObject]@{ FullName = 'TestDrive:\logs\CustomName.log' } }
            Mock Add-Content {}

            $result = Initialize-CWAAScriptLog -LogDirectory 'TestDrive:\logs' -LogName 'CustomName'

            $result | Should -Match 'CustomName'
        }
    }

    It 'writes a header line to the new log file' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { $true }
            Mock New-Item { [PSCustomObject]@{ FullName = 'TestDrive:\logs\test.log' } }
            $script:headerCaptured = $null
            Mock Add-Content { $script:headerCaptured = $Value }

            Initialize-CWAAScriptLog -LogDirectory 'TestDrive:\logs'

            $script:headerCaptured | Should -Match '\[INFO\]'
            $script:headerCaptured | Should -Match 'Log initialized'
        }
    }

    It 'strips characters that are illegal in file names from the derived log name' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Get-PSCallStack { @(
                [PSCustomObject]@{ Command = 'Initialize-CWAAScriptLog' },
                [PSCustomObject]@{ Command = '<ScriptBlock>' }
            )}

            $result = Initialize-CWAAScriptLog -LogDirectory $TestDrive

            $result | Should -Not -BeNullOrEmpty
            Split-Path $result -Leaf | Should -Match '^ScriptBlock_\d{8}-\d{6}\.log$'
            Test-Path -LiteralPath $result | Should -BeTrue
        }
    }

    It 'defaults LogDirectory to the agent install path logs folder' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { $true }
            Mock New-Item { [PSCustomObject]@{} }
            Mock Add-Content {}

            $result = Initialize-CWAAScriptLog

            $result | Should -BeLike "$(Join-Path $Script:CWAAInstallPath 'logs')\*"
        }
    }
}

# =============================================================================
# New-CWAARemoteMonitor
# =============================================================================

Describe 'New-CWAARemoteMonitor' {

    It 'encodes a scriptblock to a Base64 command string' {
        $result = New-CWAARemoteMonitor -ScriptBlock { Get-Service }
        $result | Should -Match 'powershell\.exe'
        $result | Should -Match 'FromBase64String'
    }

    It 'produces output that decodes back to the original scriptblock' {
        $original = 'Get-Service LTService'
        $result = New-CWAARemoteMonitor -ScriptBlock ([scriptblock]::Create($original))

        # Extract the encoded string from the command
        if ($result -match "'([A-Za-z0-9+/=]+)'") {
            $decoded = [System.Text.Encoding]::UTF8.GetString(
                [System.Convert]::FromBase64String($matches[1])
            )
            $decoded | Should -Be $original
        }
        else {
            throw 'Could not extract encoded string from monitor command'
        }
    }

    It 'stays under the 8191 character limit for short scripts' {
        $result = New-CWAARemoteMonitor -ScriptBlock { Get-Date }
        $result.Length | Should -BeLessOrEqual 8191
    }

    It 'throws when the encoded output exceeds 8191 characters' {
        # Generate a scriptblock large enough to exceed the limit
        $longScript = 'A' * 7000
        { New-CWAARemoteMonitor -ScriptBlock ([scriptblock]::Create($longScript)) } |
            Should -Throw '*exceeds*'
    }
}

# =============================================================================
# Invoke-CWAAScript
# =============================================================================

Describe 'Invoke-CWAAScript' {

    It 'returns Success status for a successful scriptblock' {
        $result = Invoke-CWAAScript -ScriptBlock { 'Hello' }
        $result | Should -Match 'Status=Success'
        $result | Should -Match 'Result=Hello'
    }

    It 'returns Error status when the scriptblock throws (never throws to caller)' {
        { $script:result = Invoke-CWAAScript -ScriptBlock { throw 'Boom' } } | Should -Not -Throw
        $script:result | Should -Match 'Status=Error'
        $script:result | Should -Match 'Boom'
    }

    It 'returns Error when the scriptblock writes a non-terminating error' {
        $result = Invoke-CWAAScript -ScriptBlock { Write-Error 'soft failure'; 'after' } 2>$null
        $result | Should -Match 'Status=Error'
        $result | Should -Match 'soft failure'
    }

    It 'returns Error when log initialization fails' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Initialize-CWAAScriptLog { Write-Error 'cannot create log' }

            $result = Invoke-CWAAScript -ScriptBlock { 'ok' } -EnableLogging

            $result | Should -Match 'Status=Error'
            $result | Should -Match 'cannot create log'
        }
    }

    It 'initializes logging when EnableLogging is specified' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Initialize-CWAAScriptLog { 'TestDrive:\mock.log' }

            $result = Invoke-CWAAScript -ScriptBlock { 'test' } -EnableLogging

            Should -Invoke Initialize-CWAAScriptLog -Times 1 -ParameterFilter { -not $PSBoundParameters.ContainsKey('LogDirectory') }
            $result | Should -Match 'LogPath=TestDrive:\\mock\.log'
        }
    }

    It 'passes LogDirectory through to Initialize-CWAAScriptLog when specified' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Initialize-CWAAScriptLog { 'TestDrive:\custom\mock.log' }

            $null = Invoke-CWAAScript -ScriptBlock { 'test' } -EnableLogging -LogDirectory 'TestDrive:\custom'

            Should -Invoke Initialize-CWAAScriptLog -Times 1 -ParameterFilter { $LogDirectory -eq 'TestDrive:\custom' }
        }
    }

    It 'logs errors when logging is enabled and scriptblock fails' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Initialize-CWAAScriptLog { 'TestDrive:\mock.log' }
            Mock Write-CWAAScriptLog {}

            Invoke-CWAAScript -ScriptBlock { throw 'LogMe' } -EnableLogging

            Should -Invoke Write-CWAAScriptLog -ParameterFilter { $Level -eq 'ERROR' } -Times 1
        }
    }

    It 'returns Error status without logging when scriptblock throws' {
        $result = Invoke-CWAAScript -ScriptBlock { throw 'NoLog' }
        $result | Should -Match 'Status=Error'
        $result | Should -Match 'NoLog'
        $result | Should -Match 'LogPath='
    }

    It 'fetches and executes a remote script via URL' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Invoke-RestMethod { "'RemoteResult'" } -ParameterFilter { $Uri -eq 'https://example.com/test.ps1' }

            $result = Invoke-CWAAScript -URL 'https://example.com/test.ps1'

            Should -Invoke Invoke-RestMethod -Times 1
            $result | Should -Match 'Status=Success'
            $result | Should -Match 'RemoteResult'
        }
    }

    It 'returns Error when URL fetch fails' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Invoke-RestMethod { throw 'Network error' } -ParameterFilter { $Uri -eq 'https://example.com/bad.ps1' }

            $result = Invoke-CWAAScript -URL 'https://example.com/bad.ps1'

            $result | Should -Match 'Status=Error'
            $result | Should -Match 'Network error'
        }
    }

    It 'rejects a URL without https:// (<URL>)' -ForEach @(
        @{ URL = 'example.com/script.ps1' }
        @{ URL = 'http://example.com/script.ps1' }
    ) {
        { Invoke-CWAAScript -URL $URL } | Should -Throw
    }
}

# =============================================================================
# Invoke-CWAAPwsh
# =============================================================================

Describe 'Invoke-CWAAPwsh' {

    It 'returns formatted Error output when pwsh.exe is not found' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { $false }
            Mock Get-Command { $null }

            $result = Invoke-CWAAPwsh -ScriptBlock { 'test' }

            $result | Should -Match 'Status=Error'
            $result | Should -Match 'Result=.*pwsh.*not found'
        }
    }

    It 'returns Error when the specified PwshPath does not exist' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { $false } -ParameterFilter { $Path -eq 'C:\nonexistent\pwsh.exe' }

            $result = Invoke-CWAAPwsh -ScriptBlock { 'test' } -PwshPath 'C:\nonexistent\pwsh.exe'

            $result | Should -Match 'Status=Error'
            $result | Should -Match 'does not exist'
        }
    }

    It 'checks default Program Files path before system PATH' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            # PwshPath not specified, default path does not exist, PATH has pwsh
            Mock Test-Path { $false } -ParameterFilter { $PathType -eq 'Leaf' }
            Mock Get-Command {
                [PSCustomObject]@{ Source = 'C:\from\path\pwsh.exe' }
            } -ParameterFilter { $Name -eq 'pwsh' }

            # Launching the mocked PATH result fails; the point is that Get-Command was consulted
            $null = Invoke-CWAAPwsh -ScriptBlock { 'test' }

            Should -Invoke Get-Command -Times 1
        }
    }

    It 'refuses a PATH pwsh.exe that is not validly signed by Microsoft' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Test-Path { $false } -ParameterFilter { $PathType -eq 'Leaf' }
            Mock Get-Command { [PSCustomObject]@{ Source = 'C:\Users\Public\pwsh.exe' } } -ParameterFilter { $Name -eq 'pwsh' }
            Mock Get-AuthenticodeSignature { [PSCustomObject]@{ Status = 'NotSigned'; SignerCertificate = $null } }

            $result = Invoke-CWAAPwsh -ScriptBlock { 'test' }

            $result | Should -Match 'Status=Error'
            $result | Should -Match 'not validly signed'
        }
    }

    It 'returns Error with descriptive message when valid PwshPath cannot execute' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            # Test-Path says the file exists, but execution will fail (mocked path)
            Mock Test-Path { $true } -ParameterFilter { $Path -eq 'C:\fake\pwsh.exe' -and $PathType -eq 'Leaf' }

            $result = Invoke-CWAAPwsh -ScriptBlock { 'test' } -PwshPath 'C:\fake\pwsh.exe'

            $result | Should -Match 'Status=Error'
            $result | Should -Match 'Result=.+'
        }
    }

    It 'rejects FilePath that does not exist via ValidateScript' {
        { Invoke-CWAAPwsh -FilePath 'C:\nonexistent\script.ps1' } | Should -Throw
    }

    # Note: stderr handling (Data property population, $LASTEXITCODE paths) requires
    # a real pwsh.exe process and belongs in integration/live tests.
}
