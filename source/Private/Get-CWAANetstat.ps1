function Get-CWAANetstat {
    <#
    .SYNOPSIS
        Returns raw output from the local computer's netstat.exe.
    .DESCRIPTION
        Thin wrapper around the system netstat.exe (invoked with -a -o -n) that exists to
        provide a single, mockable seam for the external process call. Callers such as
        Test-CWAAPort pipe the output to Select-String to locate processes using a port.

        The full system path ($env:windir\system32\netstat.exe) is used deliberately to
        avoid PATH hijacking, which is why this cannot be intercepted by mocking a bare
        'netstat' command - tests mock this function instead.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    Param()

    & "$env:windir\system32\netstat.exe" -a -o -n
}
