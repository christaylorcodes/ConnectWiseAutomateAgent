#Requires -Module Pester

<#
.SYNOPSIS
    Security function unit tests for ConvertTo/From-CWAASecurity.

.DESCRIPTION
    Tests the encryption and decryption round-trip behavior of
    ConvertTo-CWAASecurity and ConvertFrom-CWAASecurity functions.

    Supports dual-mode testing via $env:CWAA_TEST_LOAD_METHOD.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Security.Tests.ps1 -Output Detailed
#>

BeforeAll {
    $script:BootstrapResult = & "$PSScriptRoot\TestBootstrap.ps1"
}

AfterAll {
    Get-Module 'ConnectWiseAutomateAgent' -ErrorAction SilentlyContinue | Remove-Module -Force
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
