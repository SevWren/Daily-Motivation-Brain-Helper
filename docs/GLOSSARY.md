# Glossary

**Last Updated:** 2026-06-09
**Last Reviewed**: 2026-06-09

This glossary defines all technical, architectural, and domain-specific terms used in the Daily Motivation Brain Helper project.

---

## Table of Contents

1. [Application Features & Concepts](#application-features--concepts)
2. [Technical Architecture](#technical-architecture)
3. [PowerShell & Windows Components](#powershell--windows-components)
4. [Build System & Tooling](#build-system--tooling)
5. [Testing & Quality Assurance](#testing--quality-assurance)
6. [Project Management & Documentation](#project-management--documentation)
7. [Configuration & Data](#configuration--data)

---

## Application Features & Concepts

| Term | Definition | Context | Related Terms |
|------|-----------|---------|---------------|
| **Scheduled Task** | A Windows Task Scheduler entry that fires the popup at a specific time | Core mechanism for triggering motivational popups at 2:00 PM | Task Scheduler, Trigger Time |
| **Popup** | The WPF motivational notification window that appears at scheduled times | Implemented in `DailyMotivation.ps1` using WPF XAML | WPF, Notification Engine |
| **Snooze** | Dismissing the popup temporarily; it reappears after the selected duration (5/15/30/60 min) | User can choose snooze duration via split-button (B-10) | Snooze Loop, Snooze Engine |
| **Accept / Open Folder** | The action that completes a scheduled task and opens Windows Explorer | Terminal action marking task as COMPLETED | Task Completion, Explorer Launcher |
| **Dismiss for Today** | A terminal action that cancels all remaining snooze re-triggers without opening the folder (B-11) | Sets task status to DISMISSED without opening Explorer | Snooze Loop, SSOT-009 |
| **Undo Window** | The 30-second grace period after scheduling during which the task can be cancelled with one click (B-04) | Implemented with DispatcherTimer countdown | Grace Period, DispatcherTimer |
| **Folder Path** | The absolute Windows filesystem path to the user's target folder | Stored in `popup_config.json` and validated at popup time | Folder Name, Path Validation |
| **Folder Name** | The leaf directory name (last component of the path), shown in the popup subtitle (B-12) | Extracted using `Split-Path -Leaf` | Folder Path |
| **Explorer Launcher** | The component that calls `explorer.exe` with the target folder path | Validates path existence before launching | Path Validation |
| **Snooze Loop** | The cycle of popup → snooze → reappear that repeats until acceptance or dismissal | No maximum iteration count per SSOT-008 | Snooze, Snooze Engine |
| **Task Completion** | The state reached when the user clicks "Open Folder" (outcome=Opened) | One of five terminal states: PENDING, COMPLETED, DISMISSED, SNOOZED, DELETED | Task Status |
| **Motivation Repository** | The store of motivational messages available for popup display | 10 default messages in `messages.json`, random selection per task | messages.json |
| **Recent Folders** | A persisted list of up to 5 previously scheduled folder paths for quick re-scheduling (B-02) | FIFO queue, deduped, newest first, stored in `app_settings.json` | Last Folder, FIFO |
| **Last Folder** | The single most recently scheduled folder, offered as a one-click default on next app launch (B-01) | Stored in `app_settings.json` as `lastFolder` field | Recent Folders |
| **Shell Extension** | The optional COM DLL that adds "Schedule for Tomorrow at 2 PM" to the Windows Explorer right-click menu (B-13) | Implemented as C# COM-visible DLL with PowerShell bridge | COM, Shell Context Menu |
| **History Viewer** | The in-app panel displaying past task outcomes parsed from popup_log.txt (B-18) | Shows last 30 entries: date, folder, outcome, snooze count | popup_log.txt, Outcome Log |
| **First-Run Overlay** | The one-time onboarding card shown on initial app launch (B-07) | Dismisses with "Got it" button, sets `firstRun=false` | Onboarding |

---

## Technical Architecture

| Term | Definition | Context | Related Terms |
|------|-----------|---------|---------------|
| **WPF** | Windows Presentation Foundation — Microsoft's UI framework for Windows desktop apps | Project uses WPF for both MainApp and popup windows with XAML layouts | XAML, .NET Framework |
| **XAML** | Extensible Application Markup Language — XML-based markup for defining WPF UIs | Used in `MainWindow.xaml` for UI layout | WPF |
| **STA** | Single-Threaded Apartment — COM threading model required for WPF applications | PowerShell must run with `-STA` flag to host WPF UIs | WPF, COM |
| **Module** | A reusable PowerShell code unit (`.psm1` file) with exported functions | Project has two core modules: `ConfigManager.psm1` and `TaskScheduler.psm1` | .psm1, Export-ModuleMember |
| **ConfigManager** | PowerShell module managing all JSON config files and user settings | Handles `app_settings.json`, `tasks.json`, `popup_config.json`, `popup_log.txt` | Module, %APPDATA% |
| **TaskScheduler** | PowerShell module wrapping Windows Task Scheduler API for task lifecycle management | Creates, retrieves, updates, and deletes scheduled tasks with JSON persistence | Module, Scheduled Task |
| **Notification Engine** | The WPF popup system implemented in `DailyMotivation.ps1` | Displays popup, handles user actions, validates paths, logs outcomes | Popup, DailyMotivation.ps1 |
| **Snooze Engine** | Component managing snooze re-scheduling with duration parameters | Creates new one-time scheduled tasks for snooze triggers (B-10) | Snooze Loop, Task Scheduler |
| **Mutex** | Named system-wide synchronization primitive preventing duplicate popup instances | Uses `Global\DailyMotivationBrainHelperPopup` to enforce SSOT-006 | Named Mutex, SSOT-006 |
| **Named Mutex** | A system-wide named Mutex ensuring only one popup runs at a time | Acquired at `DailyMotivation.ps1` startup, released on window close | Mutex, SSOT-006 |
| **Architecture** | The high-level structural design of the system's components and their relationships | Documented in `ARCHITECTURE.md` and `SYSTEM ARCHITECTURE.md` | Module, Component, System Design |
| **SSOT** | Single Source of Truth — canonical rules the system must conform to | 9 immutable rules documented in `SSOT.md` (e.g., SSOT-006: one popup at a time) | Traceability |

---

## PowerShell & Windows Components

| Term | Definition | Context | Related Terms |
|------|-----------|---------|---------------|
| **PowerShell** | Microsoft's task automation and configuration management framework | Project uses PowerShell 5.1 (Windows built-in) for all scripting | .ps1, .psm1 |
| **$PSScriptRoot** | Automatic variable containing the directory path of the executing script | Critical for path resolution in PS2EXE compiled executables | Path Resolution, PS2EXE |
| **.psm1** | PowerShell module file extension | Contains reusable functions exported via `Export-ModuleMember` | Module, Import-Module |
| **.ps1** | PowerShell script file extension | Standalone executable scripts like `MainApp.ps1`, `DailyMotivation.ps1` | PowerShell |
| **PS2EXE** | Tool converting PowerShell scripts to standalone Windows executables | Used in build system to create `.exe` files from `.ps1` scripts | Invoke-ps2exe, Build System |
| **%APPDATA%** | Windows environment variable pointing to user's application data directory | Config files stored in `%APPDATA%\DailyMotivationBrainHelper\` | ConfigManager, Configuration |
| **%TEMP%** | Windows environment variable for temporary files directory | Fallback location if `%APPDATA%` is unavailable (GAP-003) | Fallback Strategy |
| **Task Scheduler** | Windows service managing scheduled tasks and triggers | Project uses COM API via `ScheduledTasks` PowerShell module | Scheduled Task, COM |
| **COM** | Component Object Model — Microsoft's binary-interface standard for software components | Used for Task Scheduler API and shell extension | Shell Extension, Task Scheduler |
| **Registry** | Windows hierarchical database storing system and application settings | Shell extension registration writes to HKEY_CLASSES_ROOT | Shell Extension |
| **UNC Path** | Universal Naming Convention path for network shares (`\\server\share\folder`) | Detected for elevated task registration (GAP-010) | Network Path, Elevated Task |
| **DispatcherTimer** | WPF timer class executing code on UI thread at specified intervals | Used for 30-second undo countdown (B-04) | WPF, Undo Window |
| **Explorer** | Windows File Explorer (`explorer.exe`) used to open folders | Launched via `Start-Process explorer.exe <path>` | Explorer Launcher |
| **Execution Policy** | PowerShell security setting controlling script execution permissions | Project launchers use `-ExecutionPolicy Bypass` to avoid errors | PowerShell |

---

## Build System & Tooling

| Term | Definition | Context | Related Terms |
|------|-----------|---------|---------------|
| **Invoke-Build** | PowerShell build automation framework similar to Make or Rake | Project uses `.build.ps1` with 12+ tasks (Clean, Analyze, Test, Build, Release) | .build.ps1, Build Task |
| **.build.ps1** | Invoke-Build script defining build tasks and dependencies | Entry point: run `Invoke-Build` to execute default build pipeline | Invoke-Build, Build System |
| **Build Task** | A named unit of work in Invoke-Build (e.g., Clean, Test, Build) | Tasks can depend on other tasks, creating a dependency graph | Invoke-Build, Build Pipeline |
| **Build Pipeline** | Sequence of build tasks: Clean → Analyze → Test → Build | Full pipeline ensures code quality before producing artifacts | CI/CD Pipeline, Quality Gate |
| **PS2EXE** | PowerShell-to-EXE compiler module wrapping .NET compilation | Converts `.ps1` scripts to standalone `.exe` files with optional GUI settings | Invoke-ps2exe, Compilation |
| **Invoke-ps2exe** | The command from PS2EXE module that performs PowerShell-to-EXE conversion | Called in `.build.ps1` Build task with parameters like `-noConsole`, `-STA` | PS2EXE |
| **QuickBuild** | Invoke-Build task that compiles without running tests or analysis | Useful for rapid development iteration: `Invoke-Build QuickBuild` | Build Task, Invoke-Build |
| **Release Task** | Invoke-Build task creating a distributable ZIP package | Runs full pipeline, compiles EXEs, packages into `Output/DailyMotivationBrainHelper_Release.zip` | Build Task, Package |
| **Output Directory** | Build artifact destination directory (`Output/`) containing compiled EXEs and dependencies | Must have `Modules/` and `data/` at root level for runtime path resolution | Build System, Path Resolution |

---

## Testing & Quality Assurance

| Term | Definition | Context | Related Terms |
|------|-----------|---------|---------------|
| **Pester** | PowerShell testing framework (v5.x) for unit and integration tests | Project has 180+ tests covering ConfigManager and TaskScheduler modules | Test Framework, Unit Test |
| **Unit Test** | Test of an individual function or component in isolation using mocks | 100+ tests in `Tests/Unit/ConfigManager.Tests.ps1`, 80+ in `TaskScheduler.Tests.ps1` | Pester, Test Coverage |
| **Integration Test** | Test of multiple components working together end-to-end | `Tests/Integration/Initialization.Tests.ps1` validates full initialization flow | Pester, Test Coverage |
| **Test Coverage** | Percentage of source code lines executed during test runs | Project target: 80%+ for modules; ConfigManager ~90%, TaskScheduler ~85% | Code Coverage, Coverage Report |
| **Code Coverage** | Synonym for test coverage; measured in lines/branches executed by tests | Generated as JaCoCo XML format by Invoke-Tests.ps1 in CI mode | Test Coverage, JaCoCo |
| **PSScriptAnalyzer** | Static analysis tool enforcing PowerShell best practices and code quality rules | Configuration in `.PSScriptAnalyzerSettings.psd1`; zero warnings required for PR merge | Static Analysis, Quality Gate |
| **Quality Gate** | CI/CD checkpoint requiring all quality criteria to pass before merge | Tests pass + 80% coverage + PSScriptAnalyzer zero warnings | CI/CD Pipeline, Blocker |
| **Tag Filter** | Pester feature selecting test subsets by category tag | Tags: `Unit`, `Integration`, `Initialization`, `PathResolution`, `ErrorHandling`, `Encoding` | Pester, Test Organization |
| **Test Fixture** | Pre-built sample data files simulating realistic inputs | Located in `Tests/Fixtures/` (e.g., `sample_app_settings.json`, `sample_tasks.json`) | Pester, Test Data |
| **Invoke-Tests.ps1** | Project's custom test runner script with tag filtering and CI mode | Wraps Pester configuration, generates coverage reports, supports `-Tag` and `-CI` flags | Pester, Test Runner |
| **CI/CD Pipeline** | Automated workflow running tests, analysis, and builds on every push/PR | Defined in `.github/workflows/test.yml` with 3 jobs: test, build, analyze | GitHub Actions, Quality Gate |
| **GitHub Actions** | GitHub's CI/CD automation platform executing workflows on cloud runners | Project uses Windows runner for PowerShell/Task Scheduler compatibility | CI/CD Pipeline |
| **Test Case** | Manual test scenario documented in `TEST_PLAN.md` for WPF UI validation | 24 test cases (TC-001 through TC-024) covering UI workflows | Manual Testing, TEST_PLAN.md |
| **Coverage Report** | XML or HTML output showing which code lines were executed during tests | Generated as `coverage.xml` (JaCoCo format) for CI tools and editors | Code Coverage, JaCoCo |

---

## Project Management & Documentation

| Term | Definition | Context | Related Terms |
|------|-----------|---------|---------------|
| **PRD** | Product Requirements Document — formal specification of all functional requirements | 25 requirements (FR-001 through FR-025) in `PRD.md` | Functional Requirement, Traceability |
| **Functional Requirement (FR)** | Specific capability the system must provide, identified by FR-XXX | Example: FR-013 "Remember Last Folder", FR-020 "Dismiss for Today" | PRD, Traceability Matrix |
| **User Story** | Narrative describing a feature from the user's perspective (US-XXX format) | 18 user stories in `USER_STORIES.md` mapping to functional requirements | PRD, Acceptance Criteria |
| **Acceptance Criteria (AC)** | Measurable conditions defining when a requirement is satisfied | 18 criteria (AC-001 through AC-018) in `ACCEPTANCE_CRITERIA.md` | Functional Requirement, Test Case |
| **Sprint** | Time-boxed development iteration (Sprint 0-4 in project) | Sprint 0: Infrastructure, Sprint 1-4: Features, documented in `SPRINT_PLAN.md` | Sprint Plan, Task |
| **Sprint Plan** | Document organizing work into sprints with task dependencies | 16 tasks across 4 sprints in `SPRINT_PLAN.md` | Sprint, Task, Backlog |
| **Task** | Unit of work within a sprint (TASK-XXX or INFRA-XXX format) | Example: TASK-004 "App Writes popup_config.json", INFRA-001 "Pester 5.x test suite" | Sprint, Sprint Plan |
| **Backlog** | Prioritized list of work items not yet scheduled to a sprint | Original 13 tasks in `NEXT_STEPS.md` evolved into sprint plan | Sprint Plan, Task |
| **Epic** | Large body of work decomposed into multiple tasks or user stories | Not explicitly used in this project; features tracked at task level | Task, User Story |
| **Traceability** | Linkage between requirements, design, implementation, and tests | Documented in `TRACEABILITY_MATRIX.md` mapping FRs → ACs → TCs | Traceability Matrix, SSOT |
| **Traceability Matrix** | Table mapping requirements to acceptance criteria and test cases | Links user needs → FRs → components → ACs → TCs in `TRACEABILITY_MATRIX.md` | Traceability, PRD |
| **Brainstorm Features (B-XX)** | 20 proposed features from multi-agent brainstorm session, 14 approved | Example: B-01 "Remember Last Folder", B-10 "Snooze Duration Choice" | Feature Brainstorm, Sprint Plan |
| **NPR** | Non-functional Product Requirement — quality attribute or constraint | 7 NPRs (NPR-001 through NPR-007) covering performance, usability, security | PRD, SSOT |
| **SSOT** | Single Source of Truth — immutable system rules all components must obey | 9 rules (SSOT-001 through SSOT-009) in `SSOT.md` | Canonical Rules, Architecture |
| **Runbook** | Operational guide for deploying, monitoring, and maintaining the system | Documented in `OPERATIONS.md` with deployment, backup, update procedures | Operations, OPERATIONS.md |
| **Architecture Document** | Specification of system structure, components, and their interactions | Two docs: `ARCHITECTURE.md` (modules, testing) and `SYSTEM ARCHITECTURE.md` (deployment) | Architecture, System Design |

---

## Configuration & Data

| Term | Definition | Context | Related Terms |
|------|-----------|---------|---------------|
| **popup_config.json** | JSON config file for active popup display written by MainApp, read by DailyMotivation.ps1 | Contains: glyph, title, body, explorer_path, folder_name, task_id | Configuration, ConfigManager |
| **app_settings.json** | User preferences and application state persisted across sessions | Contains: firstRun, lastFolder, recentFolders[], theme | Configuration, ConfigManager |
| **tasks.json** | Array of all scheduled tasks with metadata and status | Each task: task_id, folder_path, scheduled_time, status, snooze_count | Configuration, TaskScheduler |
| **messages.json** | Library of motivational messages with glyph, title, and body fields | 10 default messages, randomly selected per task | Motivation Repository |
| **popup_log.txt** | Pipe-delimited outcome log recording task history | Format: `[timestamp] | task_id | folder_name | path | outcome | snooze_count` | Outcome Log, History Viewer |
| **Outcome Log** | Structured log of popup outcomes for history display and analytics | Parsed by `Get-OutcomeLog` in ConfigManager, shown in History Viewer (B-18) | popup_log.txt |
| **Task ID** | 16-character hexadecimal unique identifier for each scheduled task | Generated from GUID substring with collision retry mechanism (GAP-007) | GUID, Scheduled Task |
| **Task Status** | Current state of a scheduled task (5 possible values) | PENDING, COMPLETED, DISMISSED, SNOOZED, DELETED | Task Scheduler, State Machine |
| **FIFO** | First-In-First-Out queue data structure | Recent folders list maintains FIFO order with 5-item cap and deduplication | Recent Folders, Queue |
| **Configuration Spec** | Document defining all JSON schemas and file locations | `CONFIGURATION_SPEC.md` specifies structure of all config files | Configuration, Schema |
| **Schema** | Structured definition of JSON object properties and types | Each config file has documented schema in `CONFIGURATION_SPEC.md` | Configuration, JSON |
| **UTF-8** | Unicode character encoding standard ensuring international text support | All JSON files saved with UTF-8 encoding; tested with emoji and international paths | Encoding, Unicode |
| **Path Validation** | Runtime check ensuring scheduled folder still exists before opening | If invalid, popup shows "moved or deleted" recovery UI (B-05) | Explorer Launcher, Error Handling |
| **Fallback Strategy** | Graceful degradation when primary approach fails | Example: ConfigManager falls back to `%TEMP%` if `%APPDATA%` unavailable (GAP-003) | Error Handling, Resilience |

---

## Abbreviations & Acronyms

| Abbreviation | Full Term | Definition |
|--------------|-----------|-----------|
| **AC** | Acceptance Criteria | Measurable condition defining requirement satisfaction |
| **API** | Application Programming Interface | Exposed functions in ConfigManager and TaskScheduler modules |
| **CI** | Continuous Integration | Automated testing on every code push |
| **CD** | Continuous Delivery | Automated build and package creation |
| **COM** | Component Object Model | Microsoft's binary-interface standard |
| **DLL** | Dynamic Link Library | Windows shared library file (e.g., shell extension) |
| **EXE** | Executable | Compiled Windows application file |
| **FIFO** | First-In-First-Out | Queue ordering where oldest items are removed first |
| **FR** | Functional Requirement | Specific system capability (FR-001 through FR-025) |
| **GUID** | Globally Unique Identifier | 128-bit unique identifier |
| **NPR** | Non-functional Product Requirement | Quality attribute or system constraint |
| **PRD** | Product Requirements Document | Formal specification of all requirements |
| **SSOT** | Single Source of Truth | Canonical, immutable system rule |
| **STA** | Single-Threaded Apartment | COM threading model for WPF |
| **TC** | Test Case | Manual test scenario (TC-001 through TC-024) |
| **UAC** | User Account Control | Windows elevation prompt for admin actions |
| **UI** | User Interface | Visual interface for user interaction |
| **UNC** | Universal Naming Convention | Network path format (`\\server\share`) |
| **US** | User Story | Feature narrative from user perspective |
| **UX** | User Experience | Overall experience of using the application |
| **WPF** | Windows Presentation Foundation | Microsoft's UI framework |
| **XAML** | Extensible Application Markup Language | XML-based UI definition for WPF |

---

## Status
> v1.1 COMPLETE — Last reviewed 2026-06-09
