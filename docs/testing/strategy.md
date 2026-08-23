# Test strategy

## Environments

| Environment | Role |
|-------------|------|
| **Windows 10/11 + PowerShell 7** | **Primary.** Source of truth for all Task Scheduler, registry, WPF, and CIM-dependent tests. |
| **Linux PowerShell 7** | Secondary. Platform-abstraction, static-analysis, and source-text tests only. |

Running the full test suite on Linux and observing a green result does **not** tell you whether Windows-specific behavior is correct. The sections below enumerate precisely which tests skip on Linux, which Windows APIs each test exercises, and what the mocked tests are structurally incapable of proving.

---

## Runner

```powershell
.\Invoke-Tests.ps1                  # all tests; coverage on by default
.\Invoke-Tests.ps1 -CI              # exit on failure; NUnit TestResults.xml
.\Invoke-Tests.ps1 -Tag Security    # run only tests tagged Security
.\Invoke-Tests.ps1 -ExcludeTag Slow # exclude tests tagged Slow (none currently tagged)
.\Invoke-Tests.ps1 -Coverage $false # skip JaCoCo coverage report
```

`Invoke-Tests.ps1` parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Tag` | `string[]` | — | Include only Pester tests with these tags |
| `-ExcludeTag` | `string[]` | — | Exclude tests with these tags |
| `-CI` | switch | off | Set `Run.Exit = $true`; write `TestResults.xml` (NUnit format) |
| `-Coverage` | `bool` | `$true` | Write `coverage.xml` (JaCoCo) for `DailyMotivation.ps1` |

**Note:** `Invoke-Tests.ps1` carries `#Requires -Version 5.1`. This allows the file to load in PowerShell 5, but the project requires PowerShell 7 (`pwsh`). Running under PowerShell 5 will produce misleading results. Always invoke with `pwsh .\Invoke-Tests.ps1`.

---

## Loading the app under test

Every suite that needs functions uses:

```powershell
. .\DailyMotivation.ps1 -NoRun
```

`-NoRun` defines all functions and script-level variables but skips the entry-point `switch ($Mode)` block. No window opens, no Task Scheduler is contacted, no UI is spawned.

---

## Complete test file inventory

| File | Platform | Skip mechanism |
|------|----------|----------------|
| `Tests/Unit/TaskScheduler.Tests.ps1` | **Windows only** | `BeforeAll` returns if `-not $IsWindows`; all `Describe` blocks carry `-Skip:(-not $IsWindows)` |
| `Tests/Unit/SyncTaskStatuses.Tests.ps1` | **Windows only** | Same pattern |
| `Tests/Unit/Security.Tests.ps1` | **Windows only** | Same pattern |
| `Tests/Unit/InputValidation.Tests.ps1` | **Partially Windows** | `AG2-001` and `AG2-004` Describes carry `-Skip:(-not $IsWindows)` |
| `Tests/Unit/ContextMenu.Tests.ps1` | **Partially Windows** | Two specific `It` blocks carry `-Skip:(-not $IsWindows)`; remainder uses platform-aware branching with registry mocks on Linux |
| `Tests/Unit/Config.Tests.ps1` | **Partially Windows** | Three fallback-directory `It` blocks carry `-Skip:(-not $IsWindows)` (require `$env:SystemRoot`) |
| `Tests/Unit/FolderScheduling.Tests.ps1` | **Partially Windows** | Two `It` blocks carry `-Skip:(-not $IsWindows)`; one carries `-Skip:($IsWindows)` |
| `Tests/Integration/SingleFile.Tests.ps1` | **Partially Windows** | `Mode switching` `It` block and `Integration scenario` `Describe` carry `-Skip:(-not $IsWindows)` |
| `Tests/Unit/Config.AG7-023.Tests.ps1` | Both | — |
| `Tests/Unit/Config.Platform.Tests.ps1` | Both — HeadlessPlatform | — |
| `Tests/Unit/TaskScheduler.Platform.Tests.ps1` | Both — HeadlessPlatform | — |
| `Tests/Unit/PlatformAdapter.Tests.ps1` | Both — HeadlessPlatform | — |
| `Tests/Unit/Messages.Tests.ps1` | Both | — |
| `Tests/Unit/PopupDisplay.Tests.ps1` | Both | — |
| `Tests/Unit/UIDisposal.Tests.ps1` | Both — source-text analysis | — |
| `Tests/Unit/Performance.Tests.ps1` | Both — source-text analysis | — |
| `Tests/Unit/AG17-002.ContextMenuVerification.Tests.ps1` | Both — source-text analysis | — |
| `Tests/Unit/AG17-009.UndoFeedbackTimer.Tests.ps1` | Both — source-text analysis | — |
| `Tests/Unit/AG17-025.ContextMenuNullCheck.Tests.ps1` | Both — source-text analysis | — |
| `Tests/Unit/AG19-010.TabOrder.Tests.ps1` | Both — source-text analysis | — |
| `Tests/Unit/Build.Tests.ps1` | Both — reads `build.ps1` | — |
| `Tests/Unit/CI.Tests.ps1` | Both — reads `.github/workflows/test.yml` | — |
| `Tests/Unit/PowerShellBestPractices.Tests.ps1` | Both | — |

