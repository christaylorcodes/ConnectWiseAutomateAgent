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
| [Install-CWAA](Install-CWAA.md) | Installs the ConnectWise Automate Agent on the local computer. |
| [Uninstall-CWAA](Uninstall-CWAA.md) | Completely uninstalls the ConnectWise Automate Agent from the local computer. |
| [Update-CWAA](Update-CWAA.md) | Manually updates the ConnectWise Automate Agent to a specified version. |
| [Redo-CWAA](Redo-CWAA.md) | Reinstalls the ConnectWise Automate Agent on the local computer. |

## Service Management

| Function | Description |
| --- | --- |
| [Start-CWAA](Start-CWAA.md) | Starts the ConnectWise Automate agent services. |
| [Stop-CWAA](Stop-CWAA.md) | Stops the ConnectWise Automate agent services. |
| [Restart-CWAA](Restart-CWAA.md) | Restarts the ConnectWise Automate agent services. |
| [Repair-CWAA](Repair-CWAA.md) | Performs escalating remediation of the ConnectWise Automate agent. |

## Agent Settings & Backup

| Function | Description |
| --- | --- |
| [Get-CWAAInfo](Get-CWAAInfo.md) | Retrieves ConnectWise Automate agent configuration from the registry. |
| [Get-CWAAInfoBackup](Get-CWAAInfoBackup.md) | Retrieves backed-up ConnectWise Automate agent configuration from the registry. |
| [Get-CWAASettings](Get-CWAASettings.md) | Retrieves ConnectWise Automate agent settings from the registry. |
| [New-CWAABackup](New-CWAABackup.md) | Creates a complete backup of the ConnectWise Automate agent installation. |
| [Reset-CWAA](Reset-CWAA.md) | Removes local agent identity settings to force re-registration. |

## Logging

| Function | Description |
| --- | --- |
| [Get-CWAAError](Get-CWAAError.md) | Reads the ConnectWise Automate Agent error log into structured objects. |
| [Get-CWAAProbeError](Get-CWAAProbeError.md) | Reads the ConnectWise Automate Agent probe error log into structured objects. |
| [Get-CWAALogLevel](Get-CWAALogLevel.md) | Retrieves the current logging level for the ConnectWise Automate Agent. |
| [Set-CWAALogLevel](Set-CWAALogLevel.md) | Sets the logging level for the ConnectWise Automate Agent. |

## Proxy

| Function | Description |
| --- | --- |
| [Get-CWAAProxy](Get-CWAAProxy.md) | Retrieves the current agent proxy settings for module operations. |
| [Set-CWAAProxy](Set-CWAAProxy.md) | Configures module proxy settings for all operations during the current session. |

## Add/Remove Programs

| Function | Description |
| --- | --- |
| [Hide-CWAAAddRemove](Hide-CWAAAddRemove.md) | Hides the Automate agent from the Add/Remove Programs list. |
| [Show-CWAAAddRemove](Show-CWAAAddRemove.md) | Shows the Automate agent in the Add/Remove Programs list. |
| [Rename-CWAAAddRemove](Rename-CWAAAddRemove.md) | Renames the Automate agent entry in the Add/Remove Programs list. |

## Health & Monitoring

| Function | Description |
| --- | --- |
| [Test-CWAAHealth](Test-CWAAHealth.md) | Performs a read-only health assessment of the ConnectWise Automate agent. |
| [Test-CWAAServerConnectivity](Test-CWAAServerConnectivity.md) | Tests connectivity to a ConnectWise Automate server's agent endpoint. |
| [Register-CWAAHealthCheckTask](Register-CWAAHealthCheckTask.md) | Creates or updates a scheduled task for periodic ConnectWise Automate agent health checks. |
| [Unregister-CWAAHealthCheckTask](Unregister-CWAAHealthCheckTask.md) | Removes the ConnectWise Automate agent health check scheduled task. |

## Security & Utilities

| Function | Description |
| --- | --- |
| [ConvertFrom-CWAASecurity](ConvertFrom-CWAASecurity.md) | Decodes a Base64-encoded string using TripleDES decryption. |
| [ConvertTo-CWAASecurity](ConvertTo-CWAASecurity.md) | Encodes a string using TripleDES encryption compatible with Automate operations. |
| [Invoke-CWAACommand](Invoke-CWAACommand.md) | Sends a service command to the ConnectWise Automate agent. |
| [Test-CWAAPort](Test-CWAAPort.md) | Tests connectivity to TCP ports required by the ConnectWise Automate agent. |