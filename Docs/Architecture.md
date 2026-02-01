# ConnectWiseAutomateAgent Architecture

Visual reference for the module's internal structure, initialization flow, and system interactions.

## Module Initialization (Two-Phase)

Module import is fast with no side effects. Networking is deferred until first use.

```mermaid
flowchart TD
    A[Import-Module ConnectWiseAutomateAgent] --> B[PSM1: Dot-source all .ps1 files<br/>from Public/ and Private/]
    B --> C{Running 32-bit PS<br/>on 64-bit OS?}
    C -->|Yes, module mode| D[Emit WOW64 warning]
    C -->|Yes, single-file mode| E[Relaunch under 64-bit PowerShell]
    C -->|No| F[Initialize-CWAA]
    D --> F
    F --> G[Create Script constants<br/>CWAARegistryRoot, CWAAInstallPath,<br/>CWAAServiceNames, etc.]
    G --> H[Create empty state objects<br/>LTServiceKeys, LTProxy]
    H --> I[Set CWAANetworkInitialized = false]
    I --> J[Module ready — no network, no registry reads]

    J -.->|First networking call| K[Initialize-CWAANetworking]

    K --> L{CWAACertCallbackRegistered?}
    L -->|No| M[Compile C# SSL callback via Add-Type<br/>Graduated trust: IP bypass,<br/>name mismatch tolerate, chain reject]
    L -->|Yes| N{SkipCertificateCheck?}
    M --> N
    N -->|Yes| O[Set SkipAll = true<br/>Full certificate bypass]
    N -->|No| P{CWAANetworkInitialized?}
    O --> P
    P -->|Yes| Q[Return — already initialized]
    P -->|No| R[Enable TLS 1.2 + 1.3]
    R --> S[Create LTWebProxy + LTServiceNetWebClient]
    S --> T[Get-CWAAProxy — discover agent proxy settings]
    T --> U[Set CWAANetworkInitialized = true]
    U --> V[Networking ready]

    style J fill:#d4edda,stroke:#28a745
    style V fill:#d4edda,stroke:#28a745
    style E fill:#fff3cd,stroke:#ffc107
    style D fill:#fff3cd,stroke:#ffc107
```

## Agent Installation Workflow

`Install-CWAA` end-to-end flow from parameter validation through post-install verification.

```mermaid
flowchart TD
    A[Install-CWAA called] --> B[Begin Block]
    B --> B1[Initialize-CWAANetworking]
    B1 --> B2{Running as Administrator?}
    B2 -->|No| B3[Throw: Needs Administrator]
    B2 -->|Yes| B4{Agent already installed?}
    B4 -->|Yes, no -Force| B5[Throw: Already installed]
    B4 -->|Yes, -Force| B6[Continue to Process]
    B4 -->|No| B7[Validate .NET 3.5+ installed]
    B7 -->|Missing| B8[Throw: .NET required]
    B7 -->|Present| B6

    B6 --> C[Process Block]
    C --> C1[Resolve-CWAAServer<br/>Validate URLs, test /Agent.aspx,<br/>parse version string]
    C1 -->|No server reachable| C2[Return — no GoodServer]
    C1 -->|Server found| C3{Auth method?}

    C3 -->|InstallerToken| C4[URL: Deployment.aspx?InstallerToken=...]
    C3 -->|ServerPassword| C5[URL: Service/LabTechRemoteAgent.msi]
    C3 -->|Anonymous, v110.374+| C6[URL: Deployment.aspx?Probe=1]
    C3 -->|Legacy| C7[URL: Deployment.aspx?MSILocations=LocationID]

    C4 --> C8{Server v240.331+?}
    C8 -->|Yes| C9[Download ZIP, extract MSI+MST]
    C8 -->|No| C10[Download MSI directly]
    C5 --> C10
    C6 --> C10
    C7 --> C10

    C9 --> C11[Test-CWAADownloadIntegrity<br/>Verify file > 1234 KB]
    C10 --> C11
    C11 -->|Failed| C12[Remove corrupt file, abort]
    C11 -->|Passed| D

    D[End Block] --> D1{Previous install detected?}
    D1 -->|Yes| D2[Uninstall-CWAA first]
    D1 -->|No| D3[Clear-CWAAInstallerArtifacts]
    D2 --> D3
    D3 --> D4[Resolve TrayPort 42000-42009]
    D4 --> D5[Build MSI arguments:<br/>SERVERADDRESS, SERVERPASS/TOKEN,<br/>LOCATION, TRAYPORT]
    D5 --> D6[Execute msiexec /i — up to 3 attempts]
    D6 -->|All attempts failed| D7[Write-Error, log event]
    D6 -->|Success| D8{Proxy configured?}
    D8 -->|Yes| D9[Wait for LTService running<br/>then Set-CWAAProxy]
    D8 -->|No| D10[Wait for agent registration<br/>poll every 2s, up to 120s]
    D9 --> D10
    D10 --> D11[Redact passwords in install log]
    D11 --> D12[Write-CWAAEventLog success]

    style B3 fill:#f8d7da,stroke:#dc3545
    style B5 fill:#f8d7da,stroke:#dc3545
    style B8 fill:#f8d7da,stroke:#dc3545
    style C12 fill:#f8d7da,stroke:#dc3545
    style D7 fill:#f8d7da,stroke:#dc3545
    style D12 fill:#d4edda,stroke:#28a745
```

