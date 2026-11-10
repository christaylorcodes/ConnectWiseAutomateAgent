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

The function searches for pwsh.exe in the following locations (in order):
1.
The path specified by the PwshPath parameter
2.
Program Files default install (C:\Program Files\PowerShell\7\pwsh.exe)
3.
The system PATH (via Get-Command)

Output is captured and returned as a CWAAScriptOutput-formatted pipe-delimited
string.
Errors from pwsh execution are caught and reported in the output.

For the ScriptBlock parameter set, the scriptblock is Base64-encoded using
Unicode (UTF-16LE) for transport via the -EncodedCommand parameter.
Only the
scriptblock's source text is sent: variables from the calling session (including
closures) are not available in the pwsh process.
Write values literally into the
scriptblock, or use the FilePath parameter set with -Parameters instead.

A non-zero pwsh exit code sets Status=Error and records ExitCode=\<n\> in Data.
ANSI color sequences are stripped from captured output.

## EXAMPLES

### EXAMPLE 1
```
Invoke-CWAAPwsh -ScriptBlock { $PSVersionTable.PSVersion.ToString() }
Runs the scriptblock under pwsh and returns the version string.
```

### EXAMPLE 2
```
Invoke-CWAAPwsh -FilePath 'C:\Scripts\MyScript.ps1' -Parameters @{ Name = 'Test' }
Runs a script file under pwsh with the specified parameter.
```

### EXAMPLE 3
```
Invoke-CWAAPwsh -ScriptBlock { Get-Service LTService } -PwshPath 'D:\Tools\pwsh.exe'
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
Each key becomes a -Name argument and each value
becomes the argument value.
Only non-empty strings and numbers are supported:
arrays, nested hashtables, switch parameters, and empty strings (which Windows
PowerShell drops when calling native commands) are not.

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
{{ Fill ProgressAction Description }}

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

