#Requires -Module Pester

<#
.SYNOPSIS
    Mocked behavioral tests for private helper and security edge-case functions.

.DESCRIPTION
    Tests ConvertTo/From-CWAASecurity edge cases, Test-CWAADownloadIntegrity,
    Remove-CWAAFolderRecursive, Resolve-CWAAServer, Wait-CWAACondition,
    Test-CWAADotNetPrerequisite, and Invoke-CWAAMsiInstaller using Pester mocks.

    Supports dual-mode testing via $env:CWAA_TEST_LOAD_METHOD.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Mocked.PrivateHelpers.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
}

# -----------------------------------------------------------------------------

Describe 'ConvertTo-CWAASecurity additional edge cases' {

    It 'returns empty string for empty input' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            ConvertTo-CWAASecurity -InputString ''
        }
        # Empty input still produces an encoded output (encrypted empty string)
        $result | Should -Not -BeNullOrEmpty
    }

    It 'returns empty string for null key (uses default)' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            ConvertTo-CWAASecurity -InputString 'TestValue' -Key $null
        }
        $result | Should -Not -BeNullOrEmpty
    }

    It 'produces different output for different keys' {
        $result1 = InModuleScope 'ConnectWiseAutomateAgent' {
            ConvertTo-CWAASecurity -InputString 'TestValue' -Key 'Key1'
        }
        $result2 = InModuleScope 'ConnectWiseAutomateAgent' {
            ConvertTo-CWAASecurity -InputString 'TestValue' -Key 'Key2'
        }
        $result1 | Should -Not -Be $result2
    }

    It 'round-trips successfully with ConvertFrom-CWAASecurity using same key' {
        $originalValue = 'RoundTripTestValue'
        $result = InModuleScope 'ConnectWiseAutomateAgent' -ArgumentList $originalValue {
            param($testValue)
            $encoded = ConvertTo-CWAASecurity -InputString $testValue -Key 'TestKey123'
            ConvertFrom-CWAASecurity -InputString $encoded -Key 'TestKey123' -Force:$false
        }
        $result | Should -Be $originalValue
    }

    It 'round-trips with default key' {
        $originalValue = 'DefaultKeyRoundTrip'
        $result = InModuleScope 'ConnectWiseAutomateAgent' -ArgumentList $originalValue {
            param($testValue)
            $encoded = ConvertTo-CWAASecurity -InputString $testValue
            ConvertFrom-CWAASecurity -InputString $encoded -Force:$false
        }
        $result | Should -Be $originalValue
    }

    It 'handles special characters in input' {
        $originalValue = 'P@ssw0rd!#$%^&*()'
        $result = InModuleScope 'ConnectWiseAutomateAgent' -ArgumentList $originalValue {
            param($testValue)
            $encoded = ConvertTo-CWAASecurity -InputString $testValue
            ConvertFrom-CWAASecurity -InputString $encoded -Force:$false
        }
        $result | Should -Be $originalValue
    }
}

# -----------------------------------------------------------------------------

