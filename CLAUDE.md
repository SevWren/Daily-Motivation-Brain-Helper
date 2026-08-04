# CLAUDE.md — Daily Motivation Brain Helper

## CRITICAL: Testing Environment Requirements

**⚠️ AI AGENTS MUST READ THIS FIRST ⚠️**

This application targets **Windows 10/11** at runtime (WPF, Task Scheduler, registry, Explorer). The test suite has **two incompatible execution environments:**

1. **Windows 10/11 PowerShell 7** (PRIMARY) - Where test baselines originate
2. **Linux PowerShell 7** (SECONDARY) - For CI/platform abstraction validation only

### Test Validation Rules for AI Agents

**🚨 CRITICAL RULE: DO NOT assume test fixes are valid based solely on tests passing in a Unix/Linux environment.**

- Test baselines were created on Windows 10 with Windows-specific paths, registry operations, and Task Scheduler behavior
- Tests passing in the Linux sandbox **DO NOT** guarantee they will pass on Windows 10
- Mock behavior differs between Windows and Linux (especially for Task Scheduler, Registry, and CIM exceptions)
- Platform abstraction tests (`*.Platform.Tests.ps1`) are designed for Linux; regular tests are designed for Windows

### Required Validation Process

Before declaring any test fix "successful":

1. ✅ **MUST** verify tests pass on **Windows 10/11 PowerShell 7** (the target platform)
2. ✅ **MUST** review Windows-specific test log output (not Linux sandbox output)
3. ✅ **MUST** understand the difference between:
   - Platform tests (HeadlessPlatform injection) - run on Linux
   - Regular unit tests (Windows API mocks) - run on Windows
4. ⚠️ **DO NOT** commit changes that only work in the Linux sandbox
5. ⚠️ **DO NOT** assume mock behavior is equivalent between Windows and Linux

### Windows-Specific Test Dependencies

These tests **REQUIRE** Windows 10/11 to validate correctly:

