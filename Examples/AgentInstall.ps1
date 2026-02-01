$InstallParameters = @{
    Server         = 'automate.example.com'
    LocationID     = 1
    InstallerToken = 'MyGeneratedInstallerToken'
}
# ^^ This info is sensitive take precautions to secure it ^^

# ==============================================================================
# SECURITY WARNING: The fallback method below uses Invoke-Expression to load
# code downloaded from the internet at runtime. This is convenient but carries
# inherent risk -- a compromised source or man-in-the-middle attack could
# execute arbitrary code on this machine.
#
# RECOMMENDED: Use Install-Module from the PowerShell Gallery instead:
#   Install-Module 'ConnectWiseAutomateAgent' -Scope AllUsers
#
# The Invoke-Expression fallback is provided ONLY for systems where the
# PowerShell Gallery is unavailable (e.g., PS 2.0, restricted networks).
# ==============================================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
try {
    $Module = 'ConnectWiseAutomateAgent'
    try { Update-Module $Module -ErrorAction Stop }
    catch { Install-Module $Module -Force -Scope AllUsers -SkipPublisherCheck }

    Get-Module $Module -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1 |
    Import-Module *>$null
}
catch {
    # WARNING: Invoke-Expression executes downloaded code. See security note above.
    # This fallback is ONLY for systems where the PowerShell Gallery is unavailable.
    $URI = 'https://raw.githubusercontent.com/christaylorcodes/ConnectWiseAutomateAgent/main/ConnectWiseAutomateAgent.ps1'
    (New-Object Net.WebClient).DownloadString($URI) | Invoke-Expression
}

# Redo will attempt to remove Automate before Installing
Redo-CWAA @InstallParameters