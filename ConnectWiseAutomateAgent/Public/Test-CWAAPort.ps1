
function Test-CWAAPort {
    [CmdletBinding()]
    [Alias('Test-LTPorts')]
    Param(
        [Parameter(ValueFromPipelineByPropertyName = $true, ValueFromPipeline=$True)]
        [string[]]$Server,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [int]$TrayPort,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Quiet
    )

    Begin{
        $Mediator = 'mediator.labtechsoftware.com'
        function Private:TestPort{
            Param(
                [parameter(Position=0)]
                [string]
                $ComputerName,

                [parameter(Mandatory=$False)]
                [System.Net.IPAddress]
                $IPAddress,

                [parameter(Mandatory=$True , Position=1)]
                [int]
                $Port
            )

            $RemoteServer = if([string]::IsNullOrEmpty($ComputerName)){$IPAddress} else{$ComputerName};
            if([string]::IsNullOrEmpty($RemoteServer)){Write-Error "ERROR: Line $(LINENUM): No ComputerName or IPAddress was provided to test."; return}

            $test = New-Object System.Net.Sockets.TcpClient;
            Try
            {
                Write-Output "Connecting to $($RemoteServer):$Port (TCP)..";
                $test.Connect($RemoteServer, $Port);
                Write-Output "Connection successful";
            }
            Catch
            {
                Write-Output "ERROR: Connection failed";
                $Global:PortTestError = 1
            }
            Finally
            {
                $test.Close();
            }

        }

        Clear-Variable CleanSvr,svr,proc,processes,port,netstat,line -EA 0 -WhatIf:$False -Confirm:$False #Clearing Variables for use
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"

    }

    Process{
        if(-not ($Server) -and (-not ($TrayPort) -or -not ($Quiet))){
            Write-Verbose 'No Server Input - Checking for names.'
            $Server = Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False|Select-Object -Expand 'Server' -EA 0
            if(-not ($Server)){
                Write-Verbose 'No Server found in installed Service Info. Checking for Service Backup.'
                $Server = Get-CWAAInfoBackup -EA 0 -Verbose:$False|Select-Object -Expand 'Server' -EA 0
            }
        }

        if(-not ($Quiet) -or (($TrayPort) -ge 1 -and ($TrayPort) -le 65530)){
            if(-not ($TrayPort) -or -not (($TrayPort) -ge 1 -and ($TrayPort) -le 65530)){
                #Learn LTTrayPort if available.
                $TrayPort = (Get-CWAAInfo -EA 0 -Verbose:$False -WhatIf:$False -Confirm:$False -Debug:$False|Select-Object -Expand TrayPort -EA 0)
            }
            if(-not ($TrayPort) -or $TrayPort -notmatch '^\d+$'){$TrayPort=42000}

            [array]$processes = @()
            #Get all processes that are using LTTrayPort (Default 42000)
            Try {$netstat=& "$env:windir\system32\netstat.exe" -a -o -n | Select-String -Pattern " .*[0-9\.]+:$($TrayPort).*[0-9\.]+:[0-9]+ .*?([0-9]+)" -EA 0}
            Catch {Write-Output "Error calling netstat.exe."; $netstat=$null}
            Foreach ($line In $netstat){
                $processes += ($line -split ' {4,}')[-1]
            }
            $processes = $processes | Where-Object {$_ -gt 0 -and $_ -match '^\d+$'}| Sort-Object | Get-Unique
            if(($processes)){
                if(-not ($Quiet)){
                    Foreach ($proc In $processes){
                        if((Get-Process -ID $proc -EA 0|Select-Object -Expand ProcessName -EA 0) -eq 'LTSvc'){
                            Write-Output "TrayPort Port $TrayPort is being used by LTSvc."
                        } else{
                            Write-Output "Error: TrayPort Port $TrayPort is being used by $(Get-Process -ID $proc|Select-Object -Expand ProcessName -EA 0)."
                        }
                    }
                } else{return $False}
            } Elseif(($Quiet) -eq $True){
                return $True
            } else{
                Write-Output "TrayPort Port $TrayPort is available."
            }
        }

        foreach ($svr in $Server){
            if ($Quiet){
                $CleanSvr = ($Svr -replace 'https?://',''|ForEach-Object {$_.Trim()})
                Test-Connection $CleanSvr -Quiet
                return
            }

            if($Svr -match '^(https?://)?(([12]?[0-9]{1,2}\.){3}[12]?[0-9]{1,2}|[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)*)$'){
                Try{
                    $CleanSvr = ($Svr -replace 'https?://',''|ForEach-Object {$_.Trim()})
                    Write-Output "Testing connectivity to required TCP ports:"
                    TestPort -ComputerName $CleanSvr -Port 70
                    TestPort -ComputerName $CleanSvr -Port 80
                    TestPort -ComputerName $CleanSvr -Port 443
                    TestPort -ComputerName $Mediator -Port 8002

                }

                Catch{
                    Write-Error "ERROR: Line $(LINENUM): There was an error testing the ports. $($Error[0])" -ErrorAction Stop
                }
            } else{
                Write-Warning "WARNING: Line $(LINENUM): Server address $($Svr) is not a valid address or is not formatted correctly. Example: https://lt.domain.com"
            }
        }
    }

    End{
        if($?){
            if (-not ($Quiet)){
                Write-Output "Test-CWAAPorts Finished"
            }
        }
        Else{$Error[0]}
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}
