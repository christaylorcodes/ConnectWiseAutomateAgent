function ConvertTo-CWAASecurity {
    <#
    .SYNOPSIS
        Encodes a string using TripleDES encryption compatible with Automate operations.
    .DESCRIPTION
        This function encodes the provided string using the specified or default key.
        It uses TripleDES with an MD5-derived key and a fixed initialization vector,
        returning a Base64-encoded result.
    .PARAMETER InputString
        The string to be encoded.
    .PARAMETER Key
        The key used for encoding. If not provided, a default value will be used.
    .EXAMPLE
        ConvertTo-CWAASecurity -InputString 'PlainTextValue'
        Encodes the string using the default key.
    .EXAMPLE
        ConvertTo-CWAASecurity -InputString 'PlainTextValue' -Key 'MyCustomKey'
        Encodes the string using a custom key.
    .NOTES
        Author: Chris Taylor
        Alias: ConvertTo-LTSecurity
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('ConvertTo-LTSecurity')]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        [string]$InputString,

        [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [AllowEmptyCollection()]
        $Key
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        $_initializationVector = [byte[]](240, 3, 45, 29, 0, 76, 173, 59)
        $DefaultKey = 'Thank you for using LabTech.'

        if ($Null -eq $Key) {
            $Key = $DefaultKey
        }

        try {
            $inputBytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
        }
        catch {
            try { $inputBytes = [System.Text.Encoding]::ASCII.GetBytes($InputString) } catch {
                Write-Debug "Failed to convert InputString to byte array: $_"
            }
        }

        Write-Debug "Attempting Encode for '$($InputString)' with Key '$($Key)'"
        $encodedString = ''
        try {
            $tripleDesProvider = New-Object System.Security.Cryptography.TripleDESCryptoServiceProvider
            $tripleDesProvider.key = (New-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([Text.Encoding]::UTF8.GetBytes($Key))
            $tripleDesProvider.IV = $_initializationVector
            $cryptoTransform = $tripleDesProvider.CreateEncryptor()
            $encodedString = [System.Convert]::ToBase64String($cryptoTransform.TransformFinalBlock($inputBytes, 0, ($inputBytes.Length)))
        }
        catch {
            Write-Debug "Failed to Encode string: '$($InputString)'. $_"
        }
        Finally {
            if ($cryptoTransform) { try { $cryptoTransform.Dispose() } catch { $cryptoTransform.Clear() } }
            if ($tripleDesProvider) { try { $tripleDesProvider.Dispose() } catch { $tripleDesProvider.Clear() } }
        }
        return $encodedString
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