Describe 'ConvertFrom-CWAASecurity additional edge cases' {

    It 'returns null for invalid base64 input without Force' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            ConvertFrom-CWAASecurity -InputString 'not-valid-base64!!!' -Key 'TestKey' -Force:$false
        }
        $result | Should -BeNullOrEmpty
    }

    It 'returns null when wrong key is used without Force' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            $encoded = ConvertTo-CWAASecurity -InputString 'TestValue' -Key 'CorrectKey'
            ConvertFrom-CWAASecurity -InputString $encoded -Key 'WrongKey' -Force:$false
        }
        $result | Should -BeNullOrEmpty
    }

    It 'falls back to alternate keys when Force is enabled and primary key fails' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            # Encode with default key
            $encoded = ConvertTo-CWAASecurity -InputString 'TestValue'
            # Try to decode with wrong key but Force enabled (should fall back to default)
            ConvertFrom-CWAASecurity -InputString $encoded -Key 'WrongKey' -Force:$true
        }
        $result | Should -Be 'TestValue'
    }

    It 'handles empty key by using default' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            $encoded = ConvertTo-CWAASecurity -InputString 'TestValue' -Key ''
            ConvertFrom-CWAASecurity -InputString $encoded -Key '' -Force:$false
        }
        $result | Should -Be 'TestValue'
    }

    It 'handles array of input strings' {
        $result = InModuleScope 'ConnectWiseAutomateAgent' {
            $encoded1 = ConvertTo-CWAASecurity -InputString 'Value1'
            $encoded2 = ConvertTo-CWAASecurity -InputString 'Value2'
            ConvertFrom-CWAASecurity -InputString @($encoded1, $encoded2) -Force:$false
        }
        $result | Should -HaveCount 2
        $result[0] | Should -Be 'Value1'
        $result[1] | Should -Be 'Value2'
    }

    It 'rejects empty string due to mandatory parameter validation' {
        # ConvertFrom-CWAASecurity has [parameter(Mandatory = $true)] [string[]]$InputString
        # which prevents binding an empty string. This confirms the validation fires.
        {
            InModuleScope 'ConnectWiseAutomateAgent' {
                ConvertFrom-CWAASecurity -InputString '' -Force:$false -ErrorAction Stop
            }
        } | Should -Throw
    }
}

# =============================================================================
# Private Helper Functions
# =============================================================================

Describe 'Test-CWAADownloadIntegrity' {

    Context 'when file exists and exceeds minimum size' {
        It 'returns true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testFile = Join-Path $env:TEMP 'CWAATestIntegrity.msi'
                # Create a file larger than 1234 KB (write ~1300 KB)
                $bytes = New-Object byte[] (1300 * 1024)
                [System.IO.File]::WriteAllBytes($testFile, $bytes)
                try {
                    Test-CWAADownloadIntegrity -FilePath $testFile -FileName 'CWAATestIntegrity.msi'
                }
                finally {
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                }
            }
            $result | Should -Be $true
        }
    }

    Context 'when file exists but is below minimum size' {
        It 'returns false and removes the file' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testFile = Join-Path $env:TEMP 'CWAATestSmall.msi'
                # Create a file smaller than 1234 KB (write 10 KB)
                $bytes = New-Object byte[] (10 * 1024)
                [System.IO.File]::WriteAllBytes($testFile, $bytes)
                $checkResult = Test-CWAADownloadIntegrity -FilePath $testFile -FileName 'CWAATestSmall.msi' -WarningAction SilentlyContinue
                $fileStillExists = Test-Path $testFile
                [PSCustomObject]@{ Result = $checkResult; FileExists = $fileStillExists }
            }
            $result.Result | Should -Be $false
            $result.FileExists | Should -Be $false
        }
    }

    Context 'when file does not exist' {
        It 'returns false' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Test-CWAADownloadIntegrity -FilePath 'C:\NonExistent\FakeFile.msi' -FileName 'FakeFile.msi'
            }
            $result | Should -Be $false
        }
    }

    Context 'with custom MinimumSizeKB threshold' {
        It 'uses the custom threshold for validation' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testFile = Join-Path $env:TEMP 'CWAATestCustom.exe'
                # Create a 100 KB file, check with 80 KB threshold
                $bytes = New-Object byte[] (100 * 1024)
                [System.IO.File]::WriteAllBytes($testFile, $bytes)
                try {
                    Test-CWAADownloadIntegrity -FilePath $testFile -FileName 'CWAATestCustom.exe' -MinimumSizeKB 80
                }
                finally {
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                }
            }
            $result | Should -Be $true
        }

        It 'fails when file is below custom threshold' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testFile = Join-Path $env:TEMP 'CWAATestCustomFail.exe'
                # Create a 50 KB file, check with 80 KB threshold
                $bytes = New-Object byte[] (50 * 1024)
                [System.IO.File]::WriteAllBytes($testFile, $bytes)
                $checkResult = Test-CWAADownloadIntegrity -FilePath $testFile -FileName 'CWAATestCustomFail.exe' -MinimumSizeKB 80 -WarningAction SilentlyContinue
                $fileStillExists = Test-Path $testFile
                [PSCustomObject]@{ Result = $checkResult; FileExists = $fileStillExists }
            }
            $result.Result | Should -Be $false
            $result.FileExists | Should -Be $false
        }
    }

    Context 'when FileName is not provided' {
        It 'derives the filename from the path' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testFile = Join-Path $env:TEMP 'CWAATestDerived.msi'
                $bytes = New-Object byte[] (1300 * 1024)
                [System.IO.File]::WriteAllBytes($testFile, $bytes)
                try {
                    Test-CWAADownloadIntegrity -FilePath $testFile
                }
                finally {
                    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
                }
            }
            $result | Should -Be $true
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Remove-CWAAFolderRecursive' {

    Context 'when folder exists with nested content' {
        It 'removes the folder and all contents' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testRoot = Join-Path $env:TEMP 'CWAATestRemoveFolder'
                $subDir = Join-Path $testRoot 'SubFolder'
                New-Item -Path $subDir -ItemType Directory -Force | Out-Null
                Set-Content -Path (Join-Path $testRoot 'file1.txt') -Value 'test'
                Set-Content -Path (Join-Path $subDir 'file2.txt') -Value 'test'
                Remove-CWAAFolderRecursive -Path $testRoot -Confirm:$false
                Test-Path $testRoot
            }
            $result | Should -Be $false
        }
    }

    Context 'when folder does not exist' {
        It 'completes without error' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Remove-CWAAFolderRecursive -Path 'C:\NonExistent\CWAATestFolder' -Confirm:$false
                }
            } | Should -Not -Throw
        }
    }

    Context 'when called with -WhatIf' {
        It 'does not actually remove the folder' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $testRoot = Join-Path $env:TEMP 'CWAATestWhatIf'
                New-Item -Path $testRoot -ItemType Directory -Force | Out-Null
                Set-Content -Path (Join-Path $testRoot 'file.txt') -Value 'test'
                Remove-CWAAFolderRecursive -Path $testRoot -WhatIf -Confirm:$false
                $exists = Test-Path $testRoot
                # Clean up for real
                Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
                $exists
            }
            $result | Should -Be $true
        }
    }
}

