# CLAUDE.md — Daily Motivation Brain Helper

## CRITICAL: Testing Environment

This app targets **Windows 10/11** (WPF, Task Scheduler, registry). Tests run in two incompatible environments:

| Environment | Valid for |
|-------------|-----------|
| Windows 10/11 PowerShell 7 | All tests — PRIMARY |
| Linux PowerShell 7 | Platform-abstraction tests only |

**Linux-safe** (HeadlessPlatform injection): `Config.Platform.Tests.ps1`, `TaskScheduler.Platform.Tests.ps1`, `PlatformAdapter.Tests.ps1`, `FolderScheduling.Tests.ps1`

**Windows-only**: `TaskScheduler.Tests.ps1`, real-cmdlet integration tests in `Tests/Integration/`

**Tests passing in Linux do not validate Windows behavior.** Always get Windows test output before declaring any fix complete.

---

## MANDATE: Schedule Failed / "Access is denied"

> Binding on all agents and contributors. See [ADR-005](docs/architecture/adr-005-mandate-history.md) for incident history.
> WPF and resource cleanup rules: `.claude/rules/dailymotivation-script.md` (loads when editing `DailyMotivation.ps1`)
> Pester mock rules: `.claude/rules/pester-tests.md` (loads when editing `Tests/**/*.ps1`)

### WRONG 1 — Fix declared verified from Linux CI or mocked tests alone

**Rule:** Never close or declare resolved any bug involving `Register-ScheduledTask`, task principal configuration, or context-menu invocation without a live test on a real Windows 10/11 machine.

**Exception:** `Tests/Integration/TaskScheduler.Real.Integration.Tests.ps1` uses real cmdlets (no mocks), is `-Skip:(-not $IsWindows)`, and is the mandated gate test.

### WRONG 4 — Error messages sanitized to `[PATH]` without naming the operation

**Rule:** Path sanitization to `[PATH]` is correct for privacy. Every error message must also name the failing operation (e.g., "OS task registration failed") and include the Windows error code where possible.

### WRONG 5 — Narrow `catch` pattern missing real Task Scheduler errors

| Windows condition | Error string |
|---|---|
| Standard access denied | "Access is denied." |
| Elevation required | "The requested operation requires elevation." |
| S4U logon failure | "A specified logon session does not exist." |
| Service unavailable | "The Task Scheduler service is not available." |
| Bad exe path | "The system cannot find the file specified." |

**Rule:** Cover all five cases in the `catch` block using `switch -Regex` on `$_.Exception.Message` + `$_.Exception.HResult` for the default. A `Register-ScheduledTask` failure must never surface as "Invalid Folder".

**Open violation:** Current `New-MotivationTask` catch block (~line 801) handles only `already exists` and `Access Denied|not have permission` — four cases are unhandled.

### WRONG 6 — Task principal configuration changed without a live Windows test

**Rule:** Any change to `New-ScheduledTaskPrincipal` parameters (`UserId`, `LogonType`, `RunLevel`) requires a live Windows 10/11 test or a `-Skip:(-not $IsWindows)` integration test against the real `Register-ScheduledTask`.

### CORRECT 1 — Task principal (validated — do not change without live Windows test)

```powershell
New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
```

`LogonType Interactive` — required so the popup fires on the user's active desktop. `S4U` fails with "Access is denied" for non-elevated users and cannot host UI (session-less). `RunLevel Limited` — `Highest` requires elevation. See [ADR-005](docs/architecture/adr-005-mandate-history.md).

---

## MANDATE: Pester 5 / CI

> Binding on all agents. Full rules load automatically when editing `Tests/**/*.ps1` from `.claude/rules/pester-tests.md`.

- **WRONG 7:** Never put common params (`ErrorAction`, etc.) in a splatted hashtable passed to a mock — double-bind produces a silent terminating exception masking the real failure
- **WRONG 8:** Never mock `New-ScheduledTaskAction/Trigger/Settings/Principal` — only mock `Register/Get/Unregister-ScheduledTask`; `PSCustomObject` fails CimInstance type constraints
- **WRONG 9:** Module-qualified calls (`ScheduledTasks\Cmdlet`) don't escape Pester — causes infinite recursion
- **WRONG 10:** No `<token>` in test names unless a `-ForEach` data key — aborts describe block under `Set-StrictMode -Version Latest`

---

## MANDATE: GitHub Issue Closure Gate

> Binding on all agents and contributors. See [ADR-005](docs/architecture/adr-005-mandate-history.md).

**Any issue whose resolution includes `-Skip:(-not $IsWindows)` tests may not be closed until a passing Windows 10/11 run is posted as an issue comment.**

Accepted proof: full `.\Invoke-Tests.ps1` terminal output from Windows PS7, a CI Windows runner link, or a screenshot — showing 0 failures for the affected tests. Linux CI, code review, or platform-abstraction-only results do not count.

If closed prematurely: reopen, comment which tests are unvalidated, do not re-close until proof is attached.

---

## Build & Test

```powershell
.\build.ps1                         # requires: Install-Module ps2exe -Scope CurrentUser
.\Invoke-Tests.ps1                  # all tests
.\Invoke-Tests.ps1 -CI              # CI mode: exit code + XML + JaCoCo
.\Invoke-Tests.ps1 -Tag Integration # integration tests only
.\Invoke-Tests.ps1 -Coverage $false # skip JaCoCo (faster)
```

Pester 5.x required: `Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck`

Tests dot-source `DailyMotivation.ps1 -NoRun` — no exe required. CI runs on `windows-latest`; PS7-syntax gate blocks `??`, `?.`, `Join-String`, `ForEach-Object -Parallel` in runtime code paths.

## Key Design Constraints

- `/popup` and `/setfolder` switch cases require **leading slashes** — `$Mode -eq "/popup"` not `"popup"`
- `$script:ExePath` is `$null` under `-NoRun`; tests must assign it before calling `New-MotivationTask`
- `Initialize-AppData` re-resolves all paths from `$env:APPDATA` at call time — enables test redirects
- Valid task statuses: `PENDING`, `DELETED`, `COMPLETED`, `FAILED`; unrecognised values normalise to `UNKNOWN`
- `Get-MotivationTasks` is plural — `Get-MotivationTask` (singular) throws `CommandNotFoundException`
- Outcome log stores SHA-256 path hashes (`HASH:{hex}`), not plaintext paths

## Code Quality

**No Startup Popups:** No dialog/prompt on startup in `main` mode on the non-error path.

**Comment Hygiene:** Remove `# AG*-*` bug-ID comments. Keep only comments explaining *why* code exists or *what* non-obvious behavior does.
