# GAP Analysis — Current Prototype vs. Full Specification

> **Historical Document:** This analysis was conducted on the initial prototype before the full application was implemented. All gaps identified here have since been resolved. The current codebase implements all modules listed as "Not Started" or "Partial" below. Retained for audit trail purposes only.

**Review Date:** 2026-06-02  
**Prototype:** `src/` (DailyMotivation.ps1, LaunchMotivation.bat, UpdateScheduledTask.ps1, popup_config.json)  
**Spec Baseline:** `docs/` (27 planning documents)  
**Review Method:** 6-agent parallel review (Product, Architecture, UX, QA, Security, Documentation)

---

## Executive Summary

| Metric | Value |
|--------|-------|
| User Stories fully implemented | 2 of 7 (~29%) |
| Acceptance Criteria passing | 2 of 6 (33%) |
| Test Cases passing | 4 of 11 (36%) |
| SSOT rules enforced | 5 of 8 (63%) |
| NPR requirements met | 3 of 7 (43%) |
| **Overall v1.0 MVP completion** | **~35%** |

The prototype successfully implements the **Notification Engine** and **Explorer Launcher** modules.  
All other modules are either stubs or entirely absent.

---

## Module Completion Status

| Module | Status | Notes |
|--------|--------|-------|
| Notification Engine | ✅ Implemented | WPF popup, countdown, fade-in, snooze engine, dismiss for today, path re-pick |
| Explorer Launcher | ✅ Implemented | `Start-Process explorer.exe` with path validation |
| Task Scheduler Module | ✅ Implemented | Full CRUD API with duplicate check, network path detection |
| Configuration Manager | ✅ Implemented | Full JSON I/O, settings, log, error dialogs |
| Snooze Engine | ✅ Implemented | Duration-parameterised re-trigger (5/15/30/60 min) |
| Motivation Repository | ✅ Implemented | 10 default messages, random selection |
| Folder Picker Module | ✅ Implemented | GUI picker + drag-and-drop in `MainApp.ps1` |
| Main Application Window | ✅ Implemented | Full WPF window with all features |

(Original prototype assessment below, retained for reference)

| Module (from ARCHITECTURE.md) | Status | Notes |
|-------------------------------|--------|-------|
| Notification Engine | ✅ Implemented | WPF popup, countdown, fade-in, button handlers |
| Explorer Launcher | ✅ Implemented | `Start-Process explorer.exe` with path from config |
| Task Scheduler Module | ⚠️ Partial | One-time admin script only; no programmatic API |
| Configuration Manager | ⚠️ Partial | Reads `popup_config.json`; no write path from UI |
| Snooze Engine | 🔶 Stub | Button exists; re-trigger not implemented |
| Motivation Repository | 🔶 Stub | Single JSON config; no message library |
| Folder Picker Module | ❌ Not Started | User edits JSON manually |
| Main Application Window | ❌ Not Started | No GUI entry point |

---

## Acceptance Criteria Status

| ID | Criterion | Status | Blocker |
|----|-----------|--------|---------|
| AC-001 | Folder scheduling without file editing | ❌ FAIL | No folder picker UI |
| AC-002 | Popup appears at 2 PM | ✅ PASS | — |
| AC-003 | Accept → Explorer opens | ✅ PASS | — |
| AC-004 | Snooze → reappear in 5 min | ❌ FAIL | Snooze Engine not implemented |
| AC-005 | Task deletion via UI | ❌ FAIL | No task management UI |
| AC-006 | No file editing required at any point | ❌ FAIL | `popup_config.json` must be manually edited |

---

## Test Case Status

| ID | Test Case | Status |
|----|-----------|--------|
| TC-001 | Folder picker selects path | 🚫 BLOCKED |
| TC-002 | Task created in Task Scheduler | ✅ PASS (manual) |
| TC-003 | Popup appears at 2 PM | ✅ PASS |
| TC-004 | Click Open Folder → Explorer | ✅ PASS |
| TC-005 | Snooze → reappear in 5 min | ❌ FAIL |
| TC-006 | Delete task via UI | 🚫 BLOCKED |
| TC-007 | Countdown auto-opens folder | ✅ PASS |
| TC-008 | Machine off at 2 PM → fires on login | ❓ UNKNOWN |
| TC-009 | Invalid path → graceful error | ❌ FAIL |
| TC-010 | Multiple snoozes loop correctly | ❌ FAIL |
| TC-011 | Task Scheduler disabled → clear error | ❌ FAIL |

---

## SSOT Compliance

| Rule | Status | Notes |
|------|--------|-------|
| SSOT-001: one task, one folder | ✅ Compliant | `popup_config.json` has one `explorer_path` |
| SSOT-002: fires at 2:00 PM | ✅ Compliant | Hardcoded in `UpdateScheduledTask.ps1` |
| SSOT-003: accept = completion | ✅ Compliant | `LetsGoBtn` sets `openExplorer=true` |
| SSOT-004: snooze ≠ completion | ✅ Compliant | `SnoozeBtn` sets `openExplorer=false` |
| SSOT-005: folder open = done | ✅ Compliant | `Start-Process` fires on completion |
| SSOT-006: one popup at a time | ❌ Not Enforced | No mutex/lock in current implementation |
| SSOT-007: user never edits config | ❌ Violated | Manual `popup_config.json` editing required |
| SSOT-008: snooze loop unlimited | ❌ Not Implemented | Re-trigger mechanism absent |

---

## NPR Compliance

| Rule | Status | Notes |
|------|--------|-------|
| NPR-001: no config file editing | ❌ VIOLATED | Core violation — user must edit `popup_config.json` |
| NPR-002: accessibility | ⚠️ Partial | Font sizes OK; keyboard nav untested |
| NPR-003: ≤ 3-click install | ❌ VIOLATED | Requires manual file edit + admin script |
| NPR-004: missed trigger recovery | ❓ UNKNOWN | `RunAtLogon` not set in `UpdateScheduledTask.ps1` |
| NPR-005: offline | ✅ Met | No network calls |
| NPR-006: < 100MB idle | ✅ Met | No persistent background process |
| NPR-007: no residual processes | ✅ Met | Popup exits cleanly |

---

## Security Findings

| Severity | Finding |
|----------|---------|
| MEDIUM | `explorer_path` from JSON passed unsanitized to `Start-Process` — validate before use |
| LOW | `popup_config.json` in script directory, not `%APPDATA%` — writable by other users on shared machines |
| LOW | No mutex to enforce SSOT-006 (duplicate popups possible) |
| INFO | Admin rights required for `UpdateScheduledTask.ps1` — acceptable for setup; document clearly |

---

## Agent Recommendations Summary

### Product Agent
Build the Folder Picker Module and a GUI wrapper first. These are the gate that blocks every other user story from being testable.

### Architecture Agent
The prototype is the Notification Engine. The remaining 5 modules are greenfield. Build the Main Application Window as a WPF app with the Folder Picker and Task Scheduler wrapper as the first sprint.

### UX Agent
**Highest priority fix:** Eliminate all manual file editing. The core user promise is broken until `popup_config.json` is written by the app, not the user.

### QA Agent
4 of 6 acceptance criteria require the Folder Picker or Snooze Engine to pass. These two modules are the unlock for QA coverage.

### Security Agent
Sanitize `explorer_path` before passing to `Start-Process`. Move config to `%APPDATA%`. Add a named mutex at popup startup.

### Documentation Agent
TRACEABILITY_MATRIX.md and SSOT.md accurately describe the target state. The gaps here are implementation gaps, not documentation gaps. Freeze both documents and use them as the implementation contract.