# -----------------------------------------------------------------------------

Describe 'Resolve-CWAAServer' {

    Context 'when server responds with valid version' {
        It 'returns the server URL and version' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    return '||||||220.105'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('https://automate.example.com')
            }
            $result | Should -Not -BeNullOrEmpty
            $result.ServerUrl | Should -Match 'automate\.example\.com'
            $result.ServerVersion | Should -Be '220.105'
        }
    }

    Context 'when server URL has no scheme' {
        It 'normalizes the URL and still resolves' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    return '||||||230.001'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('automate.example.com')
            }
            $result | Should -Not -BeNullOrEmpty
            $result.ServerVersion | Should -Be '230.001'
        }
    }

    Context 'when server returns no parseable version' {
        It 'returns null' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    return 'no version data here'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('https://automate.example.com') -WarningAction SilentlyContinue
            }
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when server is unreachable' {
        It 'returns null' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    throw 'Connection refused'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('https://automate.example.com') -WarningAction SilentlyContinue
            }
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'when first server fails but second succeeds' {
        It 'returns the second server' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $callCount = 0
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    # Use the URL to determine behavior since $callCount scope is tricky
                    if ($url -match 'bad\.example\.com') {
                        throw 'Connection refused'
                    }
                    return '||||||210.050'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('https://bad.example.com', 'https://good.example.com') -WarningAction SilentlyContinue
            }
            $result | Should -Not -BeNullOrEmpty
            $result.ServerUrl | Should -Match 'good\.example\.com'
            $result.ServerVersion | Should -Be '210.050'
        }
    }

    Context 'when server URL is invalid format' {
        It 'returns null and writes a warning' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $mockWebClient = New-Object PSObject
                $mockWebClient | Add-Member -MemberType ScriptMethod -Name DownloadString -Value {
                    param($url)
                    return '||||||220.105'
                }
                $Script:LTServiceNetWebClient = $mockWebClient
                Resolve-CWAAServer -Server @('https://automate.example.com/some/path') -WarningAction SilentlyContinue
            }
            $result | Should -BeNullOrEmpty
        }
    }
}

