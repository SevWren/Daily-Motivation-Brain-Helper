# How to schedule a folder

This guide walks through scheduling a folder to open automatically at your configured trigger time.

## Steps

### 1. Open the app

Double-click `DailyMotivation.exe`. The main window opens immediately — no splash screen or startup dialogs.

### 2. Pick a folder

**Option A — Drag and drop:** Drag any folder from Windows Explorer and drop it onto the drop zone in the main window.

**Option B — Browse:** Click **Select Folder** and use the folder picker to browse to the folder you want.

The folder path appears in the main window once selected.

### 3. Choose Today or Tomorrow

Click **Today** to schedule for the current day at the trigger hour (e.g. 2:00 PM), or **Tomorrow** for the next day.

> If the trigger time for today has already passed, use **Tomorrow** or change the `default_trigger_hour` in `config.json`.

### 4. Click Schedule

Click the **Schedule** button. A green confirmation banner appears:

- The folder is now registered with Windows Task Scheduler.
- An **Undo** button with a 30-second countdown lets you cancel immediately if you change your mind.

### 5. Close the app (optional)

You can close the main window. The popup will still fire at the scheduled time — Windows Task Scheduler runs independently of the app.

## What happens at trigger time

At the scheduled time, Windows Task Scheduler launches the app in popup mode. A dark floating window appears on screen with your motivational message and a 20-second countdown. See [Getting Started](../getting-started/index.md) for the popup button options.

## Scheduling the same folder twice

By default, scheduling the same folder for the same date is blocked (duplicate detection). A confirmation dialog asks if you want to schedule it anyway. Click **Yes** to force-schedule; the second reminder gets its own unique Task Scheduler entry.

## Scheduling a network path

You can schedule a UNC path (`\\server\share`) or a mapped drive. A warning dialog appears immediately after scheduling to remind you the path may be unavailable at trigger time if the network is unreachable.

## Viewing scheduled folders

All scheduled folders appear in the main window task list with their status (`PENDING`, `COMPLETED`, `FAILED`, `DELETED`). Click **Refresh** to sync statuses from Windows Task Scheduler.

## Undoing a schedule

Click the **Undo** button in the green confirmation banner within 30 seconds to remove the task immediately. After that window closes, use the task list to select and delete the entry manually.
