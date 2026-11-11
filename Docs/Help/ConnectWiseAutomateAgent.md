---
Module Name: ConnectWiseAutomateAgent
Module Guid: 37424fc5-48d4-4d15-8b19-e1c2bf4bab67
Download Help Link: https://raw.githubusercontent.com/christaylorcodes/ConnectWiseAutomateAgent/main/source/en-US/ConnectWiseAutomateAgent-help.xml
Help Version: 1.0.0.0
Locale: en-US
---

# ConnectWiseAutomateAgent Module

PowerShell module for managing the ConnectWise Automate (formerly LabTech) Windows agent. Install, configure, troubleshoot, and manage the Automate agent on Windows systems.

> Every function below has a legacy `LT` alias (e.g., `Install-CWAA` = `Install-LTService`). Run `Get-Alias -Definition *-CWAA*` to see them all.

## Install & Uninstall

| Function | Description |
| --- | --- |
| [Install-CWAA](ConnectWiseAutomateAgent/Install-CWAA.md) | Installs the ConnectWise Automate Agent on the local computer. |
| [Uninstall-CWAA](ConnectWiseAutomateAgent/Uninstall-CWAA.md) | Completely uninstalls the ConnectWise Automate Agent from the local computer. |
| [Update-CWAA](ConnectWiseAutomateAgent/Update-CWAA.md) | Manually updates the ConnectWise Automate Agent to a specified version. |
| [Redo-CWAA](ConnectWiseAutomateAgent/Redo-CWAA.md) | Reinstalls the ConnectWise Automate Agent on the local computer. |

## Service Management

| Function | Description |
| --- | --- |
| [Start-CWAA](ConnectWiseAutomateAgent/Start-CWAA.md) | Starts the ConnectWise Automate agent services. |
| [Stop-CWAA](ConnectWiseAutomateAgent/Stop-CWAA.md) | Stops the ConnectWise Automate agent services. |
| [Restart-CWAA](ConnectWiseAutomateAgent/Restart-CWAA.md) | Restarts the ConnectWise Automate agent services. |
| [Repair-CWAA](ConnectWiseAutomateAgent/Repair-CWAA.md) | Performs escalating remediation of the ConnectWise Automate agent. |

## Agent Settings & Backup

| Function | Description |
| --- | --- |
| [Get-CWAAInfo](ConnectWiseAutomateAgent/Get-CWAAInfo.md) | Retrieves ConnectWise Automate agent configuration from the registry. |
| [Get-CWAAInfoBackup](ConnectWiseAutomateAgent/Get-CWAAInfoBackup.md) | Retrieves backed-up ConnectWise Automate agent configuration from the registry. |
| [Get-CWAASettings](ConnectWiseAutomateAgent/Get-CWAASettings.md) | Retrieves ConnectWise Automate agent settings from the registry. |
| [New-CWAABackup](ConnectWiseAutomateAgent/New-CWAABackup.md) | Creates a complete backup of the ConnectWise Automate agent installation. |
| [Reset-CWAA](ConnectWiseAutomateAgent/Reset-CWAA.md) | Removes local agent identity settings to force re-registration. |

## Logging

| Function | Description |
| --- | --- |
| [Get-CWAAError](ConnectWiseAutomateAgent/Get-CWAAError.md) | Reads the ConnectWise Automate Agent error log into structured objects. |
| [Get-CWAAProbeError](ConnectWiseAutomateAgent/Get-CWAAProbeError.md) | Reads the ConnectWise Automate Agent probe error log into structured objects. |
| [Get-CWAALogLevel](ConnectWiseAutomateAgent/Get-CWAALogLevel.md) | Retrieves the current logging level for the ConnectWise Automate Agent. |
| [Set-CWAALogLevel](ConnectWiseAutomateAgent/Set-CWAALogLevel.md) | Sets the logging level for the ConnectWise Automate Agent. |

## Proxy

| Function | Description |
| --- | --- |
| [Get-CWAAProxy](ConnectWiseAutomateAgent/Get-CWAAProxy.md) | Retrieves the current agent proxy settings for module operations. |
| [Set-CWAAProxy](ConnectWiseAutomateAgent/Set-CWAAProxy.md) | Configures module proxy settings for all operations during the current session. |

## Add/Remove Programs

| Function | Description |
| --- | --- |
| [Hide-CWAAAddRemove](ConnectWiseAutomateAgent/Hide-CWAAAddRemove.md) | Hides the Automate agent from the Add/Remove Programs list. |
| [Show-CWAAAddRemove](ConnectWiseAutomateAgent/Show-CWAAAddRemove.md) | Shows the Automate agent in the Add/Remove Programs list. |
| [Rename-CWAAAddRemove](ConnectWiseAutomateAgent/Rename-CWAAAddRemove.md) | Renames the Automate agent entry in the Add/Remove Programs list. |

## Health & Monitoring

| Function | Description |
| --- | --- |
| [Test-CWAAHealth](ConnectWiseAutomateAgent/Test-CWAAHealth.md) | Performs a read-only health assessment of the ConnectWise Automate agent. |
| [Test-CWAAServerConnectivity](ConnectWiseAutomateAgent/Test-CWAAServerConnectivity.md) | Tests connectivity to a ConnectWise Automate server's agent endpoint. |
| [Register-CWAAHealthCheckTask](ConnectWiseAutomateAgent/Register-CWAAHealthCheckTask.md) | Creates or updates a scheduled task for periodic ConnectWise Automate agent health checks. |
| [Unregister-CWAAHealthCheckTask](ConnectWiseAutomateAgent/Unregister-CWAAHealthCheckTask.md) | Removes the ConnectWise Automate agent health check scheduled task. |

## Security & Utilities

| Function | Description |
| --- | --- |
| [ConvertFrom-CWAASecurity](ConvertFrom-CWAASecurity.md) | Decodes a Base64-encoded string using TripleDES decryption. |
| [ConvertTo-CWAASecurity](ConvertTo-CWAASecurity.md) | Encodes a string using TripleDES encryption compatible with Automate operations. |
| [Invoke-CWAACommand](ConnectWiseAutomateAgent/Invoke-CWAACommand.md) | Sends a service command to the ConnectWise Automate agent. |
| [Test-CWAAPort](ConnectWiseAutomateAgent/Test-CWAAPort.md) | Tests connectivity to TCP ports required by the ConnectWise Automate agent. |