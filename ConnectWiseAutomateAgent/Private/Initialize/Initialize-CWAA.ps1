function Initialize-CWAA {
    if (-not ($PSVersionTable)) {
        Write-Warning 'PS1 Detected. PowerShell Version 2.0 or higher is required.'
        return
    }
    if (-not ($PSVersionTable) -or $PSVersionTable.PSVersion.Major -lt 3 ) { Write-Verbose 'PS2 Detected. PowerShell Version 3.0 or higher may be required for full functionality.' }

    if ($env:PROCESSOR_ARCHITEW6432 -match '64' -and [IntPtr]::Size -ne 8) {
        Write-Warning '32-bit PowerShell session detected on 64-bit OS. Attempting to launch 64-Bit session to process commands.'
        $pshell = "${env:WINDIR}\sysnative\windowspowershell\v1.0\powershell.exe"
        if (!(Test-Path -Path $pshell)) {
            Write-Warning 'SYSNATIVE PATH REDIRECTION IS NOT AVAILABLE. Attempting to access 64-bit PowerShell directly.'
            $pshell = "${env:WINDIR}\System32\WindowsPowershell\v1.0\powershell.exe"
            $FSRedirection = $True
            Add-Type -Debug:$False -Name Wow64 -Namespace 'Kernel32' -MemberDefinition @'
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool Wow64DisableWow64FsRedirection(ref IntPtr ptr);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool Wow64RevertWow64FsRedirection(ref IntPtr ptr);
'@
            [ref]$ptr = New-Object System.IntPtr
            $Result = [Kernel32.Wow64]::Wow64DisableWow64FsRedirection($ptr) # Now you can call 64-bit Powershell from system32
        }
        if ($myInvocation.Line) {
            &"$pshell" -NonInteractive -NoProfile $myInvocation.Line
        }
        Elseif ($myInvocation.InvocationName) {
            &"$pshell" -NonInteractive -NoProfile -File "$($myInvocation.InvocationName)" $args
        }
        else {
            &"$pshell" -NonInteractive -NoProfile $myInvocation.MyCommand
        }
        $ExitResult = $LASTEXITCODE
        if ($FSRedirection -eq $True) {
            [ref]$defaultptr = New-Object System.IntPtr
            $Result = [Kernel32.Wow64]::Wow64RevertWow64FsRedirection($defaultptr)
        }
        Write-Warning 'Exiting 64-bit session. Module will only remain loaded in native 64-bit PowerShell environment.'
        Exit $ExitResult
    }

    #Ignore SSL errors
    Add-Type -Debug:$False @'
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback +=
                    delegate
                    (
                        Object obj,
                        X509Certificate certificate,
                        X509Chain chain,
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
'@
    [ServerCertificateValidationCallback]::Ignore()

    #Enable TLS, TLS1.1, TLS1.2, TLS1.3 in this session if they are available
    IF ([Net.SecurityProtocolType]::Tls) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls }
    IF ([Net.SecurityProtocolType]::Tls11) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls11 }
    IF ([Net.SecurityProtocolType]::Tls12) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 }
    IF ([Net.SecurityProtocolType]::Tls13) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls13 }

    $Null = Initialize-CWAAModule
}