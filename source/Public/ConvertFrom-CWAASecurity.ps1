function ConvertFrom-CWAASecurity {
    <#
    .SYNOPSIS
        Decodes a Base64-encoded string using TripleDES decryption.
    .DESCRIPTION
        This function decodes the provided string using the specified or default key.
        It uses TripleDES with an MD5-derived key and a fixed initialization vector.
        If decoding fails with the provided key and Force is enabled, alternate key
        values are attempted automatically.
    .PARAMETER InputString
        The Base64-encoded string to be decoded.
    .PARAMETER Key
        The key used for decoding. If not provided, default values will be tried.
    .PARAMETER Force
        Forces the function to try alternate key values if decoding fails using
        the provided key. Enabled by default.
    .EXAMPLE
        ConvertFrom-CWAASecurity -InputString 'EncodedValue'
        Decodes the string using the default key.
    .EXAMPLE
        ConvertFrom-CWAASecurity -InputString 'EncodedValue' -Key 'MyCustomKey'
        Decodes the string using a custom key.
    .NOTES
        Author: Chris Taylor
        Alias: ConvertFrom-LTSecurity
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('ConvertFrom-LTSecurity')]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 1)]
        [string[]]$InputString,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [string[]]$Key,
        [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
        [switch]$Force = $True
    )

    Begin {
        $DefaultKey = 'Thank you for using LabTech.'
        $_initializationVector = [byte[]](240, 3, 45, 29, 0, 76, 173, 59)
        $NoKeyPassed = $False
        $DecodedString = $Null
        $DecodeString = $Null
    }

    Process {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        if ($Null -eq $Key) {
            $NoKeyPassed = $True
            $Key = $DefaultKey
        }
        foreach ($testInput in $InputString) {
            $DecodeString = $Null
            foreach ($testKey in $Key) {
                if ($Null -eq $DecodeString) {
                    if ($Null -eq $testKey) {
                        $NoKeyPassed = $True
                        $testKey = $DefaultKey
                    }
                    Write-Debug "Attempting Decode for '$($testInput)' with Key '$($testKey)'"
                    Try {
                        $inputBytes = [System.Convert]::FromBase64String($testInput)
                        $tripleDesProvider = New-Object System.Security.Cryptography.TripleDESCryptoServiceProvider
                        $tripleDesProvider.key = (New-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([Text.Encoding]::UTF8.GetBytes($testKey))
                        $tripleDesProvider.IV = $_initializationVector
                        $cryptoTransform = $tripleDesProvider.CreateDecryptor()
                        $DecodeString = [System.Text.Encoding]::UTF8.GetString($cryptoTransform.TransformFinalBlock($inputBytes, 0, ($inputBytes.Length)))
                        $DecodedString += @($DecodeString)
                    }
                    Catch {
                        Write-Debug "Decode failed for '$($testInput)' with Key '$($testKey)': $_"
                    }
                    Finally {
                        if ((Get-Variable -Name cryptoTransform -Scope 0 -EA 0)) { try { $cryptoTransform.Dispose() } catch { $cryptoTransform.Clear() } }
                        if ((Get-Variable -Name tripleDesProvider -Scope 0 -EA 0)) { try { $tripleDesProvider.Dispose() } catch { $tripleDesProvider.Clear() } }
                    }
                }
            }
            if ($Null -eq $DecodeString) {
                if ($Force) {
                    if ($NoKeyPassed) {
                        $DecodeString = ConvertFrom-CWAASecurity -InputString "$($testInput)" -Key '' -Force:$False
                        if (-not ($Null -eq $DecodeString)) {
                            $DecodedString += @($DecodeString)
                        }
                    }
                    else {
                        $DecodeString = ConvertFrom-CWAASecurity -InputString "$($testInput)"
                        if (-not ($Null -eq $DecodeString)) {
                            $DecodedString += @($DecodeString)
                        }
                    }
                }
                else {
                    Write-Debug "All decode attempts exhausted for '$($testInput)' with Force disabled."
                }
            }
        }
    }

    End {
        if ($Null -eq $DecodedString) {
            Write-Debug "Failed to Decode string: '$($InputString)'"
            return $Null
        }
        else {
            return $DecodedString
        }
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
