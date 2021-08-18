function ConvertFrom-CWAASecurity {
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
                    Write-Debug "Line $(LINENUM): Attempting Decode for '$($testInput)' with Key '$($testKey)'"
                    Try {
                        $numarray = [System.Convert]::FromBase64String($testInput)
                        $ddd = New-Object System.Security.Cryptography.TripleDESCryptoServiceProvider
                        $ddd.key = (New-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([Text.Encoding]::UTF8.GetBytes($testKey))
                        $ddd.IV = $_initializationVector
                        $dd = $ddd.CreateDecryptor()
                        $DecodeString = [System.Text.Encoding]::UTF8.GetString($dd.TransformFinalBlock($numarray, 0, ($numarray.Length)))
                        $DecodedString += @($DecodeString)
                    }
                    Catch {
                    }

                    Finally {
                        if ((Get-Variable -Name dd -Scope 0 -EA 0)) { try { $dd.Dispose() } catch { $dd.Clear() } }
                        if ((Get-Variable -Name ddd -Scope 0 -EA 0)) { try { $ddd.Dispose() } catch { $ddd.Clear() } }
                    }
                }
                else {
                }
            }
            if ($Null -eq $DecodeString) {
                if ($Force) {
                    if (($NoKeyPassed)) {
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
                }
            }
        }
    }

    End {
        if ($Null -eq $DecodedString) {
            Write-Debug "Line $(LINENUM): Failed to Decode string: '$($InputString)'"
            return $Null
        }
        else {
            return $DecodedString
        }
    }

}
