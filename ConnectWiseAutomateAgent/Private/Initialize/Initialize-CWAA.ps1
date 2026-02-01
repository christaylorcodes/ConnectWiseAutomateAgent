function Get-CWAARedactedValue {
    <#
    .SYNOPSIS
        Returns a SHA256-hashed redacted representation of a sensitive string.
    .DESCRIPTION
        Private helper that returns '[SHA256:a1b2c3d4]' for non-empty strings
        and '[EMPTY]' for null/empty strings. Used to log that a credential value
        is present without exposing the actual content.
    .NOTES
        Version: 0.1.5.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$InputString
    )
    if ([string]::IsNullOrEmpty($InputString)) {
        return '[EMPTY]'
    }
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($InputString))
    $hashHex = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
    $sha256.Dispose()
    return "[SHA256:$($hashHex.Substring(0, 8))]"
}

function Initialize-CWAA {
    # Guard: PowerShell 1.0 lacks $PSVersionTable entirely
    if (-not ($PSVersionTable)) {
        Write-Warning 'PS1 Detected. PowerShell Version 2.0 or higher is required.'
        return
    }
    if ($PSVersionTable.PSVersion.Major -lt 3) {
        Write-Verbose 'PS2 Detected. PowerShell Version 3.0 or higher may be required for full functionality.'
    }

    # WOW64 relaunch: When running as 32-bit PowerShell on a 64-bit OS, many registry
    # and file system operations target the wrong hive/path. Re-launch under native
    # 64-bit PowerShell to ensure consistent behavior with the Automate agent services.
    # Note: This relaunch works correctly in single-file mode (ConnectWiseAutomateAgent.ps1).
    # In module mode (Import-Module), the .psm1 emits a warning instead since relaunch
    # cannot re-invoke Import-Module from within a function.
    if ($env:PROCESSOR_ARCHITEW6432 -match '64' -and [IntPtr]::Size -ne 8) {
        Write-Warning '32-bit PowerShell session detected on 64-bit OS. Attempting to launch 64-Bit session to process commands.'
        $pshell = "${env:WINDIR}\sysnative\windowspowershell\v1.0\powershell.exe"
        if (!(Test-Path -Path $pshell)) {
            # sysnative virtual folder is unavailable (e.g. older OS or non-interactive context).
            # Fall back to the real System32 path after disabling WOW64 file system redirection
            # so the 64-bit powershell.exe is accessible instead of the 32-bit redirected copy.
            Write-Warning 'SYSNATIVE PATH REDIRECTION IS NOT AVAILABLE. Attempting to access 64-bit PowerShell directly.'
            $pshell = "${env:WINDIR}\System32\WindowsPowershell\v1.0\powershell.exe"
            $FSRedirection = $True
            Add-Type -Debug:$False -Name Wow64 -Namespace 'Kernel32' -MemberDefinition @'
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool Wow64DisableWow64FsRedirection(ref IntPtr ptr);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool Wow64RevertWow64FsRedirection(ref IntPtr ptr);
'@
            [ref]$ptr = New-Object System.IntPtr
            $Null = [Kernel32.Wow64]::Wow64DisableWow64FsRedirection($ptr)
        }

        # Re-invoke the original command/script under the 64-bit host
        if ($myInvocation.Line) {
            &"$pshell" -NonInteractive -NoProfile $myInvocation.Line
        }
        elseif ($myInvocation.InvocationName) {
            &"$pshell" -NonInteractive -NoProfile -File "$($myInvocation.InvocationName)" $args
        }
        else {
            &"$pshell" -NonInteractive -NoProfile $myInvocation.MyCommand
        }
        $ExitResult = $LASTEXITCODE

        # Restore file system redirection if it was disabled
        if ($FSRedirection -eq $True) {
            [ref]$defaultptr = New-Object System.IntPtr
            $Null = [Kernel32.Wow64]::Wow64RevertWow64FsRedirection($defaultptr)
        }
        Write-Warning 'Exiting 64-bit session. Module will only remain loaded in native 64-bit PowerShell environment.'
        Exit $ExitResult
    }

    # Module-level constants â€” centralized to avoid duplication across functions.
    # These are cheap to create with no side effects, so they run at module load.
    $Script:CWAARegistryRoot          = 'HKLM:\SOFTWARE\LabTech\Service'
    $Script:CWAARegistrySettings      = 'HKLM:\SOFTWARE\LabTech\Service\Settings'
    $Script:CWAAInstallPath           = "${env:windir}\LTSVC"
    $Script:CWAAInstallerTempPath     = "${env:windir}\Temp\LabTech"
    $Script:CWAAServiceNames          = @('LTService', 'LTSvcMon')
    # Server URL validation regex breakdown:
    #   ^(https?://)?                              — optional http:// or https:// scheme
    #   (([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}   — IPv4 address (0.0.0.0 - 299.299.299.299)
    #   |                                          — OR
    #   [a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)  — hostname with optional subdomains
    #   $                                          — end of string, no trailing path/query
    $Script:CWAAServerValidationRegex = '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$'

    # Registry paths for Add/Remove Programs operations (shared by Hide, Show, Rename functions)
    $Script:CWAAInstallerProductKeys  = @(
        'HKLM:\SOFTWARE\Classes\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
        'HKLM:\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC'
    )
    $Script:CWAAUninstallKeys         = @(
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}'
    )
    $Script:CWAARegistryBackup        = 'HKLM:\SOFTWARE\LabTechBackup\Service'

    # Installer artifact paths for cleanup (used by Clear-CWAAInstallerArtifacts)
    $Script:CWAAInstallerArtifactPaths = @(
        "${env:windir}\Temp\_LTUpdate",
        "${env:windir}\Temp\Agent_Uninstall.exe",
        "${env:windir}\Temp\RemoteAgent.msi",
        "${env:windir}\Temp\Uninstall.exe",
        "${env:windir}\Temp\Uninstall.exe.config"
    )

    # Installer process names for cleanup (used by Clear-CWAAInstallerArtifacts)
    $Script:CWAAInstallerProcessNames = @('Agent_Uninstall', 'Uninstall', 'LTUpdate')

    # Windows Event Log settings (used by Write-CWAAEventLog)
    $Script:CWAAEventLogSource = 'ConnectWiseAutomateAgent'
    $Script:CWAAEventLogName   = 'Application'

    # Service credential storage â€" populated on-demand by Get-CWAAProxy
    $Script:LTServiceKeys = [PSCustomObject]@{
        ServerPasswordString = ''
        PasswordString       = ''
    }

    # Proxy configuration â€” populated on-demand by Initialize-CWAANetworking
    $Script:LTProxy = [PSCustomObject]@{
        ProxyServerURL = ''
        ProxyUsername   = ''
        ProxyPassword   = ''
        Enabled         = $False
    }

    # Networking subsystem deferred flags. Initialize-CWAANetworking sets these to $True
    # after registration/initialization. This keeps module import fast and avoids
    # irreversible global session side effects until networking is actually needed.
    $Script:CWAANetworkInitialized = $False
    $Script:CWAACertCallbackRegistered = $False
}
