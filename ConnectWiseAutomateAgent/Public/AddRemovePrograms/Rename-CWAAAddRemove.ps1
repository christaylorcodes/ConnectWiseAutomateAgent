Function Rename-CWAAAddRemove{
    [CmdletBinding(SupportsShouldProcess=$True)]
    [Alias('Rename-LTAddRemove')]
    Param(
        [Parameter(Mandatory=$True)]
        $Name,

        [Parameter(Mandatory=$False)]
        [AllowNull()]
        [string]$PublisherName
    )

    Begin{
        $RegRoots = ('HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
        'HKLM:\SOFTWARE\Classes\Installer\Products\C4D064F3712D4B64086B5BDE05DBC75F',
        'HKLM:\SOFTWARE\Classes\Installer\Products\D1003A85576B76D45A1AF09A0FC87FAC')
        $PublisherRegRoots = ('HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{58A3001D-B675-4D67-A5A1-0FA9F08CF7CA}',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{3F460D4C-D217-46B4-80B6-B5ED50BD7CF5}')
        $RegNameFound=0;
        $RegPublisherFound=0;
    }

    Process{
        Try{
            foreach($RegRoot in $RegRoots){
                if (Get-ItemProperty $RegRoot -Name DisplayName -ErrorAction SilentlyContinue){
                    If ($PSCmdlet.ShouldProcess("$($RegRoot)\DisplayName=$($Name)", "Set Registry Value")) {
                        Write-Verbose "Setting $($RegRoot)\DisplayName=$($Name)"
                        Set-ItemProperty $RegRoot -Name DisplayName -Value $Name -Confirm:$False
                        $RegNameFound++
                    }
                } ElseIf (Get-ItemProperty $RegRoot -Name  HiddenProductName -ErrorAction SilentlyContinue){
                    If ($PSCmdlet.ShouldProcess("$($RegRoot)\ HiddenProductName=$($Name)", "Set Registry Value")) {
                        Write-Verbose "Setting $($RegRoot)\ HiddenProductName=$($Name)"
                        Set-ItemProperty $RegRoot -Name  HiddenProductName -Value $Name -Confirm:$False
                        $RegNameFound++
                    }
                }
            }
        }

        Catch{
            Write-Error "ERROR: Line $(LINENUM): There was an error setting the registry key value. $($Error[0])" -ErrorAction Stop
        }

        If (($PublisherName)){
            Try{
                Foreach($RegRoot in $PublisherRegRoots){
                    If (Get-ItemProperty $RegRoot -Name Publisher -ErrorAction SilentlyContinue){
                        If ($PSCmdlet.ShouldProcess("$($RegRoot)\Publisher=$($PublisherName)", "Set Registry Value")) {
                            Write-Verbose "Setting $($RegRoot)\Publisher=$($PublisherName)"
                            Set-ItemProperty $RegRoot -Name Publisher -Value $PublisherName -Confirm:$False
                            $RegPublisherFound++
                        }
                    }
                }
            }

            Catch{
                Write-Error "ERROR: Line $(LINENUM): There was an error setting the registry key value. $($Error[0])" -ErrorAction Stop
            }
        }
    }

    End{
        If ($WhatIfPreference -ne $True) {
            If ($?){
                If ($RegNameFound -gt 0) {
                    Write-Output "LabTech is now listed as $($Name) in Add/Remove Programs."
                } Else {
                    Write-Warning "WARNING: Line $(LINENUM): LabTech was not found in installed software and the Name was not changed."
                }
                If (($PublisherName)){
                    If ($RegPublisherFound -gt 0) {
                        Write-Output "The Publisher is now listed as $($PublisherName)."
                    } Else {
                        Write-Warning "WARNING: Line $(LINENUM): LabTech was not found in installed software and the Publisher was not changed."
                    }
                }
            } Else {$Error[0]}
        }
    }
}
