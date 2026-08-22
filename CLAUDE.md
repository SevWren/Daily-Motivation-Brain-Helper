# CLAUDE.md — Daily Motivation Brain Helper

## CRITICAL: Testing Environment

This app targets **Windows 10/11** (WPF, Task Scheduler, registry). Tests run in two incompatible environments:

| Environment | Valid for |
|-------------|-----------|
| Windows 10/11 PowerShell 7 | All tests — PRIMARY |
| Linux PowerShell 7 | Platform-abstraction tests only |

**Linux-safe** (HeadlessPlatform injection): `Config.Platform.Tests.ps1`, `TaskScheduler.Platform.Tests.ps1`, `PlatformAdapter.Tests.ps1`, `FolderScheduling.Tests.ps1`

**Windows-only**: `TaskScheduler.Tests.ps1`, integration tests in `Tests/Integration/`

**Mixed** (most `It` blocks run cross-platform via mocks; a subset are `-Skip:(-not $IsWindows)`): `ContextMenu.Tests.ps1`

The test suite contains 30+ additional files in `Tests/Unit/` and `Tests/Integration/` not categorised above. Check each file's `BeforeAll` guard and `-Skip:` annotations before assuming platform compatibility.

**Tests passing in Linux do not validate Windows behavior.** Always get Windows test output before declaring any fix complete.

---

## MANDATE: Schedule Failed / "Access is denied" — Correct and Incorrect Fix Patterns

> **Binding on all agents and contributors.** See [ADR-005](docs/architecture/adr-005-mandate-history.md) for incident history.

### WRONG 1 — Declaring a fix verified from Linux CI or mocked tests alone

**Rule:** Never close or declare resolved any bug involving `Register-ScheduledTask`, task principal configuration, or context-menu invocation without a live test on a real Windows 10/11 machine.

**Exception:** `Tests/Integration/TaskScheduler.Real.Integration.Tests.ps1` deliberately uses real `Register-ScheduledTask` (no mocks) and is `-Skip:(-not $IsWindows)`. This is the mandated gate test — it is not a violation of WRONG 1.

### WRONG 2 — Calling `.Dispose()` on a WPF `System.Windows.Window`

`System.Windows.Window` does not implement `IDisposable`. Calling it throws:
```
Method invocation failed because [System.Windows.Window] does not contain a method named 'Dispose'.
```
**Rule:** Use `.Close()` on windows. For all other objects, guard before calling `.Dispose()`. `DriveInfo` is not IDisposable.

### WRONG 3 — Removing `$script:*` variables without checking all call sites

**Rule:** Grep the entire file for every reference before removing any `$script:*` variable. A variable with no obvious callers in the happy path may still be a required fallback (e.g. `$script:ConfigDefaults`). Note: `$script:ExePath` is only assigned inside the entry-point block — it is `$null` under `-NoRun`; tests must set it manually before calling `New-MotivationTask`.

### WRONG 4 — Sanitizing error messages to `[PATH]` without naming the operation

**Rule:** Path sanitization to `[PATH]` is correct. But every error message must also name the failing operation (e.g., "OS task registration failed"). Include the Windows error code where possible.

### WRONG 5 — Narrow `catch` pattern that misses real Task Scheduler errors

| Windows condition | Error string |
|-------------------|-------------|
| Standard access denied | "Access is denied." |
| Elevation required | "The requested operation requires elevation." |
| S4U logon failure | "A specified logon session does not exist." |
| Service unavailable | "The Task Scheduler service is not available." |
| Bad exe path | "The system cannot find the file specified." |

**Rule:** Cover all cases above, or catch all terminating exceptions and inspect `$_.Exception.HResult`.