**Source-text analysis tests** read `DailyMotivation.ps1` as a raw string and use regex to assert structural properties (presence of disposal calls, null guards, XAML attributes, etc.). They run on any platform but they can only verify that a code pattern exists in the source — they cannot verify that the pattern executes correctly at runtime.

---

## Windows-required tests: explicit enumeration

The following tests are skipped or degenerate on Linux. Each entry states the specific Windows API exercised and why a mock cannot substitute.

### `TaskScheduler.Tests.ps1` — skips entirely on Linux

| Test area | Windows API exercised | Why mock is insufficient |
|-----------|----------------------|--------------------------|
| `New-MotivationTask` happy path | `Register-ScheduledTask`, `New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`, `New-ScheduledTaskSettingsSet`, `New-ScheduledTaskPrincipal` | Mock returns `$null`; real cmdlet returns a `CimInstance` (MSFT_ScheduledTask). Code that inspects the return object will see different behavior. |
| Task principal validation | `New-ScheduledTaskPrincipal -LogonType S4U -RunLevel Limited` | Mock accepts any object. Real cmdlet enforces CimInstance type validation on all parameters. S4U logon availability depends on Windows edition and Group Policy; a mock cannot reproduce this. |
| Error path dispatch | `Register-ScheduledTask` throws | Mock throws a bare `string`. Real cmdlet throws with a populated `$_.Exception.HResult`. The catch block dispatches on HResult values (`0x80070005`, `0x80041315`, `0x8007052e`, `0x80070002`). Mock tests exercise only the `default` branch of that switch. |
| `Get-ScheduledTask` "not found" exception | `CimJobException` | Mock on line 108 of the test file constructs a `CimJobException` — this type is Windows-only (part of the CIM infrastructure). This is exactly why the whole file skips on Linux: instantiating `CimJobException` fails on Linux. |
| Task name collision detection | `Get-ScheduledTask` per-name lookup | Mock returns a stored hashtable entry. Real cmdlet queries the Windows Task Scheduler COM object; timing, service state, and scheduler database locking are not simulated. |
| `New-ScheduledTaskAction` exe-path validation | Real cmdlet | Real cmdlet validates the `Execute` path against the filesystem at registration time. Mock always succeeds regardless of path. |
| Post-registration existence check | `Get-ScheduledTask -TaskName $TaskName` after `Register-ScheduledTask` | Mock returns whatever was stored. Real scheduler may report success from `Register-ScheduledTask` yet return nothing from `Get-ScheduledTask` due to service timing. This specific race is what the MANDATE section documents as unresolved. |

### `SyncTaskStatuses.Tests.ps1` — skips entirely on Linux

| Test area | Windows API exercised | Why mock is insufficient |
|-----------|----------------------|--------------------------|
| Direction 1: PENDING task gone from OS | `Get-ScheduledTask` throws on missing task | Mock throws `System.Exception("cannot find the file specified.")`. Real cmdlet throws `CimJobException`. If the catch block is type-specific, these behave differently. |
| Direction 2: orphan recovery | `Get-ScheduledTask -TaskName "DailyMotivation_*"` | Mock returns objects with a synthetic `Description` field (`"Daily Motivation Brain Helper - C:\OrphanFolder"`). Real task objects have this field populated by whatever string was passed to `Register-ScheduledTask -Description`. Format differences cause silent parse failures. |
| Orphan trigger parsing | Task object `.Triggers[0].StartBoundary` | Mock provides an unqualified ISO string. Real Windows stores timezone-qualified strings (e.g., `"2026-08-10T14:00:00+00:00"`). Code that calls `[DateTime]::Parse()` behaves differently depending on whether a timezone offset is present. |

