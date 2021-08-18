$InstallParameters = @{
    Server = 'automate.christaylor.codes'
    LocationID = 1
    InstallerToken = 'MyGeneratedInstallerToken'
}
# ^^ This info is sensitive take precautions to secure it ^^

$Module = 'ConnectWiseAutomateAgent'
if(!(Get-Module $Module -ListAvailable)){ Install-Module $Module }
Update-Module $Module
Install-Module $Module

# Redo will attempt to remove Automate before Installing
Redo-CWAA @InstallParameters