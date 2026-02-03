function Test-CWAADotNetPrerequisite {
    <#
    .SYNOPSIS
        Checks for and optionally installs the .NET Framework 3.5 prerequisite.
    .DESCRIPTION
        Verifies that .NET Framework 3.5 is installed, which is required by the ConnectWise
        Automate agent. If 3.5 is missing, attempts automatic installation via
        Enable-WindowsOptionalFeature (Windows 8+) or Dism.exe (Windows 7/Server 2008 R2).

        With -Force, allows the agent install to proceed if .NET 2.0 or higher is present
        even when 3.5 cannot be installed. Without -Force, a missing 3.5 is a terminating error.
    .PARAMETER SkipDotNet
        Skips the .NET Framework check entirely. Returns $true immediately.
    .PARAMETER Force
        Allows fallback to .NET 2.0+ if 3.5 cannot be installed.
        Without -Force, missing 3.5 is a terminating error.
    .NOTES
        Version: 1.0.0
        Author: Chris Taylor
        Private function - not exported.
    .LINK
        https://github.com/christaylorcodes/ConnectWiseAutomateAgent
    #>
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param(
        [switch]$SkipDotNet,
        [switch]$Force
    )

    Begin {
        Write-Debug "Starting $($MyInvocation.InvocationName)"
    }

    Process {
        if ($SkipDotNet) {
            Write-Debug 'SkipDotNet specified, skipping .NET prerequisite check.'
            return $true
        }

        $DotNET = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse -EA 0 | Get-ItemProperty -Name Version, Release -EA 0 | Where-Object { $_.PSChildName -match '^(?!S)\p{L}' } | Select-Object -ExpandProperty Version -EA 0
        if ($DotNet -like '3.5.*') {
            Write-Debug '.NET Framework 3.5 is already installed.'
            return $true
        }

        Write-Warning '.NET Framework 3.5 installation needed.'
        $OSVersion = [System.Environment]::OSVersion.Version

        if ([version]$OSVersion -gt [version]'6.2') {
            # Windows 8 / Server 2012 and later -- use Enable-WindowsOptionalFeature
            Try {
                if ($PSCmdlet.ShouldProcess('NetFx3', 'Enable-WindowsOptionalFeature')) {
                    $Install = Get-WindowsOptionalFeature -Online -FeatureName 'NetFx3'
                    if ($Install.State -ne 'EnablePending') {
                        $Install = Enable-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -All -NoRestart
                    }
                    if ($Install.RestartNeeded -or $Install.State -eq 'EnablePending') {
                        Write-Warning '.NET Framework 3.5 installed but a reboot is needed.'
                    }
                }
            }
            Catch {
                Write-Error ".NET 3.5 install failed." -ErrorAction Continue
                if (-not $Force) { Write-Error $Install -ErrorAction Stop }
            }
        }
        Elseif ([version]$OSVersion -gt [version]'6.1') {
            # Windows 7 / Server 2008 R2 -- use Dism.exe
            if ($PSCmdlet.ShouldProcess('NetFx3', 'Add Windows Feature')) {
                Try { $Result = & "${env:windir}\system32\Dism.exe" /English /NoRestart /Online /Enable-Feature /FeatureName:NetFx3 2>'' }
                Catch { Write-Warning 'Error calling Dism.exe.'; $Result = $Null }
                Try { $Result = & "${env:windir}\system32\Dism.exe" /English /Online /Get-FeatureInfo /FeatureName:NetFx3 2>'' }
                Catch { Write-Warning 'Error calling Dism.exe.'; $Result = $Null }
                if ($Result -contains 'State : Enabled') {
                    Write-Warning ".Net Framework 3.5 has been installed and enabled."
                }
                Elseif ($Result -contains 'State : Enable Pending') {
                    Write-Warning ".Net Framework 3.5 installed but a reboot is needed."
                }
                else {
                    Write-Error ".NET Framework 3.5 install failed." -ErrorAction Continue
                    if (-not $Force) { Write-Error $Result -ErrorAction Stop }
                }
            }
        }

        # Re-check after install attempt
        $DotNET = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse | Get-ItemProperty -Name Version -EA 0 | Where-Object { $_.PSChildName -match '^(?!S)\p{L}' } | Select-Object -ExpandProperty Version

        if ($DotNet -like '3.5.*') {
            return $true
        }

        # .NET 3.5 still not available after install attempt
        if ($Force) {
            if ($DotNet -match '(?m)^[2-4].\d') {
                Write-Error ".NET 3.5 is not detected and could not be installed." -ErrorAction Continue
                return $true
            }
            else {
                Write-Error ".NET 2.0 or greater is not detected and could not be installed." -ErrorAction Stop
                return $false
            }
        }
        else {
            Write-Error ".NET 3.5 is not detected and could not be installed." -ErrorAction Stop
            return $false
        }
    }

    End {
        Write-Debug "Exiting $($MyInvocation.InvocationName)"
    }
}