### `Security.Tests.ps1` — skips entirely on Linux

| Test area | Windows API exercised | Why mock is insufficient |
|-----------|----------------------|--------------------------|
| AG10-001: path injection in registry | `HKCU:\Software\Classes\Directory\shell\ScheduleMotivation\command` — real write and read | Linux has no HKCU provider. The test verifies the actual stored registry value format, which is not reproducible with a mock. |
| AG10-003: path traversal rejection | `New-MotivationTask` with traversal paths, full Task Scheduler mock chain | Requires the Windows Task Scheduler cmdlet mock chain setup done in `BeforeAll` which returns early on Linux. |
| AG10-004: RunLevel not elevated for network paths | `Register-ScheduledTask` with `New-ScheduledTaskPrincipal` | Requires the Windows mock chain. The test reads back `$taskObj.Principal.RunLevel` from the mock; on real Windows the principal object is a CimInstance with different property semantics. |
| AG10-006: unique fallback AppData | `Initialize-AppData` with `$env:SystemRoot` pointing at an unwritable path | `$env:SystemRoot` does not exist on Linux. The test cannot be constructed. |
| AG10-011: file permissions | `Get-Acl -Path $script:AppDataDir` | `Get-Acl` is Windows-only. |
| AG10-022: collision retry exhaustion | Full Task Scheduler mock chain | Same as AG10-003 above. |

### `ContextMenu.Tests.ps1` — specific tests skip on Linux

| Test | Windows API exercised | Why mock is insufficient |
|------|----------------------|--------------------------|
| `Should skip registration and not write to registry when ExePath is a .ps1 file` | `Test-Path HKCU:\...\ScheduleMotivation` after call | Verifies the real registry key was NOT created. A mock that stubs `Test-Path` for `HKCU:` paths can only return what the mock is told to return; it cannot confirm real registry absence. |
| `Should skip registration and not throw when ExePath is empty` | Same | Same. |
| `Should not throw when called multiple times (idempotent)` — Windows branch | `Get-ChildItem -Path $script:VerbKey` counting real subkeys | Real subkey count. Mock on Linux returns a hard-coded list. |

### `Config.Tests.ps1` — specific tests skip on Linux

| Test | Windows API exercised | Why mock is insufficient |
|------|----------------------|--------------------------|
| `Should set AppDataDir to a path under TempDir when APPDATA creation fails` | `$env:SystemRoot` — points to `C:\Windows\System32\...` | `$env:SystemRoot` is undefined on Linux; the test cannot construct the required precondition. |
| `Should set all path vars under the fallback dir when APPDATA creation fails` | Same | Same. |
| `Should create config files under the fallback dir when APPDATA creation fails` | Same | Same. |

### `InputValidation.Tests.ps1` — AG2-001 and AG2-004 Describes skip on Linux

These Describes require the Windows Task Scheduler mock chain (set up only when `$IsWindows` is true in `BeforeAll`). Without the mocks, calling `New-MotivationTask` with null or empty `FolderPath` on Linux would reach the real (absent) Task Scheduler cmdlets and throw a different error than the one being tested.

### `FolderScheduling.Tests.ps1` — partially Windows

| Test | Skip condition | Windows API / reason |
|------|---------------|----------------------|
| `Should handle Windows drive letters as local paths` | `-Skip:(-not $IsWindows)` | Asserts `C:\Projects\MyFolder` is a valid path; path existence checks on Windows differ from Linux. |
| `Should detect mapped network drives on Windows` | `-Skip:(-not $IsWindows)` | Assumes `Z:\SharedFolder` may be a mapped drive; behavior depends on real Windows drive table. |
| `Should handle Unix paths on Linux` | `-Skip:($IsWindows)` | Tests `/home/user/documents` as a valid path; not meaningful on Windows. |

### `SingleFile.Tests.ps1` — Integration Describes skip on Linux

