#Requires -Module Pester

<#
.SYNOPSIS
    Static PowerShell 2.0 compatibility checks for the module source.

.DESCRIPTION
    The agent has to be installable on Windows 7 and Server 2008 R2 as shipped (PowerShell 2.0,
    .NET 3.5), and PowerShell 2.0 cannot be run on current Windows, so these tests read the
    syntax tree of each source file instead of running it.

    Two levels are checked:

    - Every shipped file must PARSE on PowerShell 2.0. In direct download mode the whole module
      text is loaded at once, so one newer-only piece of syntax anywhere stops everything.
    - Deployment tier files must also avoid cmdlets, parameters, type shortcuts and .NET members
      that do not exist on PowerShell 2.0 / .NET 3.5.

    A file is in the deployment tier unless it is listed in $managedTier below. Managed tier
    files only run once an agent is installed, when PowerShell 5.1 or later can be assumed.
    See "PowerShell Version Tiers" in AGENTS.md.

    This is a block list of known constructs, not a proof. It cannot see things that only show
    at run time, such as reading a property from every item of an array ($list.Name) or calling
    .Count on a single object. A Windows 7 / Server 2008 R2 test machine is still the real check.

.NOTES
    Run with:
        Invoke-Pester Tests\ConnectWiseAutomateAgent.Compatibility.Tests.ps1 -Output Detailed
#>

BeforeDiscovery {
    $sourceRoot = Join-Path (Split-Path -Path $PSScriptRoot -Parent) 'source'

    # Files that only run on a machine that already has the agent (PowerShell 5.1 or later).
    $managedTier = @(
        'Public/Scripting/*'
        'Public/Logging/*'
        'Public/Service/Repair-CWAA.ps1'
        'Public/Service/Register-CWAAHealthCheckTask.ps1'
        'Public/Service/Unregister-CWAAHealthCheckTask.ps1'
        'Public/Service/Test-CWAAHealth.ps1'
        'Public/Test-CWAAServerConnectivity.ps1'
        'Public/InstallUninstall/Update-CWAA.ps1'
        'Public/Invoke-CWAACommand.ps1'
        'Public/Settings/Reset-CWAA.ps1'
    )
    # Used in source mode only; the built module is assembled without it.
    $notShipped = @('ConnectWiseAutomateAgent.psm1')

    $newerCommands = @(
        'Expand-Archive', 'Compress-Archive', 'Get-CimInstance', 'New-CimInstance', 'Invoke-CimMethod',
        'Get-CimAssociatedInstance', 'Invoke-RestMethod', 'Invoke-WebRequest', 'ConvertTo-Json', 'ConvertFrom-Json',
        'Unblock-File', 'Get-FileHash', 'Test-NetConnection', 'Get-ScheduledTask', 'Register-ScheduledTask',
        'Unregister-ScheduledTask', 'Get-ItemPropertyValue', 'Get-NetTCPConnection', 'Resolve-DnsName',
        'New-TemporaryFile', 'Write-Information'
    )
    $newerParameters = @{
        'Get-ChildItem' = @('File', 'Directory', 'Hidden', 'Depth')
        'Get-Content'   = @('Raw')
        'Out-File'      = @('NoNewline')
        'Set-Content'   = @('NoNewline')
        'Add-Content'   = @('NoNewline')
    }

    $script:CompatibilityCases = foreach ($sourceFile in Get-ChildItem -Path $sourceRoot -Recurse -File -Include *.ps1, *.psm1) {
        $relativePath = $sourceFile.FullName.Substring($sourceRoot.Length + 1) -replace '\\', '/'
        if ($notShipped -contains $relativePath) { continue }

        $parseFindings = @()
        $runtimeFindings = @()
        $syntaxTree = [System.Management.Automation.Language.Parser]::ParseFile($sourceFile.FullName, [ref]$null, [ref]$null)
        foreach ($node in $syntaxTree.FindAll({ $true }, $true)) {
            $line = $node.Extent.StartLineNumber
            switch ($node.GetType().Name) {
                'BinaryExpressionAst' {
                    if ("$($node.Operator)" -match '^[IC]?(In|Notin)$') { $parseFindings += "line ${line}: -in / -notin operator (use -contains)" }
                }
                'NamedAttributeArgumentAst' {
                    if ($node.ExpressionOmitted) { $parseFindings += "line ${line}: attribute argument '$($node.ArgumentName)' without '= `$True'" }
                }
                { $_ -eq 'FileRedirectionAst' -or $_ -eq 'MergingRedirectionAst' } {
                    if ("$($node.FromStream)" -notmatch '^(Output|Error)$') { $parseFindings += "line ${line}: redirection of the $($node.FromStream) stream" }
                }
                'ConvertExpressionAst' {
                    if ($node.Type.TypeName.Name -match '^(PSCustomObject|ordered)$') { $runtimeFindings += "line ${line}: [$($node.Type.TypeName.Name)] cast (use New-Object PSObject -Property)" }
                }
                'VariableExpressionAst' {
                    if ($node.VariablePath.UserPath -match '^(PSScriptRoot|PSItem|PSCommandPath)$') { $runtimeFindings += "line ${line}: `$$($node.VariablePath.UserPath)" }
                }
                'InvokeMemberExpressionAst' {
                    $memberName = "$($node.Member)"
                    if ($node.Static -and $memberName -eq 'new') { $runtimeFindings += "line ${line}: ::new() (use New-Object)" }
                    if (-not $node.Static -and $memberName -match '^(Where|ForEach)$') { $runtimeFindings += "line ${line}: .$memberName() method" }
                    if ($memberName -match '^(HasFlag|IsNullOrWhiteSpace)$') { $runtimeFindings += "line ${line}: $memberName (.NET 4)" }
                }
                'MemberExpressionAst' {
                    if ($node.Static -and "$($node.Member)" -match '^(Is64BitOperatingSystem|Is64BitProcess)$') { $runtimeFindings += "line ${line}: [Environment]::$($node.Member) (.NET 4)" }
                }
                'CommandAst' {
                    $commandName = "$($node.GetCommandName())"
                    if ($newerCommands -contains $commandName) { $runtimeFindings += "line ${line}: $commandName" }
                    if ($commandName -match '^(Where-Object|ForEach-Object|where|foreach|\?|%)$' -and $node.CommandElements.Count -gt 1) {
                        # PowerShell 2.0 only has the script block form. A lone variable is let through because
                        # it can hold a script block; -Property, -MemberName or a bare property name cannot.
                        $arguments = @($node.CommandElements | Select-Object -Skip 1)
                        $hasScriptBlock = [bool]($arguments | Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] })
                        $isLoneVariable = $arguments.Count -eq 1 -and $arguments[0] -is [System.Management.Automation.Language.VariableExpressionAst]
                        if (-not $hasScriptBlock -and -not $isLoneVariable) { $runtimeFindings += "line ${line}: $commandName without a script block" }
                    }
                    for ($elementIndex = 0; $elementIndex -lt $node.CommandElements.Count; $elementIndex++) {
                        $element = $node.CommandElements[$elementIndex]
                        if ($element -isnot [System.Management.Automation.Language.CommandParameterAst]) { continue }
                        # -ErrorAction Ignore, in any spelling: abbreviated name, -EA, or -ErrorAction:Ignore
                        $parameterName = $element.ParameterName.ToLower()
                        if ($parameterName -eq 'ea' -or ($parameterName.Length -ge 6 -and 'erroraction'.StartsWith($parameterName))) {
                            $valueNode = $element.Argument
                            if (-not $valueNode -and $elementIndex + 1 -lt $node.CommandElements.Count) { $valueNode = $node.CommandElements[$elementIndex + 1] }
                            if ("$($valueNode.Extent.Text)".Trim("'", '"') -eq 'Ignore') { $runtimeFindings += "line ${line}: -ErrorAction Ignore (use SilentlyContinue)" }
                        }
                        if ($newerParameters.ContainsKey($commandName) -and $newerParameters[$commandName] -contains $element.ParameterName) {
                            $runtimeFindings += "line ${line}: $commandName -$($element.ParameterName)"
                        }
                    }
                }
            }
        }

        $isManaged = [bool]($managedTier | Where-Object { $relativePath -like $_ })
        @{
            File            = $relativePath
            Deployment      = -not $isManaged
            ParseFindings   = @($parseFindings | Select-Object -Unique)
            RuntimeFindings = @($runtimeFindings | Select-Object -Unique)
        }
    }

    $script:ManagedTierCases = foreach ($pattern in $managedTier) {
        @{ Pattern = $pattern; Matched = @($script:CompatibilityCases | Where-Object { $_.File -like $pattern }).Count }
    }
}

