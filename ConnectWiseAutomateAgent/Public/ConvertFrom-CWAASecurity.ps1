Function ConvertFrom-CWAASecurity{
    [CmdletBinding()]
    [Alias('ConvertFrom-LTSecurity')]
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 1)]
        [string[]]$InputString,

        [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $True)]
        [AllowNull()]
        [string[]]$Key,

        [parameter(Mandatory = $false, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
        [switch]$Force=$True
    )

    Begin {
        $DefaultKey='Thank you for using LabTech.'
        $_initializationVector = [byte[]](240, 3, 45, 29, 0, 76, 173, 59)
        $NoKeyPassed=$False
        $DecodedString=$Null
        $DecodeString=$Null
    }

    Process {
        If ($Null -eq $Key) {
            $NoKeyPassed=$True
            $Key=$DefaultKey
        }
        foreach ($testInput in $InputString) {
            $DecodeString=$Null
            foreach ($testKey in $Key) {
                If ($Null -eq $DecodeString) {
                    If ($Null -eq $testKey) {
                        $NoKeyPassed=$True
                        $testKey=$DefaultKey
                    }
                    Write-Debug "Line $(LINENUM): Attempting Decode for '$($testInput)' with Key '$($testKey)'"
                    Try {
                        $numarray=[System.Convert]::FromBase64String($testInput)
                        $ddd = new-object System.Security.Cryptography.TripleDESCryptoServiceProvider
                        $ddd.key=(new-Object Security.Cryptography.MD5CryptoServiceProvider).ComputeHash([Text.Encoding]::UTF8.GetBytes($testKey))
                        $ddd.IV=$_initializationVector
                        $dd=$ddd.CreateDecryptor()
                        $DecodeString=[System.Text.Encoding]::UTF8.GetString($dd.TransformFinalBlock($numarray,0,($numarray.Length)))
                        $DecodedString+=@($DecodeString)
                    } Catch {
                    }

                    Finally {
                        if ((Get-Variable -Name dd -Scope 0 -EA 0)) {try {$dd.Dispose()} catch {$dd.Clear()}}
                        if ((Get-Variable -Name ddd -Scope 0 -EA 0)) {try {$ddd.Dispose()} catch {$ddd.Clear()}}
                    }
                } Else {
                }
            }
            If ($Null -eq $DecodeString) {
                If ($Force) {
                    If (($NoKeyPassed)) {
                        $DecodeString=ConvertFrom-CWAASecurity -InputString "$($testInput)" -Key '' -Force:$False
                        If (-not ($Null -eq $DecodeString)) {
                            $DecodedString+=@($DecodeString)
                        }
                    } Else {
                        $DecodeString=ConvertFrom-CWAASecurity -InputString "$($testInput)"
                        if (-not ($Null -eq $DecodeString)) {
                            $DecodedString+=@($DecodeString)
                        }
                    }
                } Else {
                }
            }
        }
    }

    End {
        If ($Null -eq $DecodedString) {
            Write-Debug "Line $(LINENUM): Failed to Decode string: '$($InputString)'"
            return $Null
        } else {
            return $DecodedString
        }
    }

}