`Should verify tasks.json persists across mode switches` and the entire `Integration scenario - Full lifecycle` Describe require the Windows Task Scheduler mock chain. These are integration tests that exercise the full create→list→remove cycle; the cycle calls `Register-ScheduledTask` which is mocked only on Windows.

---

## What mocked tests structurally cannot validate

This is the class of Windows behavior that no amount of additional unit tests can cover — only live Windows 10/11 testing validates these.

### 1. Real `Register-ScheduledTask` success and failure on the host OS

The mock always returns `$null` on success and throws a bare string on failure. The real cmdlet:

- Returns a `CimInstance` whose properties code may inspect
- Throws with `$_.Exception.HResult` set to a specific NTSTATUS or Win32 error code. The catch block in `New-MotivationTask` dispatches on regex patterns matching HResult-derived strings. The mock exercises only the `default` branch.
- Fails with `0x80041315` ("Task Scheduler service is not available") if the service is stopped — this condition cannot be simulated with Pester mocks
- Fails with S4U logon errors (`0x8007052e`) on machines with "Deny log on as a batch job" Group Policy applied
- Silently succeeds from the cmdlet's return value while leaving the task in a broken state (e.g., the exe path does not exist at the time the task fires)

### 2. Post-registration task existence

`New-MotivationTask` calls `Get-ScheduledTask -TaskName $TaskName` immediately after `Register-ScheduledTask` to confirm the task was persisted. The mock always returns the task if it was registered in the mock's hashtable. The real Task Scheduler has a small but non-zero window in which the registration completes but the task is not yet queryable. The CLAUDE.md MANDATE documents an incident (Issue #10, 2026-07-23) where this discrepancy caused a closed bug to reopen the next day.

### 3. Task principal behavior on real Windows editions

`New-ScheduledTaskPrincipal -LogonType S4U -RunLevel Limited` is the frozen configuration per the MANDATE. On real Windows:

- **Windows 10 Home**: S4U may be blocked by default Group Policy configuration
- **Windows 10/11 Pro/Enterprise**: S4U functions as expected but requires the Task Scheduler service to be running
- **`RunLevel Highest`** (previously used, now prohibited by MANDATE): requires UAC elevation and fails for standard users — this failure surface is invisible to any mock

None of these platform-edition differences can be reproduced with mocks. Live Windows validation with a standard (non-admin) user account is the only valid confirmation.

### 4. Compiled exe path availability at task fire time

`New-MotivationTask` sets `$script:ExePath` in tests to `"C:\Test\DailyMotivation.exe"`. The real cmdlet (`New-ScheduledTaskAction -Execute $script:ExePath`) does not validate path existence at registration time on all Windows editions. The task fires silently and fails at runtime if the exe is missing or the path changed. This class of failure (task registered, task fires, task fails) is entirely outside the mock surface.

### 5. Real HKCU registry key creation for context menu

`Register-ContextMenu` writes to `HKCU:\Software\Classes\Directory\shell\ScheduleMotivation`. On Windows:

- The actual right-click verb appears in Explorer only if the key structure (`shell\verb\command`) is correctly formed
- Registry key ACLs are inherited from the parent; the test does not verify ACLs
- `Register-ContextMenu` verifies key existence with `Test-Path` after writing — this is only meaningful against a real registry, not a mock

### 6. CIM exception type handling

`TaskScheduler.Tests.ps1` constructs `[Microsoft.PowerShell.Cmdletization.Cim.CimJobException]` to simulate "task not found". This type only exists on Windows (it is part of the CIM infrastructure). On Linux, this line throws an exception about the type not being found, which is the exact reason the entire file skips. Any catch block that is type-specific on `CimJobException` cannot be tested from Linux at all.

### 7. Missing Windows integration test (MANDATE requirement)

**The following test does not exist in the test suite and must be added before any change to the task principal configuration can be declared resolved:**

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

This test is absent. See the MANDATE section of [CLAUDE.md](../../CLAUDE.md).

---

## Platform-safe tests

The following tests run on both Windows and Linux without platform-specific conditions.

**HeadlessPlatform tests** inject `[HeadlessPlatform]::new()` into `$script:Platform`. All scheduling, dialog, and folder-open calls route through the adapter, which:

