@{
    # PSScriptAnalyzer settings for ConnectWiseAutomateAgent
    # https://github.com/PowerShell/PSScriptAnalyzer/blob/master/docs/Cmdlets/Invoke-ScriptAnalyzer.md

    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # Set-CWAAProxy must convert a plain-text proxy password to SecureString
        # for storage in the agent's registry configuration. The password originates
        # from the user's -ProxyPassword parameter and there is no SecureString path
        # through the LabTech agent registry format.
        'PSAvoidUsingConvertToSecureStringWithPlainText',

        # Repair-CWAA uses Get-CimInstance Win32_Process (not WMI) for process
        # command-line matching. Suppress in case older functions trigger this rule.
        'PSAvoidUsingWMICmdlet',

        # ServerPassword parameters in Install-CWAA and Redo-CWAA accept a pre-encrypted
        # LabTech agent password string, not a user credential. The LabTech agent MSI
        # expects a plain string via SERVERPASS= argument. SecureString is not applicable.
        'PSAvoidUsingPlainTextForPassword',

        # Function names use domain-specific plural nouns that are correct:
        # Clear-CWAAInstallerArtifacts (multiple files/processes), Get-CWAASettings (multiple values)
        'PSUseSingularNouns',

        # ConvertFrom-CWAASecurity uses [switch]$Force = $True so it automatically tries
        # alternate decryption keys on failure. Many callers rely on this default.
        'PSAvoidDefaultValueSwitchParameter'
    )

    Rules = @{
        PSUseCompatibleSyntax = @{
            Enable         = $True
            TargetVersions = @('3.0', '5.1')
        }
    }
}
