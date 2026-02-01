$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue -Recurse )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue -Recurse )

Foreach ($import in @($Public + $Private)) {
    Try { . $import.fullname }
    Catch { Write-Error -Message "Failed to import function $($import.fullname): $_" }
}

# Module mode 32-bit warning: WOW64 relaunch in Initialize-CWAA works correctly for
# single-file mode (ConnectWiseAutomateAgent.ps1) but cannot relaunch Import-Module.
# Warn users so they know to use the native 64-bit PowerShell host.
if ($env:PROCESSOR_ARCHITEW6432 -match '64' -and [IntPtr]::Size -ne 8) {
    Write-Warning 'ConnectWiseAutomateAgent: Module imported from 32-bit PowerShell on a 64-bit OS. Registry and file operations may target incorrect locations. Please use 64-bit PowerShell for reliable operation.'
}

Export-ModuleMember -Function $Public.Basename -Alias *

Initialize-CWAA