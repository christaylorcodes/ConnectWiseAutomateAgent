function Invoke-CWAAMsiInstaller {
    <#
    .SYNOPSIS
        Executes the Automate agent MSI installer with retry logic.
    .DESCRIPTION
        Launches msiexec.exe with the provided arguments and retries up to a configurable
        number of attempts if the LTService service is not detected after installation.
        Between retries, polls for the service using Wait-CWAACondition. Redacts server
        passwords from verbose output for security.
    .PARAMETER InstallerArguments
        The full argument string to pass to msiexec.exe (e.g., '/i "path\Agent_Install.msi" SERVERADDRESS=... /qn').
    .PARAMETER MaxAttempts
        Maximum number of install attempts before giving up. Defaults to $Script:CWAAInstallMaxAttempts.
    .PARAMETER RetryDelaySeconds
        Seconds to wait (polling for service) between retry attempts. Defaults to $Script:CWAAInstallRetryDelaySeconds.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [Parameter(Mandatory = $True)]
        [string]$InstallerArguments,

        [Parameter()]
        [int]$MaxAttempts = $Script:CWAAInstallMaxAttempts,

        [Parameter()]
        [int]$RetryDelaySeconds = $Script:CWAAInstallRetryDelaySeconds
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        if (-not $PSCmdlet.ShouldProcess("msiexec.exe $InstallerArguments", 'Execute Install')) {
            return $true
        }

        $installAttempt = 0
        Do {
            if ($installAttempt -gt 0) {
                Write-Warning "Service Failed to Install. Retrying in $RetryDelaySeconds seconds." -WarningAction 'Continue'
                $Null = Wait-CWAACondition -Condition {
                    $serviceCount = ('LTService') | Get-Service -EA 0 | Measure-Object | Select-Object -Expand Count
                    $serviceCount -eq 1
                } -TimeoutSeconds $RetryDelaySeconds -IntervalSeconds 5 -Activity 'Waiting for service availability before retry'
            }
            $installAttempt++

            $runningServiceCount = ('LTService') | Get-Service -EA 0 | Measure-Object | Select-Object -Expand Count
            if ($runningServiceCount -eq 0) {
                $redactedArguments = $InstallerArguments -replace 'SERVERPASS="[^"]*"', 'SERVERPASS="REDACTED"'
                Write-Verbose "Launching Installation Process: msiexec.exe $redactedArguments"
                Start-Process -Wait -FilePath "${env:windir}\system32\msiexec.exe" -ArgumentList $InstallerArguments -WorkingDirectory $env:TEMP
                Start-Sleep 5
            }

            $runningServiceCount = ('LTService') | Get-Service -EA 0 | Measure-Object | Select-Object -Expand Count
        } Until ($installAttempt -ge $MaxAttempts -or $runningServiceCount -eq 1)

        if ($runningServiceCount -eq 0) {
            Write-Error "LTService was not installed. Installation failed after $MaxAttempts attempts."
            return $false
        }

        return $true
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
