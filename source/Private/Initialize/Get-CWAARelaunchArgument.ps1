function Get-CWAARelaunchArgument {
    <#
    .SYNOPSIS
        Returns the arguments needed to re-run a powershell.exe command line, or nothing if it cannot be re-run.
    .DESCRIPTION
        Used by the WOW64 relaunch in Initialize-CWAA. A 32-bit session that loaded the module
        by direct download is re-run under 64-bit PowerShell with the same arguments, so this
        takes the process command line and returns everything after the executable, untouched,
        so that quoting survives.

        Nothing is returned when re-running would not reproduce the session:
        - no arguments at all (an interactive console)
        - -Command - or -File - (the script was piped to standard input and is already consumed)
        - -NoExit (the session is meant to stay open for a person)
    .PARAMETER CommandLine
        The full process command line, as returned by [Environment]::CommandLine.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [OutputType([string])]
    Param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$CommandLine
    )

    # Drop the executable: a quoted path, or everything up to the first space
    $relaunchArguments = ("$CommandLine" -replace '^\s*(?:"[^"]*"|\S+)\s*', '').Trim()

    if (-not $relaunchArguments) { return }
    # PowerShell accepts any unambiguous prefix of a parameter name: -c, -Command, -f, -File, -noe, -NoExit
    if ($relaunchArguments -match '(?i)(?:^|\s)[-/](?:c|co|com|comm|comma|comman|command|f|fi|fil|file)\s+-\s*$') { return }
    if ($relaunchArguments -match '(?i)(?:^|\s)[-/]noe(?:x|xi|xit)?(?:\s|$)') { return }

    return $relaunchArguments
}
