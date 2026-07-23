# Installation

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

## Next steps

- [What happens when the popup fires](quickstart.md)
- [Schedule a folder step by step](../guides/how-to-schedule-folder.md)
- [Use the right-click context menu](../guides/context-menu.md)