## Health Check Escalation Flow

`Test-CWAAHealth` performs read-only assessment. `Repair-CWAA` uses those results to escalate remediation.

```mermaid
flowchart TD
    A[Repair-CWAA called] --> B{Agent installed?<br/>LTService exists?}

    B -->|No| C[Stage 4: Fresh Install]
    C --> C1{Server + LocationID +<br/>InstallerToken provided?}
    C1 -->|Yes| C2[Install-CWAA with params]
    C1 -->|No| C3[Recover from Get-CWAAInfoBackup]
    C3 --> C4{Backup has Server?}
    C4 -->|Yes| C5[Redo-CWAA from backup]
    C4 -->|No| C6[Error: No install settings available]

    B -->|Yes| D{Config readable?<br/>Get-CWAAInfo succeeds?}
    D -->|No| D1[Stage 1: Uninstall corrupt agent]
    D1 --> D2[Return Success=false<br/>for clean reinstall next cycle]

    D -->|Yes| E{Server parameter provided<br/>AND server mismatch?}
    E -->|Yes| E1[Stage 2: Redo-CWAA<br/>Reinstall with correct server]

    E -->|No| F{LastContact or LastHeartbeat<br/>older than HoursRestart?<br/>default: 2 hours}
    F -->|No| G[Agent healthy — no action<br/>Log event 4000]

    F -->|Yes| H[Stage 3: Restart-CWAA]
    H --> I[Wait up to 120s<br/>Poll LastSuccessStatus every 2s]
    I --> J{LastContact recovered?}
    J -->|Yes| K[Restart succeeded<br/>Log event 4001]

    J -->|No| L{LastContact older than<br/>HoursReinstall?<br/>default: 120 hours / 5 days}
    L -->|No| M[Wait for next cycle<br/>Return current status]
    L -->|Yes| N{Server reachable?<br/>Test-CWAAServerConnectivity}
    N -->|No| O[Error: Server unreachable<br/>Log event 4008]
    N -->|Yes| P[Stage 3b: Redo-CWAA<br/>Full reinstall<br/>Log event 4002]

    style G fill:#d4edda,stroke:#28a745
    style K fill:#d4edda,stroke:#28a745
    style C6 fill:#f8d7da,stroke:#dc3545
    style D2 fill:#f8d7da,stroke:#dc3545
    style O fill:#f8d7da,stroke:#dc3545
    style E1 fill:#fff3cd,stroke:#ffc107
    style P fill:#fff3cd,stroke:#ffc107
    style C2 fill:#cce5ff,stroke:#004085
    style C5 fill:#cce5ff,stroke:#004085
```

## Registry & File System Interaction Map

Which functions read and write the key system locations.

