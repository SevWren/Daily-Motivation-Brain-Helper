# CLAUDE.md — Daily Motivation Brain Helper

## Critical: Windows-only validation

This app targets **Windows 10/11** (WPF, Task Scheduler, registry, Explorer). Tests run in two
environments:

- **Windows 10/11 PowerShell 7** (primary) — the real target. Baselines and mock behavior for
  Task Scheduler/registry/CIM only mean anything here.
- **Linux PowerShell 7** (secondary) — CI-only, for the platform-abstraction subset
  (`*.Platform.Tests.ps1`, `PlatformAdapter.Tests.ps1`, `FolderScheduling.Tests.ps1`). These use a
  `HeadlessPlatform` injection and never touch real Task Scheduler/registry/CIM.

**Rule: a Linux CI pass is never sufficient to close a scheduling/permissions/registry issue.**
Any issue whose fix touches `-Skip:(-not $IsWindows)` tests needs one of the following attached
before closing: full Windows `Invoke-Pester`/`Invoke-Tests.ps1` output with 0 failures, a Windows CI
runner link, or a Windows terminal screenshot. "Looks correct," a Linux-only pass, or a prior run
for a different commit do not count. If an issue gets closed without this, reopen it and say why.

---

## Known bug: "Schedule Failed / Access is denied"

This dialog appears in `setfolder` and `main` mode. It comes from `Register-ScheduledTask` failing,
not from folder ACL validation. It has recurred multiple times from the same handful of mistakes —
avoid repeating them.

**Task principal is frozen. Do not change without a live Windows 10/11 test:**
```powershell
New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
```
- `RunLevel Highest` requires UAC elevation → "Access is denied" for standard users.
- `LogonType S4U` fails "Access is denied" for standard users, and even when it registers it can't
  host the interactive WPF popup this app exists to show. `Interactive` is the validated value.
- Any change to `UserId`/`LogonType`/`RunLevel` needs a live Windows test or the real
  `Register-ScheduledTask` integration test below — not documentation or Linux-side reasoning.

**Never call `.Dispose()` on a WPF `System.Windows.Window`** — it doesn't implement `IDisposable`
and throws a method-not-found error. Use `.Close()`. Same goes for `DriveInfo` (a non-disposable
value type). Before calling `.Dispose()` on anything else, check `$obj -is [System.IDisposable]`.

**Don't remove a `$script:*` module-level variable during cleanup without grepping every reference
in the file first.** A variable with no obvious caller in the happy path (e.g.
`$script:ConfigDefaults`) can still be a required fallback for a failure path; removing it silently
turns into a null-reference that surfaces as "Access is denied" somewhere else entirely.

**Error messages must name the failing operation, not just sanitize the path.** `[PATH]` redaction
is fine; collapsing every failure to a generic message isn't — the dialog needs to be
distinguishable at a glance from "Invalid Folder," and should carry the Windows error code.

**The `Register-ScheduledTask` catch block must cover more than "Access Denied":**

| Condition | Error string contains | 
|---|---|
| Access denied | "Access is denied." |
| Elevation required | "requires elevation" |
| S4U logon failure | "logon session does not exist" |
| Service unavailable | "Task Scheduler service is not available" |
| Bad exe path | "cannot find the file specified" |

```powershell
try {
    $registeredTask = Register-ScheduledTask @taskParams -ErrorAction Stop
    if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
        throw "Task registration reported success but task was not found afterward."
    }
} catch {
    $hresult = $_.Exception.HResult
    $userMsg = switch -Regex ($_.Exception.Message) {
        'Access.Denied|0x80070005'        { "OS task registration was denied. Ensure Task Scheduler is enabled for your account." }
        'elevation|requires elevation'     { "Scheduling requires administrator elevation for this operation." }
        'logon session|0x8007052e'        { "Logon configuration error contacting Task Scheduler." }
        'not available|0x80041315'        { "Windows Task Scheduler service is not running. Enable it in Services and try again." }
        'cannot find the file|0x80070002' { "Executable path not found. Rebuild the application and try again." }
        default                           { "OS task registration failed (0x{0:X8})." -f $hresult }
    }
    Show-ErrorDialog -Title "Schedule Failed" -Message "Could not schedule reminder for [PATH].`n`n$userMsg"
    return $false
}
```

