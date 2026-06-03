# Notification Engine Specification

**Last Updated:** 2026-06-03

## Overview
Manages the motivational popup lifecycle from display through acceptance, snooze, or dismissal.

## Popup States

```
HIDDEN → DISPLAYED → ACCEPTED (terminal)
                  ↘ SNOOZED → DISPLAYED (loop, B-10 duration)
                  ↘ DISMISSED (terminal, B-11)
                  ↘ PATH_MISSING → RE_PICK (B-05)
                        ↘ NEW_PATH_ACCEPTED (terminal)
                        ↘ DISMISSED (terminal)
```

## Display Rules
- Only one popup may exist at a time — enforced by named mutex (SSOT-006)
- Popup appears topmost, centered on primary screen
- Popup fades in over 300ms
- Popup starts auto-close countdown at 20 seconds
- At countdown = 0: equivalent to clicking "Open Folder"
- Countdown resets on each snooze re-display

## XAML Layout (Updated)
```
┌──────────────────────────────────────────┐
│ [Glyph]  Title                           │
├──────────────────────────────────────────┤
│ Body text (motivational message)         │
│                                          │
│ Opening: [FolderName]    ← B-12 subtitle │
│                                          │
│ Auto-opening in [N]s                     │
├──────────────────────────────────────────┤
│ [Dismiss for Today]  [Snooze ▾] [Open]  │
│       ↑ B-11              ↑ B-10         │
└──────────────────────────────────────────┘
```

## Snooze Split-Button (B-10)
- Primary label: "Snooze 5 min" (default)
- Dropdown arrow reveals menu:
  - ● 5 min (default, pre-selected)
  - ○ 15 min
  - ○ 30 min
  - ○ 1 hour
- Selected duration persists for the current popup session
- On click: `New-MotivationTask` called with `TriggerTime = now + selectedMinutes`

## Dismiss for Today (B-11)
- Button label: "Dismiss for Today" (styled subtle — smaller, grey)
- On click:
  1. `$timer.Stop()`
  2. Call `Remove-MotivationTask` for all tasks with matching `task_id` and `status=SNOOZED`
  3. `$script:openExplorer = $false`
  4. `$window.Close()`
  5. Log entry: `outcome=Dismissed`
- Does NOT open Explorer

## Folder Name Subtitle (B-12)
- New `TextBlock x:Name="FolderNameText"` below BodyText
- Content: `"Opening: $($config.folder_name)"`
- FontSize: 12, Foreground: #5A5A7A (dimmer than body)
- Visible only when `folder_name` is non-empty in config

## Missing Path Branch (B-05)
- Pre-display: `Test-Path $config.explorer_path -PathType Container`
- If FALSE:
  1. Hide CountdownText, LetsGoBtn, SnoozeBtn
  2. Show alternate BodyText: "This folder was moved or deleted."
  3. Show two buttons: [Choose New Location] [Dismiss]
  4. [Choose New Location]: open `FolderBrowserDialog` (via Add-Type), update `explorer_path` and `folder_name` in config, then open Explorer
  5. [Dismiss]: close popup, log `outcome=PathMissing`

## Post-Close Actions
- If `openExplorer=true` AND path valid: `Start-Process explorer.exe $config.explorer_path`
- Write structured log entry to `popup_log.txt`
- Release named mutex

## Status
> v1.1 DRAFT
