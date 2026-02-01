---
external help file:
Module Name: ConnectWiseAutomateAgent
online version:
schema: 2.0.0
---

# Write-CWAAEventLog

## SYNOPSIS
Writes an entry to the Windows Event Log for ConnectWise Automate Agent operations.

## SYNTAX

```
Write-CWAAEventLog -Message <String> -EntryType <String> -EventId <Int32> [<CommonParameters>]
```

## DESCRIPTION
Write-CWAAEventLog is the centralized event log writer for the ConnectWiseAutomateAgent module. It writes to the Application event log under the source defined by `$Script:CWAAEventLogSource`.

On first call, it registers the event source if it does not already exist (requires administrator privileges for registration). If the source cannot be registered or the write fails for any reason, the error is written to `Write-Debug` and the function returns silently. This ensures event logging never disrupts the calling function.

Event IDs are organized by category:

| Range | Category | Examples |
| --- | --- | --- |
| 1000-1039 | Installation | Install (1000), Uninstall (1010), Redo (1020), Update (1030) |
| 2000-2029 | Service Control | Start (2000), Stop (2010), Restart (2020) |
| 3000-3069 | Configuration | Reset (3000), Backup (3010), Proxy (3020), LogLevel (3030), AddRemove (3040) |
| 4000-4039 | Health/Monitoring | Repair (4000-4008), Register task (4020), Unregister task (4030) |

Events are viewable in Windows Event Viewer or via PowerShell:

```powershell
Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = 'ConnectWiseAutomateAgent' }
```

## EXAMPLES

### Example 1
```powershell
# Called internally after a successful installation.
Write-CWAAEventLog -Message 'Agent installed successfully.' -EntryType 'Information' -EventId 1000
```

Writes an informational event to the Application log with Event ID 1000 (Installation category).

### Example 2
```powershell
# Called internally when a repair operation detects an unreachable server.
Write-CWAAEventLog -Message 'Server unreachable during repair.' -EntryType 'Error' -EventId 4008
```

Writes an error event to the Application log with Event ID 4008 (Health/Monitoring category).

## PARAMETERS

### -Message
The event log message text.

```yaml
Type: String
Required: True
Position: Named
Default value: None
```

### -EntryType
The severity level of the event log entry. Valid values: `Information`, `Warning`, `Error`.

```yaml
Type: String
Required: True
Position: Named
Default value: None
Accepted values: Information, Warning, Error
```

### -EventId
The numeric event identifier. Should follow the category ranges documented above.

```yaml
Type: Int32
Required: True
Position: Named
Default value: None
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

This function does not accept pipeline input.

## OUTPUTS

This function produces no output. It writes to the Windows Event Log as a side effect.

## NOTES

- **Private function** — not exported by the module.
- Auto-registers the event source on first call (requires administrator privileges).
- Non-blocking design: all failures are written to `Write-Debug`, never thrown.
- Uses centralized constants: `$Script:CWAAEventLogSource`, `$Script:CWAAEventLogName`.
- Events integrate with Windows Event Log forwarding for centralized monitoring in SIEM tools.

Author: Chris Taylor

## RELATED LINKS

[Repair-CWAA](../Repair-CWAA.md)

[Register-CWAAHealthCheckTask](../Register-CWAAHealthCheckTask.md)

[Install-CWAA](../Install-CWAA.md)