```mermaid
flowchart LR
    subgraph Registry["Registry Keys"]
        REG_ROOT["HKLM:\SOFTWARE\LabTech\Service<br/><i>CWAARegistryRoot</i>"]
        REG_SETTINGS["...\Service\Settings<br/><i>CWAARegistrySettings</i>"]
        REG_BACKUP["HKLM:\SOFTWARE\LabTechBackup\Service<br/><i>CWAARegistryBackup</i>"]
        REG_UNINSTALL["HKLM:\...\Uninstall\{GUID}<br/><i>CWAAUninstallKeys</i>"]
    end

    subgraph FileSystem["File System"]
        FS_INSTALL["C:\Windows\LTSVC\<br/><i>CWAAInstallPath</i>"]
        FS_TEMP["C:\Windows\Temp\LabTech\<br/><i>CWAAInstallerTempPath</i>"]
        FS_ERRORS["C:\Windows\LTSVC\errors.txt"]
        FS_PROBES["C:\Windows\LTSVC\Probes\*.txt"]
        FS_BACKUP["C:\Windows\LTSVC\Backup\"]
    end

    subgraph Readers["Read Operations"]
        direction TB
        R1[Get-CWAAInfo]
        R2[Get-CWAASettings]
        R3[Get-CWAAInfoBackup]
        R4[Get-CWAAError]
        R5[Get-CWAAProbeError]
        R6[Get-CWAAProxy]
        R7[Test-CWAAHealth]
    end

    subgraph Writers["Write Operations"]
        direction TB
        W1[Install-CWAA]
        W2[Uninstall-CWAA]
        W3[Set-CWAALogLevel]
        W4[Set-CWAAProxy]
        W5[Reset-CWAA]
        W6[New-CWAABackup]
        W7[Start-CWAA]
        W8["Hide/Show/Rename-<br/>CWAAAddRemove"]
    end

    R1 -->|read| REG_ROOT
    R2 -->|read| REG_SETTINGS
    R3 -->|read| REG_BACKUP
    R4 -->|read| FS_ERRORS
    R5 -->|read| FS_PROBES
    R6 -->|read| REG_SETTINGS
    R7 -->|read| REG_ROOT

    W1 -->|write| FS_INSTALL
    W1 -->|write| FS_TEMP
    W2 -->|delete| REG_ROOT
    W2 -->|delete| FS_INSTALL
    W3 -->|write| REG_SETTINGS
    W4 -->|write| REG_SETTINGS
    W5 -->|delete values| REG_ROOT
    W6 -->|write| REG_BACKUP
    W6 -->|write| FS_BACKUP
    W7 -->|write TrayPort| REG_ROOT
    W8 -->|write| REG_UNINSTALL

    style REG_ROOT fill:#e2e3f1,stroke:#6c63ff
    style REG_SETTINGS fill:#e2e3f1,stroke:#6c63ff
    style REG_BACKUP fill:#e2e3f1,stroke:#6c63ff
    style REG_UNINSTALL fill:#e2e3f1,stroke:#6c63ff
    style FS_INSTALL fill:#fce4d6,stroke:#ed7d31
    style FS_TEMP fill:#fce4d6,stroke:#ed7d31
    style FS_ERRORS fill:#fce4d6,stroke:#ed7d31
    style FS_PROBES fill:#fce4d6,stroke:#ed7d31
    style FS_BACKUP fill:#fce4d6,stroke:#ed7d31
```

## Proxy Resolution Flow

`Get-CWAAProxy` discovers settings from the installed agent. `Set-CWAAProxy` applies changes with three modes.

