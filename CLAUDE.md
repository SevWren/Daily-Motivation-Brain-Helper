# CLAUDE.md — Daily Motivation Brain Helper

## CRITICAL: Testing Environment Requirements

**⚠️ AI AGENTS MUST READ THIS FIRST ⚠️**

This application is **Windows 10 only** at runtime. The test suite has **two incompatible execution environments:**

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
| 2 | Assembly loading (WPF + WinForms); exits only if `-not $NoRun` on failure |
| 3 | Config functions: `Initialize-AppData`, `Get-Config`, `Save-Config`, `Get/Set-PopupConfig`, `Write-OutcomeLog`, `Show-ErrorDialog` |
| 4 | Task Scheduler: `Get/Save-TasksJson`, `New-MotivationTask`, `Get-MotivationTasks`, `Remove-MotivationTask` |
| 5 | Context menu: `Register-ContextMenu`, `Unregister-ContextMenu` (HKCU, no admin) |
| 6 | Main window XAML (`[xml]$MainXaml`) |
| 7 | `function Show-MainWindow { }` |
| 8 | Popup window XAML (`[xml]$PopupXaml`) |
| 9 | `function Show-PopupWindow { }` |
| 10 | `$Messages = @(...)` + `function Get-RandomMessage { }` |
| 11 | Entry point: `if (-not $NoRun) { Initialize-AppData; switch($Mode) { ... } }` |

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
- Named mutex `Global\DailyMotivationBrainHelperPopup` enforces single popup
- Task Scheduler action calls `$script:ExePath /popup` (captured at runtime via `$MyInvocation.MyCommand.Path`)
- Tests override `$script:ExePath` before calling `New-MotivationTask`
- FIX-001: `Initialize-AppData` re-resolves all paths from `$env:APPDATA` at call time (enables test redirects)
- FIX-003: `Get-TasksJson` wraps result in `@()` for consistent array handling

## Code Quality Rules

### No Startup Popups
**CRITICAL:** DailyMotivation.exe must NEVER display a popup message on startup in main mode. The application should launch directly into the main window UI without any blocking dialogs, confirmation prompts, or informational messages. Startup popups degrade user experience and violate the principle of instant usability.

### Comment Hygiene
Remove bloat comments that reference bug IDs (e.g., `# AG19-003:`, `# AG7-004:`). Keep only comments that explain **why** code exists or **what** non-obvious behavior is expected. Bug tracking belongs in commit history and bug reports, not inline comments.

## Requirements Reference

See `DailyMotivationBrainHelper_TechnicalReflection_2026-06-12_v2_1_CORRECTED.md` (kept outside repo) for the full requirements, NFRs, success criteria, and phased roadmap.
