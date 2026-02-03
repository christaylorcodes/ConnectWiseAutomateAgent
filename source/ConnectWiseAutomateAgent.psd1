@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'ConnectWiseAutomateAgent.psm1'

    # Version number of this module.
    ModuleVersion     = '0.0.1'

    # ID used to uniquely identify this module
    GUID              = '37424fc5-48d4-4d15-8b19-e1c2bf4bab67'

    # Author of this module
    Author            = 'Chris Taylor'

    # Company or vendor of this module
    CompanyName       = 'Chris Taylor'

    # Copyright statement for this module
    Copyright         = '(c) 2026 Chris Taylor. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'PowerShell module for working with the ConnectWise Automate Agent.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '3.0'

    # Functions to export from this module
    # ModuleBuilder overwrites this list at build time
    FunctionsToExport = @('ConvertFrom-CWAASecurity','ConvertTo-CWAASecurity','Get-CWAAError','Get-CWAAInfo','Get-CWAAInfoBackup','Get-CWAALogLevel','Get-CWAAProbeError','Get-CWAAProxy','Get-CWAASettings','Hide-CWAAAddRemove','Install-CWAA','Invoke-CWAACommand','New-CWAABackup','Redo-CWAA','Register-CWAAHealthCheckTask','Rename-CWAAAddRemove','Repair-CWAA','Reset-CWAA','Restart-CWAA','Set-CWAALogLevel','Set-CWAAProxy','Show-CWAAAddRemove','Start-CWAA','Stop-CWAA','Test-CWAAHealth','Test-CWAAPort','Test-CWAAServerConnectivity','Uninstall-CWAA','Unregister-CWAAHealthCheckTask','Update-CWAA')

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport  = @()

    # Aliases to export from this module
    # ModuleBuilder discovers [Alias()] attributes at build time
    AliasesToExport   = @('ConvertFrom-LTSecurity','ConvertTo-LTSecurity','Get-LTErrors','Get-LTLogging','Get-LTProbeErrors','Get-LTProxy','Get-LTServiceInfo','Get-LTServiceInfoBackup','Get-LTServiceSettings','Hide-LTAddRemove','Install-LTService','Invoke-LTServiceCommand','New-LTServiceBackup','Redo-LTService','Register-LTHealthCheckTask','Reinstall-CWAA','Reinstall-LTService','Rename-LTAddRemove','Repair-LTService','Reset-LTService','Restart-LTService','Set-LTLogging','Set-LTProxy','Show-LTAddRemove','Start-LTService','Stop-LTService','Test-LTHealth','Test-LTPorts','Test-LTServerConnectivity','Uninstall-LTService','Unregister-LTHealthCheckTask','Update-LTService')

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{

        PSData = @{

            # Tags applied to this module
            Tags       = @('ChrisTaylorCodes', 'ConnectWise', 'Automate', 'LabTech', 'RMM')

            # A URL to the license for this module
            LicenseUri = 'https://github.com/christaylorcodes/ConnectWiseAutomateAgent/blob/main/LICENSE'

            # A URL to the main website for this project
            ProjectUri = 'https://github.com/christaylorcodes/ConnectWiseAutomateAgent'

            # A URL to an icon representing this module
            IconUri    = 'https://raw.githubusercontent.com/christaylorcodes/ConnectWiseAutomateAgent/main/Media/connectwise-automate.png'

            # ReleaseNotes populated at build time from CHANGELOG.md
            ReleaseNotes = ''

            # Prerelease tag for PSGallery (ASCII alphanumeric only, no dots/hyphens)
            # Controlled by GitVersion at build time; leave empty in source
            Prerelease = ''

        }

    }

    # HelpInfo URI of this module
    HelpInfoURI       = 'https://raw.githubusercontent.com/christaylorcodes/ConnectWiseAutomateAgent/main/source/en-US/ConnectWiseAutomateAgent-help.xml'

}
