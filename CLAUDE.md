# CLAUDE.md — Daily Motivation Brain Helper

## CRITICAL: Testing Environment Requirements

**⚠️ AI AGENTS MUST READ THIS FIRST ⚠️**

This application targets **Windows 10/11** at runtime (WPF, Task Scheduler, registry, Explorer). The test suite has **two incompatible execution environments:**

1. **Windows 10 PowerShell 7** (PRIMARY) - Where test baselines originate
2. **Linux PowerShell 7** (SECONDARY) - For CI/platform abstraction validation only

### Test Validation Rules for AI Agents

**🚨 CRITICAL RULE: DO NOT assume test fixes are valid based solely on tests passing in a Unix/Linux environment.**

- Test baselines were created on Windows 10 with Windows-specific paths, registry operations, and Task Scheduler behavior
- Tests passing in the Linux sandbox **DO NOT** guarantee they will pass on Windows 10
- Mock behavior differs between Windows and Linux (especially for Task Scheduler, Registry, and CIM exceptions)
- Platform abstraction tests (`*.Platform.Tests.ps1`) are designed for Linux; regular tests are designed for Windows

### Required Validation Process

Before declaring any test fix "successful":

1. ✅ **MUST** verify tests pass on **Windows 10 PowerShell 7** (the target platform)
2. ✅ **MUST** review Windows-specific test log output (not Linux sandbox output)
3. ✅ **MUST** understand the difference between:
   - Platform tests (HeadlessPlatform injection) - run on Linux
   - Regular unit tests (Windows API mocks) - run on Windows
4. ⚠️ **DO NOT** commit changes that only work in the Linux sandbox
5. ⚠️ **DO NOT** assume mock behavior is equivalent between Windows and Linux

### Windows-Specific Test Dependencies

These tests **REQUIRE** Windows 10 to validate correctly:

- `TaskScheduler.Tests.ps1` - Mocks Windows Task Scheduler cmdlets (`Register-ScheduledTask`, `Get-ScheduledTask`)
- `ContextMenu.Tests.ps1` - Uses Windows registry (`HKCU:\` provider)
- Integration tests - Validate Task Scheduler integration on Windows

### Platform Abstraction Tests (Linux-Safe)

These tests CAN run on Linux with HeadlessPlatform:

- `Config.Platform.Tests.ps1`
- `TaskScheduler.Platform.Tests.ps1`
- `PlatformAdapter.Tests.ps1`
- `FolderScheduling.Tests.ps1`

**Bottom Line:** If you're working in a Linux sandbox, your test results **do not represent Windows 10 behavior**. Always request Windows test logs before declaring fixes complete.

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

When running tests on Linux/Unix (including CI environments), PowerShell 7 must be installed. The following automated setup is required:

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

**Note:** The test suite is designed to run on Linux through platform abstraction. The app itself remains Windows 10 only (WPF, Task Scheduler, registry, Explorer context menu all require Windows).

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
