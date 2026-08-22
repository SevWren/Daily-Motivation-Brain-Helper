# CLAUDE.md — Daily Motivation Brain Helper

## CRITICAL: Testing Environment

This app targets **Windows 10/11** (WPF, Task Scheduler, registry). Tests run in two incompatible environments:

| Environment | Valid for |
|-------------|-----------|
| Windows 10/11 PowerShell 7 | All tests — PRIMARY |
| Linux PowerShell 7 | Platform-abstraction tests only |

**Linux-safe tests** (HeadlessPlatform injection): `Config.Platform.Tests.ps1`, `TaskScheduler.Platform.Tests.ps1`, `PlatformAdapter.Tests.ps1`, `FolderScheduling.Tests.ps1`

**Windows-only tests**: `TaskScheduler.Tests.ps1`, `ContextMenu.Tests.ps1`, all integration tests

**Tests passing in Linux do not validate Windows behavior.** Always get Windows test output before declaring any fix complete.

---

## MANDATE: Schedule Failed / "Access is denied" — Correct and Incorrect Fix Patterns

> **Binding on all agents and contributors.** See [ADR-005](docs/architecture/adr-005-mandate-history.md) for incident history.

### WRONG 1 — Declaring a fix verified from Linux CI or mocked tests alone

**Rule:** Never close or declare resolved any bug involving `Register-ScheduledTask`, task principal configuration, or context-menu invocation without a live test on a real Windows 10/11 machine.

### WRONG 2 — Calling `.Dispose()` on a WPF `System.Windows.Window`

`System.Windows.Window` does not implement `IDisposable`. Calling it throws:
```
Method invocation failed because [System.Windows.Window] does not contain a method named 'Dispose'.
```
**Rule:** Use `.Close()` on windows. Guard all other objects with `$obj -is [System.IDisposable]` before `.Dispose()`. `DriveInfo` is not IDisposable.

### WRONG 3 — Removing `$script:*` variables without checking all call sites

**Rule:** Grep the entire file for every reference before removing any `$script:*` variable. A variable with no obvious callers in the happy path may still be a required fallback (e.g. `$script:ConfigDefaults`).

### WRONG 4 — Sanitizing error messages to `[PATH]` without naming the operation

**Rule:** Path sanitization to `[PATH]` is correct. But every error message must also name the failing operation (e.g., "OS task registration failed") — not just the path. Include the Windows error code where possible.

### WRONG 5 — Narrow `catch` pattern that misses real Task Scheduler errors

| Windows condition | Error string |
|-------------------|-------------|
| Standard access denied | "Access is denied." |
| Elevation required | "The requested operation requires elevation." |
| S4U logon failure | "A specified logon session does not exist." |
| Service unavailable | "The Task Scheduler service is not available." |
| Bad exe path | "The system cannot find the file specified." |

**Rule:** Cover all cases above, or catch all terminating exceptions and inspect `$_.Exception.HResult`.

### WRONG 6 — Changing task principal configuration without a live Windows test

**Rule:** Any change to `New-ScheduledTaskPrincipal` parameters (`UserId`, `LogonType`, `RunLevel`) requires a live Windows 10/11 test or a `-Skip:(-not $IsWindows)` integration test against the real `Register-ScheduledTask`.

---

### CORRECT 1 — Task principal configuration (validated — do not change without live testing)

```powershell
New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
```

- `RunLevel Limited` — `Highest` requires UAC elevation and causes "Access is denied" for standard users.
- `LogonType Interactive` — required so the popup fires on the user's active desktop session. `S4U` is session-less and cannot host UI. See [ADR-005](docs/architecture/adr-005-mandate-history.md).

### CORRECT 2 — ExePath resolution for ps2exe compiled executables

```powershell
$script:ExePath = if ($MyInvocation.MyCommand.Path -and $MyInvocation.MyCommand.Path -ne '') {
    $MyInvocation.MyCommand.Path
} else {
    [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
}
```

Guard `Register-ContextMenu` to reject `.ps1` paths — context-menu verb must point to the compiled `.exe`.

### CORRECT 3 — WPF window and resource cleanup

```powershell
$window.Close()                                                        # windows: Close(), never Dispose()
if ($timer  -is [System.IDisposable]) { $timer.Stop(); $timer.Dispose() }
if ($mutex  -is [System.IDisposable]) { $mutex.Dispose() }
if ($dialog -is [System.IDisposable]) { $dialog.Dispose() }
# $window.Dispose()    <- WRONG: no such method on System.Windows.Window
# $driveInfo.Dispose() <- WRONG: DriveInfo is not IDisposable
```

