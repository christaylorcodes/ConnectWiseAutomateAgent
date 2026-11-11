# Custom build task for the 'docs' workflow (loaded automatically by build.ps1 from
# the .build/ folder, after Sampler's tasks).
#
# Generates markdown command help with Microsoft.PowerShell.PlatyPS 1.x via
# Scripts/Update-MarkdownHelp.ps1. Replaces Sampler's PlatyPS tasks, which still use
# the legacy, unmaintained platyPS 0.14.2.

# Synopsis: Regenerates markdown command help (docs/help/<Module>/) from the built module's comment-based help.
task Generate_Markdown_Help {
    . Set-SamplerTaskVariable

    $helpSourceFolder = if ($BuildInfo.HelpSourceFolder) { $BuildInfo.HelpSourceFolder } else { 'docs/help' }
    $outputPath = Get-SamplerAbsolutePath -Path $helpSourceFolder -RelativeTo $BuildRoot
    $script = Join-Path -Path $BuildRoot -ChildPath 'Scripts/Update-MarkdownHelp.ps1'

    Write-Build White "  Module:  $BuiltModuleManifest"
    Write-Build White "  Output:  $outputPath"

    # Separate process: PlatyPS and powershell-yaml (loaded by Sampler) ship
    # conflicting YamlDotNet assemblies. The child inherits PSModulePath, so it
    # uses the pinned PlatyPS from output/RequiredModules.
    $pwshPath = (Get-Process -Id $PID).Path
    & $pwshPath -NoProfile -NonInteractive -File $script -ModulePath $BuiltModuleManifest -OutputPath $outputPath

    if ($LASTEXITCODE -ne 0) {
        throw "Markdown help generation failed (exit code $LASTEXITCODE)."
    }
}