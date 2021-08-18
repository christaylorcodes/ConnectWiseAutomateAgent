function Hide-CWAAAddRemove {
    [CmdletBinding(SupportsShouldProcess = $True)]
    [Alias('Hide-LTAddRemove')]
    Param()

    Begin {
        Write-Debug "Starting $($myInvocation.InvocationName) at line $(LINENUM)"
        $RegRoots = ('HKLM:\SOFTWARE\Classes\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
            'HKLM:\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC')
        $PublisherRegRoots = ('HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}')
        $RegEntriesFound = 0
        $RegEntriesChanged = 0
    }

    Process {

        Try {
            Foreach ($RegRoot in $RegRoots) {
                if (Test-Path $RegRoot) {
                    if (Get-ItemProperty $RegRoot -Name HiddenProductName -ErrorAction SilentlyContinue) {
                        if (!(Get-ItemProperty $RegRoot -Name ProductName -ErrorAction SilentlyContinue)) {
                            Write-Verbose 'LabTech found with HiddenProductName value.'
                            Try {
                                Rename-ItemProperty $RegRoot -Name HiddenProductName -NewName ProductName
                            }
                            Catch {
                                Write-Error "ERROR: Line $(LINENUM): There was an error renaming the registry value. $($Error[0])" -ErrorAction Stop
                            }
                        }
                        else {
                            Write-Verbose 'LabTech found with unused HiddenProductName value.'
                            Try {
                                Remove-ItemProperty $RegRoot -Name HiddenProductName -EA 0 -Confirm:$False -WhatIf:$False -Force
                            }
                            Catch {}
                        }
                    }
                }
            }

            Foreach ($RegRoot in $PublisherRegRoots) {
                if (Test-Path $RegRoot) {
                    $RegKey = Get-Item $RegRoot -ErrorAction SilentlyContinue
                    if ($RegKey) {
                        $RegEntriesFound++
                        if ($PSCmdlet.ShouldProcess("$($RegRoot)", "Set Registry Values to Hide $($RegKey.GetValue('DisplayName'))")) {
                            $RegEntriesChanged++
                            @('SystemComponent') | ForEach-Object {
                                if (($RegKey.GetValue("$($_)")) -ne 1) {
                                    Write-Verbose "Setting $($RegRoot)\$($_)=1"
                                    Set-ItemProperty $RegRoot -Name "$($_)" -Value 1 -Type DWord -WhatIf:$False -Confirm:$False -Verbose:$False
                                }
                            }
                        }
                    }
                }
            }
        }

        Catch {
            Write-Error "ERROR: Line $(LINENUM): There was an error setting the registry values. $($Error[0])" -ErrorAction Stop
        }

    }

    End {
        if ($WhatIfPreference -ne $True) {
            if ($?) {
                if ($RegEntriesFound -gt 0 -and $RegEntriesChanged -eq $RegEntriesFound) {
                    Write-Output 'LabTech is hidden from Add/Remove Programs.'
                }
                else {
                    Write-Warning "WARNING: Line $(LINENUM): LabTech may not be hidden from Add/Remove Programs."
                }
            }
            else { $Error[0] }
        }
        Write-Debug "Exiting $($myInvocation.InvocationName) at line $(LINENUM)"
    }
}
