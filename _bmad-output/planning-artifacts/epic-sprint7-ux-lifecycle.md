---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - source: GitHub Issues
  - issues: [156, 155, 154, 128]
  - branch: SevAI_installing_bmad
generatedBy: bmad-agent-pm (John) CE trigger
date: 2026-08-25
---

# Daily-Motivation-Brain-Helper - Sprint 7: UX Clarity and Lifecycle

## Overview

4 issues: set keyboard focus on popup launch, add dismiss button for the
undo banner, clarify ambiguous button labels, and add an /uninstall mode
that removes the context menu registry entry.

**Sprint goal:** Remove user-visible UX friction points and close the
lifecycle gap where the context menu verb has no clean removal path.

## Epic List

1. **Epic 1: UX Clarity** - popup focus, undo banner dismiss, button labels.
2. **Epic 2: Lifecycle Management** - /uninstall mode.

---

## Epic 1: UX Clarity

### Story 1.1: Set Keyboard Focus on Popup Launch (#156)
Closes: #156 AG19-016 (High)
In `Show-PopupWindow` `Add_Loaded` handler, call `$letsGoBtn.Focus()` and
`[System.Windows.Input.Keyboard]::Focus($letsGoBtn)` after the fade-in
animation completes. In path-missing mode, focus `$rePickBtn` instead.
Windows-only (WPF); static-analysis test is Linux-safe.

### Story 1.2: Add Dismiss Button to Undo Banner (#155)
Closes: #155 AG19-014 (Medium)
Add a small X `DismissBannerBtn` Button to the UndoBanner Grid (column 2)
with a ToolTip "Close without undoing". Wire it in Show-MainWindow to
call `Stop-UndoTimer` and hide the banner WITHOUT removing the task
(the task was already scheduled; this just clears the UI banner).
Linux-safe static-analysis test.

### Story 1.3: Clarify Ambiguous Button Labels (#154)
Closes: #154 AG19-013 (Medium)
- `DismissBtn`: "Dismiss for Today" → "Dismiss for Today" is correct per
  domain model but "Dismiss" alone is cleaner for the button face with
  the tooltip carrying the full meaning. Change Content to "Dismiss" and
  add ToolTip="Remove all pending reminders for this folder".
- `UndoBtn`: already reads "Undo"  -  acceptable; no change.
- `RePickBtn`: "Choose New Location" → "Re-Pick Folder" to match the
  domain term in CONTEXT.md.
Linux-safe static-analysis tests.

---

## Epic 2: Lifecycle Management

### Story 2.1: Add /uninstall Mode (#128)
Closes: #128 AG17-003 (Medium)
Add `"/uninstall"` case to the Mode switch at the entry point. It calls
`Unregister-ContextMenu`, shows a MessageBox confirming success, then
exits. Allows clean removal without requiring a registry editor.
Linux-safe static-analysis test; no Windows-only gate needed.
