# ==============================================================================
# ScriptHelper-PwshLauncher.ps1
#
# Demonstrates using Invoke-CWAAPwsh to run PowerShell 7 code from Automate.
#
# ConnectWise Automate natively launches scripts under PowerShell 5.1
# (Windows PowerShell). When your script needs PowerShell 7 features —
# parallel ForEach-Object, ternary operators, null-coalescing, improved
# JSON handling, cross-platform cmdlets — use Invoke-CWAAPwsh to bridge
# from the PS5 session into pwsh.exe.
#
# Prerequisites:
#   - PowerShell 7 installed on the target machine
#     (winget install Microsoft.PowerShell, or MSI from GitHub Releases)
#   - ConnectWiseAutomateAgent module installed
#
# Requirements:
#   - PowerShell 5.0 or later (the Automate-launched session)
# ==============================================================================

Import-Module ConnectWiseAutomateAgent

# --- Example 1: Simple scriptblock under pwsh --------------------------------
#
# Pass a scriptblock that will be Base64-encoded and executed under pwsh.exe.
# The output is returned in Automate's pipe-delimited format.

Invoke-CWAAPwsh -ScriptBlock {
    $PSVersionTable.PSVersion.ToString()
}
# Output: Status=Success|Result=7.4.1|LogPath=|Data=

# --- Example 2: Using PS7 features ------------------------------------------
#
# This scriptblock uses ForEach-Object -Parallel, which is only available
# in PowerShell 7. Running this under PS5 would fail.

Invoke-CWAAPwsh -ScriptBlock {
    $services = 'LTService', 'LTSvcMon', 'W32Time', 'Spooler'
    $results = $services | ForEach-Object -Parallel {
        $svc = Get-Service $_ -ErrorAction SilentlyContinue
        if ($svc) { "$_ = $($svc.Status)" }
        else { "$_ = NotFound" }
    } -ThrottleLimit 4
    ($results | Sort-Object) -join ', '
}
# Output (-Parallel does not preserve order, so results are sorted):
# Status=Success|Result=LTService = Running, LTSvcMon = Running, ...|LogPath=|Data=

# --- Example 3: Running a PS7 script file with parameters --------------------
#
# Point to a .ps1 file and pass parameters as a hashtable. Strings, numbers and
# booleans/switches are supported ($true becomes -Force:$true).
# Useful when you have a PS7 script already written.

# Invoke-CWAAPwsh -FilePath 'C:\Scripts\Invoke-Remediation.ps1' -Parameters @{
#     ComputerName = $env:COMPUTERNAME
#     OutputDir    = 'C:\Temp\Remediation\'
#     Force        = $true
# }

# --- Example 4: Custom pwsh path ---------------------------------------------
#
# If pwsh.exe is installed in a non-standard location, specify it explicitly.
# pwsh is never taken from PATH. Use a folder only administrators can write to,
# because Automate scripts usually run as SYSTEM.

# Invoke-CWAAPwsh -ScriptBlock { 'Hello from custom pwsh' } -PwshPath 'C:\Program Files\PowerShell\7-preview\pwsh.exe'

# --- Example 5: Full Automate deployment pattern -----------------------------
#
# This is the typical pattern for an Automate-deployed script that needs PS7.
# The outer script runs under PS5 (launched by Automate) and delegates the
# real work to PS7. Invoke-CWAAPwsh handles pwsh detection and returns
# Status=Error if PowerShell 7 is not installed — no manual pre-check needed.

Invoke-CWAAPwsh -ScriptBlock {
    $data = @{
        PSVersion = $PSVersionTable.PSVersion.ToString()
        OS        = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
        Timestamp = Get-Date -Format 'o'
    }
    $data | ConvertTo-Json -Compress
}

# --- Example 6: Combining Invoke-CWAAScript with Invoke-CWAAPwsh ------------
#
# Use Invoke-CWAAScript to wrap the entire flow with automatic error handling.
# Invoke-CWAAPwsh never throws: it returns Status=Error, so check for that and
# throw to make the outer Invoke-CWAAScript report the failure.

Invoke-CWAAScript -EnableLogging -ScriptBlock {
    $ps7Output = Invoke-CWAAPwsh -ScriptBlock {
        # This file is parsed by Windows PowerShell before pwsh runs the block, so PS7-only
        # syntax (ternary, ??, &&) cannot appear here; put such code in a file and use -FilePath.
        # PS7-only cmdlets and parameters are fine, such as ConvertFrom-Json -AsHashtable.
        $os = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, ProductType |
            ConvertTo-Json | ConvertFrom-Json -AsHashtable
        $role = if ($os['ProductType'] -ne 1) { 'Server' } else { 'Workstation' }
        "This machine is a $role running PS $($PSVersionTable.PSVersion)"
    }
    if ($ps7Output -match '^Status=Error\|Result=([^|]*)') { throw "PowerShell 7 step failed: $($matches[1])" }
    # Invoke-CWAAPwsh returns pipe-delimited output; extract just the result
    if ($ps7Output -match 'Result=([^|]*)') { $matches[1] }
    else { $ps7Output }
}