**Open violation:** The current `catch` block in `New-MotivationTask` (lines ~801–812) handles only `already exists` and `Access Denied|not have permission`. The remaining four cases fall through to a generic `else` with the raw exception message. This is a known gap, not the correct pattern.

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
$script:ExePath = $MyInvocation.MyCommand.Path
if (-not $script:ExePath -or $script:ExePath -notmatch '\.exe$') {
    $script:ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
}
```

The fallback triggers on empty path **or** non-`.exe` path (e.g. when run as `.ps1`). Guard `Register-ContextMenu` to reject `.ps1` paths — context-menu verb must point to the compiled `.exe`.

### CORRECT 3 — WPF window and resource cleanup

```powershell
$window.Close()                                              # windows: Close(), never Dispose()
if ($null -ne $timer)  { try { $timer.Stop(); $timer.Dispose()  } catch {} }
if ($null -ne $mutex)  { try { $mutex.Dispose()  } catch {} }
if ($null -ne $dialog) { try { $dialog.Dispose() } catch {} }
# XmlNodeReader used for XAML parsing — always dispose in a finally block:
# finally { if ($reader) { $reader.Dispose() } }
# $window.Dispose()    <- WRONG: no such method on System.Windows.Window
# $driveInfo.Dispose() <- WRONG: DriveInfo is not IDisposable
```

Note: the codebase uses `$null` checks + `try/catch {}` rather than `-is [System.IDisposable]` guards. Both are safe; use the `$null`/try-catch pattern to match existing code style.

### CORRECT 4 — Error handling around Register-ScheduledTask

**Architecture note:** `New-MotivationTask` returns a result hashtable `@{ Success=$false; Error=... }` — it does NOT call `Show-ErrorDialog` directly. `Show-ErrorDialog` is the caller's responsibility (e.g. `/setfolder` entry point). Do not add `Show-ErrorDialog` inside `New-MotivationTask`'s catch block — it would break the return-value contract.

The mandated catch pattern (not yet fully implemented — see WRONG 5 open violation):

```powershell
try {
    Register-ScheduledTask @registerParams -ErrorAction Stop | Out-Null
    if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
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
    return @{ Success = $false; TaskId = $null; IsDuplicate = $false; Error = $userMsg }
}
```

Note: `Force = $true` must be in `$registerParams` to allow re-registration of an existing task name.

### CORRECT 5 — Windows integration test (exists — must pass before any scheduling change is closed)

The test lives at `Tests/Integration/TaskScheduler.Real.Integration.Tests.ps1`. It uses real `Register-ScheduledTask` with no mocks and is guarded `-Skip:(-not $IsWindows)` on the `Describe` block. It verifies `LogonType Interactive` and `RunLevel Limited` against the live OS task object. This test must pass on Windows before any scheduling principal change is declared resolved.

---

## MANDATE: Pester 5 / CI Test Infrastructure — Correct and Incorrect Patterns

> **Binding on all agents and contributors.** See [ADR-005](docs/architecture/adr-005-mandate-history.md) for incident history.

### WRONG 7 — `ErrorAction` inside a splatted hashtable passed to a mocked cmdlet

Including any PowerShell common parameter in a `@splat` dict AND on the call causes Pester's mock proxy to double-bind it — producing a silent non-terminating error with an empty message.

```powershell
# WRONG
$params = @{ TaskName = $taskName; Action = $action; ErrorAction = 'Stop' }
Register-ScheduledTask @params -ErrorAction Stop

