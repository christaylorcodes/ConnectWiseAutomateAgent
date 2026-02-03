$InstallParameters = @{
    Server         = 'automate.example.com'
    LocationID     = 1
    InstallerToken = 'MyGeneratedInstallerToken'
}
# ^^ This info is sensitive take precautions to secure it ^^

# ==============================================================================
# SECURITY NOTE: Version locking
#
# Production scripts should pin to a specific module version. This prevents
# untested updates from rolling out to endpoints and mitigates supply-chain
# risk. Update $ModuleVersion deliberately after validating new releases.
#
# The Invoke-Expression fallback downloads and executes code at runtime.
# It is provided ONLY for systems where the PowerShell Gallery is unavailable
# (e.g., PS 2.0, restricted networks). The fallback URL is version-locked to
# a GitHub Release so the code is immutable after publication.
#
# PREFERRED: Use Install-Module from the PowerShell Gallery instead:
#   Install-Module 'ConnectWiseAutomateAgent' -RequiredVersion '1.0.0'
# ==============================================================================

$Module = 'ConnectWiseAutomateAgent'
$ModuleVersion = '1.0.0'  # Pin to a tested version — update after validating new releases

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
try {
    $installed = Get-Module $Module -ListAvailable |
        Where-Object { $_.Version -eq $ModuleVersion }
    if (-not $installed) {
        Install-Module $Module -RequiredVersion $ModuleVersion -Force -Scope AllUsers
    }
    Import-Module $Module -RequiredVersion $ModuleVersion *>$null
}
catch {
    # WARNING: Invoke-Expression executes downloaded code. See security note above.
    # This fallback is ONLY for systems where the PowerShell Gallery is unavailable.
    # The URL is pinned to a specific release tag — it will not change after publication.
    $URI = "https://github.com/christaylorcodes/ConnectWiseAutomateAgent/releases/download/v$ModuleVersion/ConnectWiseAutomateAgent.psm1"
    (New-Object Net.WebClient).DownloadString($URI) | Invoke-Expression
}

# Redo will attempt to remove Automate before Installing
Redo-CWAA @InstallParameters