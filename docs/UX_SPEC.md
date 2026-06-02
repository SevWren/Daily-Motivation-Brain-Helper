# UX Specification

## Design Principles
1. **Zero learning curve** — if a user needs to read instructions, the UI has failed
2. **3-click max** — any core action completes in 3 clicks or fewer
3. **No jargon** — no technical terms in any user-facing text

## Main Application Window

### Screen: Home
```
┌─────────────────────────────────┐
│   Daily Motivation Brain Helper │
├─────────────────────────────────┤
│                                 │
│   [  Select Folder  ]           │
│   No folder selected            │
│                                 │
│   [ Schedule For Tomorrow ]     │
│                                 │
├─────────────────────────────────┤
│   Scheduled Tasks               │
│   (none)                        │
│                                 │
│   [ Manage Messages ]           │
└─────────────────────────────────┘
```

### Screen: Folder Selected
After folder picker confirms:
- Folder path shown in plain text (e.g., "D:\Projects\ClientA")
- "Schedule For Tomorrow" button becomes active
- Confirmation message: "Ready to schedule for tomorrow at 2 PM"

### Screen: Scheduled
After scheduling:
- Success banner: "Scheduled! Your folder will open tomorrow at 2 PM."
- Task appears in Scheduled Tasks list

## Popup Window

```
┌────────────────────────────────────┐
│ ⚡  Time to Show Up                │
├────────────────────────────────────┤
│ Every great outcome starts with    │
│ showing up. Let's make this        │
│ session count.                     │
│                                    │
│ Auto-opening in 20s                │
│                                    │
│        [ Snooze ]  [ Open Folder ] │
└────────────────────────────────────┘
```

## Accessibility
- Minimum font size: 13px
- All buttons keyboard-navigable
- High contrast background (#14141F with #E8E8F4 text)
- All interactive elements have visible focus states

## Status
> DRAFT