### CORRECT 4 — Error handling around Register-ScheduledTask

```powershell
try {
    $registeredTask = Register-ScheduledTask @taskParams -ErrorAction Stop
    if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
        throw "Task registration reported success but task was not found afterward."
    }
} catch {
    $hresult = $_.Exception.HResult
    $rawMsg  = $_.Exception.Message
    $userMsg = switch -Regex ($rawMsg) {
        'Access.Denied|0x80070005'         { "OS task registration was denied. Ensure Task Scheduler is enabled for your account." }
        'elevation|requires elevation'      { "Scheduling requires administrator elevation for this operation." }
        'logon session|0x8007052e'         { "Logon configuration error contacting Task Scheduler." }
        'not available|0x80041315'         { "Windows Task Scheduler service is not running. Enable it in Services and try again." }
        'cannot find the file|0x80070002'  { "Executable path not found. Rebuild the application and try again." }
        default                            { "OS task registration failed (0x{0:X8})." -f $hresult }
    }
    Show-ErrorDialog -Title "Schedule Failed" -Message "Could not schedule reminder for [PATH].`n`n$userMsg"
    return $false
}
```

A `Register-ScheduledTask` failure must never surface as "Invalid Folder" — these are separate operations.

### CORRECT 5 — Windows integration test required before any scheduling fix is closed

```powershell
Describe 'New-MotivationTask - real Task Scheduler integration' {
    It 'registers and removes a task for an accessible folder without Access Denied' `
       -Skip:(-not $IsWindows) {
        $testPath = Join-Path $env:TEMP 'dmh-integration-test'
        New-Item -ItemType Directory -Path $testPath -Force | Out-Null
        try {
            $result = New-MotivationTask -FolderPath $testPath -TriggerTime (Get-Date).AddHours(2)
            $result.Success | Should -Be $true
            (Get-ScheduledTask -TaskName $result.TaskName -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
            Remove-MotivationTask -TaskId $result.TaskId
        } finally { Remove-Item $testPath -Force -ErrorAction SilentlyContinue }
    }
}
```

**This test is currently absent.** It must exist and pass on Windows before any scheduling principal change is declared resolved.

---

## MANDATE: Pester 5 / CI Test Infrastructure — Correct and Incorrect Patterns

> **Binding on all agents and contributors.** See [ADR-005](docs/architecture/adr-005-mandate-history.md) for incident history.

### WRONG 7 — `ErrorAction` inside a splatted hashtable passed to a mocked cmdlet

Including any PowerShell common parameter in a `@splat` dict AND on the call causes Pester's mock proxy to double-bind it — producing a silent non-terminating error with an empty message that `-ErrorAction Stop` promotes to a terminating exception.

```powershell
# WRONG
$params = @{ TaskName = $taskName; Action = $action; ErrorAction = 'Stop' }
Register-ScheduledTask @params -ErrorAction Stop

# CORRECT
$params = @{ TaskName = $taskName; Action = $action }
Register-ScheduledTask @params -ErrorAction Stop
```

**Rule:** Never put `ErrorAction`, `WarningAction`, `Verbose`, or `Debug` in a splatted hashtable.

### WRONG 8 — Mocking `New-ScheduledTask*` helpers with PSCustomObjects

`-RemoveParameterValidation` strips `[Validate*]` only — not type constraints. `Register-ScheduledTask` requires `CimInstance` for `Action`, `Trigger`, `Settings`, `Principal`. A `PSCustomObject` always fails.

```powershell
# WRONG
Mock New-ScheduledTaskAction { return [PSCustomObject]@{ Execute = $Execute } }

