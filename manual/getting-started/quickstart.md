# Quickstart — What happens next

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
