@{

    # Script module or binary module file associated with this manifest.
    RootModule        = 'ConnectWiseAutomateAgent.psm1'

    # Version number of this module.
    ModuleVersion     = '1.0.0'

    # ID used to uniquely identify this module
    GUID              = '37424fc5-48d4-4d15-8b19-e1c2bf4bab67'

    # Author of this module
    Author            = 'Chris Taylor'

    # Company or vendor of this module
    CompanyName       = 'Chris Taylor'

    # Copyright statement for this module
    Copyright         = '(c) 2025 Chris Taylor. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'PowerShell module for working with the ConnectWise Automate Agent.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '3.0'

    # Functions to export from this module
    # Wildcard for development; ModuleBuilder writes explicit list at build time
    FunctionsToExport = @('*')

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport  = @()

    # Aliases to export from this module
    # Wildcard for development; ModuleBuilder discovers [Alias()] attributes at build time
    AliasesToExport   = @('*')

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

            # Prerelease tag for PSGallery (ASCII alphanumeric only, no dots/hyphens)
            # Remove or set to '' for stable releases
            Prerelease = 'alpha001'

        }

    }

    # HelpInfo URI of this module
    HelpInfoURI       = 'https://raw.githubusercontent.com/christaylorcodes/ConnectWiseAutomateAgent/main/source/en-US/ConnectWiseAutomateAgent-help.xml'

}
