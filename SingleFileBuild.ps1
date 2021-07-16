$ModuleName = 'ConnectWiseAutomateAgent'
$PathRoot =  "C:\Users\$($env:USERNAME)\OneDrive - LabTech Consulting\Code\GitHub\christaylorcodes"

# Function that needs to run for module setup
$Initialize = 'Initialize-CWAA'

$Path = Join-Path $PathRoot $ModuleName
$FileName = "$($ModuleName).ps1"
$FullPath = Join-Path $Path $FileName

Get-ChildItem $(Join-Path $Path $ModuleName) -Filter '*.ps1' -Recurse | ForEach-Object {
    (Get-Content $_.FullName | Where-Object {$_})
} | Out-File $FullPath -Force

$Initialize | Out-File $FullPath -Append