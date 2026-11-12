@{
    # PSScriptAnalyzer settings for ConnectWiseAutomateAgent
    # https://github.com/PowerShell/PSScriptAnalyzer/blob/master/docs/Cmdlets/Invoke-ScriptAnalyzer.md

    Severity = @('Error', 'Warning')

    ExcludeRules = @(
        # The module holds the proxy password as plain text because the agent registry
        # stores it re-encrypted with the agent key; there is no SecureString path through
        # that format. Set-CWAAProxy and Install-CWAA convert it back to a SecureString
        # for the WebProxy credential and for Set-CWAAProxy's -ProxyPassword parameter.
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
