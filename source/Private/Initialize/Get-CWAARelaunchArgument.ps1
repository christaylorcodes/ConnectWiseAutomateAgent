function Get-CWAARelaunchArgument {
    <#
    .SYNOPSIS
        Returns the arguments needed to re-run a powershell.exe command line, or nothing if it cannot be re-run.
    .DESCRIPTION
        Used by the WOW64 relaunch in Initialize-CWAA. A 32-bit session that loaded the module
        by direct download is re-run under 64-bit PowerShell with the same arguments, so this
        takes the process command line and returns everything after the executable, untouched,
        so that quoting survives.

        Only the host's own switches are inspected, up to the first -Command, -File or
        -EncodedCommand. Whatever follows is the caller's command text or script arguments
        and is never interpreted.

        Nothing is returned when re-running would not reproduce the session:
        - no -Command, -File or -EncodedCommand (an interactive console, or a script fed in some other way)
        - -Command - or -File - (the script was piped to standard input and is already consumed)
        - -NoExit among the host switches (the session is meant to stay open for a person)
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

    # Walk the host switches one token at a time until the one that introduces the command.
    # (?s): a -Command script can span several lines, and the rest of the text has to match across them.
    $remainingText = $relaunchArguments
    while ($remainingText -match '(?s)^\s*("[^"]*"|\S+)(.*)$') {
        $token = $Matches[1]
        $remainingText = $Matches[2]
        if ($token -notmatch '^[-/]([a-z]+):?$') { continue }
        $switchName = $Matches[1].ToLower()

        # PowerShell accepts any unambiguous prefix of a switch name (-c, -f, -e and -ec are fixed short forms)
        if ($switchName.Length -ge 3 -and 'noexit'.StartsWith($switchName)) { return }
        $introducesCommand = 'command'.StartsWith($switchName) -or 'file'.StartsWith($switchName) -or
            $switchName -eq 'ec' -or 'encodedcommand'.StartsWith($switchName)
        if ($introducesCommand) {
            $commandText = $remainingText.Trim()
            if (-not $commandText -or $commandText -eq '-') { return }
            return $relaunchArguments
        }
    }
}
