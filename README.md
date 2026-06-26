# Daily Motivation Brain Helper

A Windows 10/11 desktop utility that pops up a motivational message and opens a chosen folder in Windows Explorer at a scheduled time — helping you start focused work sessions without friction.

---

## What It Does

You pick a folder (a project, a document library, a workspace) and schedule it to open automatically at a specific time. When the time arrives, a sleek dark popup appears with a motivational message. One click and your folder is already open — no hunting, no excuses.

---

## User Experience

### Scheduling a Folder

1. **Double-click `DailyMotivation.exe`** to open the main window.
2. **Drop a folder** into the drop zone, or click **Select Folder** to browse.
3. Choose **Today** or **Tomorrow** at your configured time (default: 2:00 PM).
4. Click **Schedule**. A green confirmation banner appears with a 30-second undo option.

The folder is now registered with Windows Task Scheduler. You can close the app entirely — the popup will still fire at the right time.

### When the Popup Fires

At the scheduled time, a dark floating popup appears in the center of your screen with:

- A **motivational message** (10 rotating messages, one picked at random)
- The **folder name** being opened
- A **20-second countdown** that auto-opens the folder when it reaches zero

You have three choices:
- **Open Folder →** — open Explorer immediately (primary action)
- **Snooze** — reschedule for 5 / 15 / 30 minutes / 1 hour from now
- **Dismiss for Today** — cancel today's reminder

### Right-Click Context Menu

After your first successful schedule, a **"Set as tomorrow's folder"** option appears when you right-click any folder in Windows Explorer. This lets you schedule without opening the main app at all.

### History

Click **View History** in the main window to see a log of your last 30 popup outcomes (Opened, Dismissed, Snoozed, Path Missing) with timestamps.

---

## Execution Modes

| Invocation | Mode | When it runs |
|---|---|---|
| `DailyMotivation.exe` | Main UI | You double-click the exe |
| `DailyMotivation.exe /popup` | Popup notification | Windows Task Scheduler fires |
| `DailyMotivation.exe /setfolder "C:\path"` | Context menu handler | Explorer right-click verb |

---

## Configuration

App data is stored in `%APPDATA%\DailyMotivationBrainHelper\`:

| File | Purpose |
|---|---|
| `config.json` | `default_trigger_hour` (0–23), `task_warning_threshold` |
| `tasks.json` | Active scheduled tasks |
| `popup_config.json` | Message and folder for the next popup |
| `popup_log.txt` | Pipe-delimited outcome history |

To change the trigger time to 9:00 AM, edit `config.json`:
```json
{ "default_trigger_hour": 9, "task_warning_threshold": 5 }
```

---

## Build from Source

**Requirements:** Windows 10/11, PowerShell 7, .NET Framework 4.5+

```powershell
# 1. Install ps2exe (once)
Install-Module ps2exe -Scope CurrentUser

# 2. Compile
.\build.ps1
```

Output: a single self-contained `DailyMotivation.exe`. No companion files required.

---

## Run Tests

```powershell
# Install Pester (once)
Install-Module Pester -Force -SkipPublisherCheck

# Run all tests
.\Invoke-Tests.ps1

# CI mode (exit code + XML reports)
.\Invoke-Tests.ps1 -CI
```

Tests dot-source the script with `-NoRun` — no compiled exe required.

---

## Requirements

- Windows 10 or Windows 11
- .NET Framework 4.5 or higher (included with Windows 10+)
- Windows Task Scheduler service must be running

---

## License

MIT — see [LICENSE](LICENSE)