# CORRECT — never mock the builder cmdlets; only mock the persistence layer
Mock Register-ScheduledTask { ... }
Mock Get-ScheduledTask { ... }
Mock Unregister-ScheduledTask { ... }
```

**Rule:** Never mock `New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`, `New-ScheduledTaskSettingsSet`, or `New-ScheduledTaskPrincipal`. See AG8-007 in `SingleFile.Tests.ps1` for the canonical pattern.

### WRONG 9 — Module-qualified calls to escape Pester interception

Pester 5 intercepts `ScheduledTasks\New-ScheduledTaskAction`. Calling the real cmdlet from inside a mock body via module qualification causes infinite recursion.

**Rule:** No escape from Pester mocking via module qualification. If real behavior is needed, do not mock the cmdlet.

### WRONG 10 — `<token>` syntax in Pester 5 test names

Pester 5 expands `<key>` as a `-ForEach` template variable. Under `Set-StrictMode -Version Latest` an undefined `$key` aborts the entire describe block.

```powershell
# WRONG
It 'Should set task_name to DailyMotivation_<id> format' { ... }
# CORRECT
It 'Should set task_name to DailyMotivation_ followed by a 16-char hex id' { ... }
```

**Rule:** No `<token>` in test names unless it is a `-ForEach` data key in scope.

---

## MANDATE: GitHub Issue Closure Gate

> **Binding on all agents and contributors.** See [ADR-005](docs/architecture/adr-005-mandate-history.md).

**Any issue whose resolution includes `-Skip:(-not $IsWindows)` tests may not be closed until a passing Windows 10/11 run is posted as an issue comment.**

Accepted proof: full `.\Invoke-Tests.ps1` terminal output from Windows 10/11 PS7, a CI Windows runner link, or a terminal screenshot — all showing 0 failures for the affected tests.

Linux CI passing, code review, or platform-abstraction-only test results do not count.

If closed prematurely: reopen, comment which Windows-only tests are unvalidated, do not re-close until proof is attached.

---

## Architecture

**One file, one exe.**

```
DailyMotivation.ps1  →  Invoke-ps2exe -STA -noConsole  →  DailyMotivation.exe
```

## Execution Modes

| Invocation | Mode | When |
|------------|------|------|
| `DailyMotivation.exe` | `main` | User double-clicks the exe |
| `DailyMotivation.exe /popup` | `popup` | Windows Task Scheduler fires |
| `DailyMotivation.exe /setfolder "C:\path"` | `setfolder` | Explorer right-click context menu |

## Script Sections

| Section | Contents |
|---------|----------|
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

Full function list and config schemas: [docs/reference/](docs/reference/README.md). Domain language: [CONTEXT.md](CONTEXT.md).

## Config Files (`%APPDATA%\DailyMotivationBrainHelper\`)

| File | Contents |
|------|----------|
| `config.json` | `{"default_trigger_hour": 14, "task_warning_threshold": 5}` |
| `popup_config.json` | Written by `main`/`setfolder`, read by `popup` |
| `tasks.json` | Scheduled task list |
| `popup_log.txt` | Pipe-delimited outcome history |

## Build & Test

```powershell
.\build.ps1                  # requires: Install-Module ps2exe -Scope CurrentUser
.\Invoke-Tests.ps1           # all tests
.\Invoke-Tests.ps1 -CI       # CI mode (exit code + XML reports)
```

Tests dot-source `DailyMotivation.ps1 -NoRun` — no exe required.

## Key Design Constraints

- **Compiled exe target**: .NET Framework 4.x — avoid PS7-only syntax in runtime code paths
- STA thread model required for WPF (`-STA` baked in by ps2exe)
- Popup mutex: `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}`; config lock: `Global\DailyMotivationPopupConfigLock`
- Task Scheduler action: `$script:ExePath /popup` — resolved at runtime, overridden in tests
- `Initialize-AppData` re-resolves all paths from `$env:APPDATA` at call time (enables test redirects)
- `Get-TasksJson` wraps result in `@()` — valid statuses: `PENDING`, `DELETED`, `COMPLETED`, `FAILED`
- Outcome log stores SHA-256 path hashes, not plaintext paths

## Code Quality Rules

**No Startup Popups:** `DailyMotivation.exe` must never show a dialog, prompt, or message on startup in `main` mode.

**Comment Hygiene:** Remove bug-ID comments (`# AG19-003:`). Keep only comments that explain *why* code exists or *what* non-obvious behavior does.

## Documentation Map

| Doc | Purpose |
|-----|---------|
| [README.md](README.md) | Product overview |
| [CONTEXT.md](CONTEXT.md) | Domain language (authoritative) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guide |
| [docs/architecture/adr-005-mandate-history.md](docs/architecture/adr-005-mandate-history.md) | Incident history behind the mandates above |
| [docs/](docs/README.md) | Developer documentation |
| [manual/](manual/README.md) | End-user documentation |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting |
