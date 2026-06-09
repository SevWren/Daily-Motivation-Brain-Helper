# PowerShell Modules API Reference

This directory contains comprehensive API documentation for all PowerShell modules in the Daily Motivation Brain Helper application.

---

## Module Overview

| Module | Purpose | Key Functions | Documentation |
|--------|---------|---------------|---------------|
| **ConfigManager** | Configuration and settings management | `Initialize-AppData`, `Get-AppSettings`, `Add-RecentFolder`, `Write-OutcomeLog`, `Show-ErrorDialog` | [ConfigManager-API.md](ConfigManager-API.md) |
| **TaskScheduler** | Windows Task Scheduler integration | `New-MotivationTask`, `Get-MotivationTasks`, `Remove-MotivationTask`, `Update-MotivationTaskStatus` | [TaskScheduler-API.md](TaskScheduler-API.md) |

---

## Quick Start

### Import Modules

```powershell
# Import modules (adjust path to your installation)
Import-Module ".\src\Modules\ConfigManager.psm1"
Import-Module ".\src\Modules\TaskScheduler.psm1"
```

### Basic Usage Example

```powershell
# Initialize application data directory
Initialize-AppData

# Create a motivation task
$tomorrow9am = (Get-Date).AddDays(1).Date.AddHours(9)
$result = New-MotivationTask `
    -FolderPath "C:\Users\John\Documents\ProjectX" `
    -TriggerTime $tomorrow9am

if ($result.Success) {
    Write-Host "Task created with ID: $($result.TaskId)"
}

# Retrieve all tasks
$tasks = Get-MotivationTasks
$pending = $tasks | Where-Object { $_.status -eq "PENDING" }
Write-Host "You have $($pending.Count) pending tasks"

# Add to recent folders
Add-RecentFolder -FolderPath "C:\Users\John\Documents\ProjectX"

# Log an outcome
Write-OutcomeLog `
    -TaskId $result.TaskId `
    -FolderName "ProjectX" `
    -FolderPath "C:\Users\John\Documents\ProjectX" `
    -Outcome "Opened"
```

---

## Module Summaries

### ConfigManager.psm1

**Location:** `/src/Modules/ConfigManager.psm1`

Manages all JSON configuration files in `%APPDATA%\DailyMotivationBrainHelper\` and provides centralized error handling.

**Key Features:**
- Automatic fallback to `%TEMP%` if `%APPDATA%` unavailable
- User settings persistence (first run, last folder, recent folders, theme)
- Outcome logging with structured pipe-delimited format
- Standardized error dialogs with WPF/Forms fallback
- Defensive null/empty handling for PowerShell 5.1 compatibility

**Configuration Files Managed:**
- `app_settings.json` - User preferences
- `tasks.json` - Scheduled tasks metadata
- `popup_config.json` - Current popup configuration
- `popup_log.txt` - User interaction outcomes

**Read Full Documentation:** [ConfigManager-API.md](ConfigManager-API.md)

---

### TaskScheduler.psm1

**Location:** `/src/Modules/TaskScheduler.psm1`

Wrapper around Windows Task Scheduler for managing motivation reminder tasks.

**Key Features:**
- Create one-time scheduled tasks with Windows Task Scheduler
- Persistent task storage in `tasks.json`
- Duplicate detection (same folder + same day)
- Network path detection with automatic privilege elevation
- Automatic status synchronization between scheduler and JSON
- Snooze support with configurable duration

**Task Lifecycle:**
```
PENDING → [Fires] → COMPLETED / DISMISSED / SNOOZED
         [Deleted] → DELETED
```

**Read Full Documentation:** [TaskScheduler-API.md](TaskScheduler-API.md)

---

## Common Patterns

### Error Handling

```powershell
# Use Show-ErrorDialog for all user-facing errors
try {
    $result = Some-Operation
    if (-not $result.Success) {
        Show-ErrorDialog -Message "Operation failed: $($result.Error)"
    }
}
catch {
    Show-ErrorDialog -Message "Unexpected error: $_"
}
```

### Settings Management

```powershell
# Read settings
$settings = Get-AppSettings

# Modify and save
$settings.theme = "light"
$settings.lastFolder = "C:\Projects"
Save-AppSettings $settings

# Convenience wrappers
Set-LastFolder -FolderPath "C:\Projects"
Add-RecentFolder -FolderPath "C:\Projects"
```

### Task Management

```powershell
# Create task with duplicate check
$result = New-MotivationTask `
    -FolderPath "C:\Projects\MyApp" `
    -TriggerTime (Get-Date).AddHours(2)

if ($result.IsDuplicate) {
    Write-Host "Task already exists for this folder today"
}

# Force creation (skip duplicate check)
$result = New-MotivationTask `
    -FolderPath "C:\Projects\MyApp" `
    -TriggerTime (Get-Date).AddHours(2) `
    -Force

# Update task status
Update-MotivationTaskStatus -TaskId $taskId -Status "COMPLETED"

# Remove task
Remove-MotivationTask -TaskId $taskId
```

### Logging