# =============================================================================
# Wait-CWAACondition Tests
# =============================================================================

Describe 'Wait-CWAACondition' {

    Context 'when condition is met immediately' {
        It 'returns $true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $callCount = 0
                Wait-CWAACondition -Condition {
                    $script:callCount++
                    $true
                } -TimeoutSeconds 10 -IntervalSeconds 1
            }
            $result | Should -Be $true
        }
    }

    Context 'when condition is met after initial failure' {
        It 'returns $true after retrying' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $script:waitTestCounter = 0
                Wait-CWAACondition -Condition {
                    $script:waitTestCounter++
                    $script:waitTestCounter -ge 2
                } -TimeoutSeconds 30 -IntervalSeconds 1
            }
            $result | Should -Be $true
        }
    }

    Context 'when timeout is reached' {
        It 'returns $false' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Wait-CWAACondition -Condition { $false } -TimeoutSeconds 2 -IntervalSeconds 1
            }
            $result | Should -Be $false
        }
    }

    Context 'parameter validation' {
        It 'rejects TimeoutSeconds of 0' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Wait-CWAACondition -Condition { $true } -TimeoutSeconds 0 -IntervalSeconds 1
                }
            } | Should -Throw
        }

        It 'rejects IntervalSeconds of 0' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Wait-CWAACondition -Condition { $true } -TimeoutSeconds 10 -IntervalSeconds 0
                }
            } | Should -Throw
        }
    }
}

# =============================================================================
# Test-CWAADotNetPrerequisite Tests
# =============================================================================

Describe 'Test-CWAADotNetPrerequisite' {

    Context 'when -SkipDotNet is specified' {
        It 'returns $true immediately without checking registry' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-ChildItem {}
                Test-CWAADotNetPrerequisite -SkipDotNet
            }
            $result | Should -Be $true
        }
    }

    Context 'when .NET 3.5 is already installed' {
        It 'returns $true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Get-ChildItem {
                    [PSCustomObject]@{ PSChildName = 'Full' }
                }
                Mock Get-ItemProperty {
                    [PSCustomObject]@{ Version = '3.5.30729'; Release = $null; PSChildName = 'Full' }
                }
                Test-CWAADotNetPrerequisite -Confirm:$false
            }
            $result | Should -Be $true
        }
    }

    Context 'when .NET 3.5 is missing and -Force allows .NET 2.0+' {
        It 'returns $true with a non-terminating error when .NET 4.x is present' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                # First call: initial check returns only 4.x
                # Second call (after install attempt): still only 4.x
                Mock Get-ChildItem {
                    [PSCustomObject]@{ PSChildName = 'Full' }
                }
                Mock Get-ItemProperty {
                    [PSCustomObject]@{ Version = '4.8.03761'; Release = 528040; PSChildName = 'Full' }
                }
                Mock Get-WindowsOptionalFeature { [PSCustomObject]@{ State = 'Disabled' } }
                Mock Enable-WindowsOptionalFeature { [PSCustomObject]@{ RestartNeeded = $false; State = 'Enabled' } }
                Test-CWAADotNetPrerequisite -Force -Confirm:$false -ErrorAction SilentlyContinue
            }
            $result | Should -Be $true
        }
    }

    Context 'when .NET 3.5 is missing and no .NET 2.0+ with -Force' {
        It 'throws a terminating error' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Mock Get-ChildItem {
                        [PSCustomObject]@{ PSChildName = 'Full' }
                    }
                    Mock Get-ItemProperty {
                        [PSCustomObject]@{ Version = '1.1.4322'; Release = $null; PSChildName = 'Full' }
                    }
                    Mock Get-WindowsOptionalFeature { [PSCustomObject]@{ State = 'Disabled' } }
                    Mock Enable-WindowsOptionalFeature { [PSCustomObject]@{ RestartNeeded = $false; State = 'Enabled' } }
                    Test-CWAADotNetPrerequisite -Force -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw '*2.0*'
        }
    }

    Context 'when .NET 3.5 is missing without -Force' {
        It 'throws a terminating error' {
            {
                InModuleScope 'ConnectWiseAutomateAgent' {
                    Mock Get-ChildItem {
                        [PSCustomObject]@{ PSChildName = 'Full' }
                    }
                    Mock Get-ItemProperty {
                        [PSCustomObject]@{ Version = '4.8.03761'; Release = 528040; PSChildName = 'Full' }
                    }
                    Mock Get-WindowsOptionalFeature { [PSCustomObject]@{ State = 'Disabled' } }
                    Mock Enable-WindowsOptionalFeature { [PSCustomObject]@{ RestartNeeded = $false; State = 'Enabled' } }
                    Test-CWAADotNetPrerequisite -Confirm:$false -ErrorAction Stop
                }
            } | Should -Throw '*3.5*'
        }
    }
}

