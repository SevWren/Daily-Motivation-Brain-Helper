---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - source: GitHub Issues
  - issues: [101, 105, 103, 133]
  - closed_without_code: [95, 97, 100, 99, 113, 132]
  - branch: SevAI_installing_bmad
generatedBy: bmad-agent-pm (John) CE trigger
date: 2026-08-25
---

# Daily-Motivation-Brain-Helper - Sprint 9: Platform Polish and Date Normalization

## Overview

4 code fixes + 6 issue closures (already resolved in prior sprints).
Adds emoji font fallback, normalizes date formats, hardens locale-dependent
DateTime parsing, and shows a checkmark on the active snooze duration.

**Sprint goal:** Close all remaining AG13 platform-guard gaps that are
actually present and fix two AG17/AG18 UX gaps.

## Closed Without Code Change

- #95: Show-ErrorDialog already has WPF -> MessageBox -> WinForms -> Console fallback chain
- #97: Test-Path guard added in Sprint 5 before Start-Process explorer.exe
- #100: TempDir uses [System.IO.Path]::GetTempPath(), not literal /tmp
- #99: Join-Path normalizes separators; .local/share sub-path is Linux-only
- #113: Start-Process is fire-and-forget (no -Wait); does not block
- #132: Do-Schedule already disables scheduleBtn + shows "Creating reminder..." label

## Epic 1: Platform Polish

### Story 1.1: XAML Emoji Font Fallback Chain (#101)
Closes: #101 AG13-014 (Low)
Add `Segoe UI Emoji, Segoe UI Symbol, Segoe UI` FontFamily to both
MainWindow and PopupWindow `<Window>` elements. Ensures emoji hex
entities render on systems without Segoe UI Emoji installed.

### Story 1.2: InvariantCulture Parse for StartBoundary (#105)
Closes: #105 AG13-022 (Low)
Replace bare `[datetime]$trigger.StartBoundary` cast with
`[datetime]::Parse(... InvariantCulture, RoundtripKind)` in the
orphan-recovery path of Sync-TaskStatuses. Linux-safe.

### Story 1.3: Normalize created_at to Consistent ISO Format (#103)
Closes: #103 AG13-018 (Low)
Replace `Get-Date -Format "o"` (round-trip, fractional seconds vary
by runtime) with `Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"` to match
the format already used for scheduled_time. Both call sites updated.
Linux-safe.

## Epic 2: UX State

### Story 2.1: Snooze Menu IsChecked State (#133)
Closes: #133 AG17-014 (Medium)
Initialize Snooze5.IsChecked = true (default). Each snooze click
handler sets IsChecked=true on the clicked item and false on the others.
Shows a checkmark in the dropdown so the user can see the active duration.
Linux-safe static analysis.
