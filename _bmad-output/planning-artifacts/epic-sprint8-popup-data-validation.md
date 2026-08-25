---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - source: GitHub Issues
  - issues: [135, 129, 108, 139, 137]
  - branch: SevAI_installing_bmad
generatedBy: bmad-agent-pm (John) CE trigger
date: 2026-08-25
---

# Daily-Motivation-Brain-Helper - Sprint 8: Popup Robustness and Data Validation

## Overview

5 issues: add tooltips to snooze menu items, disable them in path-missing
mode, fix the Get-Process pipeline performance, guard Set-PopupConfig
against oversized strings, and fix countdown timer drift.

**Sprint goal:** Close all remaining AG17/AG18 popup-interaction gaps,
eliminate the all-processes enumeration on every abandoned-mutex recovery,
and make the 20s countdown accurate under UI load.

## Epic List

1. **Epic 1: Popup Interaction Polish** - tooltips, path-missing guards, countdown accuracy.
2. **Epic 2: Data Safety** - string truncation, process lookup efficiency.

---

## Epic 1: Popup Interaction Polish

### Story 1.1: Tooltips on Snooze MenuItems and ExitItem (#135)
Closes: #135 AG17-018 (Low)
Add ToolTip attribute to all four Snooze MenuItems and ExitItem in the
Popup XAML ContextMenu. Linux-safe (XAML only).

### Story 1.2: Disable Snooze MenuItems in Path-Missing Mode (#129)
Closes: #129 AG17-005 (Medium)
After `Find` calls in Show-PopupWindow, set `$mi.IsEnabled = $false`
for all four snooze MenuItems when `$script:pathMissing` is true.
The snooze action requires a task and countdown; neither exists in
path-missing mode. Linux-safe static analysis.

### Story 1.3: Wall-Clock Countdown Accuracy (#137)
Closes: #137 AG18-008 (Medium)
Record `$script:countdownStartedAt` and `$script:countdownPausedMs`
when the countdown starts. In the tick handler, derive
`$script:remaining` from elapsed wall time minus paused time rather
than blind decrement. Pause handler tracks `$script:pauseStartedAt`
and accumulates into `$script:countdownPausedMs` on resume.
Linux-safe (arithmetic only; no WPF types used).

---

## Epic 2: Data Safety

### Story 2.1: Fix Get-Process All-Processes Enumeration (#108)
Closes: #108 AG14-008 (High)
In the AbandonedMutexException handler, replace `Get-Process | Where-Object`
with `Get-Process -Name "DailyMotivation" -ErrorAction SilentlyContinue`
to avoid enumerating all system processes on every abandoned-mutex recovery.
Linux-safe static analysis.

### Story 2.2: Guard Set-PopupConfig Against Oversized Strings (#139)
Closes: #139 AG18-014 (Medium)
At the top of Set-PopupConfig, truncate Title (200), Body (1000),
Glyph (10), and ExplorerPath (2000) before writing to JSON. Use the
safe variables throughout the ordered hashtable. Linux-safe.
