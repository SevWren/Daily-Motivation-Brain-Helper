# Customization Guide

**Last Updated:** 2026-06-09
**Version:** 1.1

---

## Table of Contents

1. [Configuration Files Overview](#1-configuration-files-overview)
2. [Customizing Messages](#2-customizing-messages)
3. [Changing Schedule Times](#3-changing-schedule-times)
4. [UI Customization](#4-ui-customization)
5. [Notification Settings](#5-notification-settings)
6. [Advanced Settings](#6-advanced-settings)
7. [Multiple Profiles](#7-multiple-profiles)
8. [Shell Extension](#8-shell-extension-future)
9. [Theme Customization](#9-theme-customization)
10. [Examples Gallery](#10-examples-gallery)

---

## 1. Configuration Files Overview

All configuration files are stored in `%APPDATA%\DailyMotivationBrainHelper\`. The application manages these files automatically, but you can customize them directly for advanced scenarios.

### File Structure

| File | Purpose | Safe to Edit? |
|------|---------|---------------|
| **messages.json** | Motivational message library | ✅ Yes |
| **app_settings.json** | User preferences and recent folders | ⚠️ Carefully |
| **tasks.json** | Active scheduled tasks | ❌ No — use app UI |
| **popup_config.json** | Current popup state | ❌ No — auto-managed |
| **popup_log.txt** | Task history log | ✅ Yes (view only) |

### File Locations Quick Access

```powershell
# Open config directory in Explorer
explorer "$env:APPDATA\DailyMotivationBrainHelper"

# View messages file
notepad "$env:APPDATA\DailyMotivationBrainHelper\messages.json"

# View settings file
notepad "$env:APPDATA\DailyMotivationBrainHelper\app_settings.json"

# View history log
notepad "$env:APPDATA\DailyMotivationBrainHelper\popup_log.txt"
```

---

## 2. Customizing Messages

### Message Format

Each motivational message in `messages.json` follows this structure:

```json
{
  "message_id": "unique-identifier",
  "glyph": "[+]",
  "title": "Your Title Here",
  "body": "Your motivational message body text.",
  "is_default": false,
  "created_at": "2026-06-09T14:00:00Z"
}
```

### Field Specifications

| Field | Type | Max Length | Description |
|-------|------|------------|-------------|
| `message_id` | string (UUID) | N/A | Unique identifier (use online UUID generator) |
| `glyph` | string | 5 chars | Icon/emoji shown in popup header |
| `title` | string | 60 chars | Popup title — short and punchy |
| `body` | string | 200 chars | Main motivational text |
| `is_default` | boolean | N/A | `true` for built-in messages (read-only) |
| `created_at` | datetime | N/A | ISO 8601 timestamp |

### Adding Custom Messages

**Step 1:** Open `messages.json`
```powershell
notepad "$env:APPDATA\DailyMotivationBrainHelper\messages.json"
```

**Step 2:** Add your message to the array:
```json
{
  "message_id": "custom-001",
  "glyph": "🚀",
  "title": "Launch Time",
  "body": "Today is the day you've been preparing for. Let's make it count.",
  "is_default": false,
  "created_at": "2026-06-09T10:30:00Z"
}
```

**Step 3:** Save and restart the app. Your message will be randomly selected for future popups.

### Example: Custom Message Pack

```json
[
  {
    "message_id": "focus-001",
    "glyph": "🎯",
    "title": "Deep Work Mode",
    "body": "Next 90 minutes: No email. No Slack. Just you and the work. Let's go.",
    "is_default": false,
    "created_at": "2026-06-09T10:00:00Z"
  },
  {
    "message_id": "energy-001",
    "glyph": "⚡",
    "title": "High Energy Hour",
    "body": "You have the energy right now. Channel it into this folder before it fades.",
    "is_default": false,
    "created_at": "2026-06-09T10:01:00Z"
  },
  {
    "message_id": "deadline-001",
    "glyph": "⏰",
    "title": "Deadline Approaching",
    "body": "The clock is ticking. Open this folder and chip away at what matters most.",
    "is_default": false,
    "created_at": "2026-06-09T10:02:00Z"
  }
]
```

### Glyph Options

Popular glyphs/emojis for motivation:

- **Brackets**: `[+]` `[>]` `[*]` `[-]` `[^]` `[#]` `[!]` `[~]` `[=]` `[o]`
- **Emojis**: `🚀` `⚡` `🎯` `💡` `🔥` `⭐` `✨` `💪` `🏆` `📈`
- **Unicode**: `▶` `●` `◆` `★` `◉` `⬤` `▸` `►` `⚙` `⚡`

---

## 3. Changing Schedule Times

### Default Schedule Time

The default schedule time is **2:00 PM** (14:00). This is hardcoded in the application logic but can be modified by editing the source files.

### Modify Default Time (Advanced)

**File:** `src/DailyMotivation.ps1` (or wherever your scheduling logic lives)

**Find this line:**
```powershell
$triggerTime = (Get-Date).Date.AddDays(1).AddHours(14)
```

**Change `14` to your preferred hour** (24-hour format):
```powershell
# For 9:00 AM
$triggerTime = (Get-Date).Date.AddDays(1).AddHours(9)

# For 6:00 PM
$triggerTime = (Get-Date).Date.AddDays(1).AddHours(18)

# For 10:30 AM (requires AddMinutes)
$triggerTime = (Get-Date).Date.AddDays(1).AddHours(10).AddMinutes(30)
```

### Modify "Today" Cutoff Time

By default, the "Today at 2:00 PM" option appears only before 2:00 PM.

**File:** `src/MainWindow.xaml` or associated PowerShell logic

**Find:**
```powershell
if ((Get-Date).Hour -lt 14) {
    $TodayRadio.Visibility = "Visible"
}
```

**Change `14` to your preferred cutoff hour:**
```powershell
# Show "Today" option until 9:00 AM
if ((Get-Date).Hour -lt 9) {
    $TodayRadio.Visibility = "Visible"
}
```

### Custom Snooze Durations

**File:** `src/DailyMotivation.ps1` (popup window logic)

**Find the snooze menu definition:**
```xaml
<ComboBoxItem Content="5 minutes" Tag="5"/>
<ComboBoxItem Content="15 minutes" Tag="15"/>
<ComboBoxItem Content="30 minutes" Tag="30"/>
<ComboBoxItem Content="1 hour" Tag="60"/>
```

**Add or modify entries:**
```xaml
<ComboBoxItem Content="2 minutes" Tag="2"/>
<ComboBoxItem Content="10 minutes" Tag="10"/>
<ComboBoxItem Content="45 minutes" Tag="45"/>
<ComboBoxItem Content="2 hours" Tag="120"/>
```

---

## 4. UI Customization

### MainWindow.xaml Overview

The main application window is defined in `src/MainWindow.xaml`. All visual customization happens here.

### Key UI Elements

| Element | Control Name | Purpose |
|---------|--------------|---------|
| Window background | `Background="#0D1117"` | Main dark background color |
| Accent bar | `Background="#00BCD4"` | Cyan accent strip at top |
| Primary buttons | `PrimaryBtn` style | "Schedule" button, action buttons |
| Secondary buttons | `SecondaryBtn` style | "Select Folder", utility buttons |
| Text labels | Various `TextBlock` | Folder names, timestamps, etc. |

### Changing Colors

**Current Color Scheme:**
```
Background:     #0D1117 (dark navy)
Primary Text:   #E8E8F4 (light grey)
Secondary Text: #8888A8 (medium grey)
Dim Text:       #4A4A6A (dark grey)
Accent:         #00BCD4 (cyan)
Borders:        #2A2A42 (subtle purple-grey)
```

**Example: Change to Purple Theme**

**Find and replace in MainWindow.xaml:**
```xml
<!-- OLD -->
<Setter Property="Background" Value="#00BCD4"/>

<!-- NEW -->
<Setter Property="Background" Value="#9B59B6"/>
```

**Apply throughout:**
- Accent bar: `Background="#00BCD4"` → `Background="#9B59B6"`
- Button backgrounds: `Background="#00BCD4"` → `Background="#9B59B6"`
- Borders: `BorderBrush="#00BCD4"` → `BorderBrush="#9B59B6"`

### Font Customization

**Change default font:**
```xml
<!-- OLD -->
<Window ... FontFamily="Segoe UI">

<!-- NEW -->
<Window ... FontFamily="Consolas">
<!-- or -->
<Window ... FontFamily="Arial">
```

**Change font sizes:**
```xml
<!-- Title -->
<TextBlock Text="Daily Motivation Brain Helper"
           FontSize="17"  <!-- Change to 20 for larger -->
           FontWeight="Bold" Foreground="#E8E8F4"/>

<!-- Body text -->
<TextBlock FontSize="12"  <!-- Change to 14 -->
           Foreground="#8888A8"/>
```

### Window Size

**Find in MainWindow.xaml:**
```xml
<Window
    Width="520" SizeToContent="Height"
    WindowStartupLocation="CenterScreen"
    ResizeMode="CanMinimize">
```

**Modify:**
```xml
<!-- Wider window -->
<Window Width="680" SizeToContent="Height" ...>

<!-- Fixed height (no auto-sizing) -->
<Window Width="520" Height="800" ...>

<!-- Resizable window -->
<Window Width="520" Height="600" ResizeMode="CanResize" ...>
```

---

## 5. Notification Settings

### Popup Behavior

The popup window behavior is controlled in `src/DailyMotivation.ps1`.

### Auto-Open Countdown

**Default:** Popup auto-opens folder after 20 seconds.

**File:** `src/DailyMotivation.ps1`

**Find:**
```powershell
$script:countdown = 20
```

**Change to your preference:**
```powershell
# 30 second countdown
$script:countdown = 30

# 10 second countdown
$script:countdown = 10

# Disable auto-open (set to very high value)
$script:countdown = 999999
```

### Popup Window Properties

**File:** `src/DailyMotivation.ps1` (or popup XAML)

```xml
<Window
    Title="Daily Motivation"
    Width="450"          <!-- Popup width -->
    Height="280"         <!-- Popup height -->
    Topmost="True"       <!-- Always on top -->
    WindowStyle="None"   <!-- Remove title bar -->
    Background="#0D1117">
```

**Customizations:**
```xml
<!-- Keep title bar -->
<Window WindowStyle="SingleBorderWindow" ...>

<!-- Not always on top -->
<Window Topmost="False" ...>

<!-- Larger popup -->
<Window Width="600" Height="350" ...>
```

### Fade-In Animation

**Default:** 300ms fade-in

**Find in PowerShell logic:**
```powershell
$fadeIn = New-Object System.Windows.Media.Animation.DoubleAnimation
$fadeIn.From = 0
$fadeIn.To = 1
$fadeIn.Duration = [TimeSpan]::FromMilliseconds(300)
```

**Modify duration:**
```powershell
# Faster (150ms)
$fadeIn.Duration = [TimeSpan]::FromMilliseconds(150)

# Slower (500ms)
$fadeIn.Duration = [TimeSpan]::FromMilliseconds(500)

# No animation
# Comment out or remove the BeginAnimation call
```

### Snooze Duration Defaults

**File:** `src/DailyMotivation.ps1`

**Default snooze:** 5 minutes

**Find:**
```powershell
$defaultSnoozeDuration = 5
```

**Change:**
```powershell
# Default to 15 minutes
$defaultSnoozeDuration = 15
```

---

## 6. Advanced Settings

### app_settings.json Reference

**Location:** `%APPDATA%\DailyMotivationBrainHelper\app_settings.json`

**Schema:**
```json
{
  "firstRun": false,
  "lastFolder": "D:\\Projects\\MyProject",
  "recentFolders": [
    "D:\\Projects\\MyProject",
    "D:\\Github\\my-repo",
    "D:\\Work\\ClientA"
  ],
  "theme": "dark"
}
```

### Field Descriptions

| Field | Type | Purpose | Default |
|-------|------|---------|---------|
| `firstRun` | boolean | Show welcome overlay on next launch | `true` |
| `lastFolder` | string | Path of most recently scheduled folder | `""` |
| `recentFolders` | array | Up to 5 recent folder paths (FIFO) | `[]` |
| `theme` | string | Reserved for future theme support | `"dark"` |

### Manual Edits

**Reset welcome screen:**
```json
{
  "firstRun": true
}
```

**Clear recent folders:**
```json
{
  "recentFolders": []
}
```

**Pre-populate recent folders:**
```json
{
  "recentFolders": [
    "C:\\Users\\YourName\\Documents\\ProjectA",
    "D:\\Code\\Repository",
    "C:\\Work\\ImportantFolder"
  ]
}
```

### Task History Configuration

**File:** `popup_log.txt`

**Format:**
```
[YYYY-MM-DD HH:mm:ss] | task_id | folder_name | folder_path | outcome | snooze_count
```

**Example entries:**
```
[2026-06-09 14:00:12] | a1b2c3 | ClientA | D:\Projects\ClientA | Opened | 0
[2026-06-09 14:35:07] | d4e5f6 | mc_game | D:\Github\mc_game | Snoozed | 3
[2026-06-09 14:00:00] | g7h8i9 | OldProject | D:\Archive\Old | Dismissed | 1
```

**Outcomes:**
- `Opened` — Folder was opened via "Open Folder" button
- `Snoozed` — Popup was snoozed (snooze_count shows total snoozes)
- `Dismissed` — "Dismiss for Today" was clicked
- `PathMissing` — Folder path no longer exists

**Viewing history:**
- Use the "View History" button in the main app
- Or open `popup_log.txt` directly in a text editor
- Or parse with PowerShell:
  ```powershell
  Get-Content "$env:APPDATA\DailyMotivationBrainHelper\popup_log.txt" | Select-Object -Last 30
  ```

---

## 7. Multiple Profiles

### Use Case

Run different configurations for work vs. personal projects, or share the app across multiple users with isolated settings.

### Strategy 1: Environment Variable Override

**Modify `ConfigManager.psm1`:**

```powershell
# Before (default):
$script:AppDataDir = Join-Path $env:APPDATA "DailyMotivationBrainHelper"

# After (profile-aware):
$profileName = if ($env:BRAIN_HELPER_PROFILE) { $env:BRAIN_HELPER_PROFILE } else { "Default" }
$script:AppDataDir = Join-Path $env:APPDATA "DailyMotivationBrainHelper_$profileName"
```

**Create shortcuts for different profiles:**

**Work Profile Shortcut:**
```batch
@echo off
set BRAIN_HELPER_PROFILE=Work
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\DailyMotivation.ps1"
```

**Personal Profile Shortcut:**
```batch
@echo off
set BRAIN_HELPER_PROFILE=Personal
powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\DailyMotivation.ps1"
```

**Result:**
- Work profile uses: `%APPDATA%\DailyMotivationBrainHelper_Work\`
- Personal profile uses: `%APPDATA%\DailyMotivationBrainHelper_Personal\`

### Strategy 2: Manual Directory Switching

**Create profile directories:**
```powershell
New-Item -ItemType Directory "$env:APPDATA\DailyMotivationBrainHelper_Work"
New-Item -ItemType Directory "$env:APPDATA\DailyMotivationBrainHelper_Personal"
```

**Copy base config to each:**
```powershell
Copy-Item "$env:APPDATA\DailyMotivationBrainHelper\*" "$env:APPDATA\DailyMotivationBrainHelper_Work\"
Copy-Item "$env:APPDATA\DailyMotivationBrainHelper\*" "$env:APPDATA\DailyMotivationBrainHelper_Personal\"
```

**Switch profiles by symlinking:**
```powershell
# Switch to Work profile
Remove-Item "$env:APPDATA\DailyMotivationBrainHelper" -Force -Recurse
New-Item -ItemType SymbolicLink -Path "$env:APPDATA\DailyMotivationBrainHelper" -Target "$env:APPDATA\DailyMotivationBrainHelper_Work"

# Switch to Personal profile
Remove-Item "$env:APPDATA\DailyMotivationBrainHelper" -Force -Recurse
New-Item -ItemType SymbolicLink -Path "$env:APPDATA\DailyMotivationBrainHelper" -Target "$env:APPDATA\DailyMotivationBrainHelper_Personal"
```

### Strategy 3: Separate Installations

**Install to different directories:**
- `C:\Program Files\DailyMotivation_Work\`
- `C:\Program Files\DailyMotivation_Personal\`

Each installation maintains its own `%APPDATA%` subdirectory automatically.

---

## 8. Shell Extension (Future)

### Overview

The shell extension (planned feature B-13) adds "Schedule for Tomorrow at 2 PM" to the Windows Explorer right-click context menu.

### Installation (When Available)

**Registry key location:**
```
HKEY_CLASSES_ROOT\Directory\shell\ScheduleMotivation
```

**Registry structure:**
```registry
[HKEY_CLASSES_ROOT\Directory\shell\ScheduleMotivation]
@="Schedule for Tomorrow at 2 PM"
"Icon"="C:\\Path\\To\\icon.ico"

[HKEY_CLASSES_ROOT\Directory\shell\ScheduleMotivation\command]
@="powershell.exe -ExecutionPolicy Bypass -File \"C:\\Path\\To\\ShellBridge.ps1\" \"%1\""
```

### Customizing Context Menu Text

**Change menu label:**
```registry
[HKEY_CLASSES_ROOT\Directory\shell\ScheduleMotivation]
@="📅 Open Tomorrow at 2 PM"
```

### Customizing Schedule Time

**Edit `ShellBridge.ps1`:**
```powershell
# Default (2 PM tomorrow)
$tomorrow = (Get-Date).Date.AddDays(1).AddHours(14)

# Custom (9 AM tomorrow)
$tomorrow = (Get-Date).Date.AddDays(1).AddHours(9)

# Today at 6 PM (if before 6 PM)
$target = if ((Get-Date).Hour -lt 18) {
    (Get-Date).Date.AddHours(18)
} else {
    (Get-Date).Date.AddDays(1).AddHours(18)
}
New-MotivationTask -FolderPath $args[0] -TriggerTime $target
```

---

## 9. Theme Customization

### Current Theme: Dark Cyber

**Color Palette:**
```
Primary Background:     #0D1117 (midnight navy)
Secondary Background:   #111B22 (dark slate)
Tertiary Background:    #1C1C2C (dark purple-grey)
Primary Text:           #E8E8F4 (light grey)
Secondary Text:         #8888A8 (medium grey)
Dim Text:               #4A4A6A (dark grey)
Accent:                 #00BCD4 (cyan blue)
Success:                #52B788 (green)
Border:                 #2A2A42 (subtle purple-grey)
```

### Creating a Light Theme

**Step 1: Open MainWindow.xaml**

**Step 2: Find and replace colors:**

```xml
<!-- Background colors -->
Find:    Background="#0D1117"
Replace: Background="#F5F5F5"

Find:    Background="#111B22"
Replace: Background="#FFFFFF"

Find:    Background="#1C1C2C"
Replace: Background="#E8E8E8"

<!-- Text colors -->
Find:    Foreground="#E8E8F4"
Replace: Foreground="#333333"

Find:    Foreground="#8888A8"
Replace: Foreground="#666666"

Find:    Foreground="#4A4A6A"
Replace: Foreground="#999999"

<!-- Accent (keep or adjust) -->
Find:    #00BCD4
Replace: #0078D4  (Microsoft blue)
```

### Pre-Made Theme: Warm Orange

```xml
<!-- MainWindow.xaml color replacements -->
Background (main):      #2B1B1B  (dark warm grey)
Background (secondary): #3D2424  (warm slate)
Primary Text:           #F5E6D3  (warm white)
Secondary Text:         #C4A57B  (warm tan)
Accent:                 #FF6B35  (vibrant orange)
Border:                 #5C3A2E  (warm brown)
Success:                #85D18A  (soft green)
```

### Pre-Made Theme: Cool Blue

```xml
<!-- MainWindow.xaml color replacements -->
Background (main):      #0F1419  (deep navy)
Background (secondary): #1A2332  (midnight blue)
Primary Text:           #E3F2FD  (ice blue)
Secondary Text:         #90CAF9  (light blue)
Accent:                 #42A5F5  (bright blue)
Border:                 #1E3A5F  (navy border)
Success:                #66BB6A  (green)
```

### Pre-Made Theme: Forest Green

```xml
<!-- MainWindow.xaml color replacements -->
Background (main):      #1B2A1F  (dark forest)
Background (secondary): #243428  (deep green)
Primary Text:           #E8F5E9  (pale green)
Secondary Text:         #A5D6A7  (light green)
Accent:                 #4CAF50  (vibrant green)
Border:                 #2E5339  (forest border)
Success:                #81C784  (success green)
```

### Button Style Customization

**Rounded corners:**
```xml
<!-- Find -->
<Border ... CornerRadius="6">

<!-- Make more rounded -->
<Border ... CornerRadius="12">

<!-- Make square -->
<Border ... CornerRadius="0">
```

**Button padding:**
```xml
<!-- Find -->
<Setter Property="Padding" Value="18,8"/>

<!-- Make larger -->
<Setter Property="Padding" Value="24,12"/>

<!-- Make compact -->
<Setter Property="Padding" Value="12,6"/>
```

---

## 10. Examples Gallery

### Example 1: Morning Standup Reminder

**Goal:** Get a motivating popup at 9:00 AM for your daily standup folder.

**Steps:**

1. **Change schedule time** in source:
   ```powershell
   # MainWindow.xaml.ps1 or scheduling logic
   $triggerTime = (Get-Date).Date.AddDays(1).AddHours(9)
   ```

2. **Create custom message:**
   ```json
   {
     "message_id": "standup-001",
     "glyph": "📢",
     "title": "Standup Time",
     "body": "Your team is waiting. Open the standup notes and share your wins.",
     "is_default": false,
     "created_at": "2026-06-09T08:00:00Z"
   }
   ```

3. **Schedule folder:**
   - Open app
   - Select: `D:\Work\StandupNotes`
   - Choose "Today at 9:00 AM" (if before 9 AM)
   - Click "Schedule"

**Result:** Every morning at 9:00 AM, popup shows standup message and opens your notes folder.

---

### Example 2: Focus Block for Deep Work

**Goal:** 3-hour deep work block from 10 AM - 1 PM with custom messages.

**Steps:**

1. **Create focus messages pack:**
   ```json
   [
     {
       "message_id": "focus-001",
       "glyph": "🎯",
       "title": "Deep Work Starts Now",
       "body": "No meetings. No distractions. Just you and the code. Let's build.",
       "is_default": false,
       "created_at": "2026-06-09T09:00:00Z"
     },
     {
       "message_id": "focus-002",
       "glyph": "🔥",
       "title": "Flow State Loading",
       "body": "The first 15 minutes are the hardest. Push through. Flow is waiting.",
       "is_default": false,
       "created_at": "2026-06-09T09:01:00Z"
     },
     {
       "message_id": "focus-003",
       "glyph": "⚡",
       "title": "Peak Brain Hours",
       "body": "Your brain is sharpest right now. Don't waste it on email.",
       "is_default": false,
       "created_at": "2026-06-09T09:02:00Z"
     }
   ]
   ```

2. **Change default schedule time to 10 AM:**
   ```powershell
   $triggerTime = (Get-Date).Date.AddHours(10)
   ```

3. **Disable auto-open countdown** (you decide when to open):
   ```powershell
   $script:countdown = 999999
   ```

4. **Schedule your deep work folder:**
   - `D:\Projects\CurrentSprint`

**Result:** At 10 AM, popup appears with a random focus message. Stays on screen until you click "Open Folder" when ready.

---

### Example 3: Client Project Rotation

**Goal:** Rotate through 3 client folders, different one each day.

**Steps:**

1. **Create PowerShell rotation script** (`RotatingScheduler.ps1`):
   ```powershell
   Import-Module "$PSScriptRoot\src\Modules\TaskScheduler.psm1"

   $clients = @(
       "D:\Clients\ClientA",
       "D:\Clients\ClientB",
       "D:\Clients\ClientC"
   )

   $dayOfWeek = (Get-Date).DayOfWeek
   $index = @{ Monday=0; Tuesday=1; Wednesday=2; Thursday=0; Friday=1 }[$dayOfWeek.ToString()]

   $tomorrow = (Get-Date).Date.AddDays(1).AddHours(14)
   New-MotivationTask -FolderPath $clients[$index] -TriggerTime $tomorrow

   Write-Host "Scheduled $($clients[$index]) for tomorrow at 2 PM"
   ```

2. **Schedule this script to run daily:**
   - Use Windows Task Scheduler
   - Trigger: Daily at 11:00 PM
   - Action: `powershell.exe -File "C:\Path\To\RotatingScheduler.ps1"`

**Result:** Each weekday, a different client folder is auto-scheduled for 2 PM the next day.

---

### Example 4: Motivational Streak Tracker

**Goal:** Track consecutive days of opening folders, show streak in message.

**Steps:**

1. **Create streak tracking script** (`UpdateMessages.ps1`):
   ```powershell
   $logPath = "$env:APPDATA\DailyMotivationBrainHelper\popup_log.txt"
   $log = Get-Content $logPath | Where-Object { $_ -match 'Opened' }

   # Count consecutive days
   $dates = $log | ForEach-Object {
       if ($_ -match '^\[(\d{4}-\d{2}-\d{2})') {
           [DateTime]$matches[1]
       }
   } | Sort-Object -Unique -Descending

   $streak = 0
   $yesterday = (Get-Date).Date.AddDays(-1)

   foreach ($date in $dates) {
       if ($date.Date -eq $yesterday) {
           $streak++
           $yesterday = $yesterday.AddDays(-1)
       } else {
           break
       }
   }

   # Update messages.json with streak message
   $messagesPath = "$env:APPDATA\DailyMotivationBrainHelper\messages.json"
   $messages = Get-Content $messagesPath | ConvertFrom-Json

   $streakMsg = @{
       message_id = "streak-dynamic"
       glyph = "🔥"
       title = "Streak: $streak Days"
       body = "You've shown up $streak days in a row. Don't break the chain today."
       is_default = $false
       created_at = (Get-Date).ToString("o")
   }

   # Replace or append
   $messages = @($messages | Where-Object { $_.message_id -ne "streak-dynamic" }) + $streakMsg
   $messages | ConvertTo-Json -Depth 3 | Set-Content $messagesPath
   ```

2. **Run script before each popup:**
   - Modify `DailyMotivation.ps1` to call `UpdateMessages.ps1` on launch

**Result:** Popup shows "Streak: 5 Days" with motivating message about maintaining consistency.

---

### Example 5: Network Path Support

**Goal:** Schedule network share folders (e.g., `\\server\projects\ClientA`).

**Current Limitation:** App primarily designed for local paths.

**Workaround:**

1. **Map network drive:**
   ```batch
   net use Z: \\server\projects /persistent:yes
   ```

2. **Schedule using mapped drive:**
   - Select folder: `Z:\ClientA`
   - Schedule normally

3. **Path validation** (modify `DailyMotivation.ps1`):
   ```powershell
   # Before opening
   if (-not (Test-Path $config.explorer_path)) {
       # Show "Folder Not Found" dialog
       # Offer to reconnect network drive
   }
   ```

**Alternative:** Modify `TaskScheduler.psm1` to accept UNC paths directly and include network availability checks.

---

### Example 6: Multi-Monitor Popup Positioning

**Goal:** Show popup on specific monitor (e.g., always on left monitor).

**Steps:**

1. **Modify popup window positioning** in `DailyMotivation.ps1`:
   ```powershell
   Add-Type -AssemblyName System.Windows.Forms

   # Get monitor bounds
   $monitors = [System.Windows.Forms.Screen]::AllScreens
   $leftMonitor = $monitors | Sort-Object { $_.Bounds.X } | Select-Object -First 1

   # Position window on left monitor, centered
   $window.Left = $leftMonitor.Bounds.X + ($leftMonitor.Bounds.Width - $window.Width) / 2
   $window.Top = $leftMonitor.Bounds.Y + ($leftMonitor.Bounds.Height - $window.Height) / 2
   ```

**Variations:**
- **Right monitor:** `Select-Object -Last 1`
- **Top-right corner:** `$window.Left = $monitor.Bounds.Right - $window.Width - 20; $window.Top = $monitor.Bounds.Top + 20`
- **Bottom-center:** `$window.Top = $monitor.Bounds.Bottom - $window.Height - 50`

---

### Example 7: Conditional Messages Based on Time

**Goal:** Show different messages for morning vs. afternoon vs. evening.

**Steps:**

1. **Create time-specific messages:**
   ```json
   [
     {
       "message_id": "morning-001",
       "glyph": "☀️",
       "title": "Morning Energy",
       "body": "Fresh start. Clear mind. This is your best work time.",
       "is_default": false,
       "created_at": "2026-06-09T06:00:00Z"
     },
     {
       "message_id": "afternoon-001",
       "glyph": "⚡",
       "title": "Post-Lunch Push",
       "body": "Beat the afternoon slump. 30 minutes of focus makes a difference.",
       "is_default": false,
       "created_at": "2026-06-09T13:00:00Z"
     },
     {
       "message_id": "evening-001",
       "glyph": "🌙",
       "title": "Evening Wrap-Up",
       "body": "Tie up loose ends. Tomorrow-you will thank today-you.",
       "is_default": false,
       "created_at": "2026-06-09T18:00:00Z"
     }
   ]
   ```

2. **Filter messages by time** in popup script:
   ```powershell
   $hour = (Get-Date).Hour
   $timeTag = if ($hour -lt 12) { "morning" }
              elseif ($hour -lt 18) { "afternoon" }
              else { "evening" }

   $messages = Get-Content $messagesPath | ConvertFrom-Json
   $filtered = $messages | Where-Object { $_.message_id -like "$timeTag-*" }

   if ($filtered.Count -gt 0) {
       $randomMessage = $filtered | Get-Random
   } else {
       $randomMessage = $messages | Get-Random
   }
   ```

**Result:** Morning schedules get morning messages, afternoon gets afternoon messages, etc.

---

### Example 8: Integration with Pomodoro Timer

**Goal:** After popup opens folder, automatically start a 25-minute Pomodoro timer.

**Steps:**

1. **Install a command-line Pomodoro tool:**
   - Example: `pomo` from https://github.com/kevinschoon/pomo
   - Or use Windows built-in: `timeout /t 1500` (25 minutes in seconds)

2. **Modify folder open action** in `DailyMotivation.ps1`:
   ```powershell
   # After explorer opens
   Start-Process explorer.exe $config.explorer_path

   # Start Pomodoro timer
   Start-Process -NoNewWindow -FilePath "pomo.exe" -ArgumentList "start -d 25m"
   # Or simple timeout
   # Start-Process -NoNewWindow -FilePath "cmd.exe" -ArgumentList "/c timeout /t 1500"

   # Show notification after timer completes
   # (requires background watcher script)
   ```

3. **Optional: Show completion notification:**
   ```powershell
   # PomodoroDone.ps1
   Add-Type -AssemblyName System.Windows.Forms
   $notify = New-Object System.Windows.Forms.NotifyIcon
   $notify.Icon = [System.Drawing.SystemIcons]::Information
   $notify.Visible = $true
   $notify.ShowBalloonTip(5000, "Pomodoro Complete", "Take a 5-minute break!", [System.Windows.Forms.ToolTipIcon]::Info)
   Start-Sleep -Seconds 6
   $notify.Dispose()
   ```

**Result:** Popup opens folder and immediately starts a 25-minute focus timer.

---

### Example 9: Weekly Project Review

**Goal:** Every Friday at 4 PM, open project review folder with specific message.

**Steps:**

1. **Create weekly scheduler script** (`WeeklyReview.ps1`):
   ```powershell
   Import-Module "$PSScriptRoot\src\Modules\TaskScheduler.psm1"
   Import-Module "$PSScriptRoot\src\Modules\ConfigManager.psm1"

   $dayOfWeek = (Get-Date).DayOfWeek

   if ($dayOfWeek -eq 'Thursday') {
       $tomorrow = (Get-Date).Date.AddDays(1).AddHours(16)  # Friday 4 PM
       New-MotivationTask -FolderPath "D:\Projects\WeeklyReview" -TriggerTime $tomorrow

       # Override message for this specific task
       $customMessage = @{
           glyph = "📊"
           title = "Weekly Review Time"
           body = "What went well? What needs improvement? Document it before you forget."
       }

       # Save to popup config (will be used by tomorrow's popup)
       Set-PopupConfig -Glyph $customMessage.glyph `
                       -Title $customMessage.title `
                       -Body $customMessage.body `
                       -ExplorerPath "D:\Projects\WeeklyReview" `
                       -TaskId (New-Guid).ToString()
   }
   ```

2. **Schedule script to run Thursdays:**
   - Windows Task Scheduler
   - Trigger: Weekly, Thursday, 11:00 PM
   - Action: Run `WeeklyReview.ps1`

**Result:** Every Friday at 4 PM, popup appears with weekly review message and opens review folder.

---

### Example 10: Emergency "Do It Now" Button

**Goal:** Instant popup for urgent folder access (bypass scheduling).

**Steps:**

1. **Create instant launcher** (`OpenNow.ps1`):
   ```powershell
   param([string]$FolderPath = $(Get-Location).Path)

   Import-Module "$PSScriptRoot\src\Modules\ConfigManager.psm1"

   # Pick random motivational message
   $messagesPath = "$env:APPDATA\DailyMotivationBrainHelper\messages.json"
   $messages = Get-Content $messagesPath | ConvertFrom-Json
   $randomMsg = $messages | Get-Random

   # Set popup config for immediate launch
   Set-PopupConfig -Glyph $randomMsg.glyph `
                   -Title $randomMsg.title `
                   -Body $randomMsg.body `
                   -ExplorerPath $FolderPath `
                   -TaskId "instant-$(Get-Date -Format 'yyyyMMddHHmmss')"

   # Launch popup immediately
   powershell.exe -WindowStyle Hidden -File "$PSScriptRoot\src\DailyMotivation.ps1"
   ```

2. **Create desktop shortcut:**
   - Right-click Desktop → New → Shortcut
   - Target: `powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\OpenNow.ps1" -FolderPath "D:\UrgentProject"`
   - Name: "🚨 Open Urgent Project NOW"

3. **Or add to Windows Run dialog:**
   - Create batch file: `C:\Windows\opennow.bat`
   - Contents:
     ```batch
     @echo off
     powershell.exe -ExecutionPolicy Bypass -File "C:\Path\To\OpenNow.ps1" -FolderPath "%CD%"
     ```
   - Usage: Open Run dialog (Win+R) → Type `opennow` → Enter

**Result:** Instant motivational popup + folder open, no scheduling required.

---

## Troubleshooting Customizations

### Issue: Changes to messages.json not appearing

**Solution:**
1. Ensure JSON is valid (use JSONLint.com to validate)
2. Restart the application
3. Check file encoding is UTF-8
4. Verify file path: `%APPDATA%\DailyMotivationBrainHelper\messages.json`

### Issue: UI colors not changing after editing XAML

**Solution:**
1. Ensure you saved MainWindow.xaml
2. Rebuild/restart the application
3. Clear any cached XAML (delete `.baml` files if present)
4. Verify hex color codes are correct (6 characters, no typos)

### Issue: Custom schedule time not working

**Solution:**
1. Check you're editing the correct file (not a backup/copy)
2. Ensure PowerShell script syntax is correct
3. Verify Task Scheduler has the updated trigger time:
   - Open Task Scheduler → Task Scheduler Library
   - Find `DailyMotivation_*` tasks
   - Check "Triggers" tab

### Issue: Popup not appearing at scheduled time

**Solution:**
1. Check Windows Task Scheduler for errors
2. Ensure PC is on and unlocked at trigger time
3. Verify Task Scheduler service is running
4. Check popup_log.txt for error messages
5. Test manually: Run `DailyMotivation.ps1` directly

### Issue: Recent folders not saving

**Solution:**
1. Check app_settings.json is writable (not read-only)
2. Verify folder path doesn't contain invalid characters
3. Check disk space on %APPDATA% drive
4. Review permissions on DailyMotivationBrainHelper folder

---

## Advanced: Scripting Configuration Changes

### Bulk Update Messages

```powershell
# Add 10 custom messages at once
$newMessages = 1..10 | ForEach-Object {
    @{
        message_id = "custom-$(New-Guid)"
        glyph = "⚡"
        title = "Message $_"
        body = "Custom motivational message number $_."
        is_default = $false
        created_at = (Get-Date).ToString("o")
    }
}

$messagesPath = "$env:APPDATA\DailyMotivationBrainHelper\messages.json"
$existing = Get-Content $messagesPath | ConvertFrom-Json
$combined = @($existing) + $newMessages
$combined | ConvertTo-Json -Depth 3 | Set-Content $messagesPath
```

### Backup Configuration

```powershell
# Backup all config files
$backupDir = "$HOME\Desktop\BrainHelper_Backup_$(Get-Date -Format 'yyyyMMdd')"
New-Item -ItemType Directory -Path $backupDir
Copy-Item "$env:APPDATA\DailyMotivationBrainHelper\*" $backupDir -Recurse
Write-Host "Backup saved to: $backupDir"
```

### Restore Configuration

```powershell
# Restore from backup
$backupDir = "$HOME\Desktop\BrainHelper_Backup_20260609"
Copy-Item "$backupDir\*" "$env:APPDATA\DailyMotivationBrainHelper\" -Force -Recurse
Write-Host "Configuration restored from: $backupDir"
```

---

## Further Reading

- **CONFIGURATION_SPEC.md** — Complete config file schema reference
- **DATA_MODEL.md** — All data structures and field types
- **UX_SPEC.md** — User interface design specifications
- **NOTIFICATION_ENGINE_SPEC.md** — Popup behavior and state machine
- **TASK_SCHEDULER_SPEC.md** — Windows Task Scheduler integration details
- **TROUBLESHOOTING.md** — Common issues and solutions

---

## Conclusion

This guide covers extensive customization options for Daily Motivation Brain Helper. For questions or feature requests, please open an issue on the project repository or consult the main documentation.

Remember: The best customization is the one that helps you show up consistently. Start simple, iterate as needed.

**Happy customizing!**

---

**Version History:**
- 1.1 (2026-06-09): Initial comprehensive guide with 10 example scenarios
- 1.0 (TBD): Original draft
