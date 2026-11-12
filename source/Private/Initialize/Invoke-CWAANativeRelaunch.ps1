function Invoke-CWAANativeRelaunch {
    <#
    .SYNOPSIS
        Runs a command line under the native 64-bit powershell.exe and returns its exit code.
    .DESCRIPTION
        Used by the WOW64 relaunch in Initialize-CWAA when the module was loaded into 32-bit
        PowerShell on a 64-bit OS. The 64-bit host is reached through the sysnative folder, or
        through System32 with WOW64 file system redirection switched off for the launch when
        sysnative is not available. The child shares this console and its output streams, and
        starts in the directory this process was started in so relative paths still resolve.

        Returns nothing when the 64-bit session could not be started, so the caller can carry
        on in the 32-bit session instead of exiting with nothing done.
    .PARAMETER Arguments
        The powershell.exe arguments, as a single string so their original quoting is kept.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$Arguments
    )

    $nativePowerShell = "${env:WINDIR}\sysnative\windowspowershell\v1.0\powershell.exe"
    $redirectionDisabled = $False
    $redirectionState = [IntPtr]::Zero
    Try {
        if (-not (Test-Path -Path $nativePowerShell)) {
            # sysnative virtual folder is unavailable (e.g. older OS or non-interactive context).
            # Fall back to the real System32 path after disabling WOW64 file system redirection
            # so the 64-bit powershell.exe is accessible instead of the 32-bit redirected copy.
            Write-Warning 'SYSNATIVE PATH REDIRECTION IS NOT AVAILABLE. Attempting to access 64-bit PowerShell directly.'
            $nativePowerShell = "${env:WINDIR}\System32\WindowsPowershell\v1.0\powershell.exe"
            if (-not ('Kernel32.Wow64Redirection' -as [type])) {
                Add-Type -Debug:$False -Name Wow64Redirection -Namespace 'Kernel32' -MemberDefinition @"
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool Wow64DisableWow64FsRedirection(ref IntPtr ptr);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool Wow64RevertWow64FsRedirection(IntPtr ptr);
"@
            }
            $redirectionDisabled = [Kernel32.Wow64Redirection]::Wow64DisableWow64FsRedirection([ref]$redirectionState)
        }

        $relaunchedProcess = Start-Process -FilePath $nativePowerShell -ArgumentList $Arguments -NoNewWindow -PassThru -WorkingDirectory ([Environment]::CurrentDirectory) -ErrorAction Stop
        if (-not $relaunchedProcess) { return }
        # Wait for powershell.exe only (Start-Process -Wait also waits for everything it starts).
        # Reading Handle first is what makes ExitCode available afterwards.
        $Null = $relaunchedProcess.Handle
        $relaunchedProcess.WaitForExit()
        return $relaunchedProcess.ExitCode
    }
    Catch {
        Write-Warning "Unable to start the 64-bit PowerShell session. Error: $($_.Exception.Message)"
        return
    }
    Finally {
        if ($redirectionDisabled) {
            $Null = [Kernel32.Wow64Redirection]::Wow64RevertWow64FsRedirection($redirectionState)
        }
    }
}
