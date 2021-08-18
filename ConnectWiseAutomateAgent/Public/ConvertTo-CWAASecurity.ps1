function ConvertTo-CWAASecurity {
    [CmdletBinding()]
    [Alias('ConvertTo-LTSecurity')]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
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
        $_initializationVector = [byte[]](240, 3, 45, 29, 0, 76, 173, 59)
        $DefaultKey = 'Thank you for using LabTech.'

        if ($Null -eq $Key) {
            $Key = $DefaultKey
        }

        try {
            $numarray = [System.Text.Encoding]::UTF8.GetBytes($InputString)
        }
        catch {
            try { $numarray = [System.Text.Encoding]::ASCII.GetBytes($InputString) } catch {}
        }
        Write-Debug "Line $(LINENUM): Attempting Encode for '$($testInput)' with Key '$($testKey)'"
        try {
            $ddd = New-Object System.Security.Cryptography.TripleDESCryptoServiceProvider
            $ddd.key = (New-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([Text.Encoding]::UTF8.GetBytes($Key))
            $ddd.IV = $_initializationVector
            $dd = $ddd.CreateEncryptor()
            $str = [System.Convert]::ToBase64String($dd.TransformFinalBlock($numarray, 0, ($numarray.Length)))
        }
        catch {
            Write-Debug "Line $(LINENUM): Failed to Encode string: '$($InputString)'"
            $str = ''
        }
        Finally {
            if ($dd) { try { $dd.Dispose() } catch { $dd.Clear() } }
            if ($ddd) { try { $ddd.Dispose() } catch { $ddd.Clear() } }
        }
        return $str
    }
}
