@{
    PSDependOptions             = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository = 'PSGallery'
        }
    }

    InvokeBuild                 = 'latest'
    PSScriptAnalyzer            = 'latest'
    Pester                      = @{
        Version    = '5.6.1'
        Parameters = @{
            SkipPublisherCheck = $true
        }
    }
    Sampler                     = 'latest'
    ModuleBuilder               = 'latest'
    platyPS                     = 'latest'
    'powershell-yaml'           = 'latest'
}