```mermaid
flowchart TD
    subgraph Discovery["Get-CWAAProxy (Discovery)"]
        GP1[Get-CWAAInfo — read registry] --> GP2{ServerPassword<br/>in registry?}
        GP2 -->|No| GP3[Keys empty — no proxy available]
        GP2 -->|Yes| GP4[ConvertFrom-CWAASecurity<br/>Decrypt ServerPasswordString]
        GP4 --> GP5[ConvertFrom-CWAASecurity<br/>Decrypt PasswordString<br/>using ServerPasswordString as key]
        GP5 --> GP6[Get-CWAASettings — read Settings key]
        GP6 --> GP7{ProxyServerURL<br/>matches https?://?}
        GP7 -->|No| GP8[Proxy disabled — clear LTProxy]
        GP7 -->|Yes| GP9[Decrypt ProxyUsername +<br/>ProxyPassword using<br/>PasswordString as key]
        GP9 --> GP10["Store in $Script:LTProxy<br/>(Enabled, URL, User, Pass)"]
    end

    subgraph Configuration["Set-CWAAProxy (Configuration)"]
        SP1[Set-CWAAProxy called] --> SP2{Which mode?}
        SP2 -->|ResetProxy| SP3[Clear all proxy state<br/>New empty WebProxy]
        SP2 -->|DetectProxy| SP4[GetSystemWebProxy<br/>+ netsh winhttp show proxy]
        SP2 -->|Manual URL| SP5[Create WebProxy with URL<br/>+ optional credentials]
        SP3 --> SP6{Registry settings<br/>changed?}
        SP4 --> SP6
        SP5 --> SP6
        SP6 -->|No| SP7[Return — no update needed]
        SP6 -->|Yes| SP8[Stop-CWAA services]
        SP8 --> SP9[ConvertTo-CWAASecurity<br/>Encrypt URL + Username + Password<br/>Write to registry Settings key]
        SP9 --> SP10[Start-CWAA services]
        SP10 --> SP11[Write-CWAAEventLog 3020]
    end

    GP10 -.->|"Module session proxy<br/>used by all networking"| SP1

    style GP10 fill:#d4edda,stroke:#28a745
    style SP11 fill:#d4edda,stroke:#28a745
    style GP3 fill:#f8d7da,stroke:#dc3545
    style GP8 fill:#fff3cd,stroke:#ffc107
    style SP7 fill:#e2e3f1,stroke:#6c63ff
```

## Uninstall/Cleanup Sequence

`Uninstall-CWAA` end-to-end flow from validation through post-uninstall verification.

```mermaid
flowchart TD
    A[Uninstall-CWAA called] --> B[Begin Block]
    B --> B1[Initialize-CWAANetworking]
    B1 --> B2{Running as<br/>Administrator?}
    B2 -->|No| B3[Throw: Needs Administrator]
    B2 -->|Yes| B4{Probe agent<br/>detected?}
    B4 -->|"Yes, no -Force"| B5[Error: Probe uninstall denied]
    B4 -->|"Yes, -Force"| B6[Continue]
    B4 -->|No| B6
    B6 --> B7{-Backup specified?}
    B7 -->|Yes| B8[New-CWAABackup]
    B7 -->|No| B9[Build registry key list<br/>30+ keys across HKLM,<br/>HKCR, HKU, Wow6432Node]
    B8 --> B9

    B9 --> C[Process Block]
    C --> C1{Server provided?}
    C1 -->|No| C2[Read from agent registry<br/>or prompt user]
    C1 -->|Yes| C3[Use provided server]
    C2 --> C3
    C3 --> C4[Resolve-CWAAServer<br/>Find first reachable server]
    C4 -->|No server| C5[Return — cannot proceed]
    C4 -->|Server found| C6[Download Agent_Uninstall.msi<br/>+ Agent_Uninstall.exe]
    C6 --> C7[Test-CWAADownloadIntegrity<br/>MSI > 1234 KB, EXE > 80 KB]
    C7 -->|Failed| C5
    C7 -->|Passed| C8[GoodServer set]

    C8 --> D[End Block]
    D --> D1[Stop-CWAA — stop all services]
    D1 --> D2[Kill agent processes<br/>from install path]
    D2 --> D3[regsvr32 /u wodVPN.dll]
    D3 --> D4[msiexec /x Agent_Uninstall.msi /qn]
    D4 --> D5[Execute Agent_Uninstall.exe]
    D5 --> D6["sc.exe delete — LTService,<br/>LTSvcMon, LabVNC"]
    D6 --> D7[Remove-CWAAFolderRecursive<br/>Install path + temp dir]
    D7 --> D8[Remove MSI file<br/>retry up to 4 times]
    D8 --> D9[Remove 30+ registry keys<br/>depth-first removal]
    D9 --> D10{Remnants<br/>detected?}
    D10 -->|Yes| D11[Error: Reboot recommended<br/>Event 1011]
    D10 -->|No| D12[Success: Agent uninstalled<br/>Event 1010]

    style B3 fill:#f8d7da,stroke:#dc3545
    style B5 fill:#f8d7da,stroke:#dc3545
    style C5 fill:#f8d7da,stroke:#dc3545
    style D11 fill:#fff3cd,stroke:#ffc107
    style D12 fill:#d4edda,stroke:#28a745
```
