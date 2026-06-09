# ConfigManager API Documentation

## Module Overview

**Module Name:** ConfigManager.psm1
**Location:** `/src/Modules/ConfigManager.psm1`
**Purpose:** Manages all JSON configuration files in `%APPDATA%\DailyMotivationBrainHelper\` and provides centralized error handling for user-facing dialogs.

This module handles:
- Application data directory initialization with fallback support
- User settings persistence (first run, last folder, recent folders, theme)
- Task configuration management
- Outcome logging and retrieval
- Standardized error dialogs across all modules

**Key Design Patterns:**
- Automatic fallback to `%TEMP%` if `%APPDATA%` is unavailable (GAP-003)
- Path re-resolution on every `Initialize-AppData` call to support test environments (FIX-001)
- Case-insensitive folder path handling
- Defensive null/empty checks to prevent PowerShell 5.1 edge cases

---

## Configuration Files

The module manages these JSON files in `%APPDATA%\DailyMotivationBrainHelper\`:

| File | Purpose |
|------|---------|
| `app_settings.json` | User preferences (first run, last folder, recent folders, theme) |
| `tasks.json` | Array of scheduled motivation tasks |
| `popup_config.json` | Current popup display configuration |
| `messages.json` | Reserved for future use |
| `popup_log.txt` | Pipe-delimited outcome log |

---

## Public Functions

### Show-ErrorDialog

Shows a WPF MessageBox with a standardized "Error" title. Safe to call before or after the main window exists.

**Synopsis:**
```powershell
Show-ErrorDialog -Message <string> [-Title <string>]
```

**Parameters:**
- **Message** (string, mandatory): Error message to display to the user
- **Title** (string, optional): Dialog title (default: "Daily Motivation Brain Helper")

**Return Type:** None (void)

**Behavior:**
1. Attempts to show WPF MessageBox (`System.Windows.MessageBox`)
2. Falls back to Windows Forms MessageBox if WPF is not loaded
3. Falls back to stderr output if both UI frameworks fail

**Usage Example:**
```powershell
try {
    # Some operation that might fail
    Get-Content "C:\NonExistent.txt" -ErrorAction Stop
}
catch {
    Show-ErrorDialog -Message "Failed to load configuration: $_"
}
```

**Error Conditions:**
- Never throws exceptions (triple-fallback design ensures some output)
- Gracefully degrades through WPF → Forms → Console

---

### Initialize-AppData

Creates `%APPDATA%\DailyMotivationBrainHelper\` and default JSON files if absent. Falls back to `%TEMP%\DailyMotivationBrainHelper\` if `%APPDATA%` is unavailable.

**Synopsis:**
```powershell
Initialize-AppData
```

**Parameters:** None

**Return Type:** None (void)

**Behavior:**
1. Re-resolves all script-level paths from current `$env:APPDATA` value
2. Creates directory if missing (with fallback to `$env:TEMP` on permission denied)
3. Creates default JSON files if they don't exist:
   - `app_settings.json`: `{ firstRun: true, lastFolder: "", recentFolders: [], theme: "dark" }`
   - `tasks.json`: `[]`
   - `popup_config.json`: Blank configuration with empty strings

**Usage Example:**
```powershell
# Call at application startup
Initialize-AppData
```

**Error Conditions:**
- If `%APPDATA%` directory creation fails, warns and falls back to `%TEMP%`
- If `%TEMP%` also fails, exception propagates to caller

**Notes:**
- Must be called at every app startup
- Re-resolves paths on each call to support test environment redirects (FIX-001)
- Writes warning to console if fallback occurs (visible in logs/transcripts)

---

### Get-AppSettings

Retrieves the current application settings from `app_settings.json`.

**Synopsis:**
```powershell
Get-AppSettings
```

**Parameters:** None

**Return Type:** `[PSCustomObject]` with properties:
- **firstRun** (bool): Whether this is the user's first run
- **lastFolder** (string): Last folder path opened by the user
- **recentFolders** (array): Up to 5 recent folder paths (newest first)
- **theme** (string): UI theme preference ("dark" or "light")

**Usage Example:**
```powershell
$settings = Get-AppSettings
if ($settings.firstRun) {
    Write-Host "Welcome! This is your first run."
}
```

**Error Conditions:**
- If file read fails, returns default object with `firstRun = $true` and empty strings/arrays
- Never throws exceptions

---

### Save-AppSettings

Persists application settings to `app_settings.json`.

**Synopsis:**
```powershell
Save-AppSettings -Settings <PSCustomObject>
```

**Parameters:**
- **Settings** (PSCustomObject, mandatory): Settings object to save (typically from `Get-AppSettings`)

**Return Type:** None (void)

**Usage Example:**
```powershell
$settings = Get-AppSettings
$settings.theme = "light"
Save-AppSettings $settings
```

**Error Conditions:**
- File write failure propagates to caller (e.g., disk full, permission denied)

---

### Get-IsFirstRun

Checks whether this is the user's first run of the application.

**Synopsis:**
```powershell
Get-IsFirstRun
```

**Parameters:** None

**Return Type:** `[bool]` - `$true` if first run, `$false` otherwise

**Usage Example:**
```powershell
if (Get-IsFirstRun) {
    Show-WelcomeWizard
}
```

**Error Conditions:** None (internally uses `Get-AppSettings` which has safe defaults)

---

### Set-FirstRunComplete

Marks the first run as complete by setting `firstRun = $false`.

**Synopsis:**
```powershell
Set-FirstRunComplete
```

**Parameters:** None

**Return Type:** None (void)

**Usage Example:**
```powershell
# After completing onboarding
Set-FirstRunComplete
```

**Error Conditions:**
- File write failure propagates to caller

---

### Get-LastFolder

Retrieves the last folder path opened by the user.

**Synopsis:**
```powershell
Get-LastFolder
```

**Parameters:** None

**Return Type:** `[string]` - Last folder path, or empty string if none

**Usage Example:**
```powershell
$lastFolder = Get-LastFolder
if ($lastFolder) {
    # Pre-populate folder picker with last folder
}
```

**Error Conditions:** None (returns empty string on failure)

---

### Set-LastFolder

Saves the last folder path opened by the user.

**Synopsis:**
```powershell
Set-LastFolder -FolderPath <string>
```

**Parameters:**
- **FolderPath** (string, mandatory): Absolute path to the folder

**Return Type:** None (void)

**Usage Example:**
```powershell
Set-LastFolder -FolderPath "C:\Users\John\Documents\Project"
```

**Error Conditions:**
- File write failure propagates to caller

---

### Get-RecentFolders

Retrieves the list of recent folder paths (up to 5, newest first).

**Synopsis:**
```powershell
Get-RecentFolders
```

**Parameters:** None

**Return Type:** `[array]` - Array of folder path strings (may be empty)

**Usage Example:**
```powershell
$recent = Get-RecentFolders
foreach ($folder in $recent) {
    Write-Host "Recent: $folder"
}
```

**Error Conditions:** None (returns empty array on failure or if no recent folders exist)

**Notes:**
- Returns a proper array even if `recentFolders` is null/empty in JSON (FIX-002)

---

### Add-RecentFolder

Adds a folder to the recent list (FIFO, max 5, deduped, newest first).

**Synopsis:**
```powershell
Add-RecentFolder -FolderPath <string>
```

**Parameters:**
- **FolderPath** (string, mandatory): Absolute path to the folder

**Return Type:** None (void)

**Behavior:**
1. Removes existing entry with same path (case-insensitive comparison)
2. Prepends the new path to the list
3. Trims list to maximum 5 entries
4. Saves updated list to disk

**Usage Example:**
```powershell
Add-RecentFolder -FolderPath "C:\Users\John\Documents\Project"
```

**Error Conditions:**
- File write failure propagates to caller

**Notes:**
- Handles PowerShell 5.1 type quirks when `recentFolders` is null/empty (BUG-001, FIX-002)
- Case-insensitive deduplication using `StringComparison.OrdinalIgnoreCase`

---

### Get-PopupConfig

Retrieves the current popup configuration from `popup_config.json`.

**Synopsis:**
```powershell
Get-PopupConfig
```

**Parameters:** None

**Return Type:** `[PSCustomObject]` with properties:
- **glyph** (string): Display glyph (e.g., "[+]")
- **title** (string): Popup title
- **body** (string): Popup body text
- **explorer_path** (string): Absolute folder path to open
- **folder_name** (string): Display name of the folder
- **task_id** (string): Associated task ID

Returns `$null` if file read fails.

**Usage Example:**
```powershell
$config = Get-PopupConfig
if ($config) {
    Write-Host "Task: $($config.title)"
    Write-Host "Path: $($config.explorer_path)"
}
```

**Error Conditions:**
- Returns `$null` on file read failure or JSON parse error
- Never throws exceptions

---

### Set-PopupConfig

Writes popup configuration to `popup_config.json`.

**Synopsis:**
```powershell
Set-PopupConfig -Glyph <string> -Title <string> -Body <string> -ExplorerPath <string> -TaskId <string>
```

**Parameters:**
- **Glyph** (string, mandatory): Display glyph (e.g., "[+]")
- **Title** (string, mandatory): Popup title
- **Body** (string, mandatory): Popup body text
- **ExplorerPath** (string, mandatory): Absolute folder path to open
- **TaskId** (string, mandatory): Associated task ID

**Return Type:** None (void)

**Behavior:**
- Automatically extracts `folder_name` from `ExplorerPath` using `Split-Path -Leaf`
- Writes ordered JSON to `popup_config.json`

**Usage Example:**
```powershell
Set-PopupConfig `
    -Glyph "[+]" `
    -Title "Time to work on ProjectX!" `
    -Body "You scheduled this task for today." `
    -ExplorerPath "C:\Users\John\Projects\ProjectX" `
    -TaskId "abc123def4567890"
```