# CORRECT
$params = @{ TaskName = $taskName; Action = $action }
Register-ScheduledTask @params -ErrorAction Stop
```

**Rule:** Never put `ErrorAction`, `WarningAction`, `Verbose`, or `Debug` in a splatted hashtable. When a mock body needs to capture `ErrorAction`, declare it in the mock's `param()` block — that is the approved workaround and does not cause a double-bind.

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

**Known exception:** `TaskScheduler.Tests.ps1` (`Context 'Task Principal configuration'`, lines ~419–434) mocks `New-ScheduledTaskPrincipal` with a `PSCustomObject` to verify `LogonType`. This pre-dates the mandate. Do not replicate this pattern; treat it as a legacy outlier to be refactored.

### WRONG 9 — Module-qualified calls to escape Pester interception

Pester 5 intercepts `ScheduledTasks\New-ScheduledTaskAction`. Calling the real cmdlet from inside a mock body causes infinite recursion.

**Rule:** No escape from Pester mocking via module qualification. If real behavior is needed, do not mock the cmdlet.

### WRONG 10 — `<token>` syntax in Pester 5 test names

Pester 5 expands `<key>` as a `-ForEach` template. Under `Set-StrictMode -Version Latest` (set by `Invoke-Tests.ps1`, inherited by all test files) an undefined `$key` aborts the describe block.

```powershell
# WRONG — It 'Should set task_name to DailyMotivation_<id> format' { ... }
# CORRECT — It 'Should set task_name to DailyMotivation_ followed by a 16-char hex id' { ... }
```

**Rule:** No `<token>` in test names unless it is a `-ForEach` data key in scope.

---

## MANDATE: GitHub Issue Closure Gate

> **Binding on all agents and contributors.** See [ADR-005](docs/architecture/adr-005-mandate-history.md). Note: this gate is documentation-only — no GitHub automation enforces it.

**Any issue whose resolution includes `-Skip:(-not $IsWindows)` tests may not be closed until a passing Windows 10/11 run is posted as an issue comment.**

Accepted proof: full `.\Invoke-Tests.ps1` terminal output from Windows 10/11 PS7, a CI Windows runner link, or a terminal screenshot — all showing 0 failures for the affected tests.

Linux CI passing, code review, or platform-abstraction-only test results do not count.

If closed prematurely: reopen, comment which Windows-only tests are unvalidated, do not re-close until proof is attached.

---

## Architecture

**One file, one exe.**

```
DailyMotivation.ps1  →  build.ps1 (Invoke-ps2exe -STA -noConsole -title "Daily Motivation Brain Helper" -version "2.0.0.0")  →  DailyMotivation.exe
```

## Execution Modes

The script's `param()` block:
```powershell
param(
    [ValidateSet("main", "/popup", "/setfolder")]
    [string]$Mode       = "main",
    [ValidateScript({...})]   # rejects paths with wildcard chars: * ? < > |
    [string]$FolderPath = "",
    [switch]$NoRun
)
```

`"main"` is the default value and a `ValidateSet` member, but there is **no `"main"` case in the switch** — it falls to the `default` branch.

| Invocation | Mode matched | When |
|------------|------|------|
| `DailyMotivation.exe` | `default` branch | User double-clicks |
| `DailyMotivation.exe /popup` | `"/popup"` | Task Scheduler fires |
| `DailyMotivation.exe /setfolder "C:\path"` | `"/setfolder"` | Explorer context menu |

## Script Sections

| Section | Contents |
|---------|----------|
| 1 | `param(...)` |
| 2 | Platform detection, assembly loading (`Initialize-WindowsAssemblies`) |
| 2.5 | `HeadlessPlatform` class + `$script:Platform` injection |
| 3 | Config: `Initialize-AppData`, `Get-Config`, `Save-Config`, `Get-PopupConfig`, `Set-PopupConfig`, `Write-OutcomeLog`, `Get-SafeErrorMessage`, `Show-ErrorDialog`, `Show-InfoDialog` |
| 4 | Tasks: `Get-TasksJson`, `Save-TasksJson`, `New-MotivationTask`, `Sync-TaskStatuses`, `Get-MotivationTasks`, `Remove-MotivationTask` |
| 4.5 (unnumbered) | Business logic hoisted for testability: `Get-ScheduleTime`, `Update-TaskListUI`, `Get-HistoryData`, `Update-HistoryUI`, `Start-UndoTimer`, `Stop-UndoTimer`, `Set-SnoozeDuration`, `Invoke-FolderScheduling` |
| 5 | Context menu: `Register-ContextMenu`, `Unregister-ContextMenu` (HKCU, no admin) |
| 6–7 | Main window XAML + `Show-MainWindow` |
| 8–9 | Popup XAML + `Show-PopupWindow` + `Get-PopupOutcome` |
| 10 | `$Messages` + `Get-RandomMessage` |
| 10.5 (unnumbered) | Text helpers: `Escape-XmlText`, `Truncate-TextForDisplay` (150-char max), `Strip-MarkupText` |
| 11 | Entry point: `if (-not $NoRun) { Initialize-AppData; switch($Mode) { ... } }` |

Full function list and config schemas: [docs/reference/](docs/reference/README.md). Domain language: [CONTEXT.md](CONTEXT.md).

**Note:** `Get-MotivationTasks` is plural. There is no `Get-MotivationTask` (singular) — calling it throws `CommandNotFoundException`.

## Config Files (`%APPDATA%\DailyMotivationBrainHelper\`)

| File | Contents |
|------|----------|
| `config.json` | `{"default_trigger_hour": 14, "task_warning_threshold": 5}` |
| `popup_config.json` | Written by `Set-PopupConfig`; read exclusively by popup mode |
| `tasks.json` | Array of MotivationTask records |
| `popup_log.txt` | Pipe-delimited outcome history. Rotates at 1 MB → `popup_log.txt.archive_<timestamp>`; archives older than 30 days are deleted automatically. |
| `popup_debug.txt` | Diagnostic log written by `Show-PopupWindow`. Not user-facing. |
| `first_run.done` | Sentinel file; presence suppresses the welcome dialog. Delete to re-trigger it. |

**`popup_config.json` schema** (10 keys written by `Set-PopupConfig`):

| Key | Notes |
|-----|-------|
| `explorer_path` | The folder path — use this key when reading; `folder_path` is a legacy alias |
| `folder_path` | Legacy alias for `explorer_path` — written for backwards compatibility only |
| `folder_name` | Leaf component of the path |
| `glyph` | Three-char ASCII icon e.g. `[+]` |
| `title` | Message title |
| `body` | Message body |
| `task_id` | MotivationTask identifier |
| `message_glyph` | Legacy alias for `glyph` |
| `message_title` | Legacy alias for `title` |
| `message_body` | Legacy alias for `body` |

**`tasks.json` per-record fields:** `task_id`, `task_name`, `folder_path`, `folder_name`, `scheduled_time` (ISO 8601 local), `created_at` (ISO 8601 with offset), `status`, `snooze_count`, `description` (SHA-256 hash prefix — not the folder path).

## Build & Test

```powershell
# Prerequisites
Install-Module ps2exe -Scope CurrentUser
Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck

