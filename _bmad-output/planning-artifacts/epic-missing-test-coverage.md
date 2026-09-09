---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - source: GitHub Issues
  - issues: [158, 159, 161, 163, 166, 168, 169, 170, 119, 120, 121, 122, 123, 124, 125, 126, 127]
  - branch: SevAI_installing_bmad
generatedBy: bmad-agent-pm (John) CE trigger
date: 2026-08-24
---

# Daily-Motivation-Brain-Helper - Missing Test Coverage Sprint

## Overview

This document breaks down 17 open GitHub issues labelled `ready-for-agent` into two epics targeting
missing test coverage and CI infrastructure gaps. All stories are derived 1-to-1 from issues; no
scope has been added or invented.

**Sprint goal:** Reach a state where the test suite catches Task Scheduler regressions reliably
and the CI pipeline enforces quality gates automatically.

## Requirements Inventory

### Functional Requirements (from issues)

- FR-01: Integration tests must cover multi-folder scheduling (issue #158 AG20-001)
- FR-02: Tests must simulate SYSTEM account identity constraints (issue #159 AG20-002)
- FR-03: Post-run cleanup sweep must verify no real tasks remain (issue #170 AG20-015)
- FR-04: Trigger timing parameters must be asserted in integration tests (issue #166 AG20-011)
- FR-05: Mutex mutual-exclusion must be proven in tests (issue #163 AG20-008)
- FR-06: DST transition boundary must be covered (issue #161 AG20-006)
- FR-07: Teardown must verify Task Scheduler state is clean (issue #169 AG20-014)
- FR-08: Graceful shutdown finally-block path must be covered (issue #168 AG20-013)
- FR-09: CI must run Linux/Windows cross-platform matrix (issue #119 AG16-003)
- FR-10: PSScriptAnalyzerSettings.psd1 must exist at repo root (issue #124 AG16-015)
- FR-11: Pre-test syntax validation must run before Pester (issue #126 AG16-019)
- FR-12: Coverage threshold must fail CI when not met (issues #122 AG16-013, #127 AG16-020)
- FR-13: PowerShell version matrix must be defined in CI (issue #120 AG16-004)
- FR-14: Artifact retention-days must be defined explicitly (issue #121 AG16-012)
- FR-15: Scheduled/nightly CI run must be configured (issue #125 AG16-016)
- FR-16: Changelog must be generated on build (issue #123 AG16-014)

### Non-Functional Requirements

- NFR-01: All Task Scheduler tests must be `-Skip:(-not $IsWindows)` per CLAUDE.md mandate
- NFR-02: No fix may be declared complete from Linux CI or mocked tests alone for Register-ScheduledTask issues (CLAUDE.md WRONG 1 mandate)
- NFR-03: No new mocks of New-ScheduledTaskAction/Trigger/Settings/Principal (CLAUDE.md WRONG 8)
- NFR-04: CI changes must not break existing passing test matrix

### FR Coverage Map

| FR | Epic | Story |
|---|---|---|
| FR-01 | Epic 1 | Story 1.1 |
| FR-02 | Epic 1 | Story 1.2 |
| FR-03 | Epic 1 | Story 1.3 |
| FR-04 | Epic 1 | Story 1.4 |
| FR-05 | Epic 1 | Story 1.5 |
| FR-06 | Epic 1 | Story 1.6 |
| FR-07 | Epic 1 | Story 1.7 |
| FR-08 | Epic 1 | Story 1.8 |
| FR-09 | Epic 2 | Story 2.1 |
| FR-10 | Epic 2 | Story 2.2 |
| FR-11 | Epic 2 | Story 2.3 |
| FR-12 | Epic 2 | Story 2.4, 2.5 |
| FR-13 | Epic 2 | Story 2.6 |
| FR-14 | Epic 2 | Story 2.7 |
| FR-15 | Epic 2 | Story 2.8 |
| FR-16 | Epic 2 | Story 2.9 |

## Epic List

1. **Epic 1: Task Scheduler Integration Test Coverage** - Add missing integration and unit tests for Task Scheduler edge cases; all require live Windows validation per CLAUDE.md.
2. **Epic 2: CI Pipeline and Quality Gate Improvements** - Fix CI configuration, add coverage enforcement, and restore static analysis.

---

## Epic 1: Task Scheduler Integration Test Coverage

**Goal:** Close the eight identified gaps in Task Scheduler test coverage. Every story in this epic
produces tests tagged `-Skip:(-not $IsWindows)` and requires a passing run on a real Windows
10/11 machine before the issue may be closed (CLAUDE.md mandate: never close based on Linux CI
or mocked tests alone for Register-ScheduledTask issues).

---

### Story 1.1: Multi-Folder Scheduling Integration Tests

Closes: #158 AG20-001 (Critical)

As a developer maintaining the scheduling subsystem,
I want integration tests that schedule two or more distinct folders simultaneously,
So that tasks.json consistency with N entries and selective removal are verifiable without running the app manually.

**Acceptance Criteria:**

**Given** the test environment has a clean temp APPDATA dir and Register-ScheduledTask is mocked,
**When** `New-MotivationTask` is called for three distinct FolderPaths in the same session,
**Then** `tasks.json` contains exactly three PENDING entries, each with a unique TaskId, and `Get-ScheduledTask` is called three times.

**Given** two tasks are registered for different folders,
**When** `Remove-MotivationTask` is called for one TaskId,
**Then** `tasks.json` retains exactly one PENDING entry and `Unregister-ScheduledTask` is called exactly once with the correct task name.

**Given** a tasks.json with three entries,
**When** `Get-MotivationTasks` is called,
**Then** all three tasks are returned with correct FolderPath values (case-insensitive match).

**Dev notes:** Test file: `Tests/Integration/SingleFile.Tests.ps1` or new `Tests/Integration/MultiFolderScheduling.Tests.ps1`. Must use `-Skip:(-not $IsWindows)`. Do not mock New-ScheduledTaskAction/Trigger/Settings/Principal per CLAUDE.md WRONG 8.

---

### Story 1.2: SYSTEM Account Identity Constraint Tests

Closes: #159 AG20-002 (Critical)

As a developer,
I want tests that simulate the SYSTEM account's APPDATA and registry constraints,
So that scheduling failures under SYSTEM are caught before deployment.

**Acceptance Criteria:**

**Given** `$env:APPDATA` is set to `C:\Windows\System32\config\systemprofile\AppData\Roaming` (SYSTEM path),
**When** `Initialize-AppData` is called,
**Then** the function either creates directories under that path or throws a descriptive error naming the failing operation (not a generic "Invalid Folder" error per CLAUDE.md WRONG 5).

**Given** `Initialize-AppData` is called under the SYSTEM APPDATA path,
**When** the path is not writable (simulated via mock or temp read-only dir),
**Then** the error message includes the operation name and, where available, a Windows error code.

**Dev notes:** Must be `-Skip:(-not $IsWindows)`. No live SYSTEM impersonation required -- redirect `$env:APPDATA` in BeforeAll. Confirm test machine has write access to temp path.

---

### Story 1.3: Post-Run Task Cleanup Safety Sweep

Closes: #170 AG20-015 (High)

As a developer running the test suite on a development machine,
I want AfterAll blocks to sweep for real DailyMotivation_* tasks and fail if any are found,
So that a failed mock scope never silently leaves persistent Task Scheduler entries.

**Acceptance Criteria:**

**Given** any test in `Tests/Integration/` completes (pass or fail),
**When** the AfterAll block runs,
**Then** `Get-ScheduledTask -TaskName "DailyMotivation_*" -ErrorAction SilentlyContinue` returns no results, or the test suite logs a prominent warning and the AfterAll block calls `Unregister-ScheduledTask` on any found tasks.

**Given** a stray task is found during AfterAll sweep,
**When** cleanup runs,
**Then** the cleanup itself is logged to the test output (not silently swallowed).

**Dev notes:** Add to `AfterAll` in `SingleFile.Tests.ps1` and any other integration test file. Must be `-Skip:(-not $IsWindows)`. The sweep is a safety net, not a test assertion -- it should clean up and warn, not hard-fail the suite.

---

### Story 1.4: Trigger Timing Parameter Assertions

Closes: #166 AG20-011 (Medium)

As a developer,
I want integration tests to assert the StartBoundary, EndBoundary, and ExecutionTimeLimit values passed to the mocked Register-ScheduledTask,
So that timing regressions are caught automatically.

**Acceptance Criteria:**

**Given** `New-MotivationTask` is called with TriggerTime = today at 14:00,
**When** `Register-ScheduledTask` is captured by the mock,
**Then** the captured `$Trigger.StartBoundary` equals the ISO 8601 string for today at 14:00 in local time.

**Given** `New-MotivationTask` is called,
**When** the mock captures the task settings,
**Then** `$Trigger.EndBoundary` is 11 minutes after StartBoundary (per existing code) and `$Settings.ExecutionTimeLimit` is `PT1H` or the configured value.

**Dev notes:** Extend existing mocked tests in `Tests/TaskScheduler.Tests.ps1`. These assertions can run on Linux (mock-only). Windows live test still required for any Register-ScheduledTask fix per mandate.

---

### Story 1.5: Mutex Mutual-Exclusion Tests

Closes: #163 AG20-008 (Medium)

As a developer,
I want tests that prove the popup mutex prevents two simultaneous instances,
So that the race condition guard is verified beyond name-format checking.

**Acceptance Criteria:**

**Given** a mutex with the correct name `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}` is already held,
**When** the second `Show-PopupWindow` call attempts to acquire the same mutex,
**Then** the second call exits without showing a second popup window (verified by mock/return value).

**Given** the first mutex holder exits abnormally (simulated by releasing the mutex as abandoned),
**When** the `AbandonedMutexException` catch block runs,
**Then** the application does not crash and the mutex is re-acquired.

**Dev notes:** Use `[System.Threading.Mutex]` directly in the test to hold the mutex before calling the function under test. Tests targeting WPF must run STA (`-RunType sta` in PesterConfiguration or `-STA` on the process).

---

### Story 1.6: DST Transition Edge Case

Closes: #161 AG20-006 (Medium)

As a developer,
I want a test that schedules a task for a time that falls in a DST gap or fold,
So that `Get-ScheduleTime` and `New-MotivationTask` handle ambiguous times without crashing.

**Acceptance Criteria:**

**Given** `Get-ScheduleTime` is called with a trigger hour that falls in a DST forward-gap (e.g., 2:30 AM on a spring-forward day in a US timezone),
**When** the function returns,
**Then** the returned DateTime is not in the non-existent DST gap (i.e., the value is either the pre-gap or post-gap equivalent, not an exception).

**Given** a TriggerTime that falls in a DST fold (ambiguous hour),
**When** `New-MotivationTask` constructs the EndBoundary string,
**Then** the string is a parseable ISO 8601 value (no FormatException).

**Dev notes:** Mock `Get-Date` to return a DateTime near a known DST transition. Use `[System.TimeZoneInfo]` to construct a test-specific ambiguous time. This test can run on Linux (pure .NET, no Task Scheduler calls needed).

---

### Story 1.7: Teardown State Verification

Closes: #169 AG20-014 (Low)

As a developer,
I want the integration test AfterAll to assert the test environment is clean after each run,
So that test pollution does not cause false failures in subsequent runs.

**Acceptance Criteria:**

**Given** a complete integration test run,
**When** AfterAll finishes,
**Then** no mutex named `Global\DailyMotivationBrainHelperPopup_*` is held by the test process.

**Given** the APPDATA redirect is active during tests,
**When** AfterAll removes the temp directory,
**Then** `$env:APPDATA` is restored to its original value before AfterAll exits.

**Dev notes:** Add mutex-held check and `$env:APPDATA` restore assertion to `AfterAll` in `SingleFile.Tests.ps1`. Low-priority polish; can be combined with Story 1.3 cleanup work if convenient.

---

### Story 1.8: Graceful Shutdown Finally-Block Coverage

Closes: #168 AG20-013 (Low)

As a developer,
I want a unit test that verifies the `finally` block in `Show-PopupWindow` releases the mutex even when an exception is thrown mid-popup,
So that abnormal exits don't leave dangling mutex handles.

**Acceptance Criteria:**

**Given** `Show-PopupWindow` is dot-sourced with `-NoRun`,
**When** a test mocks the WPF window construction to throw an exception,
**Then** after the exception propagates, the mutex named `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}` is no longer held by the test process.

**Given** the finally block runs after an exception,
**Then** no ErrorRecord is written to the error stream (the finally block does not itself throw).

**Dev notes:** WPF mock requires STA. Low priority -- can defer to after higher-severity stories in this epic are complete.

---

## Epic 2: CI Pipeline and Quality Gate Improvements

**Goal:** Fix nine CI and tooling gaps. These stories are primarily changes to `.github/workflows/`
and `Invoke-Tests.ps1`; most can be verified on Linux CI without a Windows live test.

---

### Story 2.1: Cross-Platform CI Matrix

Closes: #119 AG16-003 (Critical)

As a developer,
I want the CI workflow to run tests on both `windows-latest` and `ubuntu-latest`,
So that the HeadlessPlatform abstraction is exercised automatically on every PR.

**Acceptance Criteria:**

**Given** a pull request is opened,
**When** the CI test job runs,
**Then** there are at least two matrix entries: one `windows-latest` and one `ubuntu-latest`.

**Given** the `ubuntu-latest` run executes,
**When** `Invoke-Tests.ps1` runs on Linux,
**Then** only the Linux-safe test files run (as defined in CLAUDE.md: `Config.Platform.Tests.ps1`, `TaskScheduler.Platform.Tests.ps1`, `PlatformAdapter.Tests.ps1`, `FolderScheduling.Tests.ps1`) and Windows-only tests are skipped via `-Skip:(-not $IsWindows)`.

**Given** the `windows-latest` run executes,
**When** all tests run,
**Then** the existing test suite passes without new failures introduced by the matrix change.

**Dev notes:** Modify `.github/workflows/test.yml`. Add `strategy.matrix.os: [windows-latest, ubuntu-latest]` and change `runs-on: ${{ matrix.os }}`. Confirm `pwsh` is available on ubuntu-latest runner.

---

### Story 2.2: PSScriptAnalyzerSettings File at Repo Root

Closes: #124 AG16-015 (High)

As a developer,
I want `.PSScriptAnalyzerSettings.psd1` to exist at the repo root so the CI static analysis step finds it,
So that PSScriptAnalyzer rules are actively enforced rather than silently ignored.

**Acceptance Criteria:**

**Given** `.PSScriptAnalyzerSettings.psd1` exists at the repo root,
**When** the CI PSScriptAnalyzer step runs,
**Then** the step uses the file (no "settings file not found" warning in the step output).

**Given** the settings file is in place,
**When** `Invoke-ScriptAnalyzer -Path DailyMotivation.ps1 -Settings .PSScriptAnalyzerSettings.psd1` is run locally,
**Then** the command exits 0 with no rule violations in the current source.

**Dev notes:** Copy from `Archive/.PSScriptAnalyzerSettings.psd1` or create a new one. Review rules in the Archive copy; remove any that are too noisy for current codebase state before placing at root.

---

### Story 2.3: Pre-Test Syntax Validation in Invoke-Tests.ps1

Closes: #126 AG16-019 (High)

As a developer,
I want `Invoke-Tests.ps1` to parse `DailyMotivation.ps1` for syntax errors before running Pester,
So that a syntax error produces a clear, attributable failure message rather than an opaque Pester crash.

**Acceptance Criteria:**

**Given** `DailyMotivation.ps1` has a syntax error (simulated by a temp copy with a broken function),
**When** `Invoke-Tests.ps1` is run,
**Then** the script exits before running Pester and the error output names `DailyMotivation.ps1` as the source of the failure.

**Given** `DailyMotivation.ps1` has no syntax errors,
**When** `Invoke-Tests.ps1` is run,
**Then** the script proceeds to `Invoke-Pester` without additional delay.

**Dev notes:** Add `$null = [System.Management.Automation.Language.Parser]::ParseFile('DailyMotivation.ps1', [ref]$null, [ref]$parseErrors)` before the Invoke-Pester call. If `$parseErrors.Count -gt 0`, write each error and exit 1.

---

### Story 2.4: Coverage Threshold Enforcement in Invoke-Tests.ps1

Closes: #127 AG16-020 (High)

As a developer,
I want `Invoke-Tests.ps1` to fail with exit code 1 when code coverage drops below a defined threshold,
So that coverage regressions are caught by CI automatically.

**Acceptance Criteria:**

**Given** Pester returns a coverage result below 70% (configurable threshold),
**When** `Invoke-Tests.ps1` finishes,
**Then** the script writes a clear message naming the actual coverage percentage and the threshold, then exits 1.

**Given** coverage meets or exceeds the threshold,
**When** `Invoke-Tests.ps1` finishes,
**Then** the script exits normally (exit code from `$result.FailedCount`).

**Dev notes:** Read `$result.CodeCoverage.CoveragePercent` after `Invoke-Pester`. Define `$CoverageThreshold = 70` (or parameterize). Only enforce when `-CI` flag is passed to avoid blocking local runs. Coordinate threshold value with Story 2.5.

---

### Story 2.5: Coverage Quality Gate in CI Workflow

Closes: #122 AG16-013 (High)

As a developer,
I want the CI workflow to fail the build when coverage falls below threshold,
So that the quality gate is enforced even when `Invoke-Tests.ps1` is not used directly.

**Acceptance Criteria:**

**Given** the `irongut/CodeCoverageSummary` step runs and reports coverage below the threshold,
**When** the CI job completes,
**Then** the job exits with a non-zero status code (fail the build).

**Given** coverage meets the threshold,
**When** CI runs,
**Then** the workflow passes normally.

**Dev notes:** Add `fail_below_min: true` and `minimum_coverage: 70` to the `irongut/CodeCoverageSummary` action step in `.github/workflows/test.yml`. Align threshold with Story 2.4.

---

### Story 2.6: PowerShell Version Matrix in CI

Closes: #120 AG16-004 (High)

As a developer,
I want CI to run against both PowerShell 5.1 and PowerShell 7.x,
So that version-specific regressions are caught before release.

**Acceptance Criteria:**

**Given** CI runs on `windows-latest`,
**When** the test job executes,
**Then** there is at least one run using `pwsh` (PS 7.x) and one that validates PS 5.1 compatibility (or a documented decision not to support PS 5.1 is recorded in CLAUDE.md).

**Given** the version matrix is defined,
**When** a PS7-only syntax (`??`, `?.`, `Join-String`, `ForEach-Object -Parallel`) is introduced in `DailyMotivation.ps1`,
**Then** the PS 5.1 CI run fails or a lint rule catches it (per CLAUDE.md PS7-syntax gate note).

**Dev notes:** Add `pwsh-version` to the strategy matrix in `.github/workflows/test.yml`. Note: CLAUDE.md already states "PS7-syntax gate blocks `??`, `?.`, `Join-String`, `ForEach-Object -Parallel` in runtime code paths" -- verify the gate is active or add it as a separate PSScriptAnalyzer rule.

---

### Story 2.7: Artifact Retention Policy

Closes: #121 AG16-012 (Medium)

As a developer,
I want all `upload-artifact` steps to specify `retention-days`,
So that test artifacts don't accumulate indefinitely at GitHub's default retention period.

**Acceptance Criteria:**

**Given** any `actions/upload-artifact` step in `.github/workflows/test.yml`,
**When** the YAML is reviewed,
**Then** every step includes `retention-days: <N>` where N is a defined value (e.g., 30).

**Dev notes:** Audit all `upload-artifact` steps in `test.yml` (currently lines 38-45 and 163-167). Add `retention-days: 30` (or repo-agreed value) to each.

---

### Story 2.8: Scheduled Nightly CI Runs

Closes: #125 AG16-016 (Medium)

As a developer,
I want a scheduled CI trigger to run the full test suite nightly,
So that intermittent failures and time-dependent bugs are caught automatically.

**Acceptance Criteria:**

**Given** the CI workflow YAML,
**When** the workflow file is reviewed,
**Then** a `schedule` trigger is present using a valid cron expression (e.g., `'0 3 * * *'` for 3 AM UTC daily).

**Given** the nightly run triggers,
**When** it completes,
**Then** failure notifications reach the repo maintainers (via GitHub notification defaults or an explicit `on: workflow_run` step).

**Dev notes:** Add `on: schedule: - cron: '0 3 * * *'` to `.github/workflows/test.yml`. This is a YAML-only change with no code impact.

---

### Story 2.9: Changelog Generation on Build

Closes: #123 AG16-014 (Low)

As a developer,
I want `build.ps1` or CI to generate a `CHANGELOG.md` entry on release builds,
So that release history is automatically maintained.

**Acceptance Criteria:**

**Given** a tagged release build runs in CI,
**When** `build.ps1` (or a dedicated CI step) executes,
**Then** a `CHANGELOG.md` is created or updated with the tag version, date, and list of merged PRs or commits since the previous tag.

**Given** a non-release (PR or push) build runs,
**When** CI executes,
**Then** no CHANGELOG modification occurs (changelog generation is release-only).

**Dev notes:** Lowest-priority story in this epic. Can use a GitHub Action (e.g., `softprops/action-gh-release` with `generate_release_notes: true`) as the changelog source rather than modifying `build.ps1`. Decide approach before implementing.
