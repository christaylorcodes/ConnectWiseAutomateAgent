$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue -Recurse )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue -Recurse )

Foreach ($import in @($Public + $Private)) {
    Try { . $import.fullname }
    Catch { Write-Error -Message "Failed to import function $($import.fullname): $_" }
}

# Module mode 32-bit warning, shared with the built module (build.yaml Prefix)
. $PSScriptRoot\prefix.ps1

Export-ModuleMember -Function $Public.Basename -Alias *

Initialize-CWAA