```powershell
# Write outcome log
Write-OutcomeLog `
    -TaskId "abc123" `
    -FolderName "ProjectX" `
    -FolderPath "C:\Projects\ProjectX" `
    -Outcome "Snoozed" `
    -SnoozeCount 2

# Retrieve recent logs
$logs = Get-OutcomeLog -Limit 10
foreach ($log in $logs) {
    Write-Host "$($log.Timestamp): $($log.Outcome) - $($log.FolderName)"
}
```

---

## Architecture Notes

### Data Flow

```
MainWindow.ps1
    ↓ (calls)
ConfigManager.psm1 ← Initialize-AppData
    ↓ (creates)
%APPDATA%\DailyMotivationBrainHelper\
    ├── app_settings.json
    ├── tasks.json
    ├── popup_config.json
    └── popup_log.txt

MainWindow.ps1
    ↓ (calls)
TaskScheduler.psm1 ← New-MotivationTask
    ↓ (creates)
Windows Task Scheduler
    └── DailyMotivation_abc123def4567890

[Task fires]
    ↓
LaunchMotivation.bat
    ↓
Popup.ps1
    ↓ (reads)
ConfigManager.psm1 ← Get-PopupConfig
    ↓ (writes)
ConfigManager.psm1 ← Write-OutcomeLog
```

### Module Dependencies

```
TaskScheduler.psm1
    ↓ (uses tasks.json path)
ConfigManager.psm1

Popup.ps1
    ↓ (imports both)
ConfigManager.psm1 + TaskScheduler.psm1

MainWindow.ps1
    ↓ (imports both)
ConfigManager.psm1 + TaskScheduler.psm1
```

---

## Testing Strategy

### Unit Tests

Each module should be tested independently:

1. **ConfigManager:**
   - Initialize-AppData with denied `%APPDATA%` access (verify fallback)
   - Add-RecentFolder with duplicate paths in different cases
   - Get-OutcomeLog with malformed log entries
   - Show-ErrorDialog before WPF loaded (verify Forms fallback)

2. **TaskScheduler:**
   - New-MotivationTask duplicate detection (same folder/day)
   - Get-MotivationTasks with manually deleted scheduler tasks
   - Network path detection (UNC and mapped drives)
   - Update-MotivationTaskStatus with partial updates

### Integration Tests

Test cross-module interactions:

1. Create task → Fire task → Popup reads config → Logs outcome
2. Add recent folder → Retrieve recent folders → Select from list
3. First run flow → Set first run complete → Verify flag persists
4. Delete task → Verify removal from both scheduler and JSON

---

## Troubleshooting

### Common Issues

**"Could not create AppData directory"**
- Check: User has write access to `%APPDATA%`
- Fallback: Module automatically tries `%TEMP%`
- See: `Initialize-AppData` in ConfigManager-API.md

**"Task not firing at scheduled time"**
- Check: Task Scheduler service is running
- Check: User is logged in (or `StartWhenAvailable` enabled)
- See: Task Scheduler settings in TaskScheduler-API.md

**"Duplicate task rejected"**
- Behavior: By design - one task per folder per day
- Override: Use `-Force` parameter
- See: Duplicate detection in TaskScheduler-API.md

**"Network path not accessible in task"**
- Check: Task should have `RunLevel Highest` (automatic for UNC/mapped drives)
- Check: Network path accessible when task fires
- See: Network path handling in TaskScheduler-API.md

### Debug Logging

Enable verbose output:

```powershell
$VerbosePreference = "Continue"

# ConfigManager will log:
# - Fallback directory usage
# - Malformed log entries

# TaskScheduler will log:
# - Scheduler task lookup failures
# - Access denied vs. not found errors
```

---

## Change Log

All documented changes are tracked in individual module documentation:

- **ConfigManager:** See "Change History" section in [ConfigManager-API.md](ConfigManager-API.md)
- **TaskScheduler:** See "Change History" section in [TaskScheduler-API.md](TaskScheduler-API.md)

Major changes:
- **ERR-034:** Centralized error dialog helper
- **GAP-003:** AppData fallback to TEMP
- **GAP-010:** Network path detection and elevation
- **B-16:** Duplicate task detection
- **FIX-003:** PowerShell 5.1 null array handling

---

## Contributing

When modifying modules:

1. **Update API documentation:** Reflect changes in corresponding `-API.md` file
2. **Document breaking changes:** Add to "Change History" section with reference code
3. **Add usage examples:** Show new functionality with clear code snippets
4. **Test edge cases:** Especially PowerShell 5.1 compatibility and error paths
5. **Follow error handling patterns:** Use `Show-ErrorDialog` for user errors, return safe defaults

---

## Additional Resources

- **Main Documentation:** `/docs/README.md`
- **Architecture:** `/docs/ARCHITECTURE.md` (if available)
- **Development Guide:** `/docs/DEVELOPMENT.md` (if available)
- **PowerShell Best Practices:** [Microsoft Docs](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)

---

## License

See project root for license information.

---

**Last Updated:** 2026-06-09
**PowerShell Version:** 5.1+
**Platform:** Windows 10/11, Server 2016+
