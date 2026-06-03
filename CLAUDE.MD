# CLAUDE.md — Daily Motivation Brain Helper

> Agent orientation file. Read this before touching any code.

---

## What This Project Is

A Windows desktop app that lets a non-technical user:
1. Select a folder via GUI (or drag-and-drop)
2. Schedule it to open automatically at 2 PM (today or tomorrow)
3. Receive a motivational WPF popup at that time — snooze, dismiss, or open the folder

**The north star constraint:** the user never edits a JSON file, a script, or any config.
All state is managed through the UI. See `docs/SSOT.md` and `docs/NPR.md` for hard rules.

**Distribution target:** single `.exe` via PS2EXE-NG. Run `build.ps1` from the project root.

---

## Repository Layout

```
Daily-Motivation-Brain-Helper/
├── CLAUDE.md                   ← you are here
├── build.ps1                   ← PS2EXE build script; outputs to src\DailyMotivation.exe
├── CLAUDE/skills/              ← agent skills (see ## Agent Skills below)
├── docs/                       ← all planning, specs, and architecture docs
└── src/
    ├── MainApp.ps1             ← WPF entry point; run with -STA
    ├── MainWindow.xaml         ← all UI layout; no code-behind file — handlers in MainApp.ps1
    ├── DailyMotivation.ps1     ← popup engine; fired by Task Scheduler via LaunchMotivation.bat
    ├── LaunchMotivation.bat    ← Task Scheduler action wrapper
    ├── UpdateScheduledTask.ps1 ← one-time setup; run as Admin
    ├── popup_config.json       ← active task config (written by app, read by popup)
    ├── data/
    │   └── messages.json       ← 10 default motivational messages; never user-edited
    ├── Modules/
    │   ├── ConfigManager.psm1  ← all JSON I/O: settings, tasks, log, popup config
    │   └── TaskScheduler.psm1  ← Windows Task Scheduler wrapper
    └── ShellExtension/         ← optional COM DLL (Sprint 4; not required for core loop)
        ├── MotivationShellExt.cs
        ├── Register-ShellExtension.ps1
        └── ShellBridge.ps1
```

---

## Module Map and Responsibilities

| Module | What it owns | Key exports |
|--------|-------------|-------------|
| `ConfigManager.psm1` | All JSON reads/writes; `%APPDATA%` init; log parsing | `Initialize-AppData`, `Set-PopupConfig`, `Get-OutcomeLog`, `Set-LastFolder`, `Add-RecentFolder`, `Show-ErrorDialog` |
| `TaskScheduler.psm1` | Windows Task Scheduler CRUD; duplicate detection; network-path detection | `New-MotivationTask`, `Get-MotivationTasks`, `Remove-MotivationTask`, `Update-MotivationTaskStatus` |
| `MainApp.ps1` | WPF window lifecycle; all button event handlers; undo timer; welcome overlay | entry point |
| `DailyMotivation.ps1` | Popup display; countdown; snooze re-trigger; path validation; mutex | entry point |
| `ShellBridge.ps1` | Thin CLI wrapper called by COM DLL; delegates to `New-MotivationTask` | standalone script |

**Dependency direction:** `MainApp.ps1` → imports both modules.
`DailyMotivation.ps1` → imports both modules (via `$script:ModulesPath`).
`ShellBridge.ps1` → imports both modules.
The modules do not import each other.

---

## Config File Locations (all under `%APPDATA%\DailyMotivationBrainHelper\`)

| File | Purpose |
|------|---------|
| `popup_config.json` | Active task: glyph, title, body, explorer_path, folder_name, task_id |
| `tasks.json` | All scheduled task records (source of truth alongside Windows Task Scheduler) |
| `app_settings.json` | firstRun flag, lastFolder path, recentFolders[] array, theme |
| `messages.json` | Message library (copied from `src/data/messages.json` on first run) |
| `popup_log.txt` | Pipe-delimited outcome log: `[timestamp] | task_id | folder_name | path | outcome | snooze_count` |

**Log files for debugging:**

| File | Purpose |
|------|---------|
| `%TEMP%\DailyMotivation_debug.log` | Popup script trace |
| `%APPDATA%\DailyMotivationBrainHelper\launch_log.txt` | BAT launcher trace |

---

## Domain Glossary

These terms are used throughout specs and code. Use them exactly.

