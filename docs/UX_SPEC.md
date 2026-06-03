# UX Specification

**Last Updated:** 2026-06-03

## Design Principles
1. **Zero learning curve** — if a user needs to read instructions, the UI has failed
2. **3-click max** — any core action completes in 3 clicks or fewer
3. **No jargon** — no technical terms in any user-facing text
4. **Self-explaining** — every control has a tooltip (B-19)

---

## First-Run Welcome Overlay (B-07)
Shown once, on initial launch only. Fullscreen semi-transparent overlay:

```
┌────────────────────────────────────────────┐
│                                            │
│   👋  Welcome to Daily Motivation          │
│       Brain Helper                         │
│                                            │
│   Here's how it works:                     │
│                                            │
│   📁  Pick your working folder             │
│   ⏰  Schedule it for 2 PM tomorrow        │
│   🚀  At 2 PM, a popup opens it for you   │
│                                            │
│   That's it. No settings. No code.         │
│                                            │
│          [ Got it — Let's Go! ]            │
│                                            │
└────────────────────────────────────────────┘
```

---

## Main Application Window

### Home Screen (full state)
```
┌──────────────────────────────────────────────┐
│  Daily Motivation Brain Helper               │
├──────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐ │
│ │ 💡 Schedule same as last time?           │ │  ← B-01 banner
│ │ D:\Projects\ClientA  [Yes, Schedule] [✕] │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│  ┌─────────────────────────────────────┐    │
│  │  Drop a folder here, or...          │    │  ← B-09 drag zone
│  │  [ Select Folder ]                  │    │
│  │  No folder selected                 │    │
│  └─────────────────────────────────────┘    │
│                                              │
│  Schedule for:                               │
│  ○ Today at 2:00 PM   ● Tomorrow at 2:00 PM  │  ← B-03 (Today visible before 14:00)
│                                              │
│  [ Schedule  ]   (disabled until folder set) │
│                                              │
├──────────────────────────────────────────────┤
│  Recent Folders                              │  ← B-02
│  📁 ClientA        D:\Projects\ClientA  [→] │
│  📁 mc_game        D:\Github\mc_game    [→] │
│  📁 OldProject     D:\Archive\Old       [→] │
├──────────────────────────────────────────────┤
│  Scheduled Tasks                             │
│  (none)                                      │
│  [ View History ]                            │  ← B-18
└──────────────────────────────────────────────┘
```

### After Scheduling — Undo Banner (B-04)
```
┌──────────────────────────────────────────────┐
│ ✓ Scheduled for tomorrow at 2:00 PM  [Undo]  │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░░░░░  18s remaining │
└──────────────────────────────────────────────┘
```

---

## Popup Window (Updated)
```
┌────────────────────────────────────────────┐
│ ⚡  Time to Show Up                        │
├────────────────────────────────────────────┤
│ Every great outcome starts with showing    │
│ up. Let's make this session count.         │
│                                            │
│ Opening: ClientA              ← B-12       │
│                                            │
│ Auto-opening in 20s                        │
│                                            │
│ [Dismiss for Today]  [Snooze 5min ▾] [Open]│
│      ↑ B-11               ↑ B-10           │
└────────────────────────────────────────────┘
```

### Snooze Dropdown (B-10)
```
                        ┌──────────────┐
                        │ ● 5 minutes  │
                        │ ○ 15 minutes │
                        │ ○ 30 minutes │
                        │ ○ 1 hour     │
                        └──────────────┘
```

### Missing Path State (B-05)
```
┌────────────────────────────────────────────┐
│ ⚠️  Folder Not Found                       │
├────────────────────────────────────────────┤
│ This folder was moved or deleted.          │
│                                            │
│ The folder you scheduled is no longer      │
│ at the saved location.                     │
│                                            │
│   [Choose New Location]    [Dismiss]       │
└────────────────────────────────────────────┘
```

---

## History Panel (B-18)
```
┌────────────────────────────────────────────┐
│  History                          [Clear]  │
├────────────────────────────────────────────┤
│ 2026-06-03  ClientA    ✅ Opened           │
│ 2026-06-02  mc_game    💤 Snoozed 3x       │
│ 2026-06-01  OldProject ✖ Dismissed         │
│ 2026-05-31  ClientA    ✅ Opened           │
└────────────────────────────────────────────┘
```

---

## Tooltip Specification (B-19)

| Control | Tooltip Text |
|---------|-------------|
| Select Folder button | "Choose the folder you want to open tomorrow at 2 PM" |
| Drop zone | "Drag a folder from Windows Explorer and drop it here" |
| Today radio button | "Schedule this folder to open today at 2 PM" |
| Tomorrow radio button | "Schedule this folder to open tomorrow at 2 PM" |
| Schedule button | "Create a reminder to open this folder at the scheduled time" |
| Yes, Schedule (last folder banner) | "Schedule the same folder you used last time" |
| Schedule Again (recent folders) | "Schedule this folder for the selected time" |
| Delete task button | "Remove this scheduled task permanently" |
| View History | "See a log of your past folder openings" |
| Undo button | "Cancel the schedule you just created" |
| Open Folder (popup) | "Close this popup and open the folder now" |
| Snooze (popup) | "Remind me again after the selected amount of time" |
| Dismiss for Today (popup) | "Close this reminder for the rest of today" |

---

## Accessibility
- Minimum font size: 13px
- All buttons keyboard-navigable (Tab order defined)
- High contrast background (#14141F, #E8E8F4 text)
- All interactive elements have visible focus states
- Tooltips appear within 1 second of hover (AC-018)

## Status
> v1.1 DRAFT
