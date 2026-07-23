# Architecture overview

## One file, one exe

```text
DailyMotivation.ps1  →  Invoke-ps2exe -STA -noConsole  →  DailyMotivation.exe
```

There is no `src/` tree and no companion runtime files. All UI (WPF XAML), scheduling, config, and messages live in `DailyMotivation.ps1`.

| Concern | Choice |
|---------|--------|
| Source runtime | PowerShell 7 (`pwsh`) for development/tests |
| Shipped runtime | .NET Framework 4.x exe (ps2exe) |
| UI | WPF (`-STA`); WinForms fallback for some errors |
| Scheduling | Windows Task Scheduler |
| Persistence | `%APPDATA%\DailyMotivationBrainHelper\` |
| Shell integration | HKCU context menu (no admin) |

## Execution modes

```mermaid
flowchart LR
  User[User / Explorer / Task Scheduler]
  Exe[DailyMotivation.exe]
  Main[main mode<br/>Show-MainWindow]
  Popup[popup mode<br/>Show-PopupWindow]
  Setfolder[setfolder mode<br/>schedule tomorrow]

  User -->|double-click| Exe
  User -->|/popup| Exe
  User -->|/setfolder path| Exe
  Exe --> Main
  Exe --> Popup
  Exe --> Setfolder
```

| Invocation | Mode value | Entry |
|------------|------------|--------|
| `DailyMotivation.exe` | `main` (default) | `Show-MainWindow` |
| `DailyMotivation.exe /popup` | `"/popup"` | `Show-PopupWindow` |
| `DailyMotivation.exe /setfolder "C:\path"` | `"/setfolder"` | Schedule for tomorrow + MessageBox |

ps2exe passes CLI arguments **with the leading slash**, so switch cases match `"/popup"` and `"/setfolder"`, not bare `popup`.

## Handoff and data flow

```mermaid
sequenceDiagram
  participant Main as main / setfolder
  participant JSON as popup_config.json
  participant TS as Task Scheduler
  participant Popup as popup mode

  Main->>JSON: Set-PopupConfig (message + path + task_id)
  Main->>TS: Register OS Task DailyMotivation_{TaskId}
  Note over TS: Fires at TriggerTime
  TS->>Popup: DailyMotivation.exe /popup
  Popup->>JSON: Get-PopupConfig
  Popup->>Popup: Show UI, Open Folder / Snooze / Dismiss
  Popup->>Popup: Write-OutcomeLog (hashed path)
```

Persistent state (all under AppData):

| File | Role |
|------|------|
| `config.json` | AppConfig (`default_trigger_hour`, `task_warning_threshold`) |
| `popup_config.json` | Handoff from schedule → popup |
| `tasks.json` | MotivationTask list |
| `popup_log.txt` | Outcome history (hashed paths) |

## MotivationTask lifecycle

```mermaid
stateDiagram-v2
  [*] --> PENDING: New-MotivationTask
  PENDING --> DELETED: OS Task missing / Sync-TaskStatuses
  PENDING --> COMPLETED: terminal success annotation
  PENDING --> FAILED: terminal failure annotation
  PENDING --> [*]: Remove-MotivationTask
  DELETED --> [*]
  COMPLETED --> [*]
  FAILED --> [*]
```

Duplicate detection only considers tasks with `status = PENDING` for the same folder path and calendar date (unless `-Force`).

## Popup outcomes

```mermaid
flowchart TD
  Start[Popup shown] --> Choice{User / timer}
  Choice -->|Open Folder or countdown 0| Opened[Outcome: Opened]
  Choice -->|Snooze N min| Snoozed[Outcome: Snoozed<br/>new OS Task]
  Choice -->|Dismiss for Today| Dismissed[Outcome: Dismissed<br/>remove PENDING same path]
  Choice -->|Path missing + close| Missing[Outcome: PathMissing]
  Opened --> Log[Write-OutcomeLog]
  Snoozed --> Log
  Dismissed --> Log
  Missing --> Log
```

## Platform adapter

Production uses Windows APIs directly when `$script:Platform` is `$null`. Tests may inject a HeadlessPlatform object so scheduling/dialog behavior can be mocked on non-Windows runners. See [adr-003-platform-adapter.md](adr-003-platform-adapter.md).

## Related

- [CLI reference](../reference/cli.md)
- [Config reference](../reference/config.md)
- [Security overview](../security/overview.md)