| Term | Meaning |
|------|---------|
| **Scheduled Task** | A Windows Task Scheduler entry that fires the popup at a specific time |
| **Popup** | The WPF notification window (`DailyMotivation.ps1`) |
| **Snooze** | Dismiss popup temporarily; re-trigger via a new scheduled task after selected duration |
| **Dismiss for Today** | Terminal action (SSOT-009): cancels all pending snooze re-triggers; folder is NOT opened |
| **Accept / Open Folder** | The action that completes a task; calls `explorer.exe`; logs `outcome=Opened` |
| **Undo Window** | 30-second grace period after scheduling; clicking Undo calls `Remove-MotivationTask` |
| **Folder Name** | Leaf of the path (`Split-Path -Leaf`); shown in popup subtitle (B-12) |
| **Explorer Launcher** | `Start-Process explorer.exe -ArgumentList $path` |
| **Snooze Loop** | popup → snooze task → reappear; repeats indefinitely (SSOT-008) |
| **Task Completion** | `outcome=Opened` after user clicks Open Folder |
| **History Viewer** | In-app panel that parses `popup_log.txt` and renders outcomes |
| **Recent Folders** | `recentFolders[]` in `app_settings.json`; max 5 entries, FIFO, newest first |
| **Shell Extension** | Optional COM DLL (B-13); adds right-click menu item to Explorer |

---

## Key Constraints (SSOT Rules)

Never violate these — they are architectural invariants:

- **SSOT-006** — Only one popup on screen at a time. Enforced by named mutex `Global\DailyMotivationBrainHelperPopup`.
- **SSOT-007** — The user never edits config files. All writes go through `ConfigManager.psm1`.
- **SSOT-008** — Snooze loop has no maximum count. It repeats until Accept or Dismiss for Today.
- **SSOT-009** — `Dismissed` is terminal. A dismissed task never re-triggers.
- **NPR-001** — No JSON/script/config editing required from the user at any point.
- **NPR-005** — Fully offline. Zero network calls.

---

## How to Run

**Main application (developer):**
```powershell
powershell.exe -STA -ExecutionPolicy Bypass -File "src\MainApp.ps1"
```

**Popup only (as Task Scheduler would call it):**
```powershell
# Via bat wrapper (preferred — matches production path):
.\src\LaunchMotivation.bat

# Direct (dev/debug):
powershell.exe -STA -ExecutionPolicy Bypass -File "src\DailyMotivation.ps1"
```

**Build EXE:**
```powershell
# Prereq: Install-Module -Name ps2exe -Scope CurrentUser
.\build.ps1
# Output: src\DailyMotivation.exe
```

**First-time setup (one-time, as Admin):**
```powershell
# Right-click -> Run as Administrator:
.\src\UpdateScheduledTask.ps1
```

---

## Critical Gotchas

These are the highest-value lessons from `docs/FORENSIC_REVIEW.md`. Don't repeat them.

### 1. WPF requires `-STA` — always
Every PowerShell invocation that loads WPF must include `-STA`. Without it, WPF crashes with
"The calling thread must be STA." The BAT wrapper already passes `-STA`; if you add any new
launcher, add it there too.

### 2. `$PSScriptRoot` is unreliable inside WPF event handlers
WPF dispatcher callbacks run on a different context. Always capture at the top of the script:
```powershell
$script:ModulesPath = Join-Path $PSScriptRoot "Modules"
```
Then use `$script:ModulesPath` inside all `Add_Click` and timer handlers.

### 3. PowerShell 5.1: `ConvertFrom-Json "[]"` returns `$null`, not `@()`
Always guard after deserialising tasks.json:
```powershell
$result = $raw | ConvertFrom-Json
if ($null -eq $result) { return @() }
return @($result)
```

### 4. `LauncherPath` must point to the app install dir, NOT `%APPDATA%`
`LaunchMotivation.bat` lives beside the scripts. `TaskScheduler.psm1` resolves it with:
```powershell
$script:LauncherPath = Join-Path (Split-Path $PSScriptRoot -Parent) "LaunchMotivation.bat"
```
Never hardcode `%APPDATA%` for the launcher.

### 5. All `Set-Content` and `Add-Content` calls must specify `-Encoding UTF8`
Omitting it causes silent corruption of paths with accented/non-ASCII characters on
non-English Windows installs. No exceptions.

### 6. ASCII-only in PowerShell `.ps1` and `.psm1` files
No smart quotes (`""`), no em dashes (`—`), no curly apostrophes. PowerShell 5.1 under
Windows-1252 codepages will either fail to parse or silently produce garbage. Use `--` for
dashes in comments and straight quotes everywhere.

### 7. Duplicate task check is case-insensitive (Windows paths are)
`New-MotivationTask` normalises with `[System.IO.Path]::GetFullPath(...).ToLowerInvariant()`
before comparing. Keep this pattern any time you compare folder paths.

### 8. `Remove-MotivationTask` failure ≠ task is gone
`Unregister-ScheduledTask` can fail if the task already fired or was manually deleted.
The `catch` block logs a warning but still cleans up `tasks.json`. This is correct — do
not treat Unregister failure as fatal.

### 9. `$PSScriptRoot` is empty when compiled with PS2EXE
`MainApp.ps1` already handles this with:
```powershell
$scriptDir = if ($PSScriptRoot -and $PSScriptRoot.Length -gt 0) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
```
Use this pattern in any new entry-point script.

### 10. Error handling contract: use `Show-ErrorDialog` everywhere
`ConfigManager.psm1` exports `Show-ErrorDialog`. All user-visible error messages must go
through it. Never use raw `Write-Error` or `throw` without a catch that surfaces the error
to the user via this helper.

