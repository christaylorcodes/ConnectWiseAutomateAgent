function Invoke-CWAARegExe {
    <#
    .SYNOPSIS
        Runs the system reg.exe with the given arguments and returns its exit code.
    .DESCRIPTION
        Thin wrapper around reg.exe that exists to provide a single, mockable seam for the
        external process call, in the same way Get-CWAANetstat does for netstat.exe.
        Output from reg.exe is discarded; callers act on the exit code (0 is success).

        The full system path ($env:windir\system32\reg.exe) is used deliberately to avoid
        PATH hijacking, which is why tests mock this function instead of a bare 'reg' command.
    .PARAMETER Arguments
        The arguments to pass to reg.exe, one element per argument.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [OutputType([int])]
    Param(
        [Parameter(Mandatory = $True)]
        [string[]]$Arguments
    )

    $Null = & "$env:windir\system32\reg.exe" $Arguments 2>''
    return $LASTEXITCODE
}