Describe 'PowerShell 2.0 compatibility' {

    Context 'every shipped file parses on PowerShell 2.0' {
        It '<File> has no newer-only syntax' -ForEach $script:CompatibilityCases {
            ($ParseFindings -join '; ') | Should -BeNullOrEmpty
        }
    }

    Context 'deployment tier files avoid constructs missing from PowerShell 2.0 / .NET 3.5' {
        It '<File> has no newer-only commands, parameters, casts or members' -ForEach ($script:CompatibilityCases | Where-Object { $_.Deployment }) {
            ($RuntimeFindings -join '; ') | Should -BeNullOrEmpty
        }
    }

    Context 'the managed tier list' {
        It 'entry <Pattern> matches at least one source file' -ForEach $script:ManagedTierCases {
            $Matched | Should -BeGreaterThan 0
        }

        It 'leaves the install path in the deployment tier' -ForEach @(
            @{ DeploymentFiles = @($script:CompatibilityCases | Where-Object { $_.Deployment } | ForEach-Object { $_.File }) }
        ) {
            foreach ($required in 'Public/InstallUninstall/Install-CWAA.ps1', 'Public/InstallUninstall/Uninstall-CWAA.ps1', 'Public/InstallUninstall/Redo-CWAA.ps1', 'Private/Initialize/Initialize-CWAA.ps1', 'Private/Initialize/Initialize-CWAANetworking.ps1', 'Private/Resolve-CWAAServer.ps1', 'Private/Expand-CWAAZipFile.ps1') {
                $DeploymentFiles | Should -Contain $required
            }
        }
    }
}

Describe 'PowerShell file encoding' {

    # Windows PowerShell reads a file without a byte order mark as ANSI, so any non-ASCII character
    # in it is corrupted there. PSScriptAnalyzer reports this as PSUseBOMForUnicodeEncodedFile, and
    # Codacy fails the pull request on it without saying why in the GitHub check.
    It 'every PowerShell file with non-ASCII characters starts with a UTF-8 byte order mark' {
        $repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
        $missing = foreach ($file in Get-ChildItem -Path $repositoryRoot -Recurse -File -Force -Include *.ps1, *.psm1, *.psd1) {
            $relativePath = $file.FullName.Substring($repositoryRoot.Length + 1) -replace '\\', '/'
            if ($relativePath -match '^(output|\.git|node_modules)/') { continue }
            $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
            $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            if (-not $hasBom -and [Array]::FindIndex($bytes, [Predicate[byte]] { param($b) $b -gt 127 }) -ge 0) { $relativePath }
        }
        ($missing -join ', ') | Should -BeNullOrEmpty
    }
}