---

## Task Scheduler Record Format

Tasks in `tasks.json` follow this schema:

```json
{
  "task_id": "a1b2c3d4",
  "task_name": "DailyMotivation_a1b2c3d4",
  "folder_path": "C:\\Projects\\ClientA",
  "folder_name": "ClientA",
  "scheduled_time": "2026-06-04T14:00:00",
  "created_at": "2026-06-03T09:12:00.000Z",
  "status": "PENDING",
  "snooze_count": 0,
  "snooze_duration_minutes": 5
}
```

Status values: `PENDING` | `COMPLETED` | `SNOOZED` | `DISMISSED` | `DELETED`

Task names are always `DailyMotivation_` + 8-char hex GUID substring.

---

## Module API Quick Reference

### `New-MotivationTask`
```powershell
$result = New-MotivationTask -FolderPath "C:\Projects\Foo" -TriggerTime $datetime [-Force]
# Returns: @{ Success, TaskId, IsDuplicate, IsNetworkPath, Error? }
# IsDuplicate=$true means a PENDING task for same path+date already exists.
# Caller must show warning dialog and retry with -Force if user confirms.
```

### `Get-MotivationTasks`
```powershell
$tasks = Get-MotivationTasks
# Cross-checks tasks.json against Windows Task Scheduler.
# Marks missing tasks DELETED. Returns all records.
```

### `Remove-MotivationTask`
```powershell
Remove-MotivationTask -TaskId "a1b2c3d4"
# Removes from scheduler (best-effort) and from tasks.json.
```

### `Set-PopupConfig`
```powershell
Set-PopupConfig -Glyph "[+]" -Title "Time to Show Up" -Body "..." `
                -ExplorerPath "C:\Projects\Foo" -TaskId "a1b2c3d4"
# Derives folder_name from ExplorerPath automatically.
```

### `Get-OutcomeLog`
```powershell
$entries = Get-OutcomeLog -Limit 30
# Returns PSCustomObjects: Timestamp, TaskId, FolderName, FolderPath, Outcome, SnoozeCount
```

---

## Documentation Index

Read these before making changes in the relevant area:

| Changing... | Read first |
|-------------|-----------|
| Popup behavior, snooze, dismiss | `docs/NOTIFICATION_ENGINE_SPEC.md`, `docs/SSOT.md` |
| Task creation/deletion | `docs/TASK_SCHEDULER_SPEC.md` |
| Config/JSON schema | `docs/CONFIGURATION_SPEC.md`, `docs/DATA_MODEL.md` |
| UI layout or new controls | `docs/UX_SPEC.md`, `docs/ACCEPTANCE_CRITERIA.md` |
| Feature requirements | `docs/PRD.md` (FR-001 through FR-025) |
| Acceptance criteria / test cases | `docs/ACCEPTANCE_CRITERIA.md`, `docs/TEST_PLAN.md` |
| Architecture / module boundaries | `docs/ARCHITECTURE.md` |
| Known bugs and patterns to avoid | `docs/FORENSIC_REVIEW.md` |
| Distribution packaging | `docs/DISTRIBUTION_STRATEGY.md` |
| Sprint tasks and priorities | `docs/SPRINT_PLAN.md` |

---

## Conventions

**Commits:** conventional commit format
```
feat(popup): add snooze duration split-button (B-10)
fix(config): guard against null recentFolders on fresh install
refactor(scheduler): extract duplicate-check into helper
docs(changelog): add v1.0-dev entries for Sprint 2
```

**PowerShell style:**
- `#Requires -Version 5.1` at top of every script
- `Set-StrictMode -Version Latest` in entry points
- `$ErrorActionPreference = "Stop"` in entry points; explicit `-ErrorAction Stop` in modules
- Google-style comment blocks for exported functions
- Type hints on all `param()` blocks
- No truncation or stubs — write the full implementation

**No console output in production paths.** All diagnostic output goes to `Write-DLog` (in
`DailyMotivation.ps1`) or `Write-Verbose` in modules. Never `Write-Host` or `Write-Output`
from a Task Scheduler context.

---

## Agent Skills

Skills live in `CLAUDE/skills/`. Invoke by intent:

| When you need to... | Use skill |
|--------------------|-----------|
| Debug a hard bug systematically | `engineering/diagnose` |
| Review or improve module boundaries | `engineering/improve-codebase-architecture` |
| Write a feature TDD-style | `engineering/tdd` |
| Break a spec into GitHub issues | `engineering/to-issues` |
| Triage incoming bugs or requests | `engineering/triage` |
| Understand unfamiliar code area | `engineering/zoom-out` |
| Build a throwaway proof-of-concept | `engineering/prototype` |
| Write a PRD from current context | `engineering/to-prd` |
| Stress-test a design decision | `productivity/grill-me` |
| Compress token usage when working fast | `productivity/caveman` |
| Hand off to the next session | `productivity/handoff` |
