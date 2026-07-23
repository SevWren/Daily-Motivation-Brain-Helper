# User Reference

Quick-reference for configuration and popup behavior.

## Configuration file

Located at `%APPDATA%\DailyMotivationBrainHelper\config.json`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `default_trigger_hour` | integer 0–23 | `14` | Hour at which scheduled folders open (24-hour clock). `14` = 2:00 PM. |
| `task_warning_threshold` | integer ≥ 0 | `5` | The main window shows a warning when the number of pending tasks exceeds this value. |

Example — set trigger time to 9:00 AM:

```json
{ "default_trigger_hour": 9, "task_warning_threshold": 5 }
```

Changes take effect for the next folder you schedule. Existing tasks are not affected.

## Popup countdown

The popup shows a 20-second countdown. When it reaches zero the app behaves as if you clicked **Open Folder →** — Explorer opens and the popup closes.

To prevent auto-open, click **Snooze** or **Dismiss for Today** before the countdown reaches zero.

## Snooze durations

| Option | Delay |
|--------|-------|
| 5 min | 5 minutes |
| 15 min | 15 minutes |
| 30 min | 30 minutes |
| 1 hour | 60 minutes |

Each snooze schedules a new OS Task. The snooze count is recorded in the outcome log.

## Outcome log

Located at `%APPDATA%\DailyMotivationBrainHelper\popup_log.txt`.

| Outcome | Meaning |
|---------|---------|
| `Opened` | You (or the countdown) opened the folder |
| `Snoozed` | You snoozed the popup |
| `Dismissed` | You dismissed for today |
| `PathMissing` | The folder was gone; you closed without picking a new one |

The log rotates automatically when it exceeds 1 MB. Archive files older than 30 days are deleted.

## Developer reference

For CLI parameters, config file schemas, and function reference, see [`docs/reference/`](../../docs/reference/README.md).