.\build.ps1                              # compile DailyMotivation.exe
.\Invoke-Tests.ps1                       # all tests
.\Invoke-Tests.ps1 -CI                   # CI mode: exit code + XML + JaCoCo coverage
.\Invoke-Tests.ps1 -Tag Integration      # run only tagged tests
.\Invoke-Tests.ps1 -ExcludeTag Slow      # exclude tagged tests
.\Invoke-Tests.ps1 -Coverage $false      # skip JaCoCo (faster for quick runs)
```

Tests dot-source `DailyMotivation.ps1 -NoRun` — no exe required. **Pester 5.x is required.** Pester 4 silently fails because file-scoped `BeforeAll` mocks and `-ForEach` on `It` blocks are v5 features.

`PesterConfiguration.psd1` exists but is **not loaded by `Invoke-Tests.ps1`** — it is a static snapshot for direct `Invoke-Pester` calls only. Its `Should.ErrorAction = 'Stop'` and `Run.Exit = $true` settings do not apply through the normal runner.

**CI pipeline** (`.github/workflows/test.yml`, runs on `windows-latest`):
- `test` job: Pester 5.6.1, runs full suite
- `analyze` job: PSScriptAnalyzer 1.22.0 with `.PSScriptAnalyzerSettings.psd1`; separate gate checks for PS7-only syntax forbidden in runtime paths: `Join-String`, `??`, `?.`, `ForEach-Object -Parallel`
- `build` job: gates on `test` + `analyze` passing

## Key Design Constraints

- **`#Requires -Version 7.0`** at line 1 — script requires PS7 to parse; compiled exe targets .NET Framework 4.x
- **Runtime code paths must be .NET Framework 4.x compatible** — avoid PS7-only syntax: `??`, `?.`, ternary `?:`, `Join-String`, `ForEach-Object -Parallel`
- STA thread model required for WPF (`-STA` baked in by ps2exe)
- Popup mutex: `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}`; config lock: `Global\DailyMotivationPopupConfigLock`
- Task Scheduler action: `$script:ExePath /popup` — set at entry point; **undefined under `-NoRun`**, tests must assign it before calling `New-MotivationTask`
- `Initialize-AppData` re-resolves all paths from `$env:APPDATA` (or `$script:Platform.GetAppDataPath()`) at call time — enables test redirects
- Valid task statuses: `PENDING`, `DELETED`, `COMPLETED`, `FAILED`. Any unrecognised value is normalised to `UNKNOWN` at load time by `Get-TasksJson` — handle `UNKNOWN` in any status-switching code
- Outcome log: `[timestamp] | TaskId | FolderName | HASH:{sha256} | Outcome | SnoozeCount` — path stored as SHA-256 hex, not plaintext
- **Snooze creates a new MotivationTask** (calls `New-MotivationTask -Force`) and a new OS Task — it does not reschedule the existing one

