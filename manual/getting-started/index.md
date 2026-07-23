# Getting Started

## Prerequisites

- Windows 10 or Windows 11
- .NET Framework 4.5 or higher (included with Windows 10/11 by default)
- Windows Task Scheduler service running (enabled by default on Windows)

No installation is required beyond downloading the exe.

## Download

Download `DailyMotivation.exe` from the [Releases](https://github.com/SevWren/Daily-Motivation-Brain-Helper/releases) page. It is a single self-contained file — no installer, no companion files.

## First run

1. Double-click `DailyMotivation.exe`. The main window opens.
2. Drop a folder into the drop zone, or click **Select Folder** to browse to a folder you want to open at a scheduled time.
3. Choose **Today** or **Tomorrow** at the configured trigger time (default: 2:00 PM).
4. Click **Schedule**. A green confirmation banner appears with a 30-second undo window.

That's it. You can close the app — the popup will still fire at the scheduled time because Windows Task Scheduler handles the trigger.

## When the popup fires

At the scheduled time a dark floating window appears with:

- A **motivational message** (one of 10 rotating messages, chosen at schedule time)
- The **folder name** being opened
- A **20-second countdown** — when it reaches zero, the folder opens automatically

Your choices:

| Button | What it does |
|--------|--------------|
| **Open Folder →** | Opens Explorer at your folder immediately |
| **Snooze** | Reschedules for 5, 15, 30, or 60 minutes from now |
| **Dismiss for Today** | Cancels all pending reminders for this folder today |

## Change the trigger time

The default trigger time is 2:00 PM (hour 14). To change it, edit `config.json` in `%APPDATA%\DailyMotivationBrainHelper\`:

```json
{ "default_trigger_hour": 9, "task_warning_threshold": 5 }
```

Set `default_trigger_hour` to any value from `0` (midnight) to `23` (11 PM). The change takes effect for the next folder you schedule.

## Next steps

- [Schedule a folder step by step](../guides/how-to-schedule-folder.md)
- [Use the right-click context menu](../guides/context-menu.md)
- [Common errors](../troubleshooting/common-errors.md)
