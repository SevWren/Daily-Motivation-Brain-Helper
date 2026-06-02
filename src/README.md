# src/ — Prototype Implementation

This directory contains the current working PowerShell prototype.
It is the starting point for the full application described in `docs/`.

## Files

| File | Purpose |
|------|---------|
| `DailyMotivation.ps1` | WPF motivational popup — reads `popup_config.json`, displays timed popup with Open Folder / Snooze buttons, launches Windows Explorer |
| `LaunchMotivation.bat` | Task Scheduler wrapper — launches PowerShell with all required flags (-STA, -NonInteractive, -ExecutionPolicy Bypass) and captures output to log files |
| `UpdateScheduledTask.ps1` | One-time setup script — registers the scheduled task in Windows Task Scheduler (run as Administrator) |
| `popup_config.json` | Active task configuration — glyph, title, body text, and explorer_path; written by the app, read by the popup script |

## Current Prototype Capabilities

- [x] Motivational popup with WPF (dark theme, fade-in animation)
- [x] 20-second countdown auto-accept
- [x] Open Folder button → launches Windows Explorer
- [x] Snooze button → closes popup (snooze re-trigger not yet automated)
- [x] Debug logging to `%TEMP%\DailyMotivation_debug.log`
- [x] Task Scheduler registration via `UpdateScheduledTask.ps1`
- [x] JSON-based configuration (`popup_config.json`)

## Gaps vs. Full Spec (see docs/GAP_ANALYSIS.md)

- [ ] No GUI for folder selection (user edits `popup_config.json` manually)
- [ ] No automated snooze re-trigger (5-minute loop not implemented)
- [ ] No task management UI (view/delete tasks)
- [ ] No motivational message library (single hardcoded message)
- [ ] explorer_path is hardcoded in config, not selected via file picker
