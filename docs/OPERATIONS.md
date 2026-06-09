# Operations Guide

**Last Updated:** 2026-06-09
**Version:** 1.1
**Status:** Official Operations Manual

---

## Table of Contents

1. [Deployment Procedures](#deployment-procedures)
2. [Build Process](#build-process)
3. [Release Checklist](#release-checklist)
4. [Monitoring Requirements](#monitoring-requirements)
5. [Scheduled Task Setup](#scheduled-task-setup)
6. [Configuration Management](#configuration-management)
7. [Backup Procedures](#backup-procedures)
8. [Update Procedures](#update-procedures)

---

## Deployment Procedures

### Prerequisites

Before deploying to any environment:

- Windows 10 (build 19041+) or Windows 11
- PowerShell 5.1 (included with Windows)
- .NET Framework 4.x (included with Windows)
- Administrator access for initial setup only
- Windows Task Scheduler service running

### Standard Deployment (End User)

**Step 1: Extract Application**
```
Extract release ZIP to target directory:
  Recommended: C:\DailyMotivation\
  Alternative: Any local directory (avoid network shares)
```

**Step 2: Run Initial Setup**
```powershell
# Right-click UpdateScheduledTask.ps1 → "Run with PowerShell" (as Administrator)
# This performs:
#   - Creates %APPDATA%\DailyMotivationBrainHelper\
#   - Copies Modules\ to %APPDATA%\DailyMotivationBrainHelper\Modules\
#   - Copies data\messages.json to %APPDATA%\DailyMotivationBrainHelper\
#   - Initializes app_settings.json, tasks.json, popup_config.json
#   - Registers placeholder Task Scheduler entry
```

**Step 3: Verify Installation**
```powershell
# Launch main application
powershell.exe -STA -ExecutionPolicy Bypass -File "C:\DailyMotivation\src\MainApp.ps1"

# Or double-click (if EXE built):
C:\DailyMotivation\src\DailyMotivation.exe
```

**Step 4: Optional Shell Extension**
```powershell
# Right-click Register-ShellExtension.ps1 → "Run with PowerShell" (as Administrator)
# Adds "Schedule for Tomorrow at 2 PM" to Explorer right-click menu
```

### Enterprise Deployment (Silent Install)

For mass deployment via GPO, SCCM, or Intune:

```powershell
# Silent setup script (run as SYSTEM or admin)
$targetDir = "C:\Program Files\DailyMotivation"
$userProfile = $env:USERPROFILE

# Extract to target
Expand-Archive -Path "DailyMotivationBrainHelper_Release.zip" -DestinationPath $targetDir

# Run setup as user (not SYSTEM)
Start-Process powershell.exe -ArgumentList @(
    "-ExecutionPolicy", "Bypass",
    "-File", "$targetDir\src\UpdateScheduledTask.ps1"
) -Wait -NoNewWindow

# Verify Task Scheduler entry created
Get-ScheduledTask -TaskName "DailyMotivationBrainHelper_Launcher" -ErrorAction Stop
```

**GPO/MDM Configuration:**
- Deploy to: `%ProgramFiles%\DailyMotivation\`
- Run setup script once per user (logon script)
- No elevated privileges required for normal app use
- Task Scheduler runs under user context (Interactive logon)

---

## Build Process

### Development Environment Setup

```powershell
# Install build dependencies (one-time)
Install-Module -Name InvokeBuild -Scope CurrentUser -Force
Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
Install-Module -Name ps2exe -Scope CurrentUser -Force

# Or use build automation:
Invoke-Build InstallDependencies
```

### Build Tasks

#### Full Build (Default)
```powershell
Invoke-Build

# Executes:
#   1. Clean   - Remove Output\ directory
#   2. Analyze - PSScriptAnalyzer static analysis
#   3. Test    - Run full Pester test suite (180+ tests)
#   4. Build   - Compile EXE files with PS2EXE
```

#### Quick Build (Development)
```powershell
Invoke-Build QuickBuild

# Executes:
#   1. Clean
#   2. Build (skips Analyze and Test)

# Use during active development for faster iteration
```

#### Individual Tasks
```powershell
Invoke-Build Clean          # Clean Output\ directory
Invoke-Build Analyze        # PSScriptAnalyzer only
Invoke-Build Test           # Pester tests only
Invoke-Build TestUnit       # Unit tests only (fast)
Invoke-Build TestIntegration # Integration tests only
Invoke-Build Build          # Compile EXE files only
```

### Build Output Structure

After successful build, `Output\` contains:

```
Output/
├── DailyMotivationBrainHelper.exe    # Main application executable
├── DailyMotivation.exe               # Popup executable
├── LaunchMotivation.bat              # Task Scheduler launcher
├── Modules/
│   ├── ConfigManager.psm1
│   └── TaskScheduler.psm1
└── data/
    └── messages.json
```

**CRITICAL:** `Modules\` and `data\` must be at root of `Output\`, not in a `src\` subdirectory. This is a known issue fixed in `.build.ps1` lines 182-189.

### Build Configuration

Configuration is in `.build.ps1`:

```powershell
$script:Config = @{
    ProjectRoot   = $PSScriptRoot
    SourcePath    = Join-Path $PSScriptRoot 'src'
    TestsPath     = Join-Path $PSScriptRoot 'Tests'
    OutputPath    = Join-Path $PSScriptRoot 'Output'
    MainAppScript = Join-Path $PSScriptRoot 'src\MainApp.ps1'
    PopupScript   = Join-Path $PSScriptRoot 'src\DailyMotivation.ps1'
    MainAppExe    = Join-Path $PSScriptRoot 'Output\DailyMotivationBrainHelper.exe'
    PopupExe      = Join-Path $PSScriptRoot 'Output\DailyMotivation.exe'
}
```

### Testing During Build

Tests run automatically in default build:

```powershell
# Test execution settings (from Invoke-Tests.ps1)
- Test Framework: Pester 5.x
- Coverage Target: 80%+
- Coverage Scope: src/Modules/*.psm1
- Output Format: NUnitXml (CI mode)
- Coverage Format: JaCoCo XML

# View build configuration
Invoke-Build ShowConfig
```

**Coverage Gaps:**
- `DailyMotivation.ps1` (popup): 0% automated coverage (WPF limitations)
- Validation: Manual test cases TC-003 through TC-020 in `docs/TEST_PLAN.md`

---

## Release Checklist

### Pre-Release Validation

- [ ] **All tests pass**
  ```powershell
  .\Invoke-Tests.ps1 -CI
  # Must exit 0, no failures
  ```

- [ ] **Code coverage ≥ 80%**
  ```powershell
  # Check coverage.xml output
  # ConfigManager.psm1: ~90% target
  # TaskScheduler.psm1: ~85% target
  ```

- [ ] **PSScriptAnalyzer clean**
  ```powershell
  Invoke-Build Analyze
  # Zero errors, zero warnings
  ```

- [ ] **Manual test suite complete**
  - Run all test cases in `docs/TEST_PLAN.md` (TC-001 through TC-020)
  - Verify WPF popup displays correctly
  - Test snooze/dismiss/open folder workflows
  - Verify first-run welcome overlay
  - Test drag-and-drop functionality

- [ ] **Build artifacts verified**
  ```powershell
  Invoke-Build Release
  cd Output
  .\DailyMotivationBrainHelper.exe  # Should launch without errors
  ```

- [ ] **Critical issues resolved**
  - Review `audit-reports/CRITICAL-FIXES-REQUIRED.md`
  - All BLOCKER items must be fixed
  - HIGH-PRIORITY items should be fixed or documented

### Release Package Creation

```powershell
# Full release build with package
Invoke-Build Release

# Output: Output/DailyMotivationBrainHelper_Release.zip

# Package contains:
#   - DailyMotivationBrainHelper.exe
#   - DailyMotivation.exe
#   - LaunchMotivation.bat
#   - Modules/ (ConfigManager.psm1, TaskScheduler.psm1)
#   - data/ (messages.json)
#   - src/ (source scripts for advanced users)
```

### Release Documentation

Include in release:

- [ ] **README.md** - User-facing quick start
- [ ] **docs/INSTALL.md** - Installation guide
- [ ] **LICENSE** - MIT license
- [ ] **CHANGELOG.md** - Version history and changes
- [ ] **docs/TROUBLESHOOTING.md** - Common issues and solutions

### GitHub Release Process

1. **Tag the release**
   ```bash
   git tag -a v1.1.0 -m "Release v1.1.0 - Feature complete"
   git push origin v1.1.0
   ```

2. **Create GitHub Release**
   - Go to: https://github.com/SevWren/Daily-Motivation-Brain-Helper/releases
   - Click "Draft a new release"
   - Select tag: v1.1.0
   - Release title: "Daily Motivation Brain Helper v1.1.0"
   - Upload: `Output/DailyMotivationBrainHelper_Release.zip`
   - Copy release notes from `docs/CHANGELOG.md`

3. **Post-release verification**
   - Download release ZIP from GitHub
   - Extract and install on clean test machine
   - Run through quick start guide
   - Verify Task Scheduler integration works

### Version Numbering

Format: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes, architecture overhaul
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, minor improvements

Current: v1.1.0 (feature complete with B-01 through B-19)

---

## Monitoring Requirements

### Application Health Checks

**Daily Checks:**
1. Windows Task Scheduler service status
   ```powershell
   Get-Service -Name Schedule | Select-Object Status, StartType
   # Should be: Status=Running, StartType=Automatic
   ```

2. Scheduled tasks integrity
   ```powershell
   Get-ScheduledTask -TaskName "DailyMotivation_*" | Select-Object TaskName, State
   # State should be "Ready" for pending tasks
   ```

**Weekly Checks:**
1. Log file sizes (prevent disk space issues)
   ```powershell
   $appData = "$env:APPDATA\DailyMotivationBrainHelper"
   Get-ChildItem "$appData\*.log", "$appData\*.txt" | Select-Object Name, Length
   # popup_log.txt grows ~100 bytes per entry; rotate if > 10 MB
   ```

2. Configuration file integrity
   ```powershell
   $appData = "$env:APPDATA\DailyMotivationBrainHelper"
   Get-Content "$appData\app_settings.json" | ConvertFrom-Json
   # Should parse without errors
   ```

### Key Metrics

| Metric | Location | Normal Range | Alert Threshold |
|--------|----------|--------------|-----------------|
| Task success rate | `popup_log.txt` | > 95% "Opened" | < 80% |
| Average snooze count | `popup_log.txt` | 0-2 per task | > 5 |
| Task Scheduler errors | Event Viewer | 0 per week | > 3 |
| Config parse failures | Launch logs | 0 per week | > 1 |

### Log File Locations

| Log File | Path | Purpose | Rotation |
|----------|------|---------|----------|
| popup_log.txt | `%APPDATA%\DailyMotivationBrainHelper\popup_log.txt` | Task outcomes | Manual (> 10 MB) |
| launch_log.txt | `%APPDATA%\DailyMotivationBrainHelper\launch_log.txt` | Launcher execution | Manual (> 5 MB) |
| launch_ps.log | `%APPDATA%\DailyMotivationBrainHelper\launch_ps.log` | PowerShell stderr | Manual (> 5 MB) |
| DailyMotivation_debug.log | `%TEMP%\DailyMotivation_debug.log` | Popup debug trace | Auto-overwrite |
| DailyMotivation_error.log | `%TEMP%\DailyMotivation_error.log` | Uncaught exceptions | Auto-overwrite |

### Event Viewer Monitoring

**Relevant Event Logs:**
- **Application Log** → Source: "Task Scheduler"
  - Event ID 102: Task start
  - Event ID 201: Task action completed
  - Event ID 203: Task action failed

**Sample Query:**
```powershell
Get-WinEvent -FilterHashtable @{
    LogName   = 'Microsoft-Windows-TaskScheduler/Operational'
    ID        = 201, 203
    StartTime = (Get-Date).AddDays(-7)
} | Where-Object { $_.Message -like "*DailyMotivation*" }
```

---

## Scheduled Task Setup

### Task Scheduler Architecture

```
User schedules folder via MainApp
         ↓
TaskScheduler.psm1 creates task:
  - Name: DailyMotivation_{16-char-guid}
  - Action: cmd.exe /c LaunchMotivation.bat
  - Trigger: Once at specified DateTime
  - Principal: Current user, Interactive logon
  - Settings: StartWhenAvailable=true
         ↓
At trigger time:
  LaunchMotivation.bat launches DailyMotivation.ps1
         ↓
  DailyMotivation.ps1 shows WPF popup
         ↓
  User clicks [Open Folder] → Explorer launches
         ↓
  Task status updated in tasks.json
```

### Task Naming Convention

Format: `DailyMotivation_{task_id}`

- **Prefix:** `DailyMotivation_` (constant)
- **task_id:** 16-character GUID substring (e.g., `a3f9c4e821b6d057`)

Example: `DailyMotivation_a3f9c4e821b6d057`

### Task Properties

| Property | Value | Rationale |
|----------|-------|-----------|
| Trigger | Once at DateTime | Single-use task, not recurring |
| Action | `cmd.exe /c LaunchMotivation.bat` | Batch wrapper ensures environment setup |
| Principal | User (Interactive) | Must run in user session for WPF |
| RunLevel | Limited (default) | No admin needed for normal use |
| RunLevel | Highest (network paths) | UNC/mapped drives need elevated access |
| StartWhenAvailable | True | Run at next logon if missed |
| ExecutionTimeLimit | 10 minutes | Prevent hung tasks |
| MultipleInstances | IgnoreNew | Named mutex enforces single popup |

### Manual Task Registration

If `UpdateScheduledTask.ps1` fails, register manually:

```powershell
$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"C:\DailyMotivation\src\LaunchMotivation.bat`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddHours(1)

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName "DailyMotivationBrainHelper_Launcher" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Daily Motivation Brain Helper placeholder"
```

### Task Cleanup

Remove all tasks (uninstall):

```powershell
Get-ScheduledTask -TaskName "DailyMotivation*" | Unregister-ScheduledTask -Confirm:$false
```

---

## Configuration Management

### Configuration File Schema

All config files stored in: `%APPDATA%\DailyMotivationBrainHelper\`

#### app_settings.json
```json
{
  "firstRun": true,
  "lastFolder": "C:\\Users\\User\\Documents\\Project",
  "recentFolders": [
    "C:\\Users\\User\\Documents\\Project",
    "C:\\Work\\ClientA",
    "C:\\Work\\ClientB"
  ],
  "theme": "dark"
}
```

**Fields:**
- `firstRun` (bool): Shows welcome overlay if true
- `lastFolder` (string): Path of last scheduled folder (B-01)
- `recentFolders` (array): Max 5 paths, FIFO, newest first (B-02)
- `theme` (string): UI theme (currently unused, reserved)

#### tasks.json
```json
[
  {
    "task_id": "a3f9c4e821b6d057",
    "task_name": "DailyMotivation_a3f9c4e821b6d057",
    "folder_path": "C:\\Work\\ClientA",
    "folder_name": "ClientA",
    "scheduled_time": "2026-06-10T14:00:00",
    "created_at": "2026-06-09T10:30:45.1234567Z",
    "status": "PENDING",
    "snooze_count": 0,
    "snooze_duration_minutes": 5
  }
]
```

**Status Values:**
- `PENDING`: Task not yet triggered
- `COMPLETED`: Task opened successfully
- `SNOOZED`: Task currently snoozed
- `DISMISSED`: User dismissed for today
- `MISSED`: Path invalid at trigger time

#### popup_config.json
```json
{
  "glyph": "[+]",
  "title": "Time to Show Up",
  "body": "Every great outcome starts with showing up. Let's make this session count.",
  "explorer_path": "C:\\Work\\ClientA",
  "folder_name": "ClientA",
  "task_id": "a3f9c4e821b6d057"
}
```

Written by MainApp before task creation; read by DailyMotivation.ps1 at popup time.

#### popup_log.txt (Outcome Log)
```
[2026-06-09 14:00:15] | a3f9c4e821b6d057 | ClientA | C:\Work\ClientA | Opened | 0
[2026-06-08 14:00:22] | b7e4d1c932a8f065 | ProjectX | C:\Projects\ProjectX | Snoozed | 2
[2026-06-07 14:00:10] | f5a1e9d8c3b2a074 | Archive | D:\Archive | Dismissed | 0
```

**Format:** `[timestamp] | task_id | folder_name | folder_path | outcome | snooze_count`

**Outcomes:** `Opened`, `Snoozed`, `Dismissed`, `PathMissing`

### Configuration Backup

**Backup Script:**
```powershell
$appData = "$env:APPDATA\DailyMotivationBrainHelper"
$backupDir = "$env:USERPROFILE\Documents\DailyMotivation_Backup"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

New-Item -ItemType Directory -Path "$backupDir\$timestamp" -Force
Copy-Item "$appData\*.json" "$backupDir\$timestamp\" -Force
Copy-Item "$appData\popup_log.txt" "$backupDir\$timestamp\" -Force -ErrorAction SilentlyContinue

Write-Host "Backup saved to: $backupDir\$timestamp"
```

**Restore Script:**
```powershell
$backupDir = "$env:USERPROFILE\Documents\DailyMotivation_Backup"
$appData = "$env:APPDATA\DailyMotivationBrainHelper"

$latest = Get-ChildItem $backupDir | Sort-Object Name -Descending | Select-Object -First 1
Copy-Item "$($latest.FullName)\*.json" $appData -Force
Copy-Item "$($latest.FullName)\popup_log.txt" $appData -Force -ErrorAction SilentlyContinue

Write-Host "Restored from: $($latest.FullName)"
```

### Configuration Reset

**Full reset (factory defaults):**
```powershell
$appData = "$env:APPDATA\DailyMotivationBrainHelper"
Remove-Item "$appData\*.json" -Force
Remove-Item "$appData\*.txt" -Force -ErrorAction SilentlyContinue

# Restart app to reinitialize
```

---

## Backup Procedures

### What to Back Up

**Critical Files:**
1. **Configuration** (user data)
   - `%APPDATA%\DailyMotivationBrainHelper\app_settings.json`
   - `%APPDATA%\DailyMotivationBrainHelper\tasks.json`
   - `%APPDATA%\DailyMotivationBrainHelper\messages.json` (if customized)

2. **History** (optional)
   - `%APPDATA%\DailyMotivationBrainHelper\popup_log.txt`

3. **Application** (reinstallable)
   - Installation directory (e.g., `C:\DailyMotivation\`)

**Not Critical:**
- `popup_config.json` (ephemeral, regenerated per task)
- Log files in `%TEMP%` (debug only)

### Backup Frequency

| Data Type | Frequency | Method | Retention |
|-----------|-----------|--------|-----------|
| Configuration | Daily | Automated script | 30 days |
| History log | Weekly | Manual or script | 90 days |
| Application | On update | Manual | Latest + previous |

### Automated Backup (Task Scheduler)

Create a scheduled task for daily backups:

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument @"
-ExecutionPolicy Bypass -NoProfile -Command "
  `$src = '`$env:APPDATA\DailyMotivationBrainHelper';
  `$dst = '`$env:USERPROFILE\Documents\DailyMotivation_Backup\`$(Get-Date -Format 'yyyyMMdd')';
  New-Item -ItemType Directory -Path `$dst -Force | Out-Null;
  Copy-Item `$src\*.json `$dst -Force;
  Copy-Item `$src\popup_log.txt `$dst -Force -ErrorAction SilentlyContinue
"
"@

$trigger = New-ScheduledTaskTrigger -Daily -At "03:00"

Register-ScheduledTask `
    -TaskName "DailyMotivation_Backup" `
    -Action $action `
    -Trigger $trigger `
    -Description "Daily backup of Daily Motivation config"
```

### Cloud Backup Integration

For users with cloud storage (OneDrive, Dropbox, Google Drive):

```powershell
# Symlink config directory to cloud folder
$appData = "$env:APPDATA\DailyMotivationBrainHelper"
$cloudBackup = "$env:OneDrive\Backups\DailyMotivation"

# Backup current config
Copy-Item $appData $cloudBackup -Recurse -Force

# Optional: Create symlink (requires admin)
# Remove-Item $appData -Recurse -Force
# New-Item -ItemType SymbolicLink -Path $appData -Target $cloudBackup
```

---

## Update Procedures

### In-Place Update (Recommended)

1. **Backup current configuration**
   ```powershell
   $appData = "$env:APPDATA\DailyMotivationBrainHelper"
   Copy-Item "$appData\*.json" "$env:TEMP\DM_Backup\" -Force
   ```

2. **Stop running tasks**
   ```powershell
   Get-Process | Where-Object { $_.ProcessName -like "*DailyMotivation*" } | Stop-Process -Force
   ```

3. **Extract new version over existing**
   ```powershell
   Expand-Archive -Path "DailyMotivationBrainHelper_v1.2.zip" -DestinationPath "C:\DailyMotivation" -Force
   ```

4. **Update modules in %APPDATA%**
   ```powershell
   $src = "C:\DailyMotivation\src\Modules"
   $dst = "$env:APPDATA\DailyMotivationBrainHelper\Modules"
   Copy-Item "$src\*.psm1" $dst -Force
   ```

5. **Verify configuration compatibility**
   ```powershell
   # Launch app and check for errors
   C:\DailyMotivation\src\DailyMotivation.exe
   ```

6. **Restore user customizations** (if needed)
   ```powershell
   # Only restore messages.json if user had customizations
   Copy-Item "$env:TEMP\DM_Backup\messages.json" "$appData\messages.json" -Force
   ```

### Clean Install Update

For major version upgrades or corrupted installations:

1. **Export configuration**
   ```powershell
   $appData = "$env:APPDATA\DailyMotivationBrainHelper"
   $backup = "$env:USERPROFILE\Documents\DM_Upgrade_Backup"
   Copy-Item $appData $backup -Recurse -Force
   ```

2. **Uninstall existing version**
   ```powershell
   # Remove scheduled tasks
   Get-ScheduledTask -TaskName "DailyMotivation*" | Unregister-ScheduledTask -Confirm:$false

   # Remove application directory
   Remove-Item "C:\DailyMotivation" -Recurse -Force

   # Remove %APPDATA% (config retained in backup)
   Remove-Item "$env:APPDATA\DailyMotivationBrainHelper" -Recurse -Force
   ```

3. **Install new version**
   ```powershell
   # Follow standard deployment procedure
   Expand-Archive -Path "DailyMotivationBrainHelper_v1.2.zip" -DestinationPath "C:\DailyMotivation"
   # Right-click UpdateScheduledTask.ps1 → Run as Administrator
   ```

4. **Import configuration**
   ```powershell
   # Copy back compatible config files
   Copy-Item "$backup\app_settings.json" "$env:APPDATA\DailyMotivationBrainHelper\" -Force
   Copy-Item "$backup\tasks.json" "$env:APPDATA\DailyMotivationBrainHelper\" -Force
   Copy-Item "$backup\messages.json" "$env:APPDATA\DailyMotivationBrainHelper\" -Force
   ```

### Version Migration Notes

**v1.0 → v1.1:**
- Config schema: No breaking changes
- New fields: `lastFolder`, `recentFolders` in `app_settings.json` (auto-initialized)
- New fields: `folder_name`, `task_id` in `popup_config.json` (auto-added)
- No manual migration required

**Future versions:**
- Check `CHANGELOG.md` for breaking changes
- Migration scripts provided in release notes if needed

### Rollback Procedure

If update fails:

1. **Restore application**
   ```powershell
   Remove-Item "C:\DailyMotivation" -Recurse -Force
   Expand-Archive -Path "DailyMotivationBrainHelper_v1.0.zip" -DestinationPath "C:\DailyMotivation"
   ```

2. **Restore configuration**
   ```powershell
   $backup = "$env:USERPROFILE\Documents\DM_Upgrade_Backup"
   Copy-Item "$backup\*" "$env:APPDATA\DailyMotivationBrainHelper\" -Recurse -Force
   ```

3. **Verify rollback**
   ```powershell
   C:\DailyMotivation\src\DailyMotivation.exe
   ```

---

## Appendix: PowerShell Execution Policy

### Setting Execution Policy (If Blocked)

If scripts fail with "execution policy" errors:

```powershell
# Option 1: Per-session (temporary)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Option 2: Current user (permanent)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

# Option 3: Launch with bypass (recommended for users)
powershell.exe -ExecutionPolicy Bypass -File "path\to\script.ps1"
```

**Note:** The application uses `-ExecutionPolicy Bypass` in all launchers (LaunchMotivation.bat, etc.), so users should not encounter policy errors during normal use.

---

## Appendix: Directory Structure Reference

```
Installation Directory (e.g., C:\DailyMotivation\)
│
├── src/
│   ├── MainApp.ps1                    # Main application entry point
│   ├── MainWindow.xaml                # Main window UI layout
│   ├── DailyMotivation.ps1            # Popup script
│   ├── LaunchMotivation.bat           # Task Scheduler launcher
│   ├── UpdateScheduledTask.ps1        # Initial setup script
│   ├── DailyMotivation.exe            # Compiled main app (if built)
│   │
│   ├── Modules/
│   │   ├── ConfigManager.psm1         # Config management module
│   │   └── TaskScheduler.psm1         # Task Scheduler wrapper module
│   │
│   ├── data/
│   │   └── messages.json              # Motivational messages library
│   │
│   └── ShellExtension/
│       ├── MotivationShellExt.cs      # Explorer shell extension (C#)
│       ├── Register-ShellExtension.ps1 # Shell extension installer
│       └── ShellBridge.ps1             # PowerShell bridge for shell extension
│
├── Tests/                              # Test suite (dev only)
├── docs/                               # Documentation (dev only)
├── .build.ps1                          # Build automation (dev only)
├── Invoke-Tests.ps1                    # Test runner (dev only)
└── README.md                           # User-facing documentation

User Data Directory (%APPDATA%\DailyMotivationBrainHelper\)
│
├── Modules/                            # Runtime modules (copied from src\Modules)
│   ├── ConfigManager.psm1
│   └── TaskScheduler.psm1
│
├── app_settings.json                   # User preferences and state
├── tasks.json                          # Scheduled tasks registry
├── popup_config.json                   # Active task config (ephemeral)
├── messages.json                       # Messages library (user-customizable)
├── popup_log.txt                       # Task outcome history
├── launch_log.txt                      # Launcher execution log
└── launch_ps.log                       # PowerShell stderr log

Temp Directory (%TEMP%)
│
├── DailyMotivation_debug.log           # Popup debug trace (auto-overwrite)
└── DailyMotivation_error.log           # Uncaught exceptions (auto-overwrite)
```

---

## Support and Escalation

**Documentation:**
- Installation: `docs/INSTALL.md`
- Troubleshooting: `docs/TROUBLESHOOTING.md`
- Testing: `TESTING.md`
- Architecture: `docs/ARCHITECTURE.md`

**Issue Tracking:**
- GitHub Issues: https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues
- Security Issues: Email mmueller07@gmail.com with subject `[SECURITY] Daily-Motivation-Brain-Helper`

**Build Status:**
- CI/CD: `.github/workflows/test.yml`
- Quality Gates: PSScriptAnalyzer, 80%+ coverage, all tests pass

---

**End of Operations Guide**
