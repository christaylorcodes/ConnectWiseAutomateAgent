function Clear-CWAAInstallerArtifacts {
    <#
    .SYNOPSIS
        Cleans up stale ConnectWise Automate installer processes and temporary files.
    .DESCRIPTION
        Terminates any running installer-related processes and removes temporary installer
        files left behind by incomplete or failed installations. This prevents conflicts
        when starting a new install, reinstall, or update operation.

        Process names and file paths are read from the centralized module constants
        $Script:CWAAInstallerProcessNames and $Script:CWAAInstallerArtifactPaths.

        All operations are best-effort with errors suppressed. This function is intended
        as a defensive cleanup step, not a validated operation.
    .NOTES
        Version: 0.1.5.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding()]
    Param()

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        # Kill stale installer processes that may block new installations
        foreach ($processName in $Script:CWAAInstallerProcessNames) {
            Get-Process -Name $processName -ErrorAction SilentlyContinue |
                Stop-Process -Force -ErrorAction SilentlyContinue
        }

        # Remove leftover temporary installer files
        foreach ($artifactPath in $Script:CWAAInstallerArtifactPaths) {
            Remove-Item -Path $artifactPath -Force -Recurse -ErrorAction SilentlyContinue
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
