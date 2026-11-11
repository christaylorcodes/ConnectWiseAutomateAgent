@{
    PSDependOptions       = @{
        AddToPath  = $true
        Target     = 'output/RequiredModules'
        Parameters = @{
            Repository = 'PSGallery'
        }
    }

    # Versions use NuGet range syntax (passed to Save-PSResource -Version):
    #   '[6.2.0,7.0.0)'  = 6.2.0 or newer, below 7.0.0 (newest match wins)
    # Modules whose next major/minor release is likely to break the build are
    # bounded; low-risk tooling floats on 'latest'. The Assert_RequiredModule_Versions
    # task (.build/required-modules.ps1) fails the build if a resolved version falls outside its range.

    # Bounded: breaking changes have landed (or would land) in these
    Pester                = '[6.2.0,7.0.0)'
    Sampler               = '[0.120.1,0.121.0)'  # 0.x: minor versions may break tasks
    ModuleBuilder         = '[3.2.18,4.0.0)'
    'Microsoft.PowerShell.PlatyPS' = '[1.0.3,2.0.0)'  # docs task (.build/docs.ps1); replaces legacy platyPS 0.14

    # Floating: low risk
    InvokeBuild           = 'latest'
    PSScriptAnalyzer      = 'latest'
    'Sampler.GitHubTasks' = 'latest'
    'powershell-yaml'     = 'latest'
    ChangelogManagement   = 'latest'
}
