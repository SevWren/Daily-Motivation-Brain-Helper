# Architecture

## System Overview

```
┌─────────────────────────────────────────────────────┐
│                   Main Application                   │
│                                                      │
│  ┌──────────────┐    ┌──────────────────────────┐   │
│  │ Folder Picker│    │   Task Manager UI         │   │
│  │   Module     │    │  (View / Delete Tasks)    │   │
│  └──────┬───────┘    └────────────┬─────────────┘   │
│         │                         │                  │
│  ┌──────▼─────────────────────────▼─────────────┐   │
│  │           Task Scheduler Module               │   │
│  │     (Windows Task Scheduler API wrapper)      │   │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘

At Scheduled Time (2 PM):

┌──────────────────────────────────┐
│      Notification Engine         │
│  ┌────────────────────────────┐  │
│  │   Motivational Popup (WPF) │  │
│  │  [Open Folder] [Snooze]    │  │
│  └──────┬─────────────┬───────┘  │
│         │             │          │
│    ┌────▼────┐   ┌────▼──────┐  │
│    │Explorer │   │Snooze     │  │
│    │Launcher │   │Engine     │  │
│    └─────────┘   └───────────┘  │
└──────────────────────────────────┘
```

## Modules

| Module | Responsibility |
|--------|---------------|
| Folder Picker Module | Native folder selection dialog |
| Task Scheduler Module | Create/delete Windows Scheduled Tasks |
| Notification Engine | WPF popup display and lifecycle |
| Snooze Engine | 5-minute re-trigger logic |
| Explorer Launcher | Open Windows Explorer at target path |
| Motivation Repository | Store and serve motivational messages |
| Configuration Manager | Read/write local config (popup_config.json) |

## Technology Stack
- Language: PowerShell 5.1 / C# (.NET Framework 4.x)
- UI: WPF (Windows Presentation Foundation)
- Scheduling: Windows Task Scheduler (schtasks / COM API)
- Config: JSON (managed by app, never edited by user)

## Status
> DRAFT
