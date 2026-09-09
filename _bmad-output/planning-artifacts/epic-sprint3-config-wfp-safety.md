---
stepsCompleted: [1, 2, 3, 4]
inputDocuments:
  - source: GitHub Issues
  - issues: [41, 45, 42, 43, 44, 46, 34, 96, 38, 37, 36, 35]
  - branch: SevAI_installing_bmad
generatedBy: bmad-agent-pm (John) CE trigger
date: 2026-08-24
---

# Daily-Motivation-Brain-Helper - Sprint 3: Config/AppData Robustness and WPF Safety

## Overview

12 issues across two epics. Epic 1 hardens the config and AppData init layer against
schema drift, unwritable directories, and fallback-path loss. Epic 2 guards all WPF
entry points against missing assembly loads and fixes window-ownership and resource-leak
issues.

**Sprint goal:** Eliminate silent data loss from config schema mismatches and fallback
directory amnesia, and ensure the app exits cleanly with a user-readable message instead
of a .NET assembly exception when WPF is unavailable.

## Requirements Inventory

### Functional Requirements

- FR-01: Get-Config must use $script:ConfigDefaults to fill any missing property on load (#42)
- FR-02: Initialize-AppData must detect and persist the fallback AppData path across restarts (#45)
- FR-03: Config schema version must be written on creation and checked on load (#41)
- FR-04: A migration entry-point must exist for future config schema changes (#46)
- FR-05: Save-Config and Save-TasksJson must check directory write-access before writing (#43)
- FR-06: Tilde in fallback path must be expanded to $env:HOME or equivalent (#44)
- FR-07: Tasks.json PENDING entries must be cleaned up when Task Scheduler service is stopped (#34)
- FR-08: All XamlReader call sites must guard with a PresentationFramework assembly pre-check (#96)
- FR-09: /setfolder mode must not call MessageBox before assemblies are loaded (#38)
- FR-10: Show-MainWindow and Show-PopupWindow must set window.Owner before ShowDialog (#37)
- FR-11: Event handlers in Show-MainWindow must be unregistered on window close (#36)
- FR-12: Popup XAML Window element must declare MinWidth and MinHeight (#35)

### Non-Functional Requirements

- NFR-01: All AG7 config fixes must preserve backward-compat with existing config.json files
- NFR-02: Schema version check must not break existing tests that write config.json directly
- NFR-03: Assembly pre-check must not prevent the app from running on any supported Windows version
- NFR-04: No new mocks of New-ScheduledTask* cmdlets (CLAUDE.md WRONG 8)

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
| FR-08 | Epic 2 | Story 2.1 |
| FR-09 | Epic 2 | Story 2.2 |
| FR-10 | Epic 2 | Story 2.3 |
| FR-11 | Epic 2 | Story 2.4 |
| FR-12 | Epic 2 | Story 2.5 |

---

## Epic 1: AppData and Config Robustness

**Goal:** Harden Initialize-AppData and Get-Config against schema drift, missing defaults,
unwritable directories, and fallback-path amnesia. All stories are Linux-safe unless noted.

---

### Story 1.1: Fill Missing Config Properties from ConfigDefaults

Closes: #42 AG7-007 (High)

As a developer,
I want Get-Config to merge any missing property from $script:ConfigDefaults before returning,
So that a config.json written by an older version that lacks a new property never returns $null
for that property to callers.

**Acceptance Criteria:**

**Given** config.json contains only `{"default_trigger_hour":14}` (missing task_warning_threshold),
**When** Get-Config loads it,
**Then** the returned object has `task_warning_threshold` set to the value in $script:ConfigDefaults (5).

**Given** config.json has both properties set to non-default values,
**When** Get-Config loads it,
**Then** those values are preserved (no overwrite from defaults).

**Dev notes:** After ConvertFrom-Json and the existing Add-Member guards, iterate `$script:ConfigDefaults.PSObject.Properties` and for each property where `$cfg` does not already have a valid value, assign the default. This is a forward-compat guard only -- do not overwrite existing valid values.

---

### Story 1.2: Persist Fallback AppData Path Across Restarts

Closes: #45 AG7-021 (Critical)

As a developer,
I want Initialize-AppData to write the chosen AppData directory path to a well-known marker
file when it falls back to a temp directory,
So that the next app launch reads the marker and uses the same path instead of recalculating
and potentially picking a different directory.

**Acceptance Criteria:**

**Given** $env:APPDATA is unset and Initialize-AppData falls back to a temp directory,
**When** Initialize-AppData completes,
**Then** a marker file (e.g., `DailyMotivation_appdata_fallback.txt`) is written to $env:TEMP
containing the chosen fallback path.

**Given** the marker file exists on a subsequent launch,
**When** Initialize-AppData runs,
**Then** it reads the marker and uses the recorded path rather than recalculating from $env:APPDATA.

**Given** the marker file exists but points to a path that no longer exists,
**When** Initialize-AppData runs,
**Then** it recreates the directory at that path (or falls back to a new temp path and updates the marker).

**Dev notes:** Write marker as `[System.IO.Path]::Combine($env:TEMP, 'DailyMotivation_appdata_fallback.txt')`. Content: the full AppDataDir path. On startup, check for marker before evaluating $env:APPDATA. Linux-safe: $env:TEMP exists on all platforms.

---

### Story 1.3: Write and Check Config Schema Version

Closes: #41 AG7-003 (Critical)

As a developer,
I want config.json to include a schemaVersion field on creation, and Get-Config to check it
on load,
So that a config file from an incompatible version triggers a migration rather than silent
property-access failures.

**Acceptance Criteria:**

**Given** Initialize-AppData writes the initial config.json,
**When** the file is created,
**Then** it contains `"schemaVersion": 1`.

**Given** Get-Config loads a config.json that has no schemaVersion field (existing installs),
**When** the file is loaded,
**Then** it is treated as schemaVersion 0 and defaults are applied (backward-compat).

**Given** Get-Config loads a config.json with `schemaVersion: 1`,
**When** the file is loaded,
**Then** the config is returned without forced defaults (version matches current).

**Dev notes:** Add `$script:ConfigSchemaVersion = 1` near $script:ConfigDefaults. In Initialize-AppData, write `schemaVersion = $script:ConfigSchemaVersion` into the initial config. In Get-Config, after ConvertFrom-Json, read `.schemaVersion` (default 0 if absent). Only apply forced-defaults migration when version < current. Keep migration logic minimal for v1: just ensure all defaults are filled (delegates to Story 1.1 logic).

---

### Story 1.4: Add Config Migration Entry Point

Closes: #46 AG7-022 (High)

As a developer,
I want a named function `Invoke-ConfigMigration` that runs when schemaVersion < current,
So that future schema changes have a defined, testable migration path rather than inline ad-hoc code in Get-Config.

**Acceptance Criteria:**

**Given** Get-Config detects schemaVersion 0 (no version field),
**When** it runs Invoke-ConfigMigration,
**Then** the config object is updated with any missing defaults and schemaVersion is set to the current version.

**Given** schemaVersion already equals the current version,
**When** Get-Config runs,
**Then** Invoke-ConfigMigration is not called (no unnecessary overhead).

**Dev notes:** `function Invoke-ConfigMigration { param($cfg, $fromVersion) ... }`. For v0->v1, call the defaults-fill logic from Story 1.1. The function does NOT write to disk -- Get-Config returns the migrated object in memory; callers that save config will persist it. Add a Pester test verifiable on Linux.

---

### Story 1.5: Check Directory Write-Access Before Config and Tasks Writes

Closes: #43 AG7-011 (High)

As a developer,
I want Save-Config and Save-TasksJson to verify the target directory is writable before
attempting Set-Content,
So that a read-only AppData directory produces a descriptive error rather than a raw
IOException.

**Acceptance Criteria:**

**Given** the directory containing config.json is read-only (simulated in test),
**When** Save-Config is called,
**Then** it throws with a message that names the directory and the operation (not a raw IOException).

**Given** the directory is writable,
**When** Save-Config is called,
**Then** the file is written normally (regression test).

**Dev notes:** Add a helper function `Test-DirectoryWritable { param($Path) }` that creates and immediately deletes a temp probe file. Call it in Save-Config and Save-TasksJson before the tempPath write. If not writable, throw `"Cannot write to [directory]: directory is not writable"`. Linux-safe.

---

### Story 1.6: Expand Tilde in Fallback AppData Path

Closes: #44 AG7-014 (High)

As a developer,
I want Initialize-AppData to replace a leading tilde in the fallback base directory with
the value of $env:HOME (or $env:USERPROFILE on Windows),
So that `~\.local\share\...` is never stored or used as a literal path starting with `~`.

**Acceptance Criteria:**

**Given** $env:HOME is set and $env:APPDATA is unset and $script:Platform is null,
**When** Initialize-AppData runs,
**Then** $script:AppDataDir does not start with `~` and the directory is created.

**Given** both $env:HOME and $env:APPDATA are unset,
**When** Initialize-AppData runs,
**Then** the fallback uses $env:TEMP and does not produce a path starting with `~`.

**Dev notes:** After computing $baseDir in Initialize-AppData: `if ($baseDir -like '~*') { $home = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { $env:TEMP }; $baseDir = $baseDir -replace '^~', $home }`. Linux-safe.

---

### Story 1.7: Clean Up PENDING Tasks When Task Scheduler Service Stops

Closes: #34 AG5-019 (Medium)

As a developer,
I want Show-MainWindow to mark or remove PENDING tasks.json entries when the user declines
to start the Task Scheduler service,
So that stale PENDING entries are not displayed after the service-unavailable exit.

**Acceptance Criteria:**

**Given** the Task Scheduler service is not running and the user clicks No on the restart dialog,
**When** the function returns,
**Then** all PENDING tasks.json entries have status set to DELETED (or the file is cleared) before exit.

**Given** the user clicks Yes and the service starts successfully,
**When** the app continues,
**Then** tasks.json is unmodified.

**Dev notes:** In the service-not-running code path (~line 1707-1721), before returning, call `Get-TasksJson` and update any PENDING task to DELETED, then `Save-TasksJson`. This is Windows-only code so it only runs when $IsWindows. Add a Pester test for the mark-deleted logic using mocked Task Scheduler state.

---

## Epic 2: WPF Assembly Safety and Window Fixes

**Goal:** Guard all WPF entry points against missing assembly loads, fix window
ownership, fix event handler memory leaks, and add layout constraints to the popup.
Stories 2.1-2.5 all require Windows 10/11 live testing.

---

### Story 2.1: Add PresentationFramework Pre-Check to All XamlReader Call Sites

Closes: #96 AG13-007 (Critical)

As a developer,
I want all three XamlReader call sites (Show-MainWindow, Show-PopupWindow, Show-ErrorDialog)
to verify PresentationFramework is loaded before attempting XamlReader::Load,
So that a missing WPF assembly produces a user-readable error rather than a .NET
TypeLoadException or ExecutionEngineException.

**Acceptance Criteria:**

**Given** PresentationFramework is not loaded,
**When** Show-MainWindow is invoked,
**Then** the app writes a clear diagnostic message to stderr and exits with code 1 (no .NET exception shown).

**Given** PresentationFramework is loaded normally,
**When** Show-MainWindow runs,
**Then** behavior is unchanged (no regression).

**Dev notes:** Add a guard function `Test-WpfAvailable` that attempts `[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')` and returns $false if it throws. Call it at the top of each WPF-dependent function. For Show-ErrorDialog: if WPF unavailable, write to stderr instead of showing a MessageBox. Windows-only test required.

---

### Story 2.2: Guard Assembly Load in /setfolder Mode Before MessageBox

Closes: #38 AG6-019 (High)

As a developer,
I want the /setfolder entry point to load WPF assemblies before calling Show-InfoDialog
or Show-ErrorDialog,
So that the confirmation MessageBox is never called before
[System.Windows.MessageBox] is available.

**Acceptance Criteria:**

**Given** the /setfolder switch runs on a machine where assemblies have not been loaded,
**When** Show-InfoDialog is called for the confirmation,
**Then** the assemblies are already loaded and no TypeLoadException occurs.

**Given** assemblies are already loaded (normal execution),
**When** /setfolder runs,
**Then** the load call is a no-op (idempotent).

**Dev notes:** In the /setfolder switch block (~line 3025), before any dialog call, call `Initialize-WpfAssemblies` (or the existing `$script:AssembliesLoaded` guard pattern used elsewhere). Check how Show-MainWindow initializes assemblies and replicate that check at the top of the /setfolder block. Windows-only test.

---

### Story 2.3: Set Window.Owner Before ShowDialog

Closes: #37 AG6-013 (Medium)

As a developer,
I want Show-MainWindow and Show-PopupWindow to set $window.Owner to the active desktop
window (or to $null explicitly with Topmost=$true for the popup) before ShowDialog,
So that the window appears in the correct z-order and is not hidden behind other applications.

**Acceptance Criteria:**

**Given** another window is in the foreground when Show-PopupWindow runs,
**When** the popup appears,
**Then** it is shown above all other windows (Topmost=$true already set; Owner is set or the Topmost behavior is confirmed sufficient).

**Given** Show-MainWindow opens a child dialog (folder picker),
**When** the dialog appears,
**Then** it is parented to the main window and cannot be sent behind it.

**Dev notes:** For the popup (already Topmost=$true in XAML): verify `$window.Topmost = $true` is set in code-behind before ShowDialog or confirm the XAML attribute is sufficient. For the main window: ensure any child dialog (FolderBrowserDialog) has Owner set. Windows-only test.

---

### Story 2.4: Unregister Event Handlers on Window Close

Closes: #36 AG6-011 (Medium)

As a developer,
I want Show-MainWindow to remove all Add_Click, Add_DragEnter, Add_DragLeave, and Add_Drop
handlers in a Closing event handler,
So that WPF button references are released and the GC can collect the window.

**Acceptance Criteria:**

**Given** Show-MainWindow runs and the window is closed,
**When** the Closing event fires,
**Then** a Remove_Click (or equivalent remove handler) call is made for each registered handler, OR the window is explicitly closed and set to $null to release references.

**Given** the window is closed normally (user X button),
**When** the process continues,
**Then** no ObjectDisposedException is thrown from dangling handler references.

**Dev notes:** In Show-MainWindow, add an `$window.Add_Closing({ ... remove handlers ... })` block before `ShowDialog`. In PowerShell, Add_Click scriptblocks cannot be removed by reference (no -= operator). The practical fix is: in the Closing handler, set all button variables to $null and call `$window.Close()` to ensure the WPF dispatcher releases them. Alternatively, use `$window.Dispatcher.InvokeShutdown()`. Windows-only test.

---

### Story 2.5: Add MinWidth and MinHeight to Popup Window XAML

Closes: #35 AG6-005 (Medium)

As a developer,
I want the popup Window XAML element to declare MinWidth="400" and MinHeight="200",
So that the layout never collapses to zero size on screens with unusual DPI or font scaling.

**Acceptance Criteria:**

**Given** the popup window opens on a high-DPI display,
**When** the window renders,
**Then** its width is at least 400 logical pixels and height at least 200 logical pixels.

**Given** the normal popup opens,
**When** it renders at default size (Width="500", SizeToContent="Height"),
**Then** SizeToContent still applies for the height (no regression -- MinHeight is a lower bound, not a fixed height).

**Dev notes:** In the popup XAML Window element (~line 2140), add `MinWidth="400" MinHeight="200"` attributes. Single-line XAML change. The existing `Width="500"` remains. Windows-only test (XAML rendering).
