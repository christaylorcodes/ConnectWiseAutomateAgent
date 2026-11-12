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

    It 'writes an error and returns nothing for an input with no fields (<Case>)' -ForEach @(
        @{ Case = 'a bare string'; Value = 'Status=Success' }
        @{ Case = 'a number'; Value = 42 }
        @{ Case = 'an empty hashtable'; Value = @{} }
    ) {
        $result = ConvertTo-CWAAScriptOutput -InputObject $Value -ErrorVariable problems -ErrorAction SilentlyContinue
        $result | Should -BeNullOrEmpty
        "$($problems[0])" | Should -Match 'has no fields to format'
    }

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

    It 'collapses Unicode line separators (U+2028, U+2029, U+0085)' {
        $obj = [PSCustomObject]@{ Result = "a$([char]0x2028)b$([char]0x2029)c$([char]0x0085)d" }
        ConvertTo-CWAAScriptOutput -InputObject $obj | Should -Be 'Result=a / b / c / d'
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

    It 'accepts an empty message' {
        $path = Join-Path $TestDrive 'empty.log'
        Write-CWAAScriptLog -Message '' -LogPath $path
        Get-Content -LiteralPath $path | Should -Match '\[INFO\] $'
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

    It 'returns an absolute path for a relative LogDirectory' {
        Push-Location $TestDrive
        try {
            $result = Initialize-CWAAScriptLog -LogDirectory 'relative-logs'
        }
        finally {
            Pop-Location
        }
        [System.IO.Path]::IsPathRooted($result) | Should -BeTrue
        $result | Should -BeLike "$TestDrive\relative-logs\*"
        Test-Path -LiteralPath $result | Should -BeTrue
    }

    It 'refuses a log directory reached through a junction' {
        $target = Join-Path $TestDrive 'junction-target'
        $null = New-Item -Path $target -ItemType Directory
        $junction = Join-Path $TestDrive 'junction'
        $null = New-Item -Path $junction -ItemType Junction -Value $target

        $result = Initialize-CWAAScriptLog -LogDirectory (Join-Path $junction 'logs') -ErrorVariable ev -ErrorAction SilentlyContinue

        $result | Should -BeNullOrEmpty
        "$ev" | Should -Match 'junction or symbolic link'
        # Nothing, not even the missing folder, is created through the junction
        Get-ChildItem -LiteralPath $target -Recurse | Should -BeNullOrEmpty
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

    It 'wraps the Base64 script in a command that decodes and runs it' {
        $encoded = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(' Get-Service '))
        New-CWAARemoteMonitor -ScriptBlock { Get-Service } |
            Should -Be "`"%windir%\System32\WindowsPowerShell\v1.0\powershell.exe`" `"&{`$C='$encoded';[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(`$C))|iex}`""
    }

    It 'produces output that decodes back to the original scriptblock' {
        $original = 'Get-Service LTService'
        $result = New-CWAARemoteMonitor -ScriptBlock ([scriptblock]::Create($original))

        $result -match "'(?<Encoded>[A-Za-z0-9+/=]+)'" | Should -BeTrue -Because 'the command should embed a quoted Base64 string'
        [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Matches.Encoded)) |
            Should -Be $original
    }

    It 'stays under the 8191 character limit for short scripts' {
        $result = New-CWAARemoteMonitor -ScriptBlock { Get-Date }
        $result.Length | Should -BeLessOrEqual 8191
    }

    It 'throws when the encoded output exceeds 8191 characters' {
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

    It 'returns Success when the scriptblock handles its own errors (<Case>)' -ForEach @(
        @{ Case = 'try/catch around throw'; Block = { try { throw 'x' } catch { 'handled' } } }
        @{ Case = 'try/catch around -ErrorAction Stop'; Block = { try { Get-Item 'C:\no\such\path' -ErrorAction Stop } catch { 'handled' } } }
        @{ Case = '-ErrorAction SilentlyContinue'; Block = { $null = Get-Item 'C:\no\such\path' -ErrorAction SilentlyContinue; 'handled' } }
    ) {
        Invoke-CWAAScript -ScriptBlock $Block | Should -Be 'Status=Success|Result=handled|LogPath=|Data='
    }

    It 'treats an error record the script outputs on purpose as output' {
        Invoke-CWAAScript -ScriptBlock { try { throw 'x' } catch { "handled: $_" ; $_ } } |
            Should -Match '^Status=Success\|Result=handled: x / '
    }

    It 'reports an error that is written and then rethrown only once' {
        Invoke-CWAAScript -ScriptBlock { try { throw 'once' } catch { Write-Error $_ -ErrorAction Continue; throw $_ } } |
            Should -Be 'Status=Error|Result=once|LogPath=|Data='
    }

    It 'still returns an Error line when a labeled break leaves the scriptblock' {
        $output = :outer foreach ($i in 1, 2) { Invoke-CWAAScript -ScriptBlock { 'partial'; break outer } }
        @($output).Count | Should -Be 1
        $output | Should -Match '^Status=Error\|Result=The script left Invoke-CWAAScript early.*\|Data=Output=partial$'
    }

    It 'writes the early-exit failure to the log when logging is enabled' {
        $logDirectory = Join-Path $TestDrive 'early-exit'
        $output = :outer foreach ($i in 1, 2) {
            Invoke-CWAAScript -EnableLogging -LogDirectory $logDirectory -LogName 'EarlyExit' -ScriptBlock { break outer }
        }
        $output | Should -Match '^Status=Error\|Result=The script left Invoke-CWAAScript early'
        $logFile = Get-ChildItem -LiteralPath $logDirectory -Filter 'EarlyExit*.log'
        @($logFile).Count | Should -Be 1
        Get-Content -LiteralPath $logFile.FullName -Raw | Should -Match '\[ERROR\] Script execution failed: The script left Invoke-CWAAScript early'
    }

    It 'treats native command stderr as output, not as an error' {
        Invoke-CWAAScript -ScriptBlock { cmd.exe /c '1>&2 echo progress'; 'done' } |
            Should -Be 'Status=Success|Result=progress / done|LogPath=|Data='
    }

    It 'reports an earlier non-terminating error together with a later throw' {
        Invoke-CWAAScript -ScriptBlock { Write-Error 'root cause' -ErrorAction Continue; throw 'secondary' } |
            Should -Be 'Status=Error|Result=root cause; secondary|LogPath=|Data='
    }

    It 'contains a stray break in the scriptblock' {
        $output = foreach ($i in 1) { Invoke-CWAAScript -ScriptBlock { 'before'; break } }
        $output | Should -Be 'Status=Success|Result=before|LogPath=|Data='
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

    It 'still returns one output line when the script output cannot be formatted' {
        $unformattable = New-Object PSObject
        $unformattable | Add-Member -MemberType ScriptMethod -Name ToString -Value { throw 'no string for you' } -Force

        { $script:result = Invoke-CWAAScript -ScriptBlock { 'before'; $unformattable } } | Should -Not -Throw
        @($script:result).Count | Should -Be 1
        $script:result | Should -Match '^Status=Error\|.*\|Data=Output=<could not be formatted: '
    }

    It 'rejects a URL without https:// (<URL>)' -ForEach @(
        @{ URL = 'example.com/script.ps1' }
        @{ URL = 'http://example.com/script.ps1' }
    ) {
        { Invoke-CWAAScript -URL $URL } | Should -Throw '*https*'
    }

    Context 'running a remote script with -URL' {

        BeforeAll {
            # Global so mock bodies, which run inside the module, can call it. Builds what
            # Invoke-CWAAScript reads from Invoke-WebRequest: the raw response bytes.
            function global:New-CWAATestWebResponse {
                param([string]$Text, [byte[]]$Bytes)
                if (-not $PSBoundParameters.ContainsKey('Bytes')) { $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Text) }
                $stream = New-Object System.IO.MemoryStream
                $stream.Write($Bytes, 0, $Bytes.Length)
                [PSCustomObject]@{ RawContentStream = $stream }
            }
        }

        AfterAll {
            Remove-Item -LiteralPath 'function:\New-CWAATestWebResponse' -ErrorAction SilentlyContinue
        }

        It 'fetches and executes the script' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Invoke-WebRequest { New-CWAATestWebResponse -Text "'RemoteResult'" }

                Invoke-CWAAScript -URL 'https://example.com/test.ps1' |
                    Should -Be 'Status=Success|Result=RemoteResult|LogPath=|Data='

                Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq 'https://example.com/test.ps1' }
            }
        }

        It 'decodes the script as <Case>' -ForEach @(
            @{ Case = 'UTF-8 without a byte order mark'; Encoding = (New-Object System.Text.UTF8Encoding($false)) }
            @{ Case = 'UTF-8 with a byte order mark'; Encoding = (New-Object System.Text.UTF8Encoding($true)) }
            @{ Case = 'UTF-16 with a byte order mark'; Encoding = [System.Text.Encoding]::Unicode }
        ) {
            # A non-ASCII character shows a wrong decoding; a kept byte order mark breaks the first command
            $text = "'caf$([char]0xE9)'"
            [byte[]]$responseBytes = $Encoding.GetPreamble() + $Encoding.GetBytes($text)
            InModuleScope 'ConnectWiseAutomateAgent' -Parameters @{ ResponseBytes = $responseBytes } {
                param($ResponseBytes)
                Mock Invoke-WebRequest { New-CWAATestWebResponse -Bytes $ResponseBytes }

                Invoke-CWAAScript -URL 'https://example.com/encoded.ps1' |
                    Should -Be "Status=Success|Result=caf$([char]0xE9)|LogPath=|Data="
            }
        }

        It 'runs the script in the caller''s scope, as -ScriptBlock does' {
            Mock Invoke-WebRequest { New-CWAATestWebResponse -Text '"$callerVariable / $ErrorActionPreference"' } -ModuleName 'ConnectWiseAutomateAgent'
            $callerVariable = 'seen'
            $ErrorActionPreference = 'Stop'

            Invoke-CWAAScript -URL 'https://example.com/scope.ps1' |
                Should -Be 'Status=Success|Result=seen / Stop|LogPath=|Data='
        }

        It 'does not expose the module''s private state to the script' {
            Mock Invoke-WebRequest { New-CWAATestWebResponse -Text '"[$Script:CWAAInstallPath]"; $Script:CWAAInstallPath = ''clobbered''' } -ModuleName 'ConnectWiseAutomateAgent'
            $before = InModuleScope 'ConnectWiseAutomateAgent' { $Script:CWAAInstallPath }
            $before | Should -Not -BeNullOrEmpty

            Invoke-CWAAScript -URL 'https://example.com/private.ps1' |
                Should -Be 'Status=Success|Result=[]|LogPath=|Data='

            InModuleScope 'ConnectWiseAutomateAgent' { $Script:CWAAInstallPath } | Should -Be $before
        }

        It 'enables TLS 1.2 for the download and restores the process-wide setting when the fetch <Case>' -ForEach @(
            @{ Case = 'succeeds'; Fails = $false }
            @{ Case = 'fails'; Fails = $true }
        ) {
            InModuleScope 'ConnectWiseAutomateAgent' -Parameters @{ Fails = $Fails } {
                param($Fails)
                Mock Invoke-WebRequest {
                    $script:CWAATestProtocolDuringFetch = [Net.ServicePointManager]::SecurityProtocol
                    if ($Fails) { throw 'Network error' }
                    New-CWAATestWebResponse -Text "'x'"
                }
                $original = [Net.ServicePointManager]::SecurityProtocol
                try {
                    # A known value without TLS 1.2, so the result does not depend on earlier tests
                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls11

                    $null = Invoke-CWAAScript -URL 'https://example.com/tls.ps1'

                    $script:CWAATestProtocolDuringFetch | Should -Be ([Net.SecurityProtocolType]'Tls11, Tls12')
                    [Net.ServicePointManager]::SecurityProtocol | Should -Be ([Net.SecurityProtocolType]::Tls11)
                }
                finally { [Net.ServicePointManager]::SecurityProtocol = $original }
            }
        }

        It 'leaves the operating system default TLS setting alone during the download' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Invoke-WebRequest {
                    $script:CWAATestProtocolDuringFetch = [Net.ServicePointManager]::SecurityProtocol
                    New-CWAATestWebResponse -Text "'x'"
                }
                $original = [Net.ServicePointManager]::SecurityProtocol
                try {
                    [Net.ServicePointManager]::SecurityProtocol = 0

                    $null = Invoke-CWAAScript -URL 'https://example.com/tls.ps1'

                    [int]$script:CWAATestProtocolDuringFetch | Should -Be 0
                }
                finally { [Net.ServicePointManager]::SecurityProtocol = $original }
            }
        }

        It 'returns Error when the fetch fails' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Invoke-WebRequest { throw 'Network error' }

                Invoke-CWAAScript -URL 'https://example.com/bad.ps1' |
                    Should -Be 'Status=Error|Result=Network error|LogPath=|Data='
            }
        }

        It 'returns Error when the remote script is <Case>' -ForEach @(
            @{ Case = 'empty'; ResponseBytes = [byte[]]@() }
            @{ Case = 'whitespace'; ResponseBytes = [System.Text.Encoding]::UTF8.GetBytes("  `n ") }
            @{ Case = 'only a byte order mark'; ResponseBytes = [byte[]](0xEF, 0xBB, 0xBF) }
        ) {
            InModuleScope 'ConnectWiseAutomateAgent' -Parameters @{ ResponseBytes = $ResponseBytes } {
                param($ResponseBytes)
                Mock Invoke-WebRequest { New-CWAATestWebResponse -Bytes $ResponseBytes }

                Invoke-CWAAScript -URL 'https://example.com/empty.ps1' |
                    Should -Be "Status=Error|Result=Remote script at 'https://example.com/empty.ps1' was empty.|LogPath=|Data="
            }
        }

        It 'returns Error without running anything when the remote script has a syntax error' {
            InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Invoke-WebRequest { New-CWAATestWebResponse -Text "`$global:CWAATestRanBeforeSyntaxError = `$true`nif (" }
                $global:CWAATestRanBeforeSyntaxError = $false
                try {
                    { $script:result = Invoke-CWAAScript -URL 'https://example.com/broken.ps1' } | Should -Not -Throw
                    $script:result | Should -Match '^Status=Error\|'
                    $global:CWAATestRanBeforeSyntaxError | Should -BeFalse
                }
                finally { Remove-Variable -Name CWAATestRanBeforeSyntaxError -Scope Global -ErrorAction SilentlyContinue }
            }
        }
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

        It 'returns Error without running anything when PwshPath is not an .exe' {
            $notExe = Join-Path $TestDrive 'pwsh.ps1'
            Set-Content -LiteralPath $notExe -Value "'ran in-process'"
            Invoke-CWAAPwsh -ScriptBlock { 'test' } -PwshPath $notExe |
                Should -Match '^Status=Error\|Result=.*is not an executable'
        }

        It 'returns Error when PwshPath is not a file system path' {
            function global:CWAATestFake.exe { 'ran in-process' }
            try {
                Invoke-CWAAPwsh -ScriptBlock { 'test' } -PwshPath 'function:\CWAATestFake.exe' |
                    Should -Match '^Status=Error\|Result=.*is not an executable'
            }
            finally { Remove-Item -LiteralPath 'function:\CWAATestFake.exe' -ErrorAction SilentlyContinue }
        }

        It 'returns Error when the specified PwshPath does not exist' {
            $result = Invoke-CWAAPwsh -ScriptBlock { 'test' } -PwshPath 'C:\nonexistent\pwsh.exe'
            $result | Should -Match '^Status=Error\|Result=Specified pwsh\.exe path .* does not exist'
        }

        It 'resolves a bare -PwshPath against the current folder, never PATH' {
            Push-Location $TestDrive
            try {
                $result = Invoke-CWAAPwsh -ScriptBlock { 'test' } -PwshPath 'pwsh.exe'
            }
            finally {
                Pop-Location
            }
            $result | Should -Match '^Status=Error\|Result=Specified pwsh\.exe path .pwsh\.exe. does not exist'
        }

        It 'returns a Status=Error line when FilePath does not exist' {
            { $script:result = Invoke-CWAAPwsh -FilePath 'C:\nonexistent\script.ps1' -PwshPath $script:HostExe } | Should -Not -Throw
            $script:result | Should -Be "Status=Error|Result=Script file 'C:\nonexistent\script.ps1' was not found.|LogPath=|Data="
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

        It 'returns table-formatted objects and the output that follows them' {
            $result = Invoke-CWAAPwsh -ScriptBlock { 'first'; [PSCustomObject]@{ Alpha = 1; Beta = 'two' }; 'last' } -PwshPath $script:HostExe
            $result | Should -Match '^Status=Success\|Result=first / .*Alpha\s+Beta.* / .*1\s+two.* / last\|LogPath=\|Data=$'
        }

        It 'reports an unhandled throw as Error with exit code 1 and keeps earlier output' {
            $result = Invoke-CWAAPwsh -ScriptBlock { 'out'; throw 'kaboom' } -PwshPath $script:HostExe
            $result | Should -Match '^Status=Error\|Result=.*kaboom.*\|LogPath=\|Data=ExitCode=1; Output=out$'
        }

        # Nothing is wrapped around the script, so it runs as it would on its own
        It 'keeps running after a non-terminating or statement-terminating error (<Case>)' -ForEach @(
            @{ Case = 'Write-Error'; Block = { 'before'; Write-Error 'soft'; 'after' }; Message = 'soft' }
            @{ Case = '.NET method exception'; Block = { 'before'; [int]::Parse('x'); 'after' }; Message = 'Parse' }
        ) {
            $result = Invoke-CWAAPwsh -ScriptBlock $Block -PwshPath $script:HostExe
            $result | Should -Match "^Status=Error\|Result=.*$Message.*\|LogPath=\|Data=Output=before / after$"
        }

        It 'succeeds when the script handles an error itself (<Case>)' -ForEach @(
            @{ Case = 'try/catch'; Block = { try { throw 'x' } catch { 'handled' } } }
            @{ Case = 'SilentlyContinue'; Block = { $ErrorActionPreference = 'SilentlyContinue'; 'a'; [int]::Parse('x'); 'after' } }
        ) {
            Invoke-CWAAPwsh -ScriptBlock $Block -PwshPath $script:HostExe |
                Should -Match '^Status=Success\|Result=(handled|a / after)\|LogPath=\|Data=$'
        }

        It 'succeeds when native stderr is redirected into the output inside the script' {
            Invoke-CWAAPwsh -ScriptBlock { cmd.exe /c 'echo err 1>&2' 2>&1 | ForEach-Object { "$_".Trim() }; 'after' } -PwshPath $script:HostExe |
                Should -Be 'Status=Success|Result=err / after|LogPath=|Data='
        }

        It 'does not throw on stderr when the caller uses -ErrorAction Stop' {
            { $script:result = Invoke-CWAAPwsh -ScriptBlock { [Console]::Error.WriteLine('w'); 'ok' } -PwshPath $script:HostExe -ErrorAction Stop } |
                Should -Not -Throw
            $script:result | Should -Be 'Status=Error|Result=w|LogPath=|Data=Output=ok'
        }

        It 'ignores a handled error or leftover native exit code on the last line (<Case>)' -ForEach @(
            @{ Case = 'SilentlyContinue'; Block = { 'ok'; $null = Get-Item 'C:\no\such\path' -ErrorAction SilentlyContinue } }
            @{ Case = 'native exit 1'; Block = { 'ok'; cmd.exe /c 'exit 1' } }
        ) {
            Invoke-CWAAPwsh -ScriptBlock $Block -PwshPath $script:HostExe |
                Should -Be 'Status=Success|Result=ok|LogPath=|Data='
        }

        It 'captures warning output into Result instead of leaking extra lines' {
            $output = @(Invoke-CWAAPwsh -ScriptBlock { Write-Warning 'careful'; 'ok' } -PwshPath $script:HostExe 3>&1 6>&1)
            # A pwsh 7 child prints the warning as text (captured); a 5.1 stand-in child drops it.
            # Either way nothing leaks as an extra line.
            $output.Count | Should -Be 1
            $output[0] | Should -Match '^Status=Success\|Result=(WARNING: careful / )?ok\|LogPath=\|Data=$'
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

        It 'passes hostile string values as literal text' {
            # Typographic quotes also delimit strings in PowerShell; --% is the stop-parsing token
            $smartQuoted = "a$([char]0x2019); 'INJECTED'; $([char]0x2018)b$([char]0x201A); 'INJECTED'; $([char]0x201B)c"
            $metaCharacters = '$env:USERNAME $(1+1) `t ; & > <'
            $parameters = @{
                Name  = $smartQuoted
                Count = 1.5
                Force = $false
                Dir   = '--%'
                Quote = $metaCharacters
                Empty = '-NotAParameter'
            }
            Invoke-CWAAPwsh -FilePath $script:ParamScript -Parameters $parameters -PwshPath $script:HostExe |
                Should -Be "Status=Success|Result=$smartQuoted;2;False;--%;$metaCharacters;[-NotAParameter]|LogPath=|Data="
        }

        It 'returns Error when FilePath is not a file system path' {
            function global:CWAATestFake.ps1 { 'ran by name' }
            try {
                Invoke-CWAAPwsh -FilePath 'function:\CWAATestFake.ps1' -PwshPath $script:HostExe |
                    Should -Match '^Status=Error\|Result=.*is not a file system path'
            }
            finally { Remove-Item -LiteralPath 'function:\CWAATestFake.ps1' -ErrorAction SilentlyContinue }
        }

        It 'propagates the script exit code' {
            $exitScript = Join-Path $TestDrive 'exit4.ps1'
            Set-Content -LiteralPath $exitScript -Value 'exit 4'
            Invoke-CWAAPwsh -FilePath $exitScript -PwshPath $script:HostExe |
                Should -Be 'Status=Error|Result=pwsh exited with code 4.|LogPath=|Data=ExitCode=4'
        }

        It 'ignores a leftover exit code from the script''s last native command, like pwsh -File' {
            $nativeScript = Join-Path $TestDrive 'native.ps1'
            Set-Content -LiteralPath $nativeScript -Value @'
'ran'
cmd.exe /c "exit 3"
'@
            Invoke-CWAAPwsh -FilePath $nativeScript -PwshPath $script:HostExe |
                Should -Be 'Status=Success|Result=ran|LogPath=|Data='
        }

        It 'rejects <Case> without launching pwsh' -ForEach @(
            @{ Case = 'an invalid parameter name'; Parameters = @{ 'bad name' = 'x' }; Pattern = 'not a valid PowerShell parameter name' }
            @{ Case = 'a parameter name with a trailing newline'; Parameters = @{ "Force`n" = $false }; Pattern = 'not a valid PowerShell parameter name' }
            @{ Case = 'a NaN value'; Parameters = @{ Count = [double]::NaN }; Pattern = 'NaN or infinity' }
            @{ Case = 'a null value'; Parameters = @{ Name = $null }; Pattern = 'null value' }
            @{ Case = 'an array value'; Parameters = @{ Name = @('a', 'b') }; Pattern = 'unsupported type' }
            @{ Case = 'an enum value'; Parameters = @{ Name = [System.IO.FileAttributes]'ReadOnly, Hidden' }; Pattern = 'unsupported type' }
        ) {
            $result = Invoke-CWAAPwsh -FilePath $script:ParamScript -Parameters $Parameters -PwshPath $script:HostExe
            $result | Should -Match "^Status=Error\|Result=.*$Pattern"
        }
    }
}
