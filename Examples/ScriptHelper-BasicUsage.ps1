# ==============================================================================
# ScriptHelper-BasicUsage.ps1
#
# Demonstrates the basic usage of the Scripting helper functions for writing
# ConnectWise Automate-deployed PowerShell scripts. These helpers standardize
# the output format, logging, and error handling that Automate expects.
#
# The Automate agent parses script output in pipe-delimited format:
#   Status=Success|Result=<message>|LogPath=<path>|Data=<data>
#
# Requirements:
#   - ConnectWiseAutomateAgent module installed on the target machine
#   - PowerShell 5.0 or later
# ==============================================================================

Import-Module ConnectWiseAutomateAgent

# --- Example 1: Simple script with manual output object ----------------------
#
# Create an output object, do your work, set the result, and call ToString().
# This is the most flexible approach — you control every step.

$output = New-CWAAScriptOutput
$output.Result = 'Agent is healthy'
$output.ToString()
# Output: Status=Success|Result=Agent is healthy|LogPath=|Data=

# --- Example 2: Using Invoke-CWAAScript for automatic wrapping ---------------
#
# Invoke-CWAAScript handles output object creation, error catching, and
# formatting automatically. Your scriptblock just returns a result.

Invoke-CWAAScript -ScriptBlock {
    $service = Get-Service LTService -ErrorAction Stop
    "LTService is $($service.Status)"
}
# Output: Status=Success|Result=LTService is Running|LogPath=|Data=

# If the scriptblock throws, Status is automatically set to Error:
Invoke-CWAAScript -ScriptBlock {
    Get-Service 'NonExistentService' -ErrorAction Stop
}
# Output: Status=Error|Result=Cannot find any service with service name...|LogPath=|Data=

# --- Example 3: Script with logging ------------------------------------------
#
# Enable logging to create a log file on the endpoint. The log is named after
# the calling script (or -LogName) and records the start and any failure with
# its stack trace. Automate can pull the file using the LogPath in the output.

Invoke-CWAAScript -EnableLogging -LogName 'PatchInstall' -ScriptBlock {
    'Patch installation completed successfully'
}
# Output: Status=Success|Result=Patch installation completed...|LogPath=C:\Windows\LTSvc\logs\PatchInstall_...|Data=

# --- Example 4: Manual logging with Write-CWAAScriptLog ----------------------
#
# For more control over logging, initialize a log file and write entries
# at specific points in your script.

$output = New-CWAAScriptOutput
$output.LogPath = Initialize-CWAAScriptLog -LogName 'DiskCleanup'

Write-CWAAScriptLog -Message 'Starting disk cleanup' -LogPath $output.LogPath
Write-CWAAScriptLog -Message 'Clearing temp files' -LogPath $output.LogPath

$freedMB = 150  # example value
Write-CWAAScriptLog -Message "Freed $freedMB MB of disk space" -LogPath $output.LogPath

$output.Result = "Freed $freedMB MB"
$output.ToString()
# Output: Status=Success|Result=Freed 150 MB|LogPath=C:\Windows\LTSvc\logs\DiskCleanup_20260211-143000-123.log|Data=

# --- Example 5: Returning structured data ------------------------------------
#
# Use the Data property to pass key-value pairs back to Automate for
# populating EDFs (Extra Data Fields) or script variables.

$output = New-CWAAScriptOutput
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)

$output.Result = "C: drive has $freeGB GB free"
$output.Data = "FreeGB=$freeGB,TotalGB=$([math]::Round($disk.Size / 1GB, 2))"
$output.ToString()
# Output: Status=Success|Result=C: drive has 42.5 GB free|...|Data=FreeGB=42.5,TotalGB=237.96

# --- Example 6: Conditional failure ------------------------------------------
#
# Use Status = 'Failed' when the script ran correctly but the result indicates
# a problem. Use 'Error' only for unexpected exceptions.

$output = New-CWAAScriptOutput
$output.LogPath = Initialize-CWAAScriptLog -LogName 'ServiceCheck'

$service = Get-Service LTService -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq 'Running') {
    $output.Result = 'LTService is running'
    Write-CWAAScriptLog -Message 'Service check passed' -LogPath $output.LogPath
}
else {
    $output.Status = 'Failed'
    $status = if ($service) { $service.Status } else { 'Not Found' }
    $output.Result = "LTService is $status"
    Write-CWAAScriptLog -Message "Service check failed: $status" -Level WARNING -LogPath $output.LogPath
}

$output.ToString()

# --- Example 7: Using hashtable output (quick one-liners) --------------------
#
# ConvertTo-CWAAScriptOutput also accepts hashtables for quick formatting
# without creating a full output object. Use [ordered] to keep the key order.

ConvertTo-CWAAScriptOutput -InputObject ([ordered]@{
    Status = 'Success'
    Result = 'Quick check passed'
})
# Output: Status=Success|Result=Quick check passed

# --- Example 8: Running a script from a URL ----------------------------------
#
# Invoke-CWAAScript can fetch and execute a remote script directly.
# Useful for running scripts hosted in a GitHub repo without pre-deploying them.
# The script runs as SYSTEM, so only use URLs you control. (Placeholder URL:
# uncomment and replace before running.)

# Invoke-CWAAScript -URL 'https://raw.githubusercontent.com/org/repo/main/scripts/remediation.ps1' -EnableLogging
# Output: Status=Success|Result=<script output>|LogPath=C:\Windows\LTSvc\logs\...|Data=

# --- Note: do not call exit inside Invoke-CWAAScript -------------------------
#
# exit is reported as Status=Error, but it then ends the whole PowerShell host,
# so nothing after the Invoke-CWAAScript call runs. Use throw for failures instead.