- Returns `headless-mock-{guid}` task IDs from `ScheduleTask()`
- Does nothing from `UnscheduleTask()`, `OpenFolder()`, `RegisterContextMenu()`
- Returns `"OK"` from `ShowDialog()`
- Returns a temp-path-based app data path from `GetAppDataPath()`

These tests validate the JSON-persistence layer, duplicate detection, and business logic without touching any Windows API.

**Source-text analysis tests** load `DailyMotivation.ps1` as a raw string and use regex to assert structural properties. They run on any platform but verify only that a pattern exists in source — not that the pattern behaves correctly at runtime.

| Category | Files |
|----------|-------|
| HeadlessPlatform | `Config.Platform.Tests.ps1`, `TaskScheduler.Platform.Tests.ps1`, `PlatformAdapter.Tests.ps1`, `FolderScheduling.Tests.ps1` (partial) |
| Pure logic / file I/O | `Config.Tests.ps1` (partial), `Config.AG7-023.Tests.ps1`, `Messages.Tests.ps1`, `PopupDisplay.Tests.ps1`, `PowerShellBestPractices.Tests.ps1` |
| Source-text analysis | `UIDisposal.Tests.ps1`, `Performance.Tests.ps1`, `AG17-002.ContextMenuVerification.Tests.ps1`, `AG17-009.UndoFeedbackTimer.Tests.ps1`, `AG17-025.ContextMenuNullCheck.Tests.ps1`, `AG19-010.TabOrder.Tests.ps1` |
| Build / CI artifact | `Build.Tests.ps1`, `CI.Tests.ps1` |

---

## Platform adapter

When `$script:Platform` is set to a non-null object, `New-MotivationTask`, `Remove-MotivationTask`, `Invoke-FolderScheduling`, and `Show-PopupWindow` route their OS calls through the adapter instead of invoking Windows cmdlets directly. Production code leaves `$script:Platform = $null`.

See [ADR-003](../architecture/adr-003-platform-adapter.md).

---

## Pester tags in use

| Tag | Used in |
|-----|---------|
| `Unit` | `TaskScheduler.Platform.Tests.ps1`, `FolderScheduling.Tests.ps1`, `PlatformAdapter.Tests.ps1` |
| `TaskScheduler` | `TaskScheduler.Platform.Tests.ps1` |
| `Platform` | `TaskScheduler.Platform.Tests.ps1`, `Config.Platform.Tests.ps1`, `PlatformAdapter.Tests.ps1` |
| `BusinessLogic` | `FolderScheduling.Tests.ps1` |
| `Config` | `Config.Platform.Tests.ps1` |
| `Security` | Not currently applied in any test file (referenced in runner examples only) |
| `Slow` | Not currently applied in any test file (referenced in runner examples only) |
| `AG9-001`, `HIGH` | `PowerShellBestPractices.Tests.ps1` |

---

## Coverage goals

Coverage is collected for `DailyMotivation.ps1` and output as `coverage.xml` (JaCoCo format). Coverage percentage is a signal for finding untested code paths — it is not a substitute for Windows behavioral tests. A line covered on Linux through a HeadlessPlatform mock does not mean the equivalent Windows code path has been validated.

---

## Pester version

**Pester 5.x required.** File-scoped `BeforeAll` mocks, `-ForEach` on `It`, and `New-PesterConfiguration` are v5 features. Pester 4 is not supported and will produce incorrect results.

---

## Known test defects

### `UIDisposal.Tests.ps1` — AG6-004 / BUG-2 ✓ resolved

**Fixed in commit `e0e0da6`** ("fix(ui): close WPF windows without Dispose; switch task LogonType to Interactive").

The incorrect `AG6-004: Window Disposal After ShowDialog` Describe block (which asserted `$window.Dispose()` must exist) was removed. It was replaced by two `BUG-2` regression-guard Describes that correctly assert:

- `$window.Dispose()` must **not** exist in `Show-MainWindow` or `Show-PopupWindow` — `System.Windows.Window` does not implement `IDisposable`.
- `$window.Close()` must be present in both functions.
- A file-wide guard: zero calls to `$window.Dispose()` anywhere in `DailyMotivation.ps1`.

The source code uses `$window.Close()` throughout. No further action required.
