Function Invoke-CWAACommand {
    [CmdletBinding(SupportsShouldProcess=$True)]
    [Alias('Invoke-LTServiceCommand')]
    Param(
        [Parameter(Mandatory=$True, Position=1, ValueFromPipeline=$True)]
        [ValidateSet("Update Schedule",
                        "Send Inventory",
                        "Send Drives",
                        "Send Processes",
                        "Send Spyware List",
                        "Send Apps",
                        "Send Events",
                        "Send Printers",
                        "Send Status",
                        "Send Screen",
                        "Send Services",
                        "Analyze Network",
                        "Write Last Contact Date",
                        "Kill VNC",
                        "Kill Trays",
                        "Send Patch Reboot",
                        "Run App Care Update",
                        "Start App Care Daytime Patching")][string[]]$Command
    )

    Begin {
        $Service = Get-Service 'LTService'
    }

    Process {
        If (-not ($Service)) {Write-Warning "WARNING: Line $(LINENUM): Service 'LTService' was not found. Cannot send service command"; return}
        If ($Service.Status -ne 'Running') {Write-Warning "WARNING: Line $(LINENUM): Service 'LTService' is not running. Cannot send service command"; return}
        Foreach ($Cmd in $Command) {
            $CommandID=$Null
            Try{
                switch($Cmd){
                    'Update Schedule' {$CommandID = 128}
                    'Send Inventory' {$CommandID = 129}
                    'Send Drives' {$CommandID = 130}
                    'Send Processes' {$CommandID = 131}
                    'Send Spyware List'{$CommandID = 132}
                    'Send Apps' {$CommandID = 133}
                    'Send Events' {$CommandID = 134}
                    'Send Printers' {$CommandID = 135}
                    'Send Status' {$CommandID = 136}
                    'Send Screen' {$CommandID = 137}
                    'Send Services' {$CommandID = 138}
                    'Analyze Network' {$CommandID = 139}
                    'Write Last Contact Date' {$CommandID = 140}
                    'Kill VNC' {$CommandID = 141}
                    'Kill Trays' {$CommandID = 142}
                    'Send Patch Reboot' {$CommandID = 143}
                    'Run App Care Update' {$CommandID = 144}
                    'Start App Care Daytime Patching' {$CommandID = 145}
                    default {"Invalid entry"}
                }
                If ($PSCmdlet.ShouldProcess("LTService", "Send Service Command '$($Cmd)' ($($CommandID))")) {
                    If ($Null -ne $CommandID) {
                        Write-Debug "Line $(LINENUM): Sending service command '$($Cmd)' ($($CommandID)) to 'LTService'"
                        Try {
                            $Null=& "$env:windir\system32\sc.exe" control LTService $($CommandID) 2>''
                            Write-Output "Sent Command '$($Cmd)' to 'LTService'"
                        }
                        Catch {
                            Write-Output "Error calling sc.exe. Failed to send command."
                        }
                    }
                }
            }

            Catch{
                Write-Warning ("WARNING: Line $(LINENUM)",$_.Exception)
            }
        }
    }

    End{}

}
