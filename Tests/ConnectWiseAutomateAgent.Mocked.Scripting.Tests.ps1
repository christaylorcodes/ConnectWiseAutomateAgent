#Requires -Module Pester

<#
.SYNOPSIS
    Mocked behavioral tests for Scripting helper functions.

.DESCRIPTION
    Tests ConvertTo-CWAAScriptOutput, New-CWAAScriptOutput, Write-CWAAScriptLog,
    Initialize-CWAAScriptLog, New-CWAARemoteMonitor, Invoke-CWAAScript, and
    Invoke-CWAAPwsh using Pester mocks.

    Invoke-CWAAPwsh process handling is exercised with a real child process by passing
    the current PowerShell executable as -PwshPath (powershell.exe and pwsh.exe both
    accept -NoProfile -NonInteractive -EncodedCommand), so no PowerShell 7 install is needed.

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
        ConvertTo-CWAAScriptOutput -InputObject $obj | Should -Be 'Status=Success|Result=Done'
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

    It 'serializes a CWAAScriptOutput object to exactly the four standard fields' {
        ConvertTo-CWAAScriptOutput -InputObject (New-CWAAScriptOutput) | Should -Be 'Status=Success|Result=|LogPath=|Data='
    }

    It 'accepts pipeline input' {
        $obj = [PSCustomObject]@{ Status = 'Failed'; Result = 'Nope' }
        $obj | ConvertTo-CWAAScriptOutput | Should -Be 'Status=Failed|Result=Nope'
    }

    It 'preserves values containing equals signs' {
        $obj = [PSCustomObject]@{ Status = 'Success'; Data = 'Key=Value' }
        ConvertTo-CWAAScriptOutput -InputObject $obj | Should -Be 'Status=Success|Data=Key=Value'
    }

    It 'replaces pipe characters in values so they cannot add fields' {
        $obj = [PSCustomObject]@{ Status = 'Success'; Result = 'a|Status=Fake' }
        ConvertTo-CWAAScriptOutput -InputObject $obj | Should -Be 'Status=Success|Result=a/Status=Fake'
    }

    It 'collapses line breaks in values into a single line' {
        $obj = [PSCustomObject]@{ Status = 'Success'; Result = "line1`r`nline2`nline3`r" }
        ConvertTo-CWAAScriptOutput -InputObject $obj | Should -Be 'Status=Success|Result=line1 / line2 / line3'
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

    It 'has a ToString ScriptMethod that returns the exact pipe-delimited output' {
        (New-CWAAScriptOutput -Status 'Success' -Result 'Completed').ToString() |
            Should -Be 'Status=Success|Result=Completed|LogPath=|Data='
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

    It 'writes an entry in the [timestamp] [LEVEL] Message format' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            $script:captured = $null
            Mock Add-Content -MockWith { $script:captured = $Value } -ParameterFilter { $LiteralPath -eq 'TestDrive:\test.log' }

            Write-CWAAScriptLog -Message 'Hello world' -LogPath 'TestDrive:\test.log'

            $script:captured | Should -Match '^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO\] Hello world$'
        }
    }

    It 'includes the correct log level in the entry' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            $script:captured = $null
            Mock Add-Content -MockWith { $script:captured = $Value }

            Write-CWAAScriptLog -Message 'Warning msg' -Level WARNING -LogPath 'TestDrive:\test.log'

            $script:captured | Should -Match '\[WARNING\] Warning msg$'
        }
    }

    It 'indents continuation lines so a message cannot forge a new entry' {
        $path = Join-Path $TestDrive 'multiline.log'
        Write-CWAAScriptLog -Message "first`n[2000-01-01 00:00:00] [ERROR] forged" -LogPath $path
        $lines = @(Get-Content -LiteralPath $path)
        $lines.Count | Should -Be 2
        $lines[1] | Should -Be '    [2000-01-01 00:00:00] [ERROR] forged'
    }

    It 'writes one line per pipeline input' {
        $path = Join-Path $TestDrive 'pipeline.log'
        'a', 'b' | Write-CWAAScriptLog -LogPath $path
        $lines = @(Get-Content -LiteralPath $path)
        $lines.Count | Should -Be 2
        $lines[0] | Should -Match '\[INFO\] a$'
        $lines[1] | Should -Match '\[INFO\] b$'
    }

    It 'writes error when file write fails' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Add-Content { throw 'Access denied' }

            { Write-CWAAScriptLog -Message 'Test' -LogPath 'TestDrive:\bad.log' -ErrorAction Stop } |
                Should -Throw '*Access denied*'
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
                [PSCustomObject]@{ Command = 'TestCaller.ps1' }
            ) }
    }

    It 'creates a log file named after the caller and returns its path' {
        $dir = Join-Path $TestDrive 'logs-basic'
        $null = New-Item -Path $dir -ItemType Directory

        $result = Initialize-CWAAScriptLog -LogDirectory $dir

        Split-Path $result -Leaf | Should -Match '^TestCaller_\d{8}-\d{6}-\d{3}\.log$'
        Test-Path -LiteralPath $result | Should -BeTrue
    }

    It 'writes a header line to the new log file' {
        $result = Initialize-CWAAScriptLog -LogDirectory (Join-Path $TestDrive 'logs-header')
        Get-Content -LiteralPath $result | Should -Match '^\[.+\] \[INFO\] Log initialized: TestCaller$'
    }

    It 'creates the log directory when it does not exist' {
        $dir = Join-Path $TestDrive 'new\nested'
        $result = Initialize-CWAAScriptLog -LogDirectory $dir
        Test-Path -LiteralPath $dir -PathType Container | Should -BeTrue
        Split-Path $result -Parent | Should -Be $dir
    }

    It 'uses custom LogName when provided' {
        $result = Initialize-CWAAScriptLog -LogDirectory $TestDrive -LogName 'CustomName'
        Split-Path $result -Leaf | Should -Match '^CustomName_'
    }

    It 'strips characters that are illegal in file names from the derived log name' {
        Mock Get-PSCallStack -ModuleName 'ConnectWiseAutomateAgent' { @(
                [PSCustomObject]@{ Command = 'Initialize-CWAAScriptLog' },
                [PSCustomObject]@{ Command = '<ScriptBlock>' }
            ) }

        $result = Initialize-CWAAScriptLog -LogDirectory $TestDrive

        Split-Path $result -Leaf | Should -Match '^ScriptBlock_\d{8}-\d{6}-\d{3}\.log$'
        Test-Path -LiteralPath $result | Should -BeTrue
    }

    It 'falls back to CWAAScript when the name has no legal characters' {
        $result = Initialize-CWAAScriptLog -LogDirectory $TestDrive -LogName '<>'
        Split-Path $result -Leaf | Should -Match '^CWAAScript_'
    }

    It 'refuses to reuse a file that already exists at the log path' {
        Mock Get-Date -ModuleName 'ConnectWiseAutomateAgent' { '20260101-000000-000' } -ParameterFilter { $Format -eq 'yyyyMMdd-HHmmss-fff' }
        $existing = Join-Path $TestDrive 'Planted_20260101-000000-000.log'
        Set-Content -LiteralPath $existing -Value 'planted'

        $result = Initialize-CWAAScriptLog -LogDirectory $TestDrive -LogName 'Planted' -ErrorVariable ev -ErrorAction SilentlyContinue

        $result | Should -BeNullOrEmpty
        "$ev" | Should -Match 'Failed to initialize script log'
        Get-Content -LiteralPath $existing | Should -Be 'planted'
    }

    It 'returns nothing and writes an error when the directory cannot be created' {
        $file = Join-Path $TestDrive 'afile'
        Set-Content -LiteralPath $file -Value 'x'

        $result = Initialize-CWAAScriptLog -LogDirectory (Join-Path $file 'sub') -ErrorVariable ev -ErrorAction SilentlyContinue

        $result | Should -BeNullOrEmpty
        "$ev" | Should -Match 'Failed to initialize script log'
    }

    It 'defaults LogDirectory to the agent install path logs folder' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            $originalInstallPath = $Script:CWAAInstallPath
            $Script:CWAAInstallPath = Join-Path $TestDrive 'LTSVC'
            try {
                $result = Initialize-CWAAScriptLog
                $result | Should -BeLike "$(Join-Path $Script:CWAAInstallPath 'logs')\*"
            }
            finally {
                $Script:CWAAInstallPath = $originalInstallPath
            }
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

    It 'produces a command line that runs the scriptblock through cmd.exe' {
        $result = New-CWAARemoteMonitor -ScriptBlock { 'monitor-' + 'ok' }
        $output = cmd.exe /c $result
        ($output | Out-String).Trim() | Should -Be 'monitor-ok'
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

    It 'returns the exact Success output for a successful scriptblock' {
        Invoke-CWAAScript -ScriptBlock { 'Hello' } | Should -Be 'Status=Success|Result=Hello|LogPath=|Data='
    }

    It 'returns Error status when the scriptblock throws (never throws to caller)' {
        { $script:result = Invoke-CWAAScript -ScriptBlock { throw 'Boom' } } | Should -Not -Throw
        $script:result | Should -Be 'Status=Error|Result=Boom|LogPath=|Data='
    }

    It 'returns Error for a non-terminating error, keeps partial output, and emits nothing else' {
        $output = @(Invoke-CWAAScript -ScriptBlock { 'before'; Write-Error 'soft failure' -ErrorAction Continue; 'after' } 2>&1)
        $output.Count | Should -Be 1
        $output[0] | Should -BeOfType [string]
        $output[0] | Should -Be 'Status=Error|Result=soft failure|LogPath=|Data=Output=before / after'
    }

    It 'keeps output produced before a terminating error' {
        Invoke-CWAAScript -ScriptBlock { 'before'; throw 'hard failure'; 'never' } |
            Should -Be 'Status=Error|Result=hard failure|LogPath=|Data=Output=before'
    }

    It 'keeps multi-line and pipe-containing output on one line without spoofable fields' {
        Invoke-CWAAScript -ScriptBlock { 'a|b'; 'Status=Fake' } |
            Should -Be 'Status=Success|Result=a/b / Status=Fake|LogPath=|Data='
    }

    It 'still runs the scriptblock when log initialization fails' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Initialize-CWAAScriptLog { throw 'cannot create log' }

            $result = Invoke-CWAAScript -ScriptBlock { 'ok' } -EnableLogging

            $result | Should -Be 'Status=Success|Result=ok|LogPath=|Data=LogInitFailed=cannot create log'
        }
    }

    It 'initializes logging when EnableLogging is specified' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Initialize-CWAAScriptLog { 'TestDrive:\mock.log' }

            $result = Invoke-CWAAScript -ScriptBlock { 'test' } -EnableLogging

            Should -Invoke Initialize-CWAAScriptLog -Times 1 -ParameterFilter { -not $PSBoundParameters.ContainsKey('LogDirectory') }
            $result | Should -Be 'Status=Success|Result=test|LogPath=TestDrive:\mock.log|Data='
        }
    }

    It 'names the log after its caller rather than after Invoke-CWAAScript' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Initialize-CWAAScriptLog { 'TestDrive:\mock.log' }

            $null = Invoke-CWAAScript -ScriptBlock { 'test' } -EnableLogging

            Should -Invoke Initialize-CWAAScriptLog -Times 1 -ParameterFilter { $LogName -and $LogName -ne 'Invoke-CWAAScript' }
        }
    }

    It 'passes LogName and LogDirectory through to Initialize-CWAAScriptLog when specified' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Initialize-CWAAScriptLog { 'TestDrive:\custom\mock.log' }

            $null = Invoke-CWAAScript -ScriptBlock { 'test' } -EnableLogging -LogDirectory 'TestDrive:\custom' -LogName 'MyScript'

            Should -Invoke Initialize-CWAAScriptLog -Times 1 -ParameterFilter { $LogDirectory -eq 'TestDrive:\custom' -and $LogName -eq 'MyScript' }
        }
    }

    It 'logs errors with the stack trace when logging is enabled and scriptblock fails' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Initialize-CWAAScriptLog { 'TestDrive:\mock.log' }
            Mock Write-CWAAScriptLog {}

            $null = Invoke-CWAAScript -ScriptBlock { throw 'LogMe' } -EnableLogging

            Should -Invoke Write-CWAAScriptLog -Times 1 -ParameterFilter {
                $Level -eq 'ERROR' -and $LogPath -eq 'TestDrive:\mock.log' -and $Message -match 'LogMe' -and $Message -match 'at '
            }
        }
    }

    It 'returns formatted output even when the error log write fails under -ErrorAction Stop' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Initialize-CWAAScriptLog { 'TestDrive:\mock.log' }
            Mock Write-CWAAScriptLog { throw 'disk full' }

            { $script:result = Invoke-CWAAScript -ScriptBlock { throw 'boom' } -EnableLogging -ErrorAction Stop } | Should -Not -Throw

            $script:result | Should -Be 'Status=Error|Result=boom|LogPath=TestDrive:\mock.log|Data=LogWriteFailed=disk full'
        }
    }

    It 'fetches and executes a remote script via URL' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Invoke-RestMethod { "'RemoteResult'" } -ParameterFilter { $Uri -eq 'https://example.com/test.ps1' }

            $result = Invoke-CWAAScript -URL 'https://example.com/test.ps1'

            Should -Invoke Invoke-RestMethod -Times 1
            $result | Should -Be 'Status=Success|Result=RemoteResult|LogPath=|Data='
        }
    }

    It 'returns Error when URL fetch fails' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Invoke-RestMethod { throw 'Network error' } -ParameterFilter { $Uri -eq 'https://example.com/bad.ps1' }

            $result = Invoke-CWAAScript -URL 'https://example.com/bad.ps1'

            $result | Should -Match '^Status=Error\|Result=Network error\|'
        }
    }

    It 'returns Error when the remote script is <Case>' -ForEach @(
        @{ Case = 'empty'; Body = '' }
        @{ Case = 'whitespace'; Body = "  `n " }
        @{ Case = 'not text'; Body = [PSCustomObject]@{ a = 1 } }
    ) {
        InModuleScope 'ConnectWiseAutomateAgent' -Parameters @{ Body = $Body } {
            param($Body)
            Mock Invoke-RestMethod { $Body }

            $result = Invoke-CWAAScript -URL 'https://example.com/empty.ps1'

            $result | Should -Match '^Status=Error\|Result=Remote script .* was empty or not text'
        }
    }

    It 'returns Error without throwing when the remote script has a syntax error' {
        InModuleScope 'ConnectWiseAutomateAgent' {
            Mock Invoke-RestMethod { 'if (' }

            { $script:result = Invoke-CWAAScript -URL 'https://example.com/broken.ps1' } | Should -Not -Throw
            $script:result | Should -Match '^Status=Error\|'
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

    BeforeAll {
        # The current PowerShell executable stands in for pwsh.exe in real-process tests
        $script:HostExe = (Get-Process -Id $PID).Path
    }

    Context 'locating pwsh.exe' {

        It 'returns formatted Error output when pwsh.exe is not found' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { $false }

                $result = Invoke-CWAAPwsh -ScriptBlock { 'test' }

                $result | Should -Match '^Status=Error\|Result=PowerShell 7 \(pwsh\.exe\) was not found'
            }
        }

        It 'never searches the system PATH' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Test-Path { $false }
                Mock Get-Command { [PSCustomObject]@{ Source = 'C:\Users\Public\pwsh.exe' } }

                $null = Invoke-CWAAPwsh -ScriptBlock { 'test' }

                Should -Invoke Get-Command -Times 0 -Exactly
            }
        }

        It 'checks the 64-bit Program Files location (ProgramW6432) first' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                $originalW6432 = $env:ProgramW6432
                $env:ProgramW6432 = 'X:\PF64'
                try {
                    Mock Test-Path { $true } -ParameterFilter { $LiteralPath -eq 'X:\PF64\PowerShell\7\pwsh.exe' }
                    Mock Test-Path { $false } -ParameterFilter { $LiteralPath -ne 'X:\PF64\PowerShell\7\pwsh.exe' }

                    # Launch fails (the path is fake), but the error proves which path was chosen
                    $result = Invoke-CWAAPwsh -ScriptBlock { 'test' }

                    $result | Should -Match '^Status=Error\|'
                    $result | Should -Match ([regex]::Escape('X:\PF64\PowerShell\7\pwsh.exe'))
                }
                finally {
                    $env:ProgramW6432 = $originalW6432
                }
            }
        }

        It 'returns Error when the specified PwshPath does not exist' {
            $result = Invoke-CWAAPwsh -ScriptBlock { 'test' } -PwshPath 'C:\nonexistent\pwsh.exe'
            $result | Should -Match '^Status=Error\|Result=Specified pwsh\.exe path .* does not exist'
        }

        It 'rejects FilePath that does not exist via ValidateScript' {
            { Invoke-CWAAPwsh -FilePath 'C:\nonexistent\script.ps1' } | Should -Throw
        }
    }

    Context 'running a real child process' {

        It 'returns stdout as Result on success' {
            Invoke-CWAAPwsh -ScriptBlock { 'hello' } -PwshPath $script:HostExe |
                Should -Be 'Status=Success|Result=hello|LogPath=|Data='
        }

        It 'reports a non-zero exit code as Error' {
            Invoke-CWAAPwsh -ScriptBlock { exit 3 } -PwshPath $script:HostExe |
                Should -Be 'Status=Error|Result=pwsh exited with code 3.|LogPath=|Data=ExitCode=3'
        }

        It 'uses stderr as Result and keeps stdout in Data on failure' {
            Invoke-CWAAPwsh -ScriptBlock { 'out'; [Console]::Error.WriteLine('bad'); exit 2 } -PwshPath $script:HostExe |
                Should -Be 'Status=Error|Result=bad|LogPath=|Data=ExitCode=2; Output=out'
        }

        It 'treats stderr output with exit code 0 as Error' {
            Invoke-CWAAPwsh -ScriptBlock { 'out'; [Console]::Error.WriteLine('warn') } -PwshPath $script:HostExe |
                Should -Be 'Status=Error|Result=warn|LogPath=|Data=Output=out'
        }

        It 'does not throw on stderr when the caller uses -ErrorAction Stop' {
            { $script:result = Invoke-CWAAPwsh -ScriptBlock { [Console]::Error.WriteLine('w'); 'ok' } -PwshPath $script:HostExe -ErrorAction Stop } |
                Should -Not -Throw
            $script:result | Should -Be 'Status=Error|Result=w|LogPath=|Data=Output=ok'
        }

        It 'strips ANSI color sequences from output' {
            Invoke-CWAAPwsh -ScriptBlock { "$([char]27)[31mred$([char]27)[0m" } -PwshPath $script:HostExe |
                Should -Be 'Status=Success|Result=red|LogPath=|Data='
        }

        It 'restores the console output encoding' {
            $before = [Console]::OutputEncoding.CodePage
            $null = Invoke-CWAAPwsh -ScriptBlock { 'x' } -PwshPath $script:HostExe
            [Console]::OutputEncoding.CodePage | Should -Be $before
        }
    }

    Context 'running a script file with -Parameters' {

        BeforeAll {
            $script:ParamScript = Join-Path $TestDrive 'params.ps1'
            Set-Content -LiteralPath $script:ParamScript -Value @'
param([string]$Name, [int]$Count, [switch]$Force, [string]$Dir, [string]$Quote, [string]$Empty)
"$Name;$Count;$Force;$Dir;$Quote;[$Empty]"
'@
        }

        It 'passes strings, numbers and switches through unchanged' {
            $parameters = @{
                Name  = 'abc'
                Count = 5
                Force = $true
                Dir   = 'C:\My Dir\'
                Quote = "say `"hi`" it's"
                Empty = ''
            }
            Invoke-CWAAPwsh -FilePath $script:ParamScript -Parameters $parameters -PwshPath $script:HostExe |
                Should -Be "Status=Success|Result=abc;5;True;C:\My Dir\;say `"hi`" it's;[]|LogPath=|Data="
        }

        It 'propagates the script exit code' {
            $exitScript = Join-Path $TestDrive 'exit4.ps1'
            Set-Content -LiteralPath $exitScript -Value 'exit 4'
            Invoke-CWAAPwsh -FilePath $exitScript -PwshPath $script:HostExe |
                Should -Be 'Status=Error|Result=pwsh exited with code 4.|LogPath=|Data=ExitCode=4'
        }

        It 'rejects <Case> without launching pwsh' -ForEach @(
            @{ Case = 'an invalid parameter name'; Parameters = @{ 'bad name' = 'x' }; Pattern = 'not a valid PowerShell parameter name' }
            @{ Case = 'a null value'; Parameters = @{ Name = $null }; Pattern = 'null value' }
            @{ Case = 'an array value'; Parameters = @{ Name = @('a', 'b') }; Pattern = 'unsupported type' }
        ) {
            $result = Invoke-CWAAPwsh -FilePath $script:ParamScript -Parameters $Parameters -PwshPath $script:HostExe
            $result | Should -Match "^Status=Error\|Result=.*$Pattern"
        }
    }
}
