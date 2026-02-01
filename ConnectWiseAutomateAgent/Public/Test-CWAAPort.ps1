function Test-CWAAPort {
    <#
    .SYNOPSIS
        Tests connectivity to TCP ports required by the ConnectWise Automate agent.
    .DESCRIPTION
        Verifies that the local LTTray port is available and tests connectivity to
        the required TCP ports (70, 80, 443) on the Automate server, plus port 8002
        on the Automate mediator server.
        If no server is provided, the function attempts to detect it from the installed
        agent configuration or backup info.
    .PARAMETER Server
        The URL of the Automate server (e.g., https://automate.domain.com).
        If not provided, the function uses Get-CWAAInfo or Get-CWAAInfoBackup to discover it.
    .PARAMETER TrayPort
        The local port LTSvc.exe listens on for LTTray communication.
        Defaults to 42000 if not provided or not found in agent configuration.
    .PARAMETER Quiet
        Returns a boolean connectivity result instead of verbose output.
    .EXAMPLE
        Test-CWAAPort -Server 'https://automate.domain.com'
        Tests all required ports against the specified server.
    .EXAMPLE
        Test-CWAAPort -Quiet
        Returns $True if the TrayPort is available, $False otherwise.
    .NOTES
        Author: Chris Taylor
        Alias: Test-LTPorts
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding()]
    [Alias('Test-LTPorts')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true, ValueFromPipeline = $True)]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [int]$TrayPort,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Quiet
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
        $MediatorServer = 'mediator.labtechsoftware.com'

        function Private:TestPort {
            Param(
                [parameter(Position = 0)]
                [string]$ComputerName,

                [parameter(Mandatory = $False)]
                [System.Net.IPAddress]$IPAddress,

                [parameter(Mandatory = $True, Position = 1)]
                [int]$Port
            )

            $RemoteServer = if ([string]::IsNullOrEmpty($ComputerName)) { $IPAddress } else { $ComputerName }
            if ([string]::IsNullOrEmpty($RemoteServer)) {
                Write-Error "No ComputerName or IPAddress was provided to test."
                return
            }

            $tcpClient = New-Object System.Net.Sockets.TcpClient
            Try {
                Write-Output "Connecting to $($RemoteServer):$Port (TCP).."
                $tcpClient.Connect($RemoteServer, $Port)
                Write-Output 'Connection successful'
            }
            Catch {
                Write-Output 'Connection failed'
            }
            Finally {
                $tcpClient.Close()
            }
        }
    }

    Process {
        if (-not ($Server) -and (-not ($TrayPort) -or -not ($Quiet))) {
            Write-Verbose 'No Server Input - Checking for names.'
            $Server = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand 'Server' -EA 0
            if (-not ($Server)) {
                Write-Verbose 'No Server found in installed Service Info. Checking for Service Backup.'
                $Server = Get-CWAAInfoBackup -EA 0 -Verbose:$False | Select-Object -Expand 'Server' -EA 0
            }
        }

        if (-not ($Quiet) -or (($TrayPort) -ge 1 -and ($TrayPort) -le 65530)) {
            if (-not ($TrayPort) -or -not (($TrayPort) -ge 1 -and ($TrayPort) -le 65530)) {
                # Discover TrayPort from agent configuration if not provided
                $TrayPort = (Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False | Select-Object -Expand TrayPort -EA 0)
            }
            if (-not ($TrayPort) -or $TrayPort -notmatch '^\d+$') { $TrayPort = 42000 }

            [array]$processes = @()
            # Get all processes using the TrayPort (default 42000)
            Try {
                $netstatOutput = & "$env:windir\system32\netstat.exe" -a -o -n | Select-String -Pattern " .*[0-9\.]+:$($TrayPort).*[0-9\.]+:[0-9]+ .*?([0-9]+)" -EA 0
            }
            Catch {
                Write-Output 'Error calling netstat.exe.'
                $netstatOutput = $null
            }
            foreach ($netstatLine in $netstatOutput) {
                $processes += ($netstatLine -split ' {4,}')[-1]
            }
            $processes = $processes | Where-Object { $_ -gt 0 -and $_ -match '^\d+$' } | Sort-Object | Get-Unique

            if (($processes)) {
                if (-not ($Quiet)) {
                    foreach ($processId in $processes) {
                        if ((Get-Process -Id $processId -EA 0 | Select-Object -Expand ProcessName -EA 0) -eq 'LTSvc') {
                            Write-Output "TrayPort Port $TrayPort is being used by LTSvc."
                        }
                        else {
                            Write-Output "Error: TrayPort Port $TrayPort is being used by $(Get-Process -Id $processId | Select-Object -Expand ProcessName -EA 0)."
                        }
                    }
                }
                else { return $False }
            }
            elseif (($Quiet) -eq $True) {
                return $True
            }
            else {
                Write-Output "TrayPort Port $TrayPort is available."
            }
        }

        foreach ($serverEntry in $Server) {
            if ($Quiet) {
                $cleanServerAddress = ($serverEntry -replace 'https?://', '' | ForEach-Object { $_.Trim() })
                Test-Connection $cleanServerAddress -Quiet
                return
            }

            if ($serverEntry -match $Script:CWAAServerValidationRegex) {
                Try {
                    $cleanServerAddress = ($serverEntry -replace 'https?://', '' | ForEach-Object { $_.Trim() })
                    Write-Output 'Testing connectivity to required TCP ports:'
                    TestPort -ComputerName $cleanServerAddress -Port 70
                    TestPort -ComputerName $cleanServerAddress -Port 80
                    TestPort -ComputerName $cleanServerAddress -Port 443
                    TestPort -ComputerName $MediatorServer -Port 8002
                }
                Catch {
                    Write-Error "There was an error testing the ports for '$serverEntry'. $($_)" -ErrorAction Stop
                }
            }
            else {
                Write-Warning "Server address '$($serverEntry)' is not valid or not formatted correctly. Example: https://automate.domain.com"
            }
        }
    }

    End {
        if (-not ($Quiet)) {
            Write-Output 'Test-CWAAPort Finished'
        }
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