**Required integration test** (must exist and pass on Windows before any principal-config change is
considered resolved) — `Tests/Integration/TaskScheduler.Real.Integration.Tests.ps1`, no mocking:
```powershell
Describe 'New-MotivationTask - real Task Scheduler integration' {
    It 'registers and removes a task for an accessible folder without Access Denied' `
       -Skip:(-not $IsWindows) {
        $testPath = Join-Path $env:TEMP 'dmh-integration-test'
        New-Item -ItemType Directory -Path $testPath -Force | Out-Null
        try {
            $result = New-MotivationTask -FolderPath $testPath -TriggerTime (Get-Date).AddDays(2)
            $result.Success | Should -Be $true
            # New-MotivationTask returns TaskId; the OS task name is "DailyMotivation_" + TaskId.
            Get-ScheduledTask -TaskName "DailyMotivation_$($result.TaskId)" -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty
            Remove-MotivationTask -TaskId $result.TaskId
        } finally {
            Remove-Item $testPath -Force -ErrorAction SilentlyContinue
        }
    }
}
```
Note: a task is reliably deletable only from the process that registered it — cross-process delete
can fail with `E_ACCESSDENIED`. Always clean up in-process (test `finally`/`AfterAll`), never rely
on a later process to remove it.

---

## Pester 5 / CI gotchas

- **Never put `ErrorAction`/`WarningAction`/`Verbose`/`Debug` in a splatted hashtable** if you also
  set it on the call — Pester's mock proxy double-binds it, producing a non-terminating error with
  an *empty message* that `-ErrorAction Stop` then promotes to a misleading terminating exception.
  Set common parameters on the call only, never in the splat.
- **Never mock `New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`, `New-ScheduledTaskSettingsSet`,
  or `New-ScheduledTaskPrincipal`.** `Register-ScheduledTask` requires real `CimInstance` objects;
  `-RemoveParameterValidation` strips `[Validate*]` attributes but not type constraints, so
  `PSCustomObject` mocks always fail to convert. Let these run for real; mock only the persistence
  layer (`Register-ScheduledTask`, `Get-ScheduledTask`, `Unregister-ScheduledTask`).
- **Module-qualified calls (`Module\Cmdlet`) don't escape a Pester mock** — calling them from inside
  the mock body to reach the "real" cmdlet causes infinite recursion. If you need real behavior,
  don't mock that cmdlet at all.
- **Don't use `<token>` syntax in `It` test names** unless it's a `-ForEach` data key in scope —
  under `Set-StrictMode`, Pester tries to expand it as `${token}` and aborts the whole `Describe`
  block if the variable doesn't exist. Write the description out in plain prose instead.

---

## Architecture

**One file, one exe:** `DailyMotivation.ps1 → Invoke-ps2exe -STA -noConsole → DailyMotivation.exe`
(fully self-contained; no `src/`, no companion files, no setup script).

### Execution modes

| Invocation | Mode | When |
|---|---|---|
| `DailyMotivation.exe` | `main` | User double-clicks the exe |
| `DailyMotivation.exe /popup` | `popup` | Task Scheduler fires |
| `DailyMotivation.exe /setfolder "C:\path"` | `setfolder` | Explorer right-click context menu |

### Script sections

| Section | Contents |
|---|---|
| 1 | `param($Mode, $FolderPath, [switch]$NoRun)` |
| 2 | Platform detection, assembly loading (`Initialize-WindowsAssemblies`) |
| 2.5 | Platform abstraction (`$script:Platform` / HeadlessPlatform for tests) |
| 3 | Config: `Initialize-AppData`, `Get/Save-Config`, `Get/Set-PopupConfig`, `Write-OutcomeLog`, `Get-SafeErrorMessage`, `Show-ErrorDialog`, `Show-InfoDialog` |
| 4 | Tasks: `Get/Save-TasksJson`, `New-MotivationTask`, `Sync-TaskStatuses`, `Get/Remove-MotivationTask` |
| 4.5–5 | UI helpers + scheduling: `Invoke-FolderScheduling`, undo timers, history UI |
| 5 | Context menu: `Register-ContextMenu`, `Unregister-ContextMenu` (HKCU, no admin) |
| 6–7 | Main window XAML + `Show-MainWindow` |
| 8–9 | Popup XAML + `Show-PopupWindow` (per-user/session popup mutex) |
| 10 | Text helpers + `$Messages` + `Get-RandomMessage` |
| 11 | Entry point: `if (-not $NoRun) { Initialize-AppData; switch($Mode) { ... } }` |

Full function list and config schemas: [docs/reference/](docs/reference/README.md). Domain
language: [CONTEXT.md](CONTEXT.md).

### Config files (`%APPDATA%\DailyMotivationBrainHelper\`)

| File | Contents |
|---|---|
| `config.json` | `{"default_trigger_hour": 14, "task_warning_threshold": 5}` |
| `popup_config.json` | Written by `main`/`setfolder`, read by `popup` |
| `tasks.json` | Scheduled task list |
| `popup_log.txt` | Pipe-delimited outcome history |

## Build & test

```powershell
.\build.ps1                      # requires: Install-Module ps2exe -Scope CurrentUser
.\Invoke-Tests.ps1                # all tests
.\Invoke-Tests.ps1 -CI            # CI mode (exit code, XML reports)
```

Tests dot-source the script with `-NoRun` — no exe required. To run the platform-abstraction subset
on Linux/macOS, install PowerShell 7 (`pwsh`) for your OS; this does **not** substitute for Windows
validation of Task Scheduler/registry/CIM-dependent tests — see [ADR-003](docs/architecture/adr-003-platform-adapter.md).

## Key design constraints

- Dev/testing: PowerShell 7 (`pwsh`). Compiled exe target: .NET Framework 4.x (ps2exe limitation —
  avoid PS7-only features in runtime code paths). STA thread model required for WPF (`-STA` baked
  into the ps2exe build).
- Popup mutex `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}` enforces one popup per
  user session; config writes use `Global\DailyMotivationPopupConfigLock`.
- Task Scheduler action calls `$script:ExePath /popup`, captured via
  `$MyInvocation.MyCommand.Path` at runtime — but ps2exe can leave that empty, so resolve as:
  ```powershell
  $script:ExePath = if ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path }
                     else { [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName }
  ```
  Tests override `$script:ExePath` before calling `New-MotivationTask`. `Register-ContextMenu` must
  reject `.ps1` paths — the context-menu verb has to point at the compiled `.exe`.
- `Initialize-AppData` re-resolves all paths from `$env:APPDATA` at call time (enables test
  redirects). `Get-TasksJson` wraps its result in `@()` for consistent array handling; valid
  statuses: `PENDING`, `DELETED`, `COMPLETED`, `FAILED`. Outcome log stores SHA-256 path hashes, not
  plaintext paths.

## Code quality rules

- **No startup popups.** `main` mode must launch straight into the main window — no blocking
  dialogs on launch.
- **Comment hygiene.** Remove bug-ID comments (e.g. `# AG19-003:`); bug tracking belongs in commit
  history, not inline comments. Keep only comments explaining *why* or non-obvious behavior.

## Documentation map

| Doc | Purpose |
|---|---|
| [README.md](README.md) | Product overview |
| [CONTEXT.md](CONTEXT.md) | Domain language (authoritative terminology) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [docs/](docs/README.md) | Developer documentation |
| [manual/](manual/README.md) | End-user documentation |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting |

External NFR source of truth (if present outside the repo):
`DailyMotivationBrainHelper_TechnicalReflection_2026-06-12_v2_1_CORRECTED.md`. In-repo architecture
notes: [docs/architecture/](docs/architecture/README.md).