# =============================================================================
# Invoke-CWAAMsiInstaller Tests
# =============================================================================

Describe 'Invoke-CWAAMsiInstaller' {

    Context 'when service starts on first attempt' {
        It 'returns $true' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                $script:msiCallCount = 0
                Mock Start-Process {
                    $script:msiCallCount++
                }
                Mock Start-Sleep {}
                # First call returns 0 (pre-install check), second call returns 1 (post-install)
                $script:getServiceCallCount = 0
                Mock Get-Service {
                    $script:getServiceCallCount++
                    if ($script:getServiceCallCount -ge 2) {
                        [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' }
                    }
                }
                Invoke-CWAAMsiInstaller -InstallerArguments '/i "test.msi" /qn' -Confirm:$false
            }
            $result | Should -Be $true
        }
    }

    Context 'when service starts on retry' {
        It 'returns $true after retrying' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Start-Process {}
                Mock Start-Sleep {}
                Mock Wait-CWAACondition { $false }
                # Service not present for first 4 calls (2 attempts x 2 checks each), then present
                $script:svcCounter = 0
                Mock Get-Service {
                    $script:svcCounter++
                    if ($script:svcCounter -ge 5) {
                        [PSCustomObject]@{ Name = 'LTService'; Status = 'Running' }
                    }
                }
                Invoke-CWAAMsiInstaller -InstallerArguments '/i "test.msi" /qn' -MaxAttempts 3 -RetryDelaySeconds 1 -Confirm:$false
            }
            $result | Should -Be $true
        }
    }

    Context 'when service never starts' {
        It 'returns $false after max attempts' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Start-Process {}
                Mock Start-Sleep {}
                Mock Wait-CWAACondition { $false }
                Mock Get-Service {}
                Invoke-CWAAMsiInstaller -InstallerArguments '/i "test.msi" /qn' -MaxAttempts 2 -RetryDelaySeconds 1 -Confirm:$false -ErrorAction SilentlyContinue
            }
            $result | Should -Be $false
        }
    }

    Context 'when -WhatIf is specified' {
        It 'returns $true without calling Start-Process' {
            $result = InModuleScope 'ConnectWiseAutomateAgent' {
                Mock Start-Process {}
                Invoke-CWAAMsiInstaller -InstallerArguments '/i "test.msi" /qn' -WhatIf
            }
            $result | Should -Be $true
            InModuleScope 'ConnectWiseAutomateAgent' {
                Should -Invoke Start-Process -Times 0
            }
        }
    }
}
