$InstallParameters = @{
    Server         = 'automate.christaylor.codes'
    LocationID     = 1
    InstallerToken = 'MyGeneratedInstallerToken'
}
# ^^ This info is sensitive take precautions to secure it ^^

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
try {
    $Module = 'ConnectWiseAutomateAgent'
    try { Update-Module $Module -ErrorAction Stop }
    catch {
        Invoke-RestMethod 'https://raw.githubusercontent.com/christaylorcodes/Initialize-PSGallery/main/PSGalleryHelper.ps1' | Invoke-Expression
        Install-Module $Module -Force -Scope AllUsers -SkipPublisherCheck
    }

    Get-Module $Module -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1 |
    Import-Module *>$null
}
catch {
    $URI = 'https://raw.githubusercontent.com/christaylorcodes/ConnectWiseAutomateAgent/main/ConnectWiseAutomateAgent.ps1'
    (New-Object Net.WebClient).DownloadString($URI) | Invoke-Expression
}

# Redo will attempt to remove Automate before Installing
Redo-CWAA @InstallParameters