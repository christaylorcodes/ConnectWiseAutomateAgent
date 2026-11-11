function Invoke-CWAAScript {
    <#
    .SYNOPSIS
        Executes a scriptblock with standardized Automate script output and error handling.
    .DESCRIPTION
        Wraps the execution of a PowerShell scriptblock in the standard ConnectWise Automate
        script output pattern. Automatically creates a CWAAScriptOutput object, optionally
        initializes a log file, executes the scriptblock, captures the result, and returns
        the pipe-delimited output string that Automate expects.

        If the scriptblock throws, or an error escapes it to the error stream (for example
        Write-Error, or a cmdlet error the script did not handle), the output Status is set
        to Error and all error messages are captured in Result, in order. Errors the
        scriptblock handles itself (try/catch, -ErrorAction SilentlyContinue), including
        error records it outputs on purpose (catch { $_ }), do not count.
        Any output produced before the failure is kept in Data as Output=<text>, which is
        always the last item in Data. Errors are collected, not re-emitted, so the formatted
        string is the only output. Once parameters are bound, the function always returns a
        formatted output string and does not throw.

        Execution stops at the first terminating error, including statement-terminating
        errors such as a .NET method exception or an unknown command name, which a script
        run on its own would continue past.

        stderr from native commands (git, robocopy, installers) is treated as ordinary output,
        not as an error; check $LASTEXITCODE inside the scriptblock to detect native failures.
        On Windows PowerShell 5.1 with $ErrorActionPreference = 'Stop' in the calling script,
        PowerShell itself stops at the first native stderr line, which is reported as Error.
        With $ErrorActionPreference = 'SilentlyContinue' or 'Ignore' in the calling script,
        non-terminating errors are hidden from this function and the run can report Success;
        use Continue or Stop around this call.

        Only the success output of the scriptblock is captured. Write-Host, Write-Warning,
        Write-Verbose and Write-Information output still goes to the host, so Automate sees
        it as extra lines before the Status line.

        Leaving the scriptblock through exit, or through break/continue to a label outside
        this call, is reported as Status=Error. exit still ends the PowerShell host
        afterwards, so use throw (or set a Failed status) to signal failure instead.

        An optional URL parameter allows fetching and executing a remote script. The URL
        must use https:// (the agent runs as SYSTEM, so plain HTTP is rejected). The
        downloaded content must not be empty. It is read as UTF-8 unless it starts with a
        byte order mark for another Unicode encoding. The remote script runs in the caller's
        scope, as a scriptblock passed to -ScriptBlock does.
    .PARAMETER ScriptBlock
        The PowerShell scriptblock to execute.
    .PARAMETER URL
        URL to a remote PowerShell script. When specified, the script is downloaded via
        Invoke-WebRequest and executed instead of the ScriptBlock parameter. Must use
        https://.
    .PARAMETER EnableLogging
        When specified, initializes a log file via Initialize-CWAAScriptLog before execution.
        The log path is included in the output object. Each failure is written to the log
        with its stack trace or script location, not the source line text (the exception is
        a syntax error in a -URL script, whose message quotes the offending line). If the log
        cannot be created, the scriptblock still runs: LogPath is left empty and Data
        records LogInitFailed=<message>.
    .PARAMETER LogDirectory
        The directory for the log file. Only used when EnableLogging is specified.
        Defaults to the agent log directory (the Initialize-CWAAScriptLog default).
    .PARAMETER LogName
        The base name for the log file. Only used when EnableLogging is specified.
        Defaults to the name of the script or function that called Invoke-CWAAScript.
    .EXAMPLE
        Invoke-CWAAScript -ScriptBlock { Get-Service LTService | Select-Object -ExpandProperty Status }
        # Returns: Status=Success|Result=Running|LogPath=|Data=
    .EXAMPLE
        Invoke-CWAAScript -ScriptBlock { Get-Service InvalidService -ErrorAction Stop } -EnableLogging
        # Returns: Status=Error|Result=<error message>|LogPath=C:\Windows\LTSvc\logs\...
    .EXAMPLE
        Invoke-CWAAScript -URL 'https://example.com/myscript.ps1' -EnableLogging -LogName 'MyScript'
        Downloads and executes the remote script, logging to MyScript_<timestamp>.log.
    .NOTES
        Author: Chris Taylor
        Alias: Invoke-CWAScript
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    .PARAMETER ProgressAction
        Determines how PowerShell responds to progress updates generated by a script, cmdlet, or provider.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
    [Alias('Invoke-CWAScript')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ScriptBlock')]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $true, ParameterSetName = 'URL')]
        [ValidatePattern('^https://')]
        [string]$URL,

        [Parameter()]
        [switch]$EnableLogging,

        [Parameter()]
        [string]$LogDirectory,

        [Parameter()]
        [string]$LogName
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        $scriptOutput = New-CWAAScriptOutput
        $dataParts = @()
        # Collected as they stream, so output and errors produced before a terminating error are kept
        $result = New-Object System.Collections.Generic.List[object]
        $scriptErrors = New-Object System.Collections.Generic.List[object]
        $raisedCollectedErrors = $false
        $completed = $false
        $failed = $false

        # Initialize logging if requested. Logging is diagnostic only, so a failure here is
        # recorded in Data and the script still runs.
        if ($EnableLogging) {
            Try {
                if (-not $LogName) {
                    # Name the log after our caller, not after this wrapper
                    $callStack = Get-PSCallStack
                    if ($callStack.Count -gt 1) { $LogName = ([string]$callStack[1].Command) -replace '\.ps1$', '' }
                }
                $logParams = @{ ErrorAction = 'Stop' }
                if ($LogName) { $logParams.LogName = $LogName }
                if ($PSBoundParameters.ContainsKey('LogDirectory')) { $logParams.LogDirectory = $LogDirectory }
                $scriptOutput.LogPath = [string](Initialize-CWAAScriptLog @logParams)
                Write-Debug "Invoke-CWAAScript: Logging initialized at '$($scriptOutput.LogPath)'."
            }
            Catch {
                $dataParts += "LogInitFailed=$($_.Exception.Message)"
                Write-Debug "Invoke-CWAAScript: Log initialization failed: $($_.Exception.Message)"
            }
        }

        # The finally block emits the output line even when the scriptblock leaves through
        # exit or a labeled break/continue that unwinds past this function.
        Try {
            if ($PSCmdlet.ParameterSetName -eq 'URL') {
                Write-Debug "Invoke-CWAAScript: Fetching remote script from '$URL'."
                # Windows PowerShell 5.1 may not offer TLS 1.2 by default. The setting is
                # process-wide, so it is put back after the download. 3072 is Tls12, which has
                # no named value before .NET 4.5. A value of 0 is SystemDefault, which already
                # follows the operating system and must not be narrowed to TLS 1.2 only.
                $previousProtocol = [Net.ServicePointManager]::SecurityProtocol
                Try {
                    if ([int]$previousProtocol -ne 0 -and -not ([int]$previousProtocol -band 3072)) {
                        Try { [Net.ServicePointManager]::SecurityProtocol = [int]$previousProtocol -bor 3072 }
                        Catch { Write-Debug "Invoke-CWAAScript: Could not enable TLS 1.2: $($_.Exception.Message)" }
                    }
                    $response = Invoke-WebRequest -Uri $URL -UseBasicParsing -ErrorAction Stop
                }
                Finally { [Net.ServicePointManager]::SecurityProtocol = $previousProtocol }
                # Decode the raw bytes here rather than trusting the text PowerShell built:
                # Windows PowerShell reads a response without a charset as Latin-1 and leaves a
                # byte order mark in the text. Scripts are UTF-8 unless a byte order mark says
                # otherwise, and the reader drops the mark.
                $contentStream = $response.RawContentStream
                if (-not $contentStream) { throw "Remote script at '$URL' returned no content." }
                $null = $contentStream.Seek(0, [System.IO.SeekOrigin]::Begin)
                $reader = New-Object System.IO.StreamReader($contentStream, [System.Text.Encoding]::UTF8, $true)
                $remoteScript = $reader.ReadToEnd()
                if ([string]::IsNullOrWhiteSpace($remoteScript)) {
                    throw "Remote script at '$URL' was empty."
                }
                # Report a syntax error before anything runs
                $unboundBlock = [scriptblock]::Create($remoteScript)
                # A block made by [scriptblock]::Create is not tied to any scope and would run
                # inside this module, hiding the caller's variables and preferences and exposing
                # the module's private state. Run it through a block created in the caller's
                # session state instead, so it behaves as -ScriptBlock does.
                Try {
                    $runnerFactory = [scriptblock]::Create('{ & ([scriptblock]::Create($args[0])) }')
                    $executionBlock = @($PSCmdlet.SessionState.InvokeCommand.InvokeScript($PSCmdlet.SessionState, $runnerFactory, @()))[0]
                    if ($null -eq $executionBlock) { throw 'No runner block was returned.' }
                    $executionArguments = @($remoteScript)
                }
                Catch {
                    # A host that cannot do this still runs the script, inside the module's scope
                    Write-Debug "Invoke-CWAAScript: Could not bind the remote script to the caller's scope: $($_.Exception.Message)"
                    $executionBlock = $unboundBlock
                    $executionArguments = @()
                }
            }
            else {
                $executionBlock = $ScriptBlock
                $executionArguments = @()
            }

            # Success output is tagged before the error stream is merged in, so an error
            # record the script outputs on purpose (catch { $_ }) is not mistaken for an
            # escaped error. Only errors that reach the error stream count: errors handled
            # with try/catch or suppressed with -ErrorAction SilentlyContinue never do.
            # The one-iteration loop contains an unlabeled break/continue.
            foreach ($null in 1) {
                & { & $executionBlock @executionArguments | ForEach-Object { New-Object -TypeName PSObject -Property @{ '__CWAAScriptOutput' = $_ } } } 2>&1 |
                    ForEach-Object {
                        if ($_ -is [System.Management.Automation.ErrorRecord]) {
                            # Native command stderr is output, not failure (judge natives by exit code)
                            if ($_.FullyQualifiedErrorId -like 'NativeCommandError*') { $result.Add("$_") }
                            else { $scriptErrors.Add($_) }
                        }
                        elseif ($_.PSObject.Properties['__CWAAScriptOutput']) { $result.Add($_.__CWAAScriptOutput) }
                        else { $result.Add($_) }
                    }
            }
            if ($scriptErrors.Count) {
                $raisedCollectedErrors = $true
                throw (($scriptErrors | ForEach-Object { "$_" }) -join '; ')
            }
            $scriptOutput.Result = ($result | Out-String -Width 4096).Trim()
            $completed = $true

            Write-Debug "Invoke-CWAAScript: Execution completed successfully."
        }
        Catch {
            $failed = $true
            # Location without the source line text, which could contain secrets
            $describeLocation = {
                param($record)
                if ($record.ScriptStackTrace) { return $record.ScriptStackTrace }
                $info = $record.InvocationInfo
                if ($info -and $info.ScriptLineNumber) { return "at $($info.ScriptName): line $($info.ScriptLineNumber), char $($info.OffsetInLine)" }
            }

            # Report every error in order: those collected before a terminating error, then it
            $failures = @()
            foreach ($record in $scriptErrors) {
                $failures += @{ Message = "$record"; Trace = & $describeLocation $record }
            }
            if (-not $raisedCollectedErrors) {
                # A record written to the error stream and then rethrown is reported once
                $terminatingMessage = $_.Exception.Message
                if (-not ($failures | Where-Object { $_.Message -eq $terminatingMessage })) {
                    $failures += @{ Message = $terminatingMessage; Trace = & $describeLocation $_ }
                }
            }

            $scriptOutput.Status = 'Error'
            $scriptOutput.Result = ($failures | ForEach-Object { $_.Message }) -join '; '

            Write-Debug "Invoke-CWAAScript: Execution failed. Error: $($scriptOutput.Result)"

            # Best-effort: a failed log write must not escape and lose the formatted output
            if ($scriptOutput.LogPath) {
                Try {
                    foreach ($failure in $failures) {
                        $logMessage = "Script execution failed: $($failure.Message)"
                        if ($failure.Trace) { $logMessage += "`n$($failure.Trace)" }
                        Write-CWAAScriptLog -Message $logMessage -Level ERROR -LogPath $scriptOutput.LogPath -ErrorAction Stop
                    }
                }
                Catch {
                    $dataParts += "LogWriteFailed=$($_.Exception.Message)"
                }
            }
        }
        Finally {
            if (-not $completed) {
                if (-not $failed) {
                    # Unwound by exit or a labeled break/continue: still report, as a failure
                    $scriptOutput.Status = 'Error'
                    $scriptOutput.Result = 'The script left Invoke-CWAAScript early through exit or a break/continue to a label outside it.'
                    if ($scriptOutput.LogPath) {
                        Try { Write-CWAAScriptLog -Message "Script execution failed: $($scriptOutput.Result)" -Level ERROR -LogPath $scriptOutput.LogPath -ErrorAction Stop }
                        Catch { $dataParts += "LogWriteFailed=$($_.Exception.Message)" }
                    }
                }
                # Output= is free text, so it always goes last in Data. Formatting can throw
                # (it may be what failed), and nothing here may stop the output line below.
                Try { $partialOutput = ($result | Out-String -Width 4096).Trim() }
                Catch { $partialOutput = "<could not be formatted: $($_.Exception.Message)>" }
                if ($partialOutput) { $dataParts += "Output=$partialOutput" }
            }

            $scriptOutput.Data = $dataParts -join '; '
            ConvertTo-CWAAScriptOutput -InputObject $scriptOutput
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