## Code Quality Rules

**No Startup Popups:** `DailyMotivation.exe` must never show a dialog on startup in `main` mode on the **normal (non-error) path**. An error dialog is permitted if `Initialize-AppData` throws on startup.

**Comment Hygiene:** Remove `# AG*-*` bug-ID comments. Keep only comments explaining *why* code exists or *what* non-obvious behavior does. Three surviving instances remain in the source (`# AG14-006`, `# AG14-001`, `# AG6-010`) — remove them on next touch.

**PSScriptAnalyzer:** CI runs PSScriptAnalyzer 1.22.0 with `.PSScriptAnalyzerSettings.psd1`. Any new violation blocks the build. Check the settings file for the list of approved rule exclusions before adding new ones.

## Documentation Map

| Doc | Purpose |
|-----|---------|
| [README.md](README.md) | Product overview |
| [CONTEXT.md](CONTEXT.md) | Domain language — read before writing tests or touching domain terms |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Contribution guide including AI-assisted development workflow |
| [CHANGELOG.md](CHANGELOG.md) | Version history (current: 2.0.0.0) |
| [docs/architecture/overview.md](docs/architecture/overview.md) | Architecture overview with Mermaid diagrams |
| [docs/architecture/adr-001-single-file-exe.md](docs/architecture/adr-001-single-file-exe.md) | ADR: one script → one exe |
| [docs/architecture/adr-002-popup-handoff.md](docs/architecture/adr-002-popup-handoff.md) | ADR: PopupConfig as inter-mode handoff |
| [docs/architecture/adr-003-platform-adapter.md](docs/architecture/adr-003-platform-adapter.md) | ADR: HeadlessPlatform for tests |
| [docs/architecture/adr-004-pester-cim-mocking.md](docs/architecture/adr-004-pester-cim-mocking.md) | ADR: Pester 5 mocking strategy |
| [docs/architecture/adr-005-mandate-history.md](docs/architecture/adr-005-mandate-history.md) | Incident history behind the mandates above |
| [docs/reference/README.md](docs/reference/README.md) | Full function list and config schemas |
| [manual/README.md](manual/README.md) | End-user documentation |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting |
