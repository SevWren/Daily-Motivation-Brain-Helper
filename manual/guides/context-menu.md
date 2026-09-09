# Using the right-click context menu

After your first successful schedule, Daily Motivation Brain Helper registers a right-click verb in Windows Explorer. This lets you schedule any folder for tomorrow without opening the main app.

## Setup

The context menu entry **"Set as tomorrow's folder (Daily Motivation)"** is registered automatically when you schedule a folder for the first time through the main window. No manual setup is required.

> The entry is registered under `HKCU\Software\Classes\Directory\shell\ScheduleMotivation` — no administrator rights needed.

## How to use it

1. In Windows Explorer, right-click any folder.
2. Select **"Set as tomorrow's folder (Daily Motivation)"** from the context menu.
3. The app runs silently in setfolder mode, schedules the folder for tomorrow at the configured trigger hour, and shows a small confirmation dialog.
4. Click **OK** to dismiss. Done — no main window opens.

## What gets scheduled

The context menu always schedules for **tomorrow** at the `default_trigger_hour` from `config.json` (default: 2:00 PM). To schedule for today or a different time, use the main window instead.

## Removing the context menu entry

Run `DailyMotivation.exe /uninstall` from a command prompt. This removes
the "Set as tomorrow's folder (Daily Motivation)" entry and shows a
confirmation dialog. It only removes the context menu entry - your
scheduled reminders and settings are untouched.

The entry will be re-added automatically the next time you launch the app
in main mode, or the next time you schedule a folder through the main
window - both self-heal the registry key if it's missing.
