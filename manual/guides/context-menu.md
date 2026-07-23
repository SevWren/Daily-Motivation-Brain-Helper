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

The context menu entry is re-registered each time you schedule successfully — it cannot be disabled from within the app. To remove it manually:

1. Open `regedit`.
2. Navigate to `HKCU\Software\Classes\Directory\shell\`.
3. Delete the `ScheduleMotivation` key.

The entry will be re-added the next time you schedule a folder through the main window.
