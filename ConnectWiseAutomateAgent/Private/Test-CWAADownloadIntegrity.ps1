function Test-CWAADownloadIntegrity {
    <#
    .SYNOPSIS
        Validates a downloaded file meets minimum size requirements.
    .DESCRIPTION
        Private helper that checks whether a downloaded installer file exists and
        exceeds the specified minimum size threshold. If the file is below the
        threshold, it is treated as corrupt or incomplete: a warning is emitted
        and the file is removed.

        The default threshold of 1234 KB matches the established convention for
        MSI/EXE installer files. The Agent_Uninstall.exe uses a lower threshold
        of 80 KB due to its smaller expected size.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$FilePath,

        [Parameter()]
        [string]$FileName,

        [Parameter()]
        [int]$MinimumSizeKB = 1234
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        if (-not $FileName) {
            $FileName = Split-Path $FilePath -Leaf
        }
    }

    Process {
        if (-not (Test-Path $FilePath)) {
            Write-Debug "$FileName not found at '$FilePath'."
            return $false
        }

        $fileSizeKB = (Get-Item $FilePath -ErrorAction SilentlyContinue).Length / 1KB
        if (-not ($fileSizeKB -gt $MinimumSizeKB)) {
            Write-Warning "$FileName size is below normal ($([math]::Round($fileSizeKB, 1)) KB < $MinimumSizeKB KB). Removing suspected corrupt file."
            Remove-Item $FilePath -ErrorAction SilentlyContinue -Force -Confirm:$False
            return $false
        }

        Write-Debug "$FileName integrity check passed ($([math]::Round($fileSizeKB, 1)) KB >= $MinimumSizeKB KB)."
        return $true
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