- `TaskScheduler.Tests.ps1` - Mocks Windows Task Scheduler cmdlets (`Register-ScheduledTask`, `Get-ScheduledTask`)
- `ContextMenu.Tests.ps1` - Uses Windows registry (`HKCU:\` provider)
- Integration tests - Validate Task Scheduler integration on Windows

### Platform Abstraction Tests (Linux-Safe)

These tests CAN run on Linux with HeadlessPlatform:

- `Config.Platform.Tests.ps1`
- `TaskScheduler.Platform.Tests.ps1`
- `PlatformAdapter.Tests.ps1`
- `FolderScheduling.Tests.ps1`

**Bottom Line:** If you're working in a Linux sandbox, your test results **do not represent Windows 10/11 behavior**. Always request Windows test logs before declaring fixes complete.

---

## MANDATE: Schedule Failed / "Access is denied" Bug — Correct and Incorrect Fix Patterns

> **This section is binding on all agents and contributors.**
> The "Schedule Failed / Access is denied" dialog has been attempted to be fixed 13+ times across
> 6 waves of development (2026-06-25 → 2026-07-23) and has recurred every time. The patterns below
> are grounded in the full commit and issue history of this repository.
> **Any agent or contributor ignoring this section risks re-introducing the bug.**

### The Bug

```
Schedule Failed

Could not schedule '[PATH]'

Access is denied.
```

This dialog appears in `setfolder` mode (Explorer context-menu verb) and `main` mode (Schedule Reminder button).
The folder is accessible to the user. The failure originates inside `Register-ScheduledTask`, not filesystem ACL
validation. A secondary symptom — `Window.Dispose()` error after closing the app — is caused by calling
`.Dispose()` on a WPF `System.Windows.Window`, which does not implement `IDisposable`.

---

### WRONG APPROACHES — Do Not Repeat These

These approaches have all been tried. Each one either did not fix the bug or introduced a new regression.

#### WRONG 1: Declaring the fix verified based on Linux CI / mocked tests alone

All Pester tests run on Linux. `Register-ScheduledTask`, `New-ScheduledTaskPrincipal`, and `Get-ScheduledTask`
are fully mocked — the real Windows Task Scheduler COM object is **never invoked** in any CI test.
Tests passing in the Linux sandbox say nothing about whether `Register-ScheduledTask` will succeed on
Windows 10. Issue #10 was closed on 2026-07-23 based on code review; the bug was still present the next day.

**Rule:** Do not close or declare resolved any bug involving `Register-ScheduledTask`, task principal
configuration, or context-menu invocation without a live test on a real Windows 10/11 machine.

#### WRONG 2: Calling `.Dispose()` on a WPF `System.Windows.Window`

`System.Windows.Window` does not implement `System.IDisposable`. Calling `.Dispose()` on it throws:
```
Method invocation failed because [System.Windows.Window] does not contain a method named 'Dispose'.
```
This was HOTFIXed in commit `26b7679c` (2026-07-01) for `Show-MainWindow`, then independently
re-introduced in commit `8f4d736d` (2026-06-30) for `Show-PopupWindow`.

**Rule:** Never call `.Dispose()` on `System.Windows.Window`. Use `.Close()` instead.
For `DispatcherTimer`, `Mutex`, and `FolderBrowserDialog` — verify the object implements `IDisposable`
before calling `.Dispose()`. `DriveInfo` is a value type and is not `IDisposable`.

#### WRONG 3: Removing `$script:*` variables during cleanup without checking all call sites

Commit `adbd395f` (2026-07-02) removed `$script:ConfigDefaults` as part of a forensic bloat-removal
pass. That object is the fallback used in 3 places when config reads fail. Without it, scheduling
attempts hit a null-reference path that propagated through the Windows API chain and surfaced as
"Access is denied". This was fixed same-day in commit `97d3a650`, but only after the regression shipped.

**Rule:** Before removing any `$script:*` module-level variable, grep the entire file for every
reference. A variable with zero obvious callers in the happy path may still be a required fallback.

#### WRONG 4: Sanitizing all error messages to `[PATH]` without preserving the operation name

Commit `370d9228` (2026-07-01) replaced all folder paths in error messages with `[PATH]` for security.
This makes the user-visible dialog ambiguous — "Access is denied" can come from folder validation,
`Register-ScheduledTask`, a wrong exe path in the task action, or the Task Scheduler service being
stopped. With `[PATH]` replacing the path, the dialog gives no indication of which operation failed.

**Rule:** Error messages must always include the name of the failing operation. The path may be
sanitized to `[PATH]`, but the error must identify what failed (e.g., "OS task registration failed").
Always propagate the Windows error code alongside the sanitized message where possible.

#### WRONG 5: Using a narrow `catch` pattern that misses real Windows Task Scheduler error strings

The catch block for `Register-ScheduledTask` must not match only `'Access Denied|not have permission'`.
Real Windows Task Scheduler errors that pattern misses:

| Windows condition | Typical error string | Matched by current pattern? |
|-------------------|---------------------|-----------------------------|
| Standard access denied | "Access is denied." | Yes |
| Elevation required | "The requested operation requires elevation." | No |
| S4U logon failure | "A specified logon session does not exist." | No |
| Service unavailable | "The Task Scheduler service is not available." | No |
| File not found (bad exe path) | "The system cannot find the file specified." | No |

**Rule:** The catch block must cover the full range of Windows Task Scheduler failure modes,
or catch all terminating exceptions and inspect `$_.Exception.HResult` for known codes.

#### WRONG 6: Changing task principal configuration without a live Windows test

The `LogonType` was changed `Interactive → S4U` in commit `57df3f6c` (2026-06-30) and `RunLevel`
was changed `Highest → Limited` in commit `98a5d300` (2026-06-30). `S4U` can fail on Windows 10
with "Deny log on as a batch job" Group Policy or on Windows 10 Home. Neither change was validated
on a real Windows 10 machine before shipping.

**Rule:** Any change to `New-ScheduledTaskPrincipal` parameters (`UserId`, `LogonType`, `RunLevel`)
requires a live Windows 10/11 manual test or a `-Skip:(-not $IsWindows)` integration test that
exercises the real `Register-ScheduledTask` cmdlet with no mocking.

---

### CORRECT APPROACH — Follow This Pattern

#### CORRECT 1: Task principal configuration (current — do not change without live testing)

```powershell
New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Limited
```

- `RunLevel Limited` (not `Highest`) is correct — `Highest` requires UAC elevation and causes
  "Access is denied" for standard users.
- `S4U` is the intended logon type for per-user tasks that run without an active session.
- Do not change either of these values without a live Windows 10 test confirming the alternative works.

#### CORRECT 2: ExePath resolution for ps2exe compiled executables

ps2exe may leave `$MyInvocation.MyCommand.Path` empty at runtime. The correct resolution order is:

```powershell
$script:ExePath = if ($MyInvocation.MyCommand.Path -and $MyInvocation.MyCommand.Path -ne '') {
    $MyInvocation.MyCommand.Path
} else {
    [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
}
```

Always guard `Register-ContextMenu` to reject `.ps1` paths — the context-menu verb must point to
the compiled `.exe`, not the source script. This guard is in place; do not remove it.

#### CORRECT 3: WPF window and resource cleanup

```powershell
# CORRECT: close the window
$window.Close()

# CORRECT: dispose only objects that implement IDisposable
if ($timer  -is [System.IDisposable]) { $timer.Stop(); $timer.Dispose() }
if ($mutex  -is [System.IDisposable]) { $mutex.Dispose() }
if ($dialog -is [System.IDisposable]) { $dialog.Dispose() }

# WRONG — do not do either of these:
# $window.Dispose()     <- System.Windows.Window has no Dispose() method
# $driveInfo.Dispose()  <- DriveInfo is not IDisposable
```

Use `$obj -is [System.IDisposable]` before calling `.Dispose()` on any object whose IDisposable
status is not statically certain from the .NET type documentation.

#### CORRECT 4: Error handling around Register-ScheduledTask

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
    # Never surface a Register-ScheduledTask failure as "Invalid Folder"
    Show-ErrorDialog -Title "Schedule Failed" -Message "Could not schedule reminder for [PATH].`n`n$userMsg"
    return $false
}
```

A `Register-ScheduledTask` failure must never be shown as "Invalid Folder". Folder validation and
OS task registration are separate operations; surface them separately.

#### CORRECT 5: The Windows integration test that must exist before any scheduling fix is closed

```powershell
Describe 'New-MotivationTask - real Task Scheduler integration' {
    It 'registers and removes a task for an accessible folder without Access Denied' `
       -Skip:(-not $IsWindows) {
        $testPath = Join-Path $env:TEMP 'dmh-integration-test'
        New-Item -ItemType Directory -Path $testPath -Force | Out-Null
        try {
            $result = New-MotivationTask -FolderPath $testPath `
                                         -TriggerTime (Get-Date).AddHours(2)
            $result.Success | Should -Be $true
            $task = Get-ScheduledTask -TaskName $result.TaskName -ErrorAction SilentlyContinue
            $task | Should -Not -BeNullOrEmpty
            Remove-MotivationTask -TaskId $result.TaskId
        } finally {
            Remove-Item $testPath -Force -ErrorAction SilentlyContinue
        }
    }
}
```

This test is currently absent. It must exist and pass on Windows before any future change to the
scheduling principal configuration is declared resolved.

---

### MANDATE STATEMENT

**This mandate is binding on all AI agents, automated systems, and human contributors.**

1. **No scheduling or permissions bug may be declared resolved without live Windows 10/11 validation.**
   Linux CI passing is necessary but not sufficient for closure. Issue #10 was closed without live
   Windows validation; the bug was still present the following day.

2. **`Register-ScheduledTask` must always be wrapped in `try/catch` with `-ErrorAction Stop`.**
   The catch block must distinguish access-denied, elevation-required, service-unavailable, and
   logon-failure cases, and surface each with a user-visible message naming the failing operation —
   not the folder path.

3. **Never call `.Dispose()` on `System.Windows.Window`.** Use `.Close()`. For all other objects,
   check `$obj -is [System.IDisposable]` before calling `.Dispose()`. `DriveInfo` is not IDisposable.

4. **No `$script:*` module-level variable may be removed during cleanup without a grep of all
   references in the file.** Silent removal of fallback objects (e.g., `$script:ConfigDefaults`)
   directly causes "Access is denied" regressions by introducing null-reference paths that propagate
   into Windows API error strings.

5. **Task principal parameters (`LogonType`, `RunLevel`) are frozen at `S4U / Limited` until a live
   Windows integration test confirms any proposed alternative works.** Do not change these values
   based solely on documentation or Linux-side reasoning.

6. **Error messages must name the failing operation.** Path sanitization (`[PATH]`) is correct for
   privacy but must not replace the operation name or Windows error code. A "Schedule Failed" dialog
   must be distinguishable from an "Invalid Folder" dialog at a glance.

---

## MANDATE: Pester 5 / CI Test Infrastructure — Correct and Incorrect Patterns

> **This section is binding on all AI agents, automated systems, and human contributors.**
> The patterns below were discovered across 10 consecutive CI failures on `project-restart-pwsh7`
> (2026-08-03, issues #178 and #179). Each WRONG pattern was attempted and failed in CI before the
> root cause was confirmed. The final resolution required 7 commits.
> **Any agent ignoring this section risks reproducing the same iterative failure cycle.**

---

### WRONG APPROACHES — Do Not Repeat These

#### WRONG 7: Including `ErrorAction` in a splatted hashtable passed to a mocked cmdlet

When `ErrorAction` (or any PowerShell common parameter) is included in a `@splat` dict AND also
specified directly on the call (e.g., `-ErrorAction Stop`), Pester's mock proxy binds the parameter
twice — once from the splat and once from PowerShell's common parameter machinery. This emits a
**non-terminating error with an empty message**. `-ErrorAction Stop` promotes it to a terminating
`RuntimeException`. The caller catches it with `$_.Exception.Message = ""`, producing
`Success=$false` with `Error=""` — indistinguishable from a genuine downstream failure without
examining Pester internals.

This was the root cause of 6 CI failures diagnosed as "Save-TasksJson failure with empty exception
message." The hypothesis was wrong — `Save-TasksJson` was never reached. The failure happened at
`Register-ScheduledTask` due to the double-bind.

```powershell
# WRONG — ErrorAction in splat dict + on call = double-bind
$params = @{
    TaskName  = $taskName
    Action    = $action
    ErrorAction = 'Stop'   # <-- DO NOT include common params in splat
}
Register-ScheduledTask @params -ErrorAction Stop
```

```powershell
# CORRECT — ErrorAction on the call only, never in the splat
$params = @{
    TaskName = $taskName
    Action   = $action
}
Register-ScheduledTask @params -ErrorAction Stop
```

**Rule:** Never include `ErrorAction`, `WarningAction`, `Verbose`, `Debug`, or any other PowerShell
common parameter in a splatted hashtable. Specify them directly on the cmdlet call only.

---

#### WRONG 8: Mocking `New-ScheduledTask*` helper cmdlets with PSCustomObjects + `-RemoveParameterValidation`

`-RemoveParameterValidation` strips `[Validate*]` attributes only. It does **not** strip parameter
type constraints. `Register-ScheduledTask` has hard CIM type constraints on `Action`, `Trigger`,
`Settings`, and `Principal` — each must be a `Microsoft.Management.Infrastructure.CimInstance`.
Passing a `PSCustomObject` always fails with:

```
Cannot convert the "@{Execute=...}" value of type "System.Management.Automation.PSCustomObject"
to type "Microsoft.Management.Infrastructure.CimInstance".
```

This was attempted in both `SingleFile.Tests.ps1` and `AG20-009.ExePathSpaces.Tests.ps1` with
`-RemoveParameterValidation 'Action','Trigger','Settings','Principal'`. It failed every time.

```powershell
# WRONG — PSCustomObject never satisfies CimInstance type constraints
Mock New-ScheduledTaskAction { return [PSCustomObject]@{ Execute = $Execute } }
Mock Register-ScheduledTask -RemoveParameterValidation 'Action','Trigger','Settings','Principal' { ... }
```

```powershell
# CORRECT — let real Windows cmdlets produce genuine CimInstance objects
# Do NOT mock New-ScheduledTaskAction, New-ScheduledTaskTrigger,
# New-ScheduledTaskSettingsSet, or New-ScheduledTaskPrincipal.
# Only mock the persistence layer.
Mock Register-ScheduledTask { ... }   # captures the real CimInstance objects
Mock Get-ScheduledTask { ... }
Mock Unregister-ScheduledTask { ... }
```

**Rule:** Never mock `New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`,
`New-ScheduledTaskSettingsSet`, or `New-ScheduledTaskPrincipal`. Let them run as real Windows
cmdlets. Only mock `Register-ScheduledTask`, `Get-ScheduledTask`, and `Unregister-ScheduledTask`.
See the AG8-007 test in `SingleFile.Tests.ps1` for the canonical reference pattern.

---

#### WRONG 9: Using module-qualified calls to escape Pester mock interception

When a Pester mock for `New-ScheduledTaskAction` is active, calling
`ScheduledTasks\New-ScheduledTaskAction` (module-qualified) does **not** bypass the mock.
Pester 5 intercepts module-qualified calls too. Attempting to delegate to the real implementation
from inside a mock body via module qualification causes infinite recursion.

```powershell
# WRONG — module-qualified call is still intercepted; causes infinite recursion
Mock New-ScheduledTaskAction {
    $script:CapturedActions += ...
    return ScheduledTasks\New-ScheduledTaskAction @PSBoundParameters  # <-- infinite loop
}
```

**Rule:** There is no escape route from Pester mocking via module qualification. If you need the
real cmdlet behavior, do not mock it at all. Capture what you need from the outputs of the
persistence-layer mocks instead (e.g., inspect `$Action.Execute` inside the `Register-ScheduledTask`
mock body — the real CimInstance has those properties).

---

#### WRONG 10: Using `<token>` syntax in Pester 5 test names

Pester 5 treats `<key>` tokens in test names as `${key}` template variable expansions (used with
`-ForEach`). Under `Set-StrictMode -Version Latest`, if no `$key` variable exists in scope, Pester
throws `The variable '$key' cannot be retrieved because it has not been set` — not a test failure,
but a block-level error that aborts the entire describe block.

```powershell
# WRONG — Pester 5 tries to expand <id> as a template variable
It 'Should set task_name to DailyMotivation_<id> format' { ... }
```

```powershell
# CORRECT — no angle brackets in test names unless using -ForEach data
It 'Should set task_name to DailyMotivation_ followed by a 16-char hex id' { ... }
```

**Rule:** Never use `<word>` tokens in Pester test names unless you are using `-ForEach` and `$word`
is a key in that data source. Write out the description in plain prose instead.

---

### MANDATE STATEMENT — Pester CI Rules

**These rules are binding on all AI agents, automated systems, and human contributors.**

7. **Never include PowerShell common parameters (`ErrorAction`, `WarningAction`, `Verbose`, `Debug`, etc.)
   in a splatted hashtable passed to a mocked cmdlet.** Specify them directly on the call. The
   double-bind produces a silent non-terminating error with empty message that is promoted to a
   terminating exception by `-ErrorAction Stop`, masking the real failure site.

8. **Never mock `New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`, `New-ScheduledTaskSettingsSet`,
   or `New-ScheduledTaskPrincipal`.** These must run as real Windows cmdlets to produce the
   `CimInstance` types that `Register-ScheduledTask` requires. `-RemoveParameterValidation` does not
   override type constraints. Mock only the persistence layer: `Register-ScheduledTask`,
   `Get-ScheduledTask`, `Unregister-ScheduledTask`.

9. **Module-qualified calls (`Module\Cmdlet`) are intercepted by Pester mocks.** There is no way
   to call the real implementation from inside a Pester mock body. If the real behavior is needed,
   do not mock the cmdlet at all.

10. **Do not use `<token>` in Pester 5 test names** unless that token is a `-ForEach` data key in
    scope. Use plain prose descriptions instead.

---

## Architecture

**One file, one exe.**

```
DailyMotivation.ps1  →  Invoke-ps2exe -STA -noConsole  →  DailyMotivation.exe
```

The compiled exe is fully self-contained. No `src/`, no companion files, no setup script.

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

## Config Files (all in `%APPDATA%\DailyMotivationBrainHelper\`)

| File | Contents |
|------|----------|
| `config.json` | `{"default_trigger_hour": 14, "task_warning_threshold": 5}` |
| `popup_config.json` | Written by `main`/`setfolder` mode, read by `popup` mode |
| `tasks.json` | Scheduled task list |
| `popup_log.txt` | Pipe-delimited outcome history |

## Build

```powershell
.\build.ps1
```

Requires `ps2exe` module: `Install-Module ps2exe -Scope CurrentUser`

## Test

```powershell
.\Invoke-Tests.ps1               # all tests
.\Invoke-Tests.ps1 -CI           # CI mode (exit code, XML reports)
```

Tests dot-source the script with `-NoRun` — no exe required to run tests.

### Linux/Unix Test Environment Setup

> **Scope: Platform-abstraction tests only.** This covers `*.Platform.Tests.ps1`, `PlatformAdapter.Tests.ps1`, and `FolderScheduling.Tests.ps1`. It does **not** substitute for Windows 10/11 PowerShell 7 validation of Task Scheduler, registry, and CIM-dependent tests. See the critical warning above and [ADR-003](docs/architecture/adr-003-platform-adapter.md).

When running the platform-abstraction subset on Linux/Unix, PowerShell 7 must be installed. The following setup covers that path only:

```bash
# Detect OS and install PowerShell 7 if on Linux/Unix
if [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command -v pwsh &> /dev/null; then
        echo "Installing PowerShell 7 to $HOME/.powershell..."
        mkdir -p "$HOME/.powershell"
        cd "$HOME/.powershell"

        # Download and extract PowerShell 7
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            wget -q https://github.com/PowerShell/PowerShell/releases/download/v7.4.2/powershell-7.4.2-linux-x64.tar.gz
            tar -xzf powershell-7.4.2-linux-x64.tar.gz
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            wget -q https://github.com/PowerShell/PowerShell/releases/download/v7.4.2/powershell-7.4.2-osx-x64.tar.gz
            tar -xzf powershell-7.4.2-osx-x64.tar.gz
        fi

        # Add to PATH
        export PATH="$HOME/.powershell:$PATH"
        echo "PowerShell 7 installed successfully."
    fi
fi
```

**Note:** The platform-abstraction test subset runs on Linux. The full test suite and the app itself require Windows 10/11 (WPF, Task Scheduler, registry, Explorer context menu all require Windows).

## Key Design Constraints

- **Development/Testing**: PowerShell 7 (`pwsh`)
- **Compiled exe target**: .NET Framework 4.x (ps2exe limitation - WPF/Task Scheduler require .NET Framework)
- **Source code compatibility**: Must work when compiled to .NET Framework 4.x (avoid PowerShell 7-only features in runtime code paths)
- STA thread model required for WPF (`-STA` baked in by ps2exe)
- Popup mutex `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}` enforces one popup per user session; config writes use `Global\DailyMotivationPopupConfigLock`
- Task Scheduler action calls `$script:ExePath /popup` (captured at runtime via `$MyInvocation.MyCommand.Path`)
- Tests override `$script:ExePath` before calling `New-MotivationTask`
- `Initialize-AppData` re-resolves all paths from `$env:APPDATA` at call time (enables test redirects)
- `Get-TasksJson` wraps result in `@()` for consistent array handling; valid statuses: PENDING, DELETED, COMPLETED, FAILED
- Outcome log stores SHA-256 path hashes, not plaintext paths

## Code Quality Rules

### No Startup Popups
**CRITICAL:** DailyMotivation.exe must NEVER display a popup message on startup in main mode. The application should launch directly into the main window UI without any blocking dialogs, confirmation prompts, or informational messages. Startup popups degrade user experience and violate the principle of instant usability.

### Comment Hygiene
Remove bloat comments that reference bug IDs (e.g., `# AG19-003:`, `# AG7-004:`). Keep only comments that explain **why** code exists or **what** non-obvious behavior is expected. Bug tracking belongs in commit history and bug reports, not inline comments.

## Documentation map

| Doc | Purpose |
|-----|---------|
| [README.md](README.md) | Product overview |
| [CONTEXT.md](CONTEXT.md) | Domain language (authoritative terminology) |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [docs/](docs/README.md) | Developer documentation |
| [manual/](manual/README.md) | End-user documentation |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting |

External requirements / NFR source of truth (if present outside the repo):
`DailyMotivationBrainHelper_TechnicalReflection_2026-06-12_v2_1_CORRECTED.md`.
In-repo architecture notes live under [docs/architecture/](docs/architecture/README.md).
