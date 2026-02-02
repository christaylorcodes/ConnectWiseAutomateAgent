function Wait-CWAACondition {
    <#
    .SYNOPSIS
        Polls a condition script block until it returns $true or a timeout is reached.
    .DESCRIPTION
        Generic polling helper that evaluates a condition at regular intervals. Returns $true
        if the condition was satisfied before the timeout, or $false if the timeout expired.
        Used to replace duplicated stopwatch-based Do-Until polling loops throughout the module.
    .PARAMETER Condition
        A script block that is evaluated each interval. The loop exits when this returns $true.
    .PARAMETER TimeoutSeconds
        Maximum number of seconds to wait before giving up. Must be at least 1.
    .PARAMETER IntervalSeconds
        Number of seconds to sleep between condition evaluations. Defaults to 5.
    .PARAMETER Activity
        Optional description logged via Write-Verbose at start and finish for diagnostics.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True)]
        [ScriptBlock]$Condition,

        [Parameter(Mandatory = $True)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$TimeoutSeconds,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$IntervalSeconds = 5,

        [Parameter()]
        [string]$Activity
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        if ($Activity) { Write-Verbose "Waiting for: $Activity" }

        $timeout = New-TimeSpan -Seconds $TimeoutSeconds
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        Do {
            Start-Sleep -Seconds $IntervalSeconds
            $conditionMet = & $Condition
        } Until ($stopwatch.Elapsed -gt $timeout -or $conditionMet)

        $stopwatch.Stop()
        $elapsedSeconds = [int]$stopwatch.Elapsed.TotalSeconds

        if ($conditionMet) {
            if ($Activity) { Write-Verbose "$Activity completed after $elapsedSeconds seconds." }
            return $true
        }
        else {
            if ($Activity) { Write-Verbose "$Activity timed out after $elapsedSeconds seconds." }
            return $false
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