**Error Conditions:**
- File write failure propagates to caller

---

### Write-OutcomeLog

Writes a structured pipe-delimited log entry to `popup_log.txt`.

**Synopsis:**
```powershell
Write-OutcomeLog -TaskId <string> -FolderName <string> -FolderPath <string> -Outcome <string> [-SnoozeCount <int>]
```

**Parameters:**
- **TaskId** (string, mandatory): Task identifier
- **FolderName** (string, mandatory): Display name of the folder
- **FolderPath** (string, mandatory): Absolute folder path
- **Outcome** (string, mandatory): One of: `Opened`, `Snoozed`, `Dismissed`, `PathMissing`
- **SnoozeCount** (int, optional): Number of times snoozed (default: 0)

**Return Type:** None (void)

**Log Format:**
```
[YYYY-MM-DD HH:mm:ss] | task_id | folder_name | folder_path | outcome | snooze_count
```

**Usage Example:**
```powershell
Write-OutcomeLog `
    -TaskId "abc123def4567890" `
    -FolderName "ProjectX" `
    -FolderPath "C:\Users\John\Projects\ProjectX" `
    -Outcome "Opened" `
    -SnoozeCount 2
```

**Error Conditions:**
- File write failures are silently ignored (`-ErrorAction SilentlyContinue`)
- This ensures logging never crashes the application

---

### Get-OutcomeLog

Returns parsed log entries as objects, newest first, max 30 entries by default.

**Synopsis:**
```powershell
Get-OutcomeLog [-Limit <int>]
```

**Parameters:**
- **Limit** (int, optional): Maximum number of entries to return (default: 30)

**Return Type:** `[array]` of `[PSCustomObject]` with properties:
- **Timestamp** (string): "YYYY-MM-DD HH:mm:ss"
- **TaskId** (string)
- **FolderName** (string)
- **FolderPath** (string)
- **Outcome** (string): `Opened`, `Snoozed`, `Dismissed`, `PathMissing`
- **SnoozeCount** (int)

**Usage Example:**
```powershell
$log = Get-OutcomeLog -Limit 10
foreach ($entry in $log) {
    Write-Host "$($entry.Timestamp): $($entry.Outcome) - $($entry.FolderName)"
}
```

**Error Conditions:**
- Returns empty array if log file doesn't exist or is empty
- Skips malformed lines with verbose warning (ERR-005)
- Never throws exceptions

**Notes:**
- Guards against null/empty arrays before reversing (UB-003)
- Only processes lines starting with `[` (timestamp format)

---

### Clear-OutcomeLog

Clears all entries from `popup_log.txt`.

**Synopsis:**
```powershell
Clear-OutcomeLog
```

**Parameters:** None

**Return Type:** None (void)

**Usage Example:**
```powershell
Clear-OutcomeLog
```

**Error Conditions:**
- File write failures are silently ignored (`-ErrorAction SilentlyContinue`)

---

## Script-Level Variables

These variables are internal to the module and not directly accessible:

| Variable | Purpose |
|----------|---------|
| `$script:AppDataDir` | `%APPDATA%\DailyMotivationBrainHelper` or fallback path |
| `$script:ConfigPath` | Full path to `popup_config.json` |
| `$script:TasksPath` | Full path to `tasks.json` |
| `$script:MessagesPath` | Full path to `messages.json` |
| `$script:SettingsPath` | Full path to `app_settings.json` |
| `$script:LogPath` | Full path to `popup_log.txt` |

---

## Error Handling Strategy

1. **User-facing errors:** Use `Show-ErrorDialog` for all user-visible errors
2. **Silent failures:** Logging functions use `-ErrorAction SilentlyContinue`
3. **Safe defaults:** Getter functions return empty/default values instead of throwing
4. **Fallback paths:** `Initialize-AppData` automatically falls back to `%TEMP%` (GAP-003)
5. **Path re-resolution:** Paths are re-calculated on `Initialize-AppData` to support test environments (FIX-001)

---

## Dependencies

- **PowerShell Version:** 5.1+
- **Assemblies:**
  - `System.Windows` (WPF, optional - falls back if unavailable)
  - `System.Windows.Forms` (optional - secondary fallback)
- **Filesystem:** Requires read/write access to `%APPDATA%` or `%TEMP%`

---

## Related Modules

- **TaskScheduler.psm1:** Consumes `tasks.json` and uses `Show-ErrorDialog`
- **Popup.ps1:** Calls `Get-PopupConfig`, `Write-OutcomeLog`
- **MainWindow.ps1:** Calls `Initialize-AppData`, settings functions, recent folders API

---

## Change History

| Reference | Description |
|-----------|-------------|
| ERR-034 | Centralized error dialog helper (`Show-ErrorDialog`) |
| GAP-003 | Fallback to `%TEMP%` if `%APPDATA%` unavailable |
| FIX-001 | Re-resolve paths in `Initialize-AppData` for test compatibility |
| BUG-001 | Fixed `recentFolders` null/empty handling in PowerShell 5.1 |
| FIX-002 | Explicit List construction in `Add-RecentFolder` |
| UB-003 | Guard against null/empty before reversing in `Get-OutcomeLog` |
| ERR-005 | Log malformed lines with verbose warning |

---

## Testing Recommendations

1. **Fallback behavior:** Temporarily deny write access to `%APPDATA%` and verify fallback to `%TEMP%`
2. **Recent folders:** Test deduplication with same path in different cases
3. **Log parsing:** Create malformed log entries and verify `Get-OutcomeLog` skips them gracefully
4. **First run:** Delete `app_settings.json` and verify `Get-IsFirstRun` returns `$true`
5. **Error dialogs:** Call `Show-ErrorDialog` before and after loading WPF to test fallback logic
