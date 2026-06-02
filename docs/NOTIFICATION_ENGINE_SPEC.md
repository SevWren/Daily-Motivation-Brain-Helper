# Notification Engine Specification

## Overview
The Notification Engine manages the motivational popup lifecycle from display through acceptance or snooze.

## Popup States

```
HIDDEN → DISPLAYED → ACCEPTED (terminal)
                  ↘ SNOOZED → DISPLAYED (loop)
```

## Display Rules
- Only one popup may exist at a time (SSOT-006)
- Popup appears topmost, centered on primary screen
- Popup fades in over 300ms
- Popup starts auto-close countdown at 20 seconds (auto-accepts if countdown reaches 0)

## Countdown Behavior
- CountdownText decrements every second
- At 0: equivalent to clicking "Open Folder"
- Countdown resets on each snooze re-display

## Button Behavior

| Button | Action |
|--------|--------|
| Open Folder | Stop countdown, set openExplorer=true, close popup |
| Snooze | Stop countdown, set openExplorer=false, close popup, reschedule in 5 min |

## Post-Close Actions
- If openExplorer=true: launch `explorer.exe {folder_path}`
- Write outcome to `popup_log.txt`

## WPF Implementation Notes
- Must run in STA (Single-Threaded Apartment) mode
- Requires `-STA` flag when launched via PowerShell
- Window style: None (borderless), AllowsTransparency: True

## Status
> DRAFT
