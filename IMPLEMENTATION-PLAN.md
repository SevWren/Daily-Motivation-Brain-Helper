# Implementation Plan: Documentation Architecture & Phase 2-3 Updates

**Date:** 2026-06-03
**Author:** Claude (multi-agent session)
**Status:** APPROVED — ready for execution
**Commit to follow:** 8d6cb0d (Phase 1 doc updates)

> This is the canonical, unambiguous execution plan. Every file move, every section addition,
> every line change is specified here. No interpretation required. Execute top to bottom.

---

## Table of Contents

1. [Pre-flight Checks](#pre-flight-checks)
2. [Phase 0 — Repository Architecture: Archive vs. Permanent Home](#phase-0--repository-architecture-archive-vs-permanent-home)
3. [Phase 2 — High Priority Documentation Updates](#phase-2--high-priority-documentation-updates)
4. [Phase 3 — Medium/Low Priority Documentation Updates](#phase-3--mediumlow-priority-documentation-updates)
5. [Phase 4 — PRD to GitHub Issue (to-prd skill)](#phase-4--prd-to-github-issue)
6. [Git Workflow](#git-workflow)
7. [Validation Checklist](#validation-checklist)

---

## Pre-flight Checks

Before executing any phase, verify:

```bash
cd /home/vercel-sandbox/Daily-Motivation-Brain-Helper
git status          # must be clean (no uncommitted changes)
git log --oneline -3  # confirm HEAD is 8d6cb0d
```

Ensure GitHub token `<GITHUB_PAT_REDACTED>` is set in remote URL:
```bash
git remote get-url origin
# must show: https://<TOKEN>@github.com/SevWren/Daily-Motivation-Brain-Helper.git
```

---

## Phase 0 — Repository Architecture: Archive vs. Permanent Home

### Overview

The `improve-codebase-architecture` skill's **deletion test** applied to documentation:
> "If we deleted this file, would its value *vanish* (archive it) or *reappear* across callers (it's earning its keep — keep it in place)?"

### Decision Matrix

| File | Current Location | Classification | Verdict | Destination |
|------|-----------------|----------------|---------|-------------|
| `MODERN-POWERSHELL-SCAFFOLDING.md` | repo root | Session completion report — its architectural content is fully captured in `TESTING.md` and `Tests/README.md`. Keeping it at root pollutes primary navigation. Deletion test: delete it → complexity does NOT reappear elsewhere (TESTING.md covers it). | **ARCHIVE** | `docs/reports/SCAFFOLDING-COMPLETION-2026-06-03.md` |
| `INITIALIZATION-BUGS.md` | repo root | Bug analysis session report — all actionable content was converted to GitHub Issues #2-#8. Those issues are the live source of truth. This is a historical artifact. Deletion test: delete it → bug details still exist in issues. | **ARCHIVE** | `docs/reports/INITIALIZATION-BUG-ANALYSIS-2026-06-03.md` |
| `docs/HANDOFF.md` | `docs/` | AI-to-AI session handoff — captures point-in-time context for a completed session. Not a living document. Future agents read `CLAUDE.MD` and current state, not past handoffs. | **ARCHIVE** | `docs/reports/HANDOFF-SESSION-1-2026-06-03.md` |
| `docs/HANDOFF2.md` | `docs/` | Same rationale as HANDOFF.md — second session handoff, also completed and no longer active. | **ARCHIVE** | `docs/reports/HANDOFF-SESSION-2-2026-06-03.md` |
| `COMMIT-4ba633a-AUDIT-MASTER-REPORT.md` | repo root | Multi-agent audit report — historical record, not a living doc | **ARCHIVE** | `docs/reports/AUDIT-MASTER-REPORT-COMMIT-4ba633a.md` |
| `DOCUMENTATION-AUDIT-REPORT.md` | repo root | Agent-generated audit report | **ARCHIVE** | `docs/reports/DOCUMENTATION-AUDIT-REPORT-2026-06-03.md` |
| `DOCUMENTATION-UPDATE-CHECKLIST.md` | repo root | Agent-generated update checklist | **ARCHIVE** | `docs/reports/DOCUMENTATION-UPDATE-CHECKLIST-2026-06-03.md` |
| `DOCUMENTATION_AUDIT_REPORT.md` | repo root | Duplicate audit report (underscore variant) | **ARCHIVE** | `docs/reports/DOCUMENTATION-AUDIT-REPORT-ALT-2026-06-03.md` |
| `SPEC_AUDIT_REPORT.md` | repo root | Spec-focused audit report | **ARCHIVE** | `docs/reports/SPEC-AUDIT-REPORT-2026-06-03.md` |
| `DOCUMENTATION-AUDIT-SUMMARY.txt` | repo root | Plain-text audit summary | **ARCHIVE** | `docs/reports/DOCUMENTATION-AUDIT-SUMMARY-2026-06-03.txt` |
| `AUDIT-COMPLETION-SUMMARY.md` | repo root | Phase 1 audit completion summary | **ARCHIVE** | `docs/reports/AUDIT-COMPLETION-SUMMARY-2026-06-03.md` |
| `TESTING.md` | repo root | **PERMANENT** — living developer guide for test execution, CI, coverage | **KEEP** | `TESTING.md` (no move) |

### What Gets a Permanent Home: docs/reports/

The `docs/reports/` directory is the **canonical archive** for:
- Session work products (analysis, audits, handoffs)
- Historical snapshots that are no longer maintained
- Agent-generated reports that served their purpose

**Rule:** Files in `docs/reports/` are read-only historical records. They are never updated in place — new sessions create new dated files.

### Step-by-step execution for Phase 0

**Step 0.1 — Create `docs/reports/` directory**
```bash
mkdir -p docs/reports
```

**Step 0.2 — Move/rename each file**

Execute each `git mv` command exactly as written:

```bash
git mv MODERN-POWERSHELL-SCAFFOLDING.md docs/reports/SCAFFOLDING-COMPLETION-2026-06-03.md
git mv INITIALIZATION-BUGS.md docs/reports/INITIALIZATION-BUG-ANALYSIS-2026-06-03.md
git mv docs/HANDOFF.md docs/reports/HANDOFF-SESSION-1-2026-06-03.md
git mv docs/HANDOFF2.md docs/reports/HANDOFF-SESSION-2-2026-06-03.md
git mv COMMIT-4ba633a-AUDIT-MASTER-REPORT.md "docs/reports/AUDIT-MASTER-REPORT-COMMIT-4ba633a.md"
git mv DOCUMENTATION-AUDIT-REPORT.md docs/reports/DOCUMENTATION-AUDIT-REPORT-2026-06-03.md
git mv DOCUMENTATION-UPDATE-CHECKLIST.md docs/reports/DOCUMENTATION-UPDATE-CHECKLIST-2026-06-03.md
git mv DOCUMENTATION_AUDIT_REPORT.md docs/reports/DOCUMENTATION-AUDIT-REPORT-ALT-2026-06-03.md
git mv SPEC_AUDIT_REPORT.md docs/reports/SPEC-AUDIT-REPORT-2026-06-03.md
git mv DOCUMENTATION-AUDIT-SUMMARY.txt docs/reports/DOCUMENTATION-AUDIT-SUMMARY-2026-06-03.txt
git mv AUDIT-COMPLETION-SUMMARY.md docs/reports/AUDIT-COMPLETION-SUMMARY-2026-06-03.md
```

**Step 0.3 — Create `docs/reports/README.md`**

Create the file `docs/reports/README.md` with the following content (verbatim):

```markdown
# docs/reports — Session Work Products Archive

This directory contains historical session artifacts: agent-generated analysis reports,
audit documents, session handoffs, and one-time work products.

**Rule:** Files here are read-only records. Do not update them. Create new dated files.

## Index

| File | Type | Date | Description |
|------|------|------|-------------|
| SCAFFOLDING-COMPLETION-2026-06-03.md | Completion report | 2026-06-03 | Modern PowerShell infrastructure scaffold summary (commit 4ba633a) |
| INITIALIZATION-BUG-ANALYSIS-2026-06-03.md | Bug analysis | 2026-06-03 | Root cause analysis for Issues #2-#8; source for GitHub issue creation |
| HANDOFF-SESSION-1-2026-06-03.md | Session handoff | 2026-06-03 | AI-to-AI handoff after initial documentation stack creation |
| HANDOFF-SESSION-2-2026-06-03.md | Session handoff | 2026-06-03 | AI-to-AI handoff after skill installation and diagnose run |
| AUDIT-MASTER-REPORT-COMMIT-4ba633a.md | Audit report | 2026-06-03 | Master multi-agent doc audit for commit 4ba633a |
| DOCUMENTATION-AUDIT-REPORT-2026-06-03.md | Audit report | 2026-06-03 | Core docs audit (README, CLAUDE.MD, INITIALIZATION-BUGS) |
| DOCUMENTATION-UPDATE-CHECKLIST-2026-06-03.md | Checklist | 2026-06-03 | Phase-based update checklist from Phase 1 audit |
| DOCUMENTATION-AUDIT-REPORT-ALT-2026-06-03.md | Audit report | 2026-06-03 | Development workflow audit (CONTRIBUTING, TEST_PLAN, etc.) |
| SPEC-AUDIT-REPORT-2026-06-03.md | Audit report | 2026-06-03 | Architecture and spec audit (ARCHITECTURE, PRD, specs) |
| DOCUMENTATION-AUDIT-SUMMARY-2026-06-03.txt | Summary | 2026-06-03 | Plain-text audit summary |
| AUDIT-COMPLETION-SUMMARY-2026-06-03.md | Summary | 2026-06-03 | Phase 1 documentation audit completion summary |
```

**Step 0.4 — Update cross-references in CLAUDE.MD**

After archival, `CLAUDE.MD` must not reference the moved files. Do a search-and-replace:

In `CLAUDE.MD`, find and replace any reference to `MODERN-POWERSHELL-SCAFFOLDING.md` that implies it is at the repo root — change to `docs/reports/SCAFFOLDING-COMPLETION-2026-06-03.md`.

**Step 0.5 — Update cross-references in README.md**

In root `README.md`, find any reference to `MODERN-POWERSHELL-SCAFFOLDING.md` in the repository structure diagram and update path. The "Testing & Development" section already references it correctly; update the path where shown.

Also in root `README.md` repository structure diagram, the line:
```
+-- MODERN-POWERSHELL-SCAFFOLDING.md  # Infrastructure overview
```
Must be changed to:
```
+-- docs/reports/                     # Historical session reports and audit artifacts
```
And the reference in "See [TESTING.md](TESTING.md) and [MODERN-POWERSHELL-SCAFFOLDING.md]..." in the Testing & Development section must become:
```
See [TESTING.md](TESTING.md) and [Tests/README.md](Tests/README.md) for details.
```

**Step 0.6 — Update src/README.md cross-references**

In `src/README.md`, the line referencing `MODERN-POWERSHELL-SCAFFOLDING.md` as `../MODERN-POWERSHELL-SCAFFOLDING.md` must be updated to `../docs/reports/SCAFFOLDING-COMPLETION-2026-06-03.md` with updated purpose description "Historical infrastructure setup report (commit 4ba633a)".

**Step 0.7 — Verify all cross-references are resolved**

Run:
```bash
grep -r "MODERN-POWERSHELL-SCAFFOLDING" . --include="*.md" | grep -v "docs/reports"
grep -r "INITIALIZATION-BUGS.md" . --include="*.md" | grep -v "docs/reports"
grep -r "HANDOFF\.md\|HANDOFF2\.md" . --include="*.md" | grep -v "docs/reports"
```
None should return results outside `docs/reports/`.

**Step 0.8 — Commit Phase 0**

```bash
git add -A
git commit -m "refactor(docs): archive session work products to docs/reports/

Applies improve-codebase-architecture deletion test to documentation files.
Files that no longer serve as living documents are relocated to docs/reports/
as dated historical records.

Archived:
- MODERN-POWERSHELL-SCAFFOLDING.md -> docs/reports/SCAFFOLDING-COMPLETION-2026-06-03.md
  (completion report; TESTING.md and Tests/README.md are the living equivalents)
- INITIALIZATION-BUGS.md -> docs/reports/INITIALIZATION-BUG-ANALYSIS-2026-06-03.md
  (GitHub Issues #2-#8 are the live source of truth)
- docs/HANDOFF.md -> docs/reports/HANDOFF-SESSION-1-2026-06-03.md
- docs/HANDOFF2.md -> docs/reports/HANDOFF-SESSION-2-2026-06-03.md
  (both are completed AI-to-AI session handoffs)
- All root-level audit report files from 2026-06-03 doc audit session

Created: docs/reports/README.md index of archived materials

Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin main
```

---

## Phase 2 — High Priority Documentation Updates

### Context

These 10 files are out-of-date in ways that affect developer experience and project quality. Each change below is specified at the **exact section level** with the **exact text to add or modify**.

---

### File 1: `docs/ARCHITECTURE.md`

**Why:** The architecture document is missing a Quality Assurance section. Any developer reading it for context gets zero information about the test infrastructure, which is now a first-class concern.

**Location of change:** After the "Technology Stack" section. If no explicit "Technology Stack" section header exists, insert after the last diagram block (the one ending with "Named mutex...").

**Read the file first to find the insertion point.** Look for the last `---` separator before any "Contributing" or similar section. Insert there.

**Add this exact section** (no modifications):

```markdown
---

## Quality Assurance & Test Infrastructure

### Test Coverage by Module

| Module | Test File | Test Count | Coverage |
|--------|-----------|------------|----------|
| `ConfigManager.psm1` | `Tests/Unit/ConfigManager.Tests.ps1` | 100+ | ~90% |
| `TaskScheduler.psm1` | `Tests/Unit/TaskScheduler.Tests.ps1` | 80+ | ~85% |
| Integration | `Tests/Integration/Initialization.Tests.ps1` | 16 scenarios | N/A |

### Coverage Gap: Notification Engine

`DailyMotivation.ps1` has **zero automated test coverage**. WPF components cannot be
exercised by Pester without a live Windows desktop session. Manual testing (TC-003 through
TC-020 in `docs/TEST_PLAN.md`) remains the validation mechanism for this component.

This is the highest quality risk in the codebase. See `docs/NOTIFICATION_ENGINE_SPEC.md`
for the testing approach roadmap.

### Build Automation (`.build.ps1`)

| Task | Command | Description |
|------|---------|-------------|
| Default | `Invoke-Build` | Clean -> Analyze -> Test -> Build |
| Test only | `Invoke-Build Test` | Run Pester suite |
| Quick build | `Invoke-Build QuickBuild` | Build without tests |
| Release | `Invoke-Build Release` | Full pipeline + package |
| Install deps | `Invoke-Build InstallDependencies` | Install Pester, PSScriptAnalyzer, ps2exe |

### CI/CD Pipeline (`.github/workflows/test.yml`)

Three jobs run on every push and PR:

1. **test** — PSScriptAnalyzer + Pester suite + coverage upload + PR comment
2. **build** — PS2EXE compilation; only runs after `test` job passes
3. **analyze** — PSScriptAnalyzer SARIF for GitHub Security code scanning

**Quality gates (PR merge is blocked if any fail):**
- All Pester tests must pass
- Code coverage must be ≥ 80%
- PSScriptAnalyzer zero warnings

See `TESTING.md` for developer usage.
```

---

### File 2: `docs/INSTALL.md`

**Why:** Line 27 references `build.ps1` (does not exist — it is `.build.ps1`). Also missing a "Developer Setup" section for contributors who need to build and test locally.

**Change 1 — Fix incorrect filename (line 27):**

Find the exact string:
```
Or double-click `src\DailyMotivation.exe` if you built the EXE with `build.ps1`.
```
Replace with:
```
Or double-click `src\DailyMotivation.exe` if you built the EXE with `Invoke-Build` (see Developer Setup below).
```

**Change 2 — Add Developer Setup section** after the existing `## Troubleshooting` section:

```markdown
---

## Developer Setup

This section is for developers building from source or running tests.

### Prerequisites

Install development dependencies (one-time setup):

```powershell
# Requires Invoke-Build module. Install it first if needed:
Install-Module -Name InvokeBuild -Scope CurrentUser -Force

# Then install all project dev dependencies:
Invoke-Build InstallDependencies
```

This installs: **Pester 5.x**, **PSScriptAnalyzer**, **ps2exe**

### Running Tests

```powershell
# All tests (180+ total)
.\Invoke-Tests.ps1

# Unit tests only (fast, no integration overhead)
.\Invoke-Tests.ps1 -Tag Unit

# Integration tests only
.\Invoke-Tests.ps1 -Tag Integration

# CI mode — generates NUnit XML and JaCoCo coverage XML
.\Invoke-Tests.ps1 -CI
```

### Building the EXE

```powershell
# Full build: clean, analyze, test, compile
Invoke-Build

# Quick build (skip tests, useful during active development)
Invoke-Build QuickBuild

# Release package (ZIP + EXE)
Invoke-Build Release
```

See `TESTING.md` for complete developer testing guide.
```

---

### File 3: `docs/PRD.md`

**Why:** 25 functional requirements with no traceability to automated validation. After 180+ tests were added, the PRD has no way to show what has been validated.

**Location of change:** Append to the end of the file (after all FR entries).

**Add this exact section:**

```markdown
---

## Requirements Validation Matrix

This matrix links requirements to automated test coverage (as of commit 4ba633a).
"Validated" means a Pester test exercises the described behavior. "Manual only" means
the requirement is validated by manual test cases in `docs/TEST_PLAN.md`.

| FR | Requirement Summary | Automated Coverage | Test Reference |
|----|--------------------|--------------------|----------------|
| FR-002 | Schedule a folder for tomorrow at 2 PM | ✅ Validated | `Tests/Unit/TaskScheduler.Tests.ps1` — task creation, trigger time |
| FR-003 | Duplicate schedule warning | ✅ Validated | `Tests/Unit/TaskScheduler.Tests.ps1` — duplicate detection (case-insensitive, Force flag) |
| FR-011 | Persist settings across launches | ✅ Validated | `Tests/Unit/ConfigManager.Tests.ps1` — settings get/save |
| FR-013 | Remember last 5 folders (FIFO) | ✅ Validated | `Tests/Unit/ConfigManager.Tests.ps1` — FIFO, dedup, max-5 cap |
| FR-014 | Log popup outcomes | ✅ Validated | `Tests/Unit/ConfigManager.Tests.ps1` — write/read/clear/parse |
| FR-015 | UTF-8 encoding for all paths | ✅ Validated | `Tests/Unit/ConfigManager.Tests.ps1` — international paths, emoji glyphs |
| FR-018 | Recover gracefully from corrupted config | ✅ Validated | `Tests/Unit/ConfigManager.Tests.ps1` — corrupted file fallback |
| FR-023 | Task status state machine | ✅ Validated | `Tests/Unit/TaskScheduler.Tests.ps1` — all 5 status values |
| FR-024 | Network path detection | ✅ Validated | `Tests/Unit/TaskScheduler.Tests.ps1` — UNC path detection |
| FR-001 | Folder picker dialog | ⬜ Manual only | TC-001 |
| FR-004 | Drag-and-drop folder | ⬜ Manual only | TC-018 |
| FR-005 | Schedule today option (before 2 PM) | ⬜ Manual only | TC-014 |
| FR-006 | Undo schedule (30s grace period) | ⬜ Manual only | TC-015 |
| FR-007 | First-run welcome screen | ⬜ Manual only | TC-017 |
| FR-008 | Remember last folder banner | ⬜ Manual only | TC-012 |
| FR-009 | Recent folders list | ⬜ Manual only | TC-013 |
| FR-010 | Snooze duration choice | ⬜ Manual only | TC-019 |
| FR-012 | Popup display at scheduled time | ⬜ Manual only | TC-003 |
| FR-016 | Open folder via Explorer | ⬜ Manual only | TC-004 |
| FR-017 | Moved folder re-pick prompt | ⬜ Manual only | TC-016 |
| FR-019 | Dismiss for Today | ⬜ Manual only | TC-020 |
| FR-020 | Task history viewer | ⬜ Manual only | TC-023 |
| FR-021 | Tooltips on all controls | ⬜ Manual only | TC-024 |
| FR-022 | Named mutex (single popup) | ⬜ Manual only | SSOT-006 manual verification |
| FR-025 | Shell extension right-click | ⬜ Manual only | Manual install + context menu check |

**Coverage summary:** 9/25 requirements (36%) have automated Pester validation.
The unvalidated requirements are UI-driven and require a live Windows WPF session to test.
```

---

### File 4: `docs/TRACEABILITY_MATRIX.md`

**Why:** Traceability matrix does not reflect test validation status. Read the file first to determine its current column structure.

**How to determine what to add:** Read `docs/TRACEABILITY_MATRIX.md` and identify:
- The existing column headers of the main requirements table
- The last row of the table

**Add "Automated Test" as a new column** to the existing table header and each row. Map values using the PRD validation matrix above (FR-002, FR-003, FR-011, FR-013, FR-014, FR-015, FR-018, FR-023, FR-024 get ✅; all others get ⬜).

**Also append this section at the end of the file:**

```markdown
---

## Module-Level Test Coverage Traceability

| Module | Functionality | Test File | Coverage |
|--------|--------------|-----------|----------|
| `ConfigManager.psm1` | `Initialize-AppData` directory creation | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | Settings management (get/set/firstRun/lastFolder) | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | Recent folders (FIFO, dedup, 5-item limit) | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | Popup config (all 6 fields) | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | Outcome log (write/read/parse/clear) | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | UTF-8 encoding | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `ConfigManager.psm1` | Corrupted file recovery | `Tests/Unit/ConfigManager.Tests.ps1` | ~90% |
| `TaskScheduler.psm1` | Task creation (IDs, timestamps, JSON) | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `TaskScheduler.psm1` | Duplicate detection (B-16) | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `TaskScheduler.psm1` | Task retrieval and cross-checking | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `TaskScheduler.psm1` | Task deletion (best-effort) | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `TaskScheduler.psm1` | Status updates (all 5 values) | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `TaskScheduler.psm1` | Network path detection (UNC) | `Tests/Unit/TaskScheduler.Tests.ps1` | ~85% |
| `DailyMotivation.ps1` | WPF popup display, state machine, buttons | None | **0% — manual only** |
| `MainApp.ps1` | WPF window, event handlers, UI interaction | None | **0% — manual only** |
```

---

### File 5: `docs/DISTRIBUTION_STRATEGY.md`

**Why:** The distribution strategy references `build.ps1` for compilation — this is the legacy build script; the current build system uses `Invoke-Build` via `.build.ps1`.

**Read the file first.** Then apply these changes:

**Change 1:** Every occurrence of `.\build.ps1` or `build.ps1` in the context of "building the EXE" must become `Invoke-Build` or `Invoke-Build Build`.

**Change 2:** After the build/compilation section, add or update to include:

```markdown
### Build System

The project uses **Invoke-Build** (`.build.ps1`) for all build automation.

```powershell
# Complete release pipeline (recommended for distribution):
Invoke-Build Release

# This runs: Clean -> PSScriptAnalyzer -> Pester tests -> PS2EXE compile -> ZIP package
# Output: ./output/DailyMotivation.exe and ./output/DailyMotivation-vX.X.X.zip
```

**Pre-release quality gates** (all must pass before distributing):
1. `Invoke-Build Analyze` — zero PSScriptAnalyzer warnings
2. `Invoke-Build Test` — all 180+ Pester tests pass
3. Coverage ≥ 80% (checked by CI/CD via `.github/workflows/test.yml`)
```

---

### File 6: `docs/SPRINT_PLAN.md`

**Why:** Sprint plan doesn't document the test infrastructure as completed work. New contributors reading the sprint plan don't know a full test suite exists.

**Read the file first.** Then:

**Change 1:** If the sprint plan begins at "Sprint 1", insert a new Sprint 0 block **before Sprint 1**:

```markdown
## Sprint 0 — Engineering Infrastructure (COMPLETE)

**Completed:** 2026-06-03 (commit 4ba633a)
**Goal:** Establish modern PowerShell development practices before feature work.

### Delivered

| Task | Status | Notes |
|------|--------|-------|
| INFRA-001 | ✅ Done | Pester 5.x test suite — 180+ tests |
| INFRA-002 | ✅ Done | ConfigManager unit tests (100+ tests, ~90% coverage) |
| INFRA-003 | ✅ Done | TaskScheduler unit tests (80+ tests, ~85% coverage) |
| INFRA-004 | ✅ Done | Integration tests for initialization bugs (Issues #2-#8) |
| INFRA-005 | ✅ Done | Invoke-Build automation (.build.ps1, 12 tasks) |
| INFRA-006 | ✅ Done | Invoke-Tests.ps1 test runner with tag filtering and CI mode |
| INFRA-007 | ✅ Done | PSScriptAnalyzer configuration (.PSScriptAnalyzerSettings.psd1) |
| INFRA-008 | ✅ Done | GitHub Actions CI/CD pipeline (.github/workflows/test.yml) |
| INFRA-009 | ✅ Done | Test documentation (TESTING.md, Tests/README.md) |

### Known Gaps Identified

- `DailyMotivation.ps1` (Notification Engine): **0% automated coverage** — WPF component; addressed in Sprint 3+
- Issues #3, #5, #6, #7: Tests documented but skipped pending fix implementation

---
```

**Change 2:** If the sprint plan has a "remaining tasks" or "backlog" column, add a row for "Notification Engine test coverage" in the appropriate sprint column (typically Sprint 3 or later).

---

### File 7: `docs/ROADMAP.md`

**Why:** The roadmap v1.0 section doesn't mention test infrastructure, giving the impression the project has no automated tests.

**Read the file first.** Then add this block inside the `## v1.0 — MVP (Current Sprint)` section, before the first bullet list item:

```markdown
### Engineering Foundation (COMPLETE — commit 4ba633a)

- ✅ Pester 5.x test suite — 180+ tests
- ✅ CI/CD pipeline — GitHub Actions (tests + build + security scan)
- ✅ PSScriptAnalyzer — zero-warning code quality enforcement
- ✅ Invoke-Build automation — 12 build tasks
- ✅ Code coverage tracking — target 80%+, achieved ~85%
- ✅ ConfigManager module: ~90% coverage
- ✅ TaskScheduler module: ~85% coverage
- ⬜ Notification Engine test coverage — deferred (WPF requires live session)

```

---

### File 8: `docs/NOTIFICATION_ENGINE_SPEC.md`

**Why:** The spec describes a complex 6-state machine with countdown timer, mutex, and three button handlers — none of which have any automated test coverage. This is the highest quality risk in the codebase. The spec must clearly communicate this risk and the path forward.

**Location of change:** After the `## Overview` section (the first section after the title and "Last Updated" line).

**Add this exact section** between `## Overview` and `## Popup States`:

```markdown
## ⚠️ Test Coverage Warning

**This component has zero automated test coverage.**

`DailyMotivation.ps1` runs a WPF window dispatched from a PowerShell `-STA` thread and
depends on Windows Task Scheduler for invocation. Neither of these can be exercised by
Pester in a CI/CD environment without a live Windows desktop session.

| Risk | Severity | Mitigation |
|------|----------|-----------|
| State machine logic untested | HIGH | Manual TC-003 through TC-020 in `docs/TEST_PLAN.md` |
| Countdown timer untested | HIGH | Manual TC-007 |
| Mutex enforcement untested | MEDIUM | Manual: launch two instances simultaneously |
| Snooze loop untested | HIGH | Manual TC-005, TC-010 |
| Path validation branch untested | MEDIUM | Manual TC-009, TC-016 |

### Testing Approach Roadmap

To achieve automated coverage of this component, one of these approaches is required:

1. **Extract pure logic from WPF** — move state machine transitions and countdown logic
   into a testable module (`NotificationEngine.psm1`), keeping `DailyMotivation.ps1`
   as a thin WPF host. Pure state machine: fully testable with Pester. WPF host: still
   manual only, but now a thin wrapper with minimal logic.

2. **UI Automation** — use Windows UI Automation (UIA) or FlaUI to drive the WPF window
   from Pester via COM. Requires Windows runner in CI. Complex but achieves full coverage.

3. **Status quo + thorough manual regression** — maintain TC-003 through TC-020 manually
   before every release. Low coverage but zero investment.

**Current status:** Status quo (option 3). Option 1 is the recommended path if/when the
Notification Engine needs modification.

---
```

---

### File 9: `docs/CONFIGURATION_SPEC.md`

**Why:** Configuration schemas are fully validated by the Pester test suite, but the spec contains no reference to tests. A developer reading the spec doesn't know that any change to a schema must also update the tests.

**Read the file first.** For each schema section that corresponds to a file in `%APPDATA%\DailyMotivationBrainHelper\`:
- `popup_config.json`
- `tasks.json`
- `app_settings.json`
- `popup_log.txt`

**For each schema section**, append this line immediately after the schema block (before the next `---` or section header):

For `popup_config.json` schema:
```markdown
> **Test validation:** Schema fully covered in `Tests/Unit/ConfigManager.Tests.ps1` — `Set-PopupConfig` tests.
> Any schema change must update corresponding test cases.
```

For `tasks.json` schema:
```markdown
> **Test validation:** Schema fully covered in `Tests/Unit/TaskScheduler.Tests.ps1` — task creation and retrieval tests.
> Any schema change must update corresponding test cases.
```

For `app_settings.json` schema:
```markdown
> **Test validation:** Schema fully covered in `Tests/Unit/ConfigManager.Tests.ps1` — settings and recent-folders tests.
> Any schema change must update corresponding test cases.
```

For `popup_log.txt` format:
```markdown
> **Test validation:** Log format fully covered in `Tests/Unit/ConfigManager.Tests.ps1` — `Get-OutcomeLog` tests.
> Any format change must update corresponding test cases.
```

---

### Phase 2 Git Commit

After completing all 9 file changes above:

```bash
git add docs/ARCHITECTURE.md docs/INSTALL.md docs/PRD.md docs/TRACEABILITY_MATRIX.md \
        docs/DISTRIBUTION_STRATEGY.md docs/SPRINT_PLAN.md docs/ROADMAP.md \
        docs/NOTIFICATION_ENGINE_SPEC.md docs/CONFIGURATION_SPEC.md

git commit -m "docs(phase2): high-priority documentation updates post-4ba633a audit

Addresses critical and high-priority gaps identified by 5-agent documentation audit.
All changes reflect test infrastructure added in commit 4ba633a.

Files updated:
- ARCHITECTURE.md: Add Quality Assurance & Test Infrastructure section
- INSTALL.md: Fix build script reference, add Developer Setup section
- PRD.md: Add Requirements Validation Matrix (9/25 FRs have automated coverage)
- TRACEABILITY_MATRIX.md: Add Automated Test column, module-level coverage section
- DISTRIBUTION_STRATEGY.md: Update build commands to Invoke-Build system
- SPRINT_PLAN.md: Add Sprint 0 documenting test infrastructure (INFRA-001 through INFRA-009)
- ROADMAP.md: Add Engineering Foundation completed milestone to v1.0 section
- NOTIFICATION_ENGINE_SPEC.md: Add test coverage warning and testing approach roadmap
- CONFIGURATION_SPEC.md: Add test validation notes to all schema sections

Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin main
```

---

## Phase 3 — Medium/Low Priority Documentation Updates

### File 1: `docs/README.md`

**Why:** The document index is missing entries for the new test/build documents and the new docs/reports archive.

**Read the file first.** Then:

**Change 1:** Add a new section (or table entries) for the following documents. If the file has a table of all docs, add these rows:

```markdown
| TESTING.md (root) | Developer testing guide — how to run tests, CI, coverage |
| Tests/README.md | Test suite documentation — structure, fixtures, conventions |
| docs/reports/ | Historical session work products (audits, handoffs, analysis) |
```

**Change 2:** If `docs/HANDOFF.md` and `docs/HANDOFF2.md` appear in the index, remove those entries (they have moved to `docs/reports/`).

---

### File 2: `docs/NPR.md`

**Why:** Non-Product Requirements do not reflect the engineering discipline standards that commit 4ba633a established as mandatory.

**Append to the end of the file:**

```markdown
---

## NPR-008 — Maintainability

All PowerShell modules must maintain automated Pester test coverage of **80% or higher**.
New functions added to `ConfigManager.psm1` or `TaskScheduler.psm1` require corresponding
tests in `Tests/Unit/` before the PR is merged.

**Rationale:** Test coverage protects against regression as the codebase evolves. The
80% threshold was chosen to allow practical coverage of the non-UI code paths while
acknowledging that WPF components cannot be covered by Pester.

## NPR-009 — Code Quality

All PowerShell code (`.ps1`, `.psm1`) must pass **PSScriptAnalyzer** static analysis
with **zero warnings** using the project configuration in `.PSScriptAnalyzerSettings.psd1`.

**Rationale:** Enforced via CI/CD. Any warning indicates a potential bug (alias misuse,
scope issue, encoding problem) that should be fixed before shipping.

## NPR-010 — Build Automation

The project must provide a **single-command build** that runs analysis, tests, and
compilation: `Invoke-Build` (uses `.build.ps1` at project root).

**Rationale:** Reproducible builds reduce the "works on my machine" class of problems.
All distribution artifacts must be produced by the automated build pipeline, not
manual steps.
```

---

### File 3: `docs/RISK_REGISTER.md`

**Why:** Test infrastructure introduces new risks not currently tracked.

**Read the file first.** Identify the last risk ID in the register (currently R-011). Then append:

```markdown
| R-012 | Test dependency version drift (Pester, PSScriptAnalyzer incompatible versions) | Low | Low | `Invoke-Build InstallDependencies` pins versions; CI uses consistent runner |
| R-013 | Notification Engine change introduced without manual test run | Medium | Medium | NOTIFICATION_ENGINE_SPEC.md warning; CONTRIBUTING.md checklist; pre-release regression requirement |
| R-014 | Code coverage drops below 80% threshold (flag only in CI) | Medium | Low | CI blocks PR merge on coverage regression; developer must add tests or document exception |
```

---

### File 4: `docs/GLOSSARY.md`

**Why:** Test terminology is used throughout the codebase documentation but undefined in the glossary.

**Read the file first.** Identify the last entry, then append new terms in the same table format (alphabetical order preferred). Add these entries:

```markdown
| **CI/CD Pipeline** | Automated workflow (`.github/workflows/test.yml`) that runs PSScriptAnalyzer, Pester tests, and PS2EXE compilation on every push and pull request |
| **Code Coverage** | Percentage of source code lines executed during a Pester test run; project target is 80%+ for module code |
| **Invoke-Build** | PowerShell build automation framework; project uses it via `.build.ps1` for test, analyze, compile, and package tasks |
| **Pester** | PowerShell testing framework (v5.x); used for unit and integration tests in `Tests/` |
| **PSScriptAnalyzer** | Static analysis tool for PowerShell; enforces code quality rules defined in `.PSScriptAnalyzerSettings.psd1` |
| **Quality Gate** | CI/CD enforcement point: tests must pass, coverage must be ≥80%, PSScriptAnalyzer must show zero warnings before a PR can merge |
| **Test Fixture** | Pre-built sample data files in `Tests/Fixtures/` used to simulate realistic inputs in Pester tests |
| **Tag Filter** | Pester feature for running a subset of tests by category: `Unit`, `Integration`, `Initialization` |
```

---

### File 5: `docs/FEATURE_MATRIX.md`

**Why:** The feature matrix tracks what's in which version but omits engineering infrastructure features.

**Read the file first.** Identify the table structure (versions as columns). Then append rows for engineering features, using the same column pattern:

```markdown
| Automated test suite (180+ Pester tests) | ❌ | ✅ v1.0 | ✅ |
| CI/CD pipeline (GitHub Actions) | ❌ | ✅ v1.0 | ✅ |
| Build automation (Invoke-Build) | ❌ | ✅ v1.0 | ✅ |
| PSScriptAnalyzer code quality enforcement | ❌ | ✅ v1.0 | ✅ |
| Code coverage reporting (JaCoCo) | ❌ | ✅ v1.0 | ✅ |
```

*Adjust version column alignment to match the existing table.*

---

### File 6: `docs/DOC_IMPACT_ANALYSIS.md`

**Why:** The impact analysis tracked documentation changes for features B-01 through B-19. It should record the test infrastructure addition as a separate audit.

**Append to end of file:**

```markdown
---

## Addendum: Test Infrastructure Impact (Commit 4ba633a — 2026-06-03)

**Trigger:** Modern PowerShell engineering scaffold added (Pester, Invoke-Build, CI/CD)
**Audit methodology:** 5-agent parallel review of 60+ files
**Agent audit reports:** See `docs/reports/` for full reports

### Documentation Changes Required (25 files identified)

| Document | Change Type | Status |
|----------|------------|--------|
| README.md | Add Tests/ to structure, add Testing section | ✅ Done (commit 8d6cb0d) |
| CLAUDE.MD | Fix build ref, update layout, add testing conventions | ✅ Done (commit 8d6cb0d) |
| src/README.md | Add Test Infrastructure section | ✅ Done (commit 8d6cb0d) |
| docs/CONTRIBUTING.md | Add Development Workflow, TDD guidelines | ✅ Done (commit 8d6cb0d) |
| docs/TEST_PLAN.md | Add Automated Testing section | ✅ Done (commit 8d6cb0d) |
| docs/CHANGELOG.md | Add commit 4ba633a entry | ✅ Done (commit 8d6cb0d) |
| docs/ARCHITECTURE.md | Add QA section | ✅ Done (Phase 2) |
| docs/INSTALL.md | Fix build ref, add Developer Setup | ✅ Done (Phase 2) |
| docs/PRD.md | Add validation matrix | ✅ Done (Phase 2) |
| docs/TRACEABILITY_MATRIX.md | Add test coverage column | ✅ Done (Phase 2) |
| docs/DISTRIBUTION_STRATEGY.md | Update build commands | ✅ Done (Phase 2) |
| docs/SPRINT_PLAN.md | Add Sprint 0 | ✅ Done (Phase 2) |
| docs/ROADMAP.md | Add infra milestone | ✅ Done (Phase 2) |
| docs/NOTIFICATION_ENGINE_SPEC.md | Add zero-coverage warning | ✅ Done (Phase 2) |
| docs/CONFIGURATION_SPEC.md | Add test validation notes | ✅ Done (Phase 2) |
| docs/README.md | Add test doc entries | ✅ Done (Phase 3) |
| docs/NPR.md | Add NPR-008, NPR-009, NPR-010 | ✅ Done (Phase 3) |
| docs/RISK_REGISTER.md | Add R-012, R-013, R-014 | ✅ Done (Phase 3) |
| docs/GLOSSARY.md | Add test terminology | ✅ Done (Phase 3) |
| docs/FEATURE_MATRIX.md | Add infra feature rows | ✅ Done (Phase 3) |
| docs/NEXT_STEPS.md | Update with TDD workflow | ✅ Done (Phase 3) |
| docs/FORENSIC_REVIEW.md | Add regression protection section | ✅ Done (Phase 3) |
| Archive session files to docs/reports/ | File moves | ✅ Done (Phase 0) |
```

---

### File 7: `docs/NEXT_STEPS.md`

**Why:** Next steps document contains original backlog tasks; it should be updated to reflect TDD workflow in place and infrastructure completions.

**Read the file first.** Then:

**Change 1:** If the file has unchecked items for "set up testing" or similar, mark them as done.

**Change 2:** Add or update to include the following note at the top of the document:

```markdown
> **Note (2026-06-03):** Test-Driven Development infrastructure is now in place (commit 4ba633a).
> New work items should follow the TDD workflow: write failing test first, implement to pass,
> refactor. See `TESTING.md` and `docs/CONTRIBUTING.md` for developer workflow.
```

**Change 3:** Add this item to the backlog (if not already present):

```markdown
- [ ] Address Notification Engine test coverage gap — extract pure logic from DailyMotivation.ps1 into testable module (see NOTIFICATION_ENGINE_SPEC.md Testing Approach Roadmap)
```

---

### File 8: `docs/FORENSIC_REVIEW.md`

**Why:** The forensic review documented patterns of bugs and their root causes. Now that tests exist for many of these, it should reference which bugs are protected from regression.

**Read the file first.** Append at the end:

```markdown
---

## Regression Protection Status

The following findings from this forensic review are now protected by automated tests
(as of commit 4ba633a). A future code change that re-introduces these bugs will cause
a Pester test to fail, blocking CI.

| Finding | Pester Protection | Test Reference |
|---------|------------------|----------------|
| `Initialize-AppData` not creating `%APPDATA%` directory | ✅ Protected | `Tests/Integration/Initialization.Tests.ps1` — Issue #2 test |
| Module import before directory creation (order of operations) | ✅ Protected | `Tests/Integration/Initialization.Tests.ps1` — Issue #4 test |
| `ConvertFrom-Json "[]"` returns `$null` not `@()` | ✅ Protected | `Tests/Unit/TaskScheduler.Tests.ps1` — empty task list test |
| Duplicate task check case-sensitivity | ✅ Protected | `Tests/Unit/TaskScheduler.Tests.ps1` — case-insensitive path comparison |
| UTF-8 corruption on non-English Windows | ✅ Protected | `Tests/Unit/ConfigManager.Tests.ps1` — international path encoding test |
| Corrupted config file crash | ✅ Protected | `Tests/Unit/ConfigManager.Tests.ps1` — corrupted file recovery test |
| Recent folders exceeding 5 entries | ✅ Protected | `Tests/Unit/ConfigManager.Tests.ps1` — FIFO max-5 test |

**NOT yet protected by automated tests (manual verification required before each release):**
- `$PSScriptRoot` empty in PS2EXE (Issue #3) — requires compiled EXE context
- `DailyMotivation.ps1` silent exit behavior (Issue #6) — WPF context required
- Task Scheduler invocation path (Issues #5, #7) — live Windows session required
```

---

### Phase 3 Git Commit

```bash
git add docs/README.md docs/NPR.md docs/RISK_REGISTER.md docs/GLOSSARY.md \
        docs/FEATURE_MATRIX.md docs/DOC_IMPACT_ANALYSIS.md docs/NEXT_STEPS.md \
        docs/FORENSIC_REVIEW.md

git commit -m "docs(phase3): medium/low priority documentation completeness updates

Final pass of documentation updates from 5-agent audit of commit 4ba633a.
All remaining gaps identified in the audit are now addressed.

Files updated:
- docs/README.md: Add test documentation entries, remove archived HANDOFF entries
- docs/NPR.md: Add NPR-008 (Maintainability), NPR-009 (Code Quality), NPR-010 (Build Automation)
- docs/RISK_REGISTER.md: Add R-012, R-013, R-014 for test infrastructure risks
- docs/GLOSSARY.md: Add 8 test-related terms (Pester, PSScriptAnalyzer, Invoke-Build, etc.)
- docs/FEATURE_MATRIX.md: Add test infrastructure feature rows
- docs/DOC_IMPACT_ANALYSIS.md: Add commit 4ba633a audit addendum with full change table
- docs/NEXT_STEPS.md: Add TDD workflow note, add Notification Engine test gap item
- docs/FORENSIC_REVIEW.md: Add Regression Protection Status section

Documentation audit is now complete. All 25 identified files updated.

Co-Authored-By: Claude <noreply@anthropic.com>"

git push origin main
```

---

## Phase 4 — PRD to GitHub Issue

### Skill: `to-prd`

After Phase 3 push completes, execute the `to-prd` skill using the current conversation context.

**Inputs to synthesize for the PRD:**

- **Problem:** Documentation for the Daily Motivation Brain Helper project was significantly out of date after commit 4ba633a added 180+ Pester tests, Invoke-Build automation, and CI/CD. Developers reading existing docs could not find the test infrastructure, used incorrect build commands, and had no contribution workflow.

- **Solution:** Multi-agent documentation audit + systematic 3-phase update of 25 documentation files + repository architecture improvement (archiving session work products).

- **Modules affected:** All documentation files, plus `docs/reports/` as a new module in the repository architecture.

**PRD template fields:**

**Problem Statement:** Developers and future agents onboarding to the project encounter documentation that describes a pre-test-infrastructure codebase. Build commands are wrong. Repository structure diagrams are incomplete. Contribution guidelines have no testing workflow. The test infrastructure (180+ tests, CI/CD, Invoke-Build) is effectively invisible to anyone reading the docs.

**Solution:** Systematic documentation update across 25 files in 3 phases, guided by a 5-agent parallel audit. Phase 0 also resolves a structural issue: session work products (audit reports, handoff docs) were cluttering the repository root and docs/ directory.

**Label to apply:** `ready-for-agent`

**Publish as:** GitHub Issue titled: `docs: documentation architecture audit + phase 2/3 updates (commit 4ba633a)`

**How to publish:**

```bash
gh issue create \
  --title "docs: documentation architecture audit + phase 2/3 updates (commit 4ba633a)" \
  --label "ready-for-agent" \
  --body "$(cat <<'PRD_EOF'
## Problem Statement

...PRD body...
PRD_EOF
)"
```

*The agent executing Phase 4 must read this plan, the CLAUDE.MD, the conversation context, and `docs/agents/issue-tracker.md` to ensure correct label and issue format before creating the issue.*

---

## Git Workflow Summary

| Phase | Commit Message Summary | Push |
|-------|----------------------|------|
| 0 | `refactor(docs): archive session work products to docs/reports/` | `git push origin main` |
| 2 | `docs(phase2): high-priority documentation updates post-4ba633a audit` | `git push origin main` |
| 3 | `docs(phase3): medium/low priority documentation completeness updates` | `git push origin main` |
| 4 | N/A (GitHub Issue created via `gh` CLI) | N/A |

**Token:** Already configured in remote URL from previous session. Verify with:
```bash
git remote get-url origin | grep ghp_
```

---

## Validation Checklist

Execute after all phases are complete:

### Phase 0 Validation
- [ ] `docs/reports/` directory exists with 11 archived files + README.md
- [ ] `MODERN-POWERSHELL-SCAFFOLDING.md` is NOT in repo root
- [ ] `INITIALIZATION-BUGS.md` is NOT in repo root
- [ ] `docs/HANDOFF.md` is NOT in `docs/`
- [ ] `docs/HANDOFF2.md` is NOT in `docs/`
- [ ] All audit report .md files are NOT in repo root
- [ ] `TESTING.md` IS still in repo root
- [ ] No broken cross-references to moved files: `grep -r "MODERN-POWERSHELL-SCAFFOLDING" . --include="*.md" | grep -v "docs/reports"`

### Phase 2 Validation
- [ ] `docs/ARCHITECTURE.md` contains "Quality Assurance & Test Infrastructure" section
- [ ] `docs/INSTALL.md` does NOT contain `build.ps1` (only `.build.ps1` or `Invoke-Build`)
- [ ] `docs/PRD.md` ends with "Requirements Validation Matrix" table (9 ✅ rows)
- [ ] `docs/TRACEABILITY_MATRIX.md` contains "Module-Level Test Coverage Traceability" section
- [ ] `docs/DISTRIBUTION_STRATEGY.md` commands use `Invoke-Build` not `build.ps1`
- [ ] `docs/SPRINT_PLAN.md` starts with Sprint 0 block (INFRA-001 through INFRA-009)
- [ ] `docs/ROADMAP.md` v1.0 section contains "Engineering Foundation (COMPLETE)" subsection
- [ ] `docs/NOTIFICATION_ENGINE_SPEC.md` contains "⚠️ Test Coverage Warning" section
- [ ] `docs/CONFIGURATION_SPEC.md` has test validation note after each of 4 schema sections

### Phase 3 Validation
- [ ] `docs/README.md` contains entries for `TESTING.md`, `Tests/README.md`, `docs/reports/`
- [ ] `docs/NPR.md` contains NPR-008, NPR-009, NPR-010
- [ ] `docs/RISK_REGISTER.md` contains R-012, R-013, R-014
- [ ] `docs/GLOSSARY.md` contains entries for: Pester, PSScriptAnalyzer, Invoke-Build, Code Coverage, CI/CD Pipeline, Quality Gate, Test Fixture, Tag Filter
- [ ] `docs/FEATURE_MATRIX.md` contains rows for automated test suite and CI/CD pipeline
- [ ] `docs/DOC_IMPACT_ANALYSIS.md` ends with "Addendum: Test Infrastructure Impact" table
- [ ] `docs/NEXT_STEPS.md` starts with TDD workflow note
- [ ] `docs/FORENSIC_REVIEW.md` ends with "Regression Protection Status" table

### Phase 4 Validation
- [ ] GitHub issue exists at `https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues`
- [ ] Issue has `ready-for-agent` label
- [ ] Issue body follows PRD template with all required sections

### Final Check
```bash
# No broken links to archived files
grep -r "HANDOFF\.md\b" . --include="*.md" | grep -v "docs/reports"
grep -r "HANDOFF2\.md\b" . --include="*.md" | grep -v "docs/reports"
grep -r "INITIALIZATION-BUGS\.md" . --include="*.md" | grep -v "docs/reports"
grep -r "MODERN-POWERSHELL-SCAFFOLDING" . --include="*.md" | grep -v "docs/reports"

# Confirm git log
git log --oneline -6
```

Expected git log (most recent first):
```
<hash> docs(phase3): medium/low priority documentation completeness updates
<hash> docs(phase2): high-priority documentation updates post-4ba633a audit
<hash> refactor(docs): archive session work products to docs/reports/
8d6cb0d docs: update documentation for test infrastructure (commit 4ba633a audit)
4ba633a feat: add modern PowerShell engineering infrastructure with Pester tests
...
```

---

## Appendix: File Move Reference

Quick reference for all `git mv` operations in Phase 0:

| Source | Destination |
|--------|-------------|
| `MODERN-POWERSHELL-SCAFFOLDING.md` | `docs/reports/SCAFFOLDING-COMPLETION-2026-06-03.md` |
| `INITIALIZATION-BUGS.md` | `docs/reports/INITIALIZATION-BUG-ANALYSIS-2026-06-03.md` |
| `docs/HANDOFF.md` | `docs/reports/HANDOFF-SESSION-1-2026-06-03.md` |
| `docs/HANDOFF2.md` | `docs/reports/HANDOFF-SESSION-2-2026-06-03.md` |
| `COMMIT-4ba633a-AUDIT-MASTER-REPORT.md` | `docs/reports/AUDIT-MASTER-REPORT-COMMIT-4ba633a.md` |
| `DOCUMENTATION-AUDIT-REPORT.md` | `docs/reports/DOCUMENTATION-AUDIT-REPORT-2026-06-03.md` |
| `DOCUMENTATION-UPDATE-CHECKLIST.md` | `docs/reports/DOCUMENTATION-UPDATE-CHECKLIST-2026-06-03.md` |
| `DOCUMENTATION_AUDIT_REPORT.md` | `docs/reports/DOCUMENTATION-AUDIT-REPORT-ALT-2026-06-03.md` |
| `SPEC_AUDIT_REPORT.md` | `docs/reports/SPEC-AUDIT-REPORT-2026-06-03.md` |
| `DOCUMENTATION-AUDIT-SUMMARY.txt` | `docs/reports/DOCUMENTATION-AUDIT-SUMMARY-2026-06-03.txt` |
| `AUDIT-COMPLETION-SUMMARY.md` | `docs/reports/AUDIT-COMPLETION-SUMMARY-2026-06-03.md` |
