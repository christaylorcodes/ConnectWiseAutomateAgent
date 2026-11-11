---
external help file: ConnectWiseAutomateAgent-help.xml
Module Name: ConnectWiseAutomateAgent
online version: https://github.com/christaylorcodes/ConnectWiseAutomateAgent
schema: 2.0.0
---

# Invoke-CWAAPwsh

## SYNOPSIS
Executes a scriptblock or script file under PowerShell 7 (pwsh.exe).

## SYNTAX

### ScriptBlock (Default)
```
Invoke-CWAAPwsh -ScriptBlock <ScriptBlock> [-PwshPath <String>] [-ProgressAction <ActionPreference>]
 [<CommonParameters>]
```

### FilePath
```
Invoke-CWAAPwsh -FilePath <String> [-Parameters <Hashtable>] [-PwshPath <String>]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Launches the specified scriptblock or script file under pwsh.exe for environments
where ConnectWise Automate only natively starts PowerShell 5.
The caller must
explicitly opt in to pwsh execution by calling this function.

pwsh.exe is only resolved from administrator-controlled locations, in this order:
1.
The path specified by the PwshPath parameter
2.
The 64-bit Program Files install ($env:ProgramW6432\PowerShell\7\pwsh.exe), so a
   32-bit host still finds the x64 install
3.
$env:ProgramFiles\PowerShell\7\pwsh.exe
4.
Install locations registered under
   HKLM:\SOFTWARE\Microsoft\PowerShellCore\InstalledVersions (64-bit registry view),
   accepted only when they are inside Program Files
The system PATH is deliberately not searched: this often runs as SYSTEM, and a copy of
the genuine signed pwsh.exe in a user-writable PATH folder would load unsigned DLLs
planted beside it.

Output is captured and returned as a CWAAScriptOutput-formatted pipe-delimited
string.
The run is reported as Status=Error when pwsh exits non-zero or writes
anything to stderr.
PowerShell errors in the child (Write-Error, unhandled cmdlet
errors) arrive on stderr, so they fail the run as they would in Invoke-CWAAScript.
Unlike Invoke-CWAAScript, stderr written by native commands inside the child cannot
be told apart and also counts as an error; redirect it inside the scriptblock
(2\>&1) if a tool writes progress to stderr.
On error, Result holds the stderr text
(or stdout when stderr is empty) and Data holds ExitCode=\<n\> and, when stderr
replaced it, the stdout text as Output=\<text\>, always last.
ANSI color sequences are stripped from captured output.

For both parameter sets the exit code follows pwsh -File semantics: an explicit
exit \<n\> or an unhandled error fails the run, but a handled error or a leftover
non-zero exit code from the last native command does not.
Warning, verbose and
Write-Host output from the child is captured into Result as plain text lines.

For the ScriptBlock parameter set, the scriptblock is Base64-encoded using
Unicode (UTF-16LE) for transport via the -EncodedCommand parameter.
Only the
scriptblock's source text is sent: variables from the calling session (including
closures) are not available in the pwsh process.
Write values literally into the
scriptblock, or use the FilePath parameter set with -Parameters instead.

The encoded command, including any parameter values, appears on the pwsh.exe command
line, which process auditing and EDR tools record.
Do not pass secrets this way.

## EXAMPLES

### EXAMPLE 1
```
Invoke-CWAAPwsh -ScriptBlock { $PSVersionTable.PSVersion.ToString() }
Runs the scriptblock under pwsh and returns the version in the Result field, for
example: Status=Success|Result=7.4.6|LogPath=|Data=
```

### EXAMPLE 2
```
Invoke-CWAAPwsh -FilePath 'C:\Scripts\MyScript.ps1' -Parameters @{ Name = 'Test'; Count = 3; Force = $true }
Runs a script file under pwsh with the specified parameters.
```

### EXAMPLE 3
```
Invoke-CWAAPwsh -ScriptBlock { Get-Service LTService } -PwshPath 'C:\Program Files\PowerShell\7-preview\pwsh.exe'
Runs a scriptblock using a custom pwsh.exe path.
```

## PARAMETERS

### -ScriptBlock
A PowerShell scriptblock to encode and execute under pwsh.exe.

```yaml
Type: ScriptBlock
Parameter Sets: ScriptBlock
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -FilePath
The full path to a .ps1 script file to execute under pwsh.exe.

```yaml
Type: String
Parameter Sets: FilePath
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Parameters
Optional hashtable of parameters to pass to the script file.
Only used with
the FilePath parameter set.
Keys must be valid parameter names.
Values may be
strings (including empty strings), numbers, or booleans/switches (passed as
-Name:$true or -Name:$false).
Values are passed as PowerShell literals inside the
encoded command, so quotes, spaces and trailing backslashes arrive unchanged.
$null, NaN, infinity, arrays, hashtables and other object types are rejected.

```yaml
Type: Hashtable
Parameter Sets: FilePath
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -PwshPath
Optional override for the path to pwsh.exe.
Use this when pwsh is installed
in a non-standard location.
The path is resolved to a full path (a bare name is
never looked up on PATH) and then trusted as given: make sure the folder is not
writable by non-administrators, because this usually runs as SYSTEM.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
Determines how PowerShell responds to progress updates generated by a script, cmdlet, or provider.

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES
Author: Chris Taylor
Alias: Invoke-LTPwsh

## RELATED LINKS

[https://github.com/christaylorcodes/ConnectWiseAutomateAgent](https://github.com/christaylorcodes/ConnectWiseAutomateAgent)

