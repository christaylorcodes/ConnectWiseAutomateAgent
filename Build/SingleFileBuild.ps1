$ModuleName = 'ConnectWiseAutomateAgent'
$PathRoot = "."

# Function that needs to run for module setup
$Initialize = 'Initialize-CWAA'

$FileName = "$($ModuleName).ps1"
$FullPath = Join-Path $PathRoot $FileName

Get-ChildItem $(Join-Path $PathRoot $ModuleName) -Filter '*.ps1' -Recurse | ForEach-Object {
    (Get-Content $_.FullName | Where-Object { $_ })
} | Out-File $FullPath -Force

$Initialize | Out-File $FullPath -Append