function Remove-CWAAFolderRecursive {
    <#
    .SYNOPSIS
        Performs depth-first removal of a folder and all its contents.
    .DESCRIPTION
        Private helper that removes a folder using a three-pass depth-first strategy:
        1. Remove files inside each subfolder (leaves first)
        2. Remove subfolders sorted by path depth (deepest first)
        3. Remove the root folder itself

        This approach maximizes cleanup even when some files or folders are locked
        by running processes, which is common during agent uninstall/update operations.

        All removal operations use best-effort error handling (-ErrorAction SilentlyContinue).
        The caller's $WhatIfPreference and $ConfirmPreference propagate automatically
        through PowerShell's preference variable mechanism.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$Path
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        if (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
            Write-Debug "Path '$Path' does not exist. Nothing to remove."
            return
        }

        if ($PSCmdlet.ShouldProcess($Path, 'Remove Folder')) {
            Write-Debug "Removing Folder: $Path"
            Try {
                # Pass 1: Remove files inside each subfolder (leaves first)
                Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.psiscontainer } |
                    ForEach-Object {
                        Get-ChildItem -Path $_.FullName -ErrorAction SilentlyContinue |
                            Where-Object { -not $_.psiscontainer } |
                            Remove-Item -Force -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
                    }

                # Pass 2: Remove subfolders sorted by path depth (deepest first)
                Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
                    Where-Object { $_.psiscontainer } |
                    Sort-Object { $_.FullName.Length } -Descending |
                    Remove-Item -Force -ErrorAction SilentlyContinue -Recurse -Confirm:$False -WhatIf:$False

                # Pass 3: Remove the root folder itself
                Remove-Item -Recurse -Force -Path $Path -ErrorAction SilentlyContinue -Confirm:$False -WhatIf:$False
            }
            Catch {
                Write-Debug "Error removing folder '$Path': $($_.Exception.Message)"
            }
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
