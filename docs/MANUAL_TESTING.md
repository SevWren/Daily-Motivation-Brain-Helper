# Manual Testing Guide

**Last Updated:** 2026-06-09
**Version:** v1.1

---

## Table of Contents

1. [Why Manual Testing](#1-why-manual-testing)
2. [Manual Test Suite](#2-manual-test-suite)
3. [Test Environment Setup](#3-test-environment-setup)
4. [Pre-release Test Checklist](#4-pre-release-test-checklist)
5. [Test Scenarios](#5-test-scenarios)
6. [Expected Behaviors](#6-expected-behaviors)
7. [Common Failures](#7-common-failures)
8. [Bug Reporting](#8-bug-reporting)
9. [Regression Testing](#9-regression-testing)
10. [Sign-off Process](#10-sign-off-process)

---

## 1. Why Manual Testing

### 1.1 WPF Automation Challenges

This project uses **Windows Presentation Foundation (WPF)** for its user interface components. While automated testing is excellent for backend logic and modules, WPF UI testing presents unique challenges:

- **UI Automation Complexity**: WPF UI automation requires specialized frameworks (e.g., FlaUI, TestStack.White) that add significant complexity and external dependencies
- **Visual Validation**: Many user interactions depend on visual feedback (animations, color changes, tooltips) that are difficult to validate programmatically
- **Timing Dependencies**: WPF rendering and dispatcher timing can be unpredictable in automated test environments
- **Windows Task Scheduler Integration**: Testing scheduled task execution requires real system integration that's difficult to mock reliably
- **User Experience Testing**: The core value proposition is UX - how the popup feels at 2 PM, whether the countdown creates urgency, etc.

### 1.2 Current Test Coverage

| Component | Coverage | Method |
|-----------|----------|--------|
| **ConfigManager.psm1** | ~90% | Automated (Pester) |
| **TaskScheduler.psm1** | ~85% | Automated (Pester) |
| **Initialization System** | 100% | Automated (Pester) |
| **DailyMotivation.ps1** | 0% | **Manual Testing Required** |
| **MainApp.ps1** | 0% | **Manual Testing Required** |

**See Also:** `TEST_PLAN.md` (lines 57-59), `Tests/README.md` (lines 205-220)

### 1.3 What Manual Testing Covers

Manual testing focuses on:

1. **End-to-end user workflows** - Complete user journeys from app launch to folder opening
2. **Visual and interactive elements** - Drag-and-drop, button clicks, tooltips, animations
3. **Windows Task Scheduler integration** - Real scheduled task creation and execution
4. **Timing-dependent scenarios** - Countdown timers, snooze behavior, undo timeouts
5. **Edge cases** - Moved folders, network paths, service failures, duplicate schedules

---

## 2. Manual Test Suite

### 2.1 Test Case Overview

The manual test suite comprises **24 test cases** (TC-003 through TC-024) covering all user-facing functionality. These test cases validate:

- **Original Requirements** (TC-003 through TC-011): Core functionality from initial PRD
- **Enhancement Requirements** (TC-012 through TC-024): Features added in v1.1 (B-01 through B-19)

**Note:** TC-001 and TC-002 are basic sanity checks that are implicitly validated by later test cases.

### 2.2 Test Case Reference

| Category | Test Cases | Features Tested |
|----------|------------|-----------------|
| **Popup Window** | TC-003, TC-004, TC-005, TC-007, TC-021 | Display, Open Folder, Snooze, Countdown, Folder Name |
| **Scheduling** | TC-002, TC-006, TC-014, TC-014b, TC-022 series | Task creation, deletion, timing, duplicates |
| **Edge Cases** | TC-008, TC-009, TC-016 | Machine offline, missing paths, moved folders |
| **Recent Folders** | TC-012, TC-013, TC-018 | Last folder banner, recent list, drag-and-drop |
| **Undo/Dismiss** | TC-015 series, TC-020 | Undo timing, dismiss behavior |
| **First Run** | TC-017 series | Welcome overlay |
| **Snooze Engine** | TC-010, TC-019 | Multiple snoozes, duration selection |
| **History** | TC-023 | Outcome logging and display |
| **UI Polish** | TC-024 | Tooltips |

**Source:** `TEST_PLAN.md` (lines 68-105)

---

## 3. Test Environment Setup

### 3.1 Prerequisites

#### Required Software
- Windows 10 (build 19041+) or Windows 11
- PowerShell 5.1 (pre-installed on Windows)
- .NET Framework 4.5+ (pre-installed on Windows 10+)
- Windows Task Scheduler service running

#### Required Access
- Administrator privileges (for Task Scheduler operations)
- File system write access to `%APPDATA%\DailyMotivationBrainHelper`

### 3.2 Test Machine Configuration

#### Clean State Testing
For regression testing and release validation, start with a clean configuration:

1. **Delete existing app data:**
   ```powershell
   Remove-Item "$env:APPDATA\DailyMotivationBrainHelper" -Recurse -Force -ErrorAction SilentlyContinue
   ```

2. **Remove existing scheduled tasks:**
   ```powershell
   Get-ScheduledTask | Where-Object { $_.TaskName -like "DailyMotivation_*" } | Unregister-ScheduledTask -Confirm:$false
   ```

3. **Verify Task Scheduler service:**
   ```powershell
   Get-Service -Name Schedule | Start-Service
   ```

#### Test Data Preparation

Create test folders in known locations:

```powershell
# Create test directories
New-Item -ItemType Directory -Path "C:\TestFolders\ProjectA" -Force
New-Item -ItemType Directory -Path "C:\TestFolders\ProjectB" -Force
New-Item -ItemType Directory -Path "C:\TestFolders\ClientWork" -Force
```

### 3.3 Installation

1. **Download the latest build** from the `dist/` directory or build from source:
   ```powershell
   .\Build.ps1
   ```

2. **Extract to a test location** (e.g., `C:\Program Files\DailyMotivationBrainHelper\`)

3. **Verify file structure:**
   ```
   DailyMotivationBrainHelper/
   ├── MainApp.ps1
   ├── DailyMotivation.ps1
   ├── MainWindow.xaml
   ├── LaunchMotivation.bat
   ├── Modules/
   │   ├── ConfigManager.psm1
   │   └── TaskScheduler.psm1
   └── data/
       └── messages.json
   ```

### 3.4 Test Tools

#### Useful PowerShell Commands

```powershell
# View app data
Get-ChildItem "$env:APPDATA\DailyMotivationBrainHelper"

# View debug logs
Get-Content "$env:TEMP\DailyMotivation_debug.log" -Tail 50

# List scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like "DailyMotivation_*" }

# Trigger a task manually (for testing without waiting)
Start-ScheduledTask -TaskName "DailyMotivation_<TaskId>"

# View popup config
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\popup_config.json" | ConvertFrom-Json
```

#### Time Manipulation for Testing

To test time-dependent features without waiting:

1. **Schedule for 1 minute from now** (modify `Get-ScheduleTime` temporarily in MainApp.ps1):
   ```powershell
   # For testing only - DO NOT COMMIT
   return (Get-Date).AddMinutes(1)
   ```

2. **Or manually create a test task:**
   ```powershell
   # Import the module
   Import-Module ".\Modules\TaskScheduler.psm1"

   # Create task for 1 minute from now
   New-MotivationTask -FolderPath "C:\TestFolders\ProjectA" -TriggerTime (Get-Date).AddMinutes(1)
   ```

---

## 4. Pre-release Test Checklist

Before any release, complete this checklist. All items must pass.

### 4.1 Critical Path Tests (Must Pass)

- [ ] **TC-003**: Popup appears at scheduled time
- [ ] **TC-004**: Open Folder button launches Explorer at correct path
- [ ] **TC-005**: Snooze button re-triggers popup after selected duration
- [ ] **TC-002**: Schedule For Tomorrow creates task in Task Scheduler
- [ ] **TC-006**: Delete button removes task from Task Scheduler
- [ ] **TC-017**: First-run welcome overlay displays once

### 4.2 Enhancement Tests (Should Pass)

- [ ] **TC-012**: Last folder banner appears on second launch
- [ ] **TC-013**: Recent folders list populates after 3+ schedules
- [ ] **TC-014/14b**: "Today at 2:00 PM" visibility based on current time
- [ ] **TC-015/15b**: Undo banner timeout and functionality
- [ ] **TC-016**: Moved folder detection and re-pick prompt
- [ ] **TC-020**: Dismiss for Today prevents re-trigger
- [ ] **TC-022 series**: Duplicate warning dialog

### 4.3 Edge Cases (Should Handle Gracefully)

- [ ] **TC-008**: Popup fires on next login if machine was off
- [ ] **TC-009**: Invalid path displays re-pick prompt
- [ ] **TC-011**: Task Scheduler service disabled shows actionable error
- [ ] **TC-018**: Drag-and-drop from Explorer populates path
- [ ] **TC-023**: History panel displays past outcomes

### 4.4 Sign-off Requirements

- [ ] All Critical Path tests pass
- [ ] At least 90% of Enhancement tests pass
- [ ] All Edge Cases handled without crashes
- [ ] No PSScriptAnalyzer errors or warnings
- [ ] All automated tests pass (`.\Invoke-Tests.ps1`)
- [ ] Visual inspection confirms UI polish (animations, colors, spacing)

**Sign-off Authority:** Project maintainer or designated release manager

---

## 5. Test Scenarios

### 5.1 MainApp.ps1 (Main UI Window)

#### TC-001: Select Folder via Picker

**Objective:** Verify folder selection via the Browse button

**Steps:**
1. Launch `MainApp.ps1` by running:
   ```powershell
   powershell.exe -STA -ExecutionPolicy Bypass -File MainApp.ps1
   ```
2. Click the **"📁 Choose Your Folder"** button
3. Navigate to `C:\TestFolders\ProjectA`
4. Click **Select Folder**

**Expected Result:**
- The selected path appears in the UI: `C:\TestFolders\ProjectA`
- Path text color changes from dim gray (#5A5A7A) to bright gray (#C8C8E8)
- Schedule button becomes enabled (no longer grayed out)

**Source:** TEST_PLAN.md line 71

---

#### TC-002: Click Schedule For Tomorrow

**Objective:** Verify task creation in Windows Task Scheduler

**Preconditions:**
- Complete TC-001 to select a folder

**Steps:**
1. Ensure "Tomorrow at 2:00 PM" radio button is selected
2. Click **"Schedule For Tomorrow"** button
3. Open Task Scheduler (`taskschd.msc`)
4. Navigate to Task Scheduler Library
5. Look for a task named `DailyMotivation_<timestamp>`

**Expected Result:**
- Task appears in Task Scheduler
- Task trigger is set for tomorrow at 14:00 (2:00 PM)
- Task action executes `LaunchMotivation.bat`
- Undo banner appears: "✓ Scheduled for [date] at 2:00 PM - undo in 30s"
- Task list in main window updates to show the new task

**Verification Commands:**
```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like "DailyMotivation_*" } | Format-List TaskName, State
```

**Source:** TEST_PLAN.md line 72, ACCEPTANCE_CRITERIA.md AC-001

---

#### TC-012: Second App Open After Scheduling

**Objective:** Verify Last Folder banner (B-01) appears on subsequent launches

**Preconditions:**
- Complete TC-002 (schedule a folder)
- Close MainApp.ps1

**Steps:**
1. Re-launch `MainApp.ps1`
2. Observe the top section of the window

**Expected Result:**
- A banner appears with text: "Schedule [folder path] again?"
- Banner contains two buttons: **"✓ Yes, Schedule Now"** and **"✖ Dismiss"**
- Banner background is distinct from main UI (#1C1C2C vs #14141F)

**Source:** TEST_PLAN.md line 87, ACCEPTANCE_CRITERIA.md AC-007

---

#### TC-013: Open App After 3 Prior Schedules

**Objective:** Verify Recent Folders list (B-02) populates

**Preconditions:**
- Schedule 3 different folders on different occasions

**Steps:**
1. Schedule `C:\TestFolders\ProjectA` (close and re-open app)
2. Schedule `C:\TestFolders\ProjectB` (close and re-open app)
3. Schedule `C:\TestFolders\ClientWork` (close and re-open app)
4. Re-launch MainApp.ps1
5. Scroll down to view "Recent Folders" section

**Expected Result:**
- Recent Folders panel is visible (not collapsed)
- List shows up to 5 most recent folders, newest first
- Each entry shows the folder name (leaf) and a **"Schedule Again"** button
- Clicking a "Schedule Again" button schedules that folder without opening the folder picker

**Source:** TEST_PLAN.md line 88

---

#### TC-014: Open App at 13:00 (1 PM)

**Objective:** Verify "Today at 2:00 PM" option visibility before 2 PM (B-03)

**Preconditions:**
- System time is before 14:00 (2:00 PM)

**Steps:**
1. Set system time to 13:00 (or any time before 14:00)
2. Launch `MainApp.ps1`
3. Observe the scheduling options

**Expected Result:**
- Two radio buttons are visible:
  - **"Today at 2:00 PM"** (visible)
  - **"Tomorrow at 2:00 PM"** (visible, default selected)

**Source:** TEST_PLAN.md line 89, ACCEPTANCE_CRITERIA.md AC-008

---

#### TC-014b: Open App at 15:00 (3 PM)

**Objective:** Verify "Today at 2:00 PM" option is hidden after 2 PM

**Preconditions:**
- System time is after 14:00 (2:00 PM)

**Steps:**
1. Set system time to 15:00 (or any time after 14:00)
2. Launch `MainApp.ps1`
3. Observe the scheduling options

**Expected Result:**
- Only one radio button is visible:
  - **"Tomorrow at 2:00 PM"** (visible and selected)
- "Today at 2:00 PM" is not displayed (Visibility="Collapsed")

**Source:** TEST_PLAN.md line 90, MainApp.ps1 lines 374-376

---

#### TC-015: Click Undo Within 30s

**Objective:** Verify Undo banner functionality (B-04)

**Preconditions:**
- Complete TC-002 (schedule a folder)

**Steps:**
1. Immediately after scheduling, observe the Undo banner
2. Click **"Undo"** button before 30 seconds elapse
3. Open Task Scheduler and verify the task is removed

**Expected Result:**
- Undo banner dismisses immediately
- Task is removed from Windows Task Scheduler
- Task no longer appears in MainApp's task list
- No success message or popup appears (silent deletion)

**Verification Commands:**
```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like "DailyMotivation_*" }
# Should return no results
```

**Source:** TEST_PLAN.md line 91, ACCEPTANCE_CRITERIA.md AC-009

---

#### TC-015b: Wait 30s After Scheduling

**Objective:** Verify Undo banner auto-dismisses after timeout

**Preconditions:**
- Complete TC-002 (schedule a folder)

**Steps:**
1. After scheduling, observe the Undo banner countdown
2. Wait 30 seconds without clicking Undo
3. Observe the banner and verify task persistence

**Expected Result:**
- Banner countdown decrements from 30 to 0
- Banner dismisses automatically when countdown reaches 0
- Task remains in Task Scheduler (not deleted)
- Task still appears in MainApp's task list

**Source:** TEST_PLAN.md line 92

---

#### TC-018: Drag Folder from Explorer onto App

**Objective:** Verify drag-and-drop functionality (B-09)

**Steps:**
1. Launch `MainApp.ps1`
2. Open Windows Explorer and navigate to `C:\TestFolders\`
3. Drag the `ProjectA` folder
4. Drop it onto the "Drop a folder here" zone in MainApp

**Expected Result:**
- Path populates: `C:\TestFolders\ProjectA`
- Path text color changes to bright gray (#C8C8E8)
- Schedule button becomes enabled
- Last Folder banner (if visible) dismisses

**Error Cases:**
- Dropping a file (not folder) shows error: "Please drop a folder, not a file."
- Dropping an invalid path shows error: "That path does not exist or is not a folder"

**Source:** TEST_PLAN.md line 96, ACCEPTANCE_CRITERIA.md AC-012, MainApp.ps1 lines 341-369

---

#### TC-022: Schedule Same Folder Twice Same Day

**Objective:** Verify duplicate warning dialog (B-16)

**Preconditions:**
- A task already exists for `C:\TestFolders\ProjectA` scheduled for tomorrow

**Steps:**
1. Select `C:\TestFolders\ProjectA` again
2. Ensure "Tomorrow at 2:00 PM" is selected
3. Click **"Schedule For Tomorrow"**

**Expected Result:**
- A warning dialog appears:
  - Title: "Already Scheduled"
  - Message: "This folder is already scheduled for [date]. Schedule again anyway?"
  - Buttons: **Yes**, **No**

**Source:** TEST_PLAN.md line 100, ACCEPTANCE_CRITERIA.md AC-016

---

#### TC-022b: Click Yes on Duplicate Warning

**Objective:** Verify force scheduling on duplicate confirmation

**Preconditions:**
- Complete TC-022 to trigger duplicate warning

**Steps:**
1. In the duplicate warning dialog, click **Yes**

**Expected Result:**
- A new task is created (duplicate task exists)
- Both tasks appear in Task Scheduler with different timestamps
- Undo banner appears for the new task

**Source:** TEST_PLAN.md line 101

---

#### TC-022c: Click Cancel on Duplicate Warning

**Objective:** Verify duplicate scheduling cancellation

**Preconditions:**
- Complete TC-022 to trigger duplicate warning

**Steps:**
1. In the duplicate warning dialog, click **No**

**Expected Result:**
- Dialog dismisses
- No new task is created
- Original task remains unchanged
- No Undo banner appears

**Source:** TEST_PLAN.md line 102

---

#### TC-023: View History Panel

**Objective:** Verify History panel displays past outcomes (B-18)

**Preconditions:**
- At least one task has been triggered and completed (opened, snoozed, or dismissed)

**Steps:**
1. Launch `MainApp.ps1`
2. Click **"📋 View History"** button at the bottom
3. Observe the History panel

**Expected Result:**
- History panel expands (slides down or appears)
- Panel shows up to 30 most recent outcomes
- Each entry displays:
  - Timestamp (YYYY-MM-DD HH:MM:SS)
  - Folder name
  - Outcome: ✅ Opened, 💤 Snoozed [count]x, ✖ Dismissed, ⚠ Path Missing
  - Color-coded outcomes (green for Opened, orange for Dismissed, gray for others)
- **"Clear History"** button is visible

**Source:** TEST_PLAN.md line 103, ACCEPTANCE_CRITERIA.md AC-017, MainApp.ps1 lines 179-202

---

#### TC-024: Hover Over Schedule Button

**Objective:** Verify tooltips appear (B-19)

**Steps:**
1. Launch `MainApp.ps1`
2. Hover mouse cursor over the **"Schedule For Tomorrow"** button
3. Wait up to 1 second

**Expected Result:**
- A tooltip appears with descriptive text
- Tooltip appears within 1 second of hover
- Tooltip dismisses when cursor moves away

**Note:** Test tooltips on other interactive elements (folder picker button, undo button, task list items)

**Source:** TEST_PLAN.md line 104, ACCEPTANCE_CRITERIA.md AC-018

---

#### TC-017: First Launch

**Objective:** Verify welcome overlay appears on first run (B-07)

**Preconditions:**
- Clean state: `%APPDATA%\DailyMotivationBrainHelper` does not exist

**Steps:**
1. Delete app data directory:
   ```powershell
   Remove-Item "$env:APPDATA\DailyMotivationBrainHelper" -Recurse -Force
   ```
2. Launch `MainApp.ps1`

**Expected Result:**
- Main window loads
- A semi-transparent overlay appears on top
- Overlay contains:
  - Welcome message: "👋 Welcome to Daily Motivation Brain Helper"
  - Brief instructions (3 steps)
  - **"Got it - Let's Go!"** button
- Clicking the button dismisses overlay and reveals main UI

**Source:** TEST_PLAN.md line 94, ACCEPTANCE_CRITERIA.md AC-011, MainApp.ps1 lines 498-551

---

#### TC-017b: Second Launch

**Objective:** Verify welcome overlay does NOT appear on subsequent launches

**Preconditions:**
- Complete TC-017 (first launch)
- Click "Got it - Let's Go!" to dismiss overlay

**Steps:**
1. Close MainApp.ps1
2. Re-launch MainApp.ps1

**Expected Result:**
- Main window loads normally
- No overlay appears
- App proceeds directly to normal operation

**Source:** TEST_PLAN.md line 95

---

### 5.2 DailyMotivation.ps1 (Popup Window)

#### TC-003: Popup Appears at 2 PM

**Objective:** Verify scheduled popup displays at trigger time

**Preconditions:**
- A task is scheduled for 14:00 (2:00 PM) today
- System time approaches 14:00

**Steps:**
1. Create a task scheduled for 1 minute from now:
   ```powershell
   Import-Module ".\Modules\TaskScheduler.psm1"
   New-MotivationTask -FolderPath "C:\TestFolders\ProjectA" -TriggerTime (Get-Date).AddMinutes(1)
   ```
2. Wait for the scheduled time
3. Observe screen

**Expected Result:**
- At the scheduled time, the popup window appears
- Popup displays:
  - Glyph (e.g., [+])
  - Title (e.g., "Time to Show Up")
  - Body text (motivational message)
  - Folder name subtitle: "Opening: ProjectA"
  - Countdown: "Auto-opening in 20s"
  - Three buttons: "Dismiss for Today", "Snooze 5m", "Open Folder >"
- Popup is centered on screen
- Popup is topmost (appears above other windows)
- Popup has fade-in animation (300ms)
- Popup does NOT show in taskbar

**Debug:**
If popup doesn't appear, check:
```powershell
Get-Content "$env:TEMP\DailyMotivation_debug.log" -Tail 50
```

**Source:** TEST_PLAN.md line 73, ACCEPTANCE_CRITERIA.md AC-002, DailyMotivation.ps1 lines 138-301

---

#### TC-004: Click Open Folder

**Objective:** Verify Open Folder button launches Explorer at correct path

**Preconditions:**
- Complete TC-003 (popup is displayed)

**Steps:**
1. In the popup window, click **"Open Folder >"** button
2. Observe system behavior

**Expected Result:**
- Popup window closes immediately
- Windows Explorer opens displaying contents of `C:\TestFolders\ProjectA`
- Explorer window comes to foreground
- Task is marked complete in outcome log
- Outcome log entry shows: `Opened` status

**Verification:**
```powershell
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\popup_log.txt" -Tail 5
# Look for line with "Opened" outcome
```

**Source:** TEST_PLAN.md line 74, ACCEPTANCE_CRITERIA.md AC-003, DailyMotivation.ps1 lines 464-472

---

#### TC-005: Click Snooze

**Objective:** Verify Snooze button re-triggers popup after selected duration

**Preconditions:**
- Complete TC-003 (popup is displayed)

**Steps:**
1. In the popup window, note the current snooze duration (default: "Snooze 5m")
2. Click **"Snooze 5m"** button (left side of split button)
3. Observe popup closure
4. Wait 5 minutes (or use time manipulation)

**Expected Result:**
- Popup closes immediately upon clicking Snooze
- A new scheduled task is created for 5 minutes from now
- After 5 minutes elapse, popup re-appears with the same configuration
- Countdown resets to 20 seconds
- Snooze count increments in outcome log

**Verification:**
```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like "DailyMotivation_*" }
# Should show a new task with trigger time 5 minutes ahead
```

**Source:** TEST_PLAN.md line 75, ACCEPTANCE_CRITERIA.md AC-004, DailyMotivation.ps1 lines 421-438

---

#### TC-007: Countdown Reaches 0

**Objective:** Verify auto-open when countdown expires

**Preconditions:**
- Complete TC-003 (popup is displayed)

**Steps:**
1. Wait for countdown to decrement from 20 to 0
2. Do NOT click any buttons
3. Observe behavior when countdown reaches 0

**Expected Result:**
- Countdown decrements once per second (20, 19, 18, ... 1, 0)
- When countdown reaches 0:
  - Popup closes automatically
  - Windows Explorer opens at scheduled folder path
  - Outcome log records "Opened" status

**Source:** TEST_PLAN.md line 77, DailyMotivation.ps1 lines 379-401

---

#### TC-010: Multiple Snoozes

**Objective:** Verify popup continues to reappear after multiple snooze cycles

**Preconditions:**
- Complete TC-003 (popup is displayed)

**Steps:**
1. Click **Snooze** (wait 5 minutes, popup reappears)
2. Click **Snooze** again (wait 5 minutes, popup reappears)
3. Click **Snooze** a third time (wait 5 minutes, popup reappears)
4. On fourth appearance, click **Open Folder**

**Expected Result:**
- Popup reappears after each snooze interval
- Each snooze creates a new temporary scheduled task
- Snooze count increments in debug log
- Final outcome log shows: `Snoozed` with count of 3

**Verification:**
```powershell
Get-Content "$env:TEMP\DailyMotivation_debug.log" | Select-String "Snooze"
```

**Source:** TEST_PLAN.md line 80

---

#### TC-019: Select 30 Min Snooze; Click Snooze

**Objective:** Verify snooze duration customization (B-10)

**Preconditions:**
- Complete TC-003 (popup is displayed)

**Steps:**
1. Click the dropdown arrow (right side of Snooze button - small "v" button)
2. Select **"30 minutes"** from the dropdown menu
3. Observe button text change to "Snooze 30m"
4. Click **"Snooze 30m"** button
5. Wait 30 minutes (or use time manipulation)

**Expected Result:**
- Dropdown menu displays with 4 options:
  - 5 minutes (default)
  - 15 minutes
  - 30 minutes
  - 1 hour
- After selecting 30 minutes, button text updates to "Snooze 30m"
- Popup closes when Snooze is clicked
- Popup reappears after exactly 30 minutes

**Source:** TEST_PLAN.md line 97, ACCEPTANCE_CRITERIA.md AC-013, DailyMotivation.ps1 lines 404-418

---

#### TC-020: Click Dismiss for Today

**Objective:** Verify Dismiss for Today prevents re-trigger (B-11)

**Preconditions:**
- Complete TC-003 (popup is displayed)

**Steps:**
1. In the popup window, click **"Dismiss for Today"** button
2. Observe popup closure
3. Wait to confirm no further popups appear

**Expected Result:**
- Popup closes immediately
- No snooze task is created
- No further popups appear for this task today
- Outcome log records "Dismissed" status
- Any pending tasks for the same folder/date are removed

**Source:** TEST_PLAN.md line 98, ACCEPTANCE_CRITERIA.md AC-014, DailyMotivation.ps1 lines 441-461

---

#### TC-021: Schedule Folder "ClientA"

**Objective:** Verify folder name appears in popup subtitle (B-12)

**Preconditions:**
- Schedule a folder with a clear name: `C:\TestFolders\ClientA`

**Steps:**
1. Schedule `C:\TestFolders\ClientA` for 1 minute from now
2. Wait for popup to appear
3. Observe the subtitle text below the body text

**Expected Result:**
- Popup displays subtitle: "Opening: ClientA"
- Subtitle uses folder name (leaf) not full path
- Subtitle text color is dim (#5A5A7A)
- Subtitle appears between body text and countdown

**Special Case - UNC Root Shares:**
If scheduling `\\server\share`, the full path should display instead of context-free leaf name

**Source:** TEST_PLAN.md line 99, ACCEPTANCE_CRITERIA.md AC-015, DailyMotivation.ps1 lines 346-358

---

#### TC-016: Schedule Folder; Move Folder; Wait for 2 PM

**Objective:** Verify moved folder detection and re-pick prompt (B-05)

**Preconditions:**
- A task is scheduled for `C:\TestFolders\ProjectA`

**Steps:**
1. Schedule `C:\TestFolders\ProjectA` for 1 minute from now
2. While waiting, rename or move the folder:
   ```powershell
   Rename-Item "C:\TestFolders\ProjectA" "C:\TestFolders\ProjectA_OLD"
   ```
3. Wait for popup to appear

**Expected Result:**
- Popup appears but displays "Path Missing" mode instead of normal mode
- Popup shows:
  - Warning glyph: [!] (orange color #F4A261)
  - Title: "Folder Not Found"
  - Message: "The folder you scheduled was moved or deleted."
  - Label: "Was looking for: C:\TestFolders\ProjectA"
  - Two buttons: "Dismiss" and "Choose New Location"
- No countdown is displayed
- Clicking "Choose New Location" opens folder picker

**Source:** TEST_PLAN.md line 93, ACCEPTANCE_CRITERIA.md AC-010, DailyMotivation.ps1 lines 256-296

---

#### TC-009: Folder Path No Longer Exists

**Objective:** Verify re-pick prompt when folder is deleted (edge case of TC-016)

**Preconditions:**
- A task is scheduled for `C:\TestFolders\ProjectA`

**Steps:**
1. Schedule `C:\TestFolders\ProjectA` for 1 minute from now
2. While waiting, delete the folder:
   ```powershell
   Remove-Item "C:\TestFolders\ProjectA" -Recurse -Force
   ```
3. Wait for popup to appear
4. Click **"Choose New Location"**
5. Select `C:\TestFolders\ProjectB`

**Expected Result:**
- Popup displays "Path Missing" mode (as in TC-016)
- Clicking "Choose New Location" opens folder picker dialog
- After selecting new location:
  - `popup_config.json` is updated with new path
  - Popup closes
  - Explorer opens at new location (`C:\TestFolders\ProjectB`)
  - Outcome log records the new path

**Source:** TEST_PLAN.md line 79, DailyMotivation.ps1 lines 481-507

---

#### TC-008: Machine Off at 2 PM

**Objective:** Verify popup fires on next login if scheduled time was missed

**Preconditions:**
- A task is scheduled for 14:00 (2:00 PM)

**Steps:**
1. Schedule a task for 14:00 today
2. Shut down the machine before 14:00
3. Keep machine off past 14:00
4. Boot machine and log in after 14:00

**Expected Result:**
- Task Scheduler detects the missed trigger
- Popup appears shortly after login (within 1-2 minutes)
- Popup displays normally with countdown and buttons
- Task executes as if it triggered at 14:00

**Note:** This behavior depends on Task Scheduler's "Run task as soon as possible after a scheduled start is missed" setting, which should be enabled in the task configuration.

**Source:** TEST_PLAN.md line 78

---

#### TC-006: Delete Task from UI

**Objective:** Verify task deletion removes it from Task Scheduler

**Preconditions:**
- At least one task is scheduled and visible in MainApp's task list

**Steps:**
1. Launch `MainApp.ps1`
2. Locate the scheduled task in the task list
3. Click the **×** (delete) button next to the task
4. Confirm deletion in the warning dialog
5. Open Task Scheduler (`taskschd.msc`) to verify

**Expected Result:**
- Warning dialog appears: "Remove this scheduled task? This cannot be undone."
- After clicking Yes:
  - Task is removed from MainApp's task list
  - Task is removed from Windows Task Scheduler
  - No popup will appear at scheduled time

**Verification:**
```powershell
Get-ScheduledTask | Where-Object { $_.TaskName -like "DailyMotivation_*" }
# Should not include the deleted task
```

**Source:** TEST_PLAN.md line 76, ACCEPTANCE_CRITERIA.md AC-005, MainApp.ps1 lines 451-468

---

#### TC-011: Task Scheduler Service Disabled

**Objective:** Verify actionable error when Task Scheduler service is not running

**Preconditions:**
- Windows Task Scheduler service is stopped

**Steps:**
1. Stop the Task Scheduler service:
   ```powershell
   Stop-Service -Name Schedule
   ```
2. Launch `MainApp.ps1`

**Expected Result:**
- A dialog appears immediately on startup:
  - Title: "Task Scheduler Required"
  - Message: "Windows Task Scheduler is not running. This app requires it to schedule folder openings. Would you like to start the service now?"
  - Buttons: **Yes**, **No**
- Clicking Yes attempts to start the service
- If successful, app continues normally
- If failed or user clicks No, app exits gracefully

**Cleanup:**
```powershell
Start-Service -Name Schedule
```

**Source:** TEST_PLAN.md line 81, MainApp.ps1 lines 62-77

---

## 6. Expected Behaviors

### 6.1 Visual Design

#### Color Palette
- **Background**: #14141F (dark navy)
- **Panels**: #1C1C2C (slightly lighter)
- **Primary accent**: #00BCD4 (cyan)
- **Text - bright**: #E8E8F4 (white)
- **Text - dim**: #8888A8 (gray)
- **Text - very dim**: #5A5A7A (dark gray)
- **Warning**: #F4A261 (orange)
- **Success**: #52B788 (green)

#### Typography
- **Titles**: 19px, Bold
- **Body text**: 14px, Regular
- **Buttons**: 12-13px, SemiBold/Bold
- **Subtitles**: 12px, Regular

#### Animations
- **Fade-in**: 300ms duration on popup window load
- **Smooth transitions**: All hover states should transition smoothly (no jarring changes)

### 6.2 User Interaction Patterns

#### Confirmation Dialogs
The app uses confirmation dialogs for destructive actions:
- Task deletion: "Remove this scheduled task? This cannot be undone."
- Duplicate scheduling: "This folder is already scheduled... Schedule again anyway?"
- Clear history: "Clear all history entries? This cannot be undone."

All confirmation dialogs use Yes/No buttons (not OK/Cancel).

#### Error Messages
Error messages should be:
- **Specific**: Include the problematic path or value
- **Actionable**: Explain what the user can do to fix it
- **Non-technical**: Avoid jargon like "JSON parse error"

Examples:
- ✅ "That path does not exist or is not a folder: C:\InvalidPath"
- ❌ "Invalid input"

### 6.3 File System Behavior

#### Configuration Files
Location: `%APPDATA%\DailyMotivationBrainHelper\`

Files created:
- `app_settings.json` - Main app settings (last folder, first run flag, recent folders)
- `popup_config.json` - Current popup configuration (glyph, title, body, folder path)
- `tasks.json` - Scheduled task metadata
- `popup_log.txt` - Outcome log (one line per task completion)
- `messages.json` - Motivational messages (copied from `data/` on first run)

All files use **UTF-8 encoding**.

#### Debug Logs
Location: `%TEMP%\`

Files created:
- `DailyMotivation_debug.log` - Detailed execution log for popup script
- `DailyMotivation_error.log` - Error-specific log

Debug logs are **append-only** (not overwritten on each run).

### 6.4 Windows Task Scheduler Integration

#### Task Naming Convention
Format: `DailyMotivation_<timestamp>_<random>`

Example: `DailyMotivation_20260609140000_a7f3`

#### Task Configuration
- **Trigger**: One-time trigger at specified date/time
- **Action**: Run `LaunchMotivation.bat` with working directory set to app folder
- **Settings**:
  - "Run whether user is logged on or not": No (requires user session)
  - "Run with highest privileges": No
  - "Wake the computer to run this task": No
  - "Run task as soon as possible after a scheduled start is missed": Yes
  - "Stop the task if it runs longer than": 1 hour

#### Task Cleanup
Tasks are NOT automatically deleted after execution. This allows the outcome log to reference the task ID. Manual cleanup via the UI or Task Scheduler is required.

---

## 7. Common Failures

### 7.1 Popup Does Not Appear

**Symptoms:**
- Scheduled time arrives but no popup window displays

**Possible Causes:**

1. **Task Scheduler service stopped**
   - Check: `Get-Service -Name Schedule`
   - Fix: `Start-Service -Name Schedule`

2. **Task failed to execute**
   - Check Task Scheduler History (enable in Task Scheduler UI: View > Show History)
   - Look for error code in Last Run Result column
   - Common errors:
     - 0x1: Incorrect file path in task action
     - 0x41301: Task instance already running (mutex violation)

3. **PowerShell execution policy blocked script**
   - LaunchMotivation.bat should include `-ExecutionPolicy Bypass`
   - Verify: Right-click task in Task Scheduler > Properties > Actions

4. **Popup config missing or corrupt**
   - Check: `Test-Path "$env:APPDATA\DailyMotivationBrainHelper\popup_config.json"`
   - Recreate by scheduling a new task from MainApp

5. **Mutex deadlock**
   - If popup crashed while holding mutex, subsequent runs will exit silently
   - Fix: Restart machine or wait 5 minutes for mutex to release
   - Check log: `Get-Content "$env:TEMP\DailyMotivation_debug.log" | Select-String "Mutex"`

### 7.2 Explorer Does Not Open

**Symptoms:**
- Popup appears and closes but Windows Explorer does not open

**Possible Causes:**

1. **Invalid folder path**
   - Path contains typos or special characters
   - Verify path in popup_config.json

2. **Folder was moved or deleted**
   - Should trigger "Path Missing" mode
   - If not, check `$script:pathMissing` logic in DailyMotivation.ps1

3. **Network path not accessible**
   - Mapped drive not available (drive letter missing)
   - UNC path requires authentication
   - Check: Manually run `explorer.exe "\\server\share"` in cmd

4. **Explorer.exe blocked by policy**
   - Rare in standard Windows environments
   - Check Event Viewer for Application Errors

### 7.3 Undo Does Not Work

**Symptoms:**
- Clicking Undo button does not remove the scheduled task

**Possible Causes:**

1. **Task ID mismatch**
   - `$script:lastTaskId` does not match actual task in Task Scheduler
   - Verify: Check tasks.json and compare with Task Scheduler list

2. **Insufficient permissions**
   - User cannot delete scheduled tasks (requires admin in some environments)
   - Verify: Try deleting task manually from Task Scheduler

3. **Timer already expired**
   - User clicked Undo after 30-second timeout
   - Undo banner should be hidden (Visibility="Collapsed")

### 7.4 Snooze Creates Multiple Tasks

**Symptoms:**
- After snoozing, multiple popups appear at different times

**Possible Causes:**

1. **Race condition in task creation**
   - Multiple snooze clicks registered before popup closed
   - Should be prevented by disabling button after first click

2. **Old tasks not cleaned up**
   - Previous snooze tasks from earlier sessions still exist
   - Check: `Get-ScheduledTask | Where-Object { $_.TaskName -like "DailyMotivation_*" }`
   - Clean up manually if needed

### 7.5 Welcome Overlay Appears Every Launch

**Symptoms:**
- First-run welcome overlay displays on every app launch, not just the first

**Possible Causes:**

1. **FirstRunComplete flag not persisted**
   - `app_settings.json` not being written or is deleted
   - Check: `Get-Content "$env:APPDATA\DailyMotivationBrainHelper\app_settings.json"`
   - Should contain: `"FirstRunComplete": true`

2. **App data directory deleted between runs**
   - Possible if running in a locked-down environment or using temporary profiles

3. **Set-FirstRunComplete not called**
   - User closed app before clicking "Got it - Let's Go!" button
   - Welcome overlay should block interaction with main window until dismissed

### 7.6 Drag-and-Drop Does Not Work

**Symptoms:**
- Dragging a folder onto the drop zone has no effect

**Possible Causes:**

1. **App not running with -STA flag**
   - STA (Single-Threaded Apartment) required for WPF drag-and-drop
   - Verify launch command includes `-STA`

2. **Dropping file instead of folder**
   - Error message should appear: "Please drop a folder, not a file."
   - If no message appears, event handler is not firing

3. **Security policy blocks drag-and-drop**
   - Some enterprise environments disable drag-and-drop across processes
   - Test: Try dragging within Explorer to rule out OS-level restriction

---

## 8. Bug Reporting

### 8.1 Bug Report Template

When reporting a bug found during manual testing, include the following information:

```markdown
## Bug Report: [Short Description]

**Test Case:** TC-XXX
**Severity:** Critical / High / Medium / Low
**Environment:**
- Windows Version: [e.g., Windows 11 22H2]
- PowerShell Version: [Run: $PSVersionTable.PSVersion]
- App Version: [e.g., v1.1.0]

**Steps to Reproduce:**
1.
2.
3.

**Expected Behavior:**
[What should happen according to test case]

**Actual Behavior:**
[What actually happened]

**Screenshots/Logs:**
[Attach screenshots and relevant log excerpts]

**Additional Context:**
[Any other relevant information]
```

### 8.2 Severity Definitions

| Severity | Definition | Examples |
|----------|------------|----------|
| **Critical** | Blocks release; app unusable or data loss | Crash on launch, tasks not created, data corruption |
| **High** | Major feature broken; workaround exists | Popup doesn't appear, Explorer doesn't open, snooze fails |
| **Medium** | Minor feature broken; impacts UX | Tooltip doesn't appear, color incorrect, animation glitchy |
| **Low** | Cosmetic issue; no functional impact | Typo in text, slight spacing issue, debug log verbose |

### 8.3 Required Log Attachments

For all bug reports, attach:

1. **Debug log:**
   ```powershell
   Get-Content "$env:TEMP\DailyMotivation_debug.log" | Out-File BugReport_debug.txt
   ```

2. **Error log (if exists):**
   ```powershell
   Get-Content "$env:TEMP\DailyMotivation_error.log" | Out-File BugReport_error.txt
   ```

3. **App settings:**
   ```powershell
   Get-Content "$env:APPDATA\DailyMotivationBrainHelper\app_settings.json" | Out-File BugReport_settings.txt
   ```

4. **Task Scheduler state:**
   ```powershell
   Get-ScheduledTask | Where-Object { $_.TaskName -like "DailyMotivation_*" } | Format-List * | Out-File BugReport_tasks.txt
   ```

### 8.4 GitHub Issue Labels

Apply appropriate labels to GitHub issues:

- **Type**: `bug`, `enhancement`, `documentation`
- **Component**: `MainApp`, `Popup`, `TaskScheduler`, `ConfigManager`
- **Priority**: `P0-critical`, `P1-high`, `P2-medium`, `P3-low`
- **Status**: `needs-repro`, `confirmed`, `in-progress`, `blocked`

---

## 9. Regression Testing

### 9.1 When to Run Regression Tests

Regression tests must be run:

- **Before every release** (all test cases)
- **After every bug fix** (affected test cases + related edge cases)
- **After module refactoring** (all test cases for affected modules)
- **After dependency updates** (all test cases)

### 9.2 High-Risk Areas to Retest

When making changes to these components, retest the associated test cases:

| Component | High-Risk Test Cases | Reason |
|-----------|---------------------|--------|
| **TaskScheduler.psm1** | TC-002, TC-006, TC-008, TC-022 series | Task creation/deletion logic |
| **ConfigManager.psm1** | TC-012, TC-013, TC-017, TC-023 | Settings persistence |
| **DailyMotivation.ps1** | TC-003, TC-004, TC-005, TC-007, TC-016 | Core popup functionality |
| **MainApp.ps1** | TC-018, TC-024, TC-015 series | UI interactions |
| **Snooze Engine** | TC-005, TC-010, TC-019, TC-020 | Time-dependent behavior |

### 9.3 Regression Test Prioritization

If time is limited, prioritize test cases in this order:

1. **Tier 1 - Critical Path** (must pass):
   - TC-003, TC-004, TC-002, TC-006

2. **Tier 2 - Core Features** (should pass):
   - TC-005, TC-007, TC-012, TC-015, TC-017, TC-020

3. **Tier 3 - Enhancements** (nice to have):
   - TC-013, TC-018, TC-019, TC-022 series, TC-023, TC-024

4. **Tier 4 - Edge Cases** (validate on major releases):
   - TC-008, TC-009, TC-010, TC-011, TC-016

### 9.4 Regression Test Checklist

Before marking regression testing complete, verify:

- [ ] All Tier 1 tests pass without issues
- [ ] At least 90% of Tier 2 tests pass
- [ ] Any failing tests have GitHub issues created with severity assigned
- [ ] No new bugs introduced (compare against previous test run)
- [ ] All automated tests still pass (`.\Invoke-Tests.ps1`)
- [ ] PSScriptAnalyzer reports no new errors or warnings

---

## 10. Sign-off Process

### 10.1 Release Checklist

Before any version is released, the following must be completed and signed off:

#### 10.1.1 Automated Testing
- [ ] All Pester tests pass (`.\Invoke-Tests.ps1`)
- [ ] Code coverage meets or exceeds 80%
- [ ] No PSScriptAnalyzer errors
- [ ] No PSScriptAnalyzer warnings (or documented exceptions)

#### 10.1.2 Manual Testing
- [ ] All Critical Path tests (TC-003, TC-004, TC-002, TC-006) pass
- [ ] At least 90% of Enhancement tests pass
- [ ] All Edge Cases tested and handled gracefully
- [ ] All known bugs triaged with severity assigned
- [ ] No P0-critical or P1-high bugs remain open

#### 10.1.3 Documentation
- [ ] CHANGELOG.md updated with all changes
- [ ] README.md reflects current feature set
- [ ] TEST_PLAN.md updated with any new test cases
- [ ] MANUAL_TESTING.md updated if test procedures changed

#### 10.1.4 Build Verification
- [ ] Clean build completes without errors
- [ ] EXE file generated (if using PS2EXE)
- [ ] Version number updated in all files
- [ ] Installation tested on clean Windows machine

### 10.2 Sign-off Authority

The following roles have sign-off authority:

| Role | Responsibility | Required For |
|------|----------------|--------------|
| **QA Lead** | All manual tests pass per checklist | Major releases (v1.x, v2.x) |
| **Project Maintainer** | Code review, automated tests pass | All releases |
| **Release Manager** | Build verification, documentation | Major releases |

For minor releases (v1.1, v1.2) and patches (v1.1.1), Project Maintainer sign-off is sufficient.

### 10.3 Sign-off Record Template

Document sign-offs in the release notes or a separate RELEASES.md file:

```markdown
## Release v1.1.0 - 2026-06-09

### Test Sign-off
- **QA Lead:** [Name] - Signed 2026-06-09
  - Manual tests: 23/24 passed (TC-011 skipped - environment limitation)
  - Regressions: None identified

- **Project Maintainer:** [Name] - Signed 2026-06-09
  - Automated tests: 180/180 passed
  - Code coverage: 82%
  - PSScriptAnalyzer: 0 errors, 0 warnings

### Known Issues
- TC-011: Cannot test Task Scheduler service recovery in CI environment
- TC-008: Requires manual verification (machine shutdown scenario)

### Approval
Approved for release to production.
```

### 10.4 Emergency Hotfix Process

For critical bugs requiring immediate fix:

1. **Create hotfix branch** from latest release tag
2. **Implement fix** with minimal scope
3. **Run affected test cases** (not full regression)
4. **Fast-track approval** (Project Maintainer sign-off only)
5. **Deploy and monitor** closely
6. **Schedule full regression** for next regular release

---

## Appendix A: Quick Reference

### Test Cases by Component

| Component | Test Cases |
|-----------|------------|
| **MainApp UI** | TC-001, TC-012, TC-013, TC-014/14b, TC-017/17b, TC-018, TC-023, TC-024 |
| **Scheduling** | TC-002, TC-006, TC-015/15b, TC-022 series |
| **Popup Display** | TC-003, TC-004, TC-007, TC-021 |
| **Snooze/Dismiss** | TC-005, TC-010, TC-019, TC-020 |
| **Error Handling** | TC-008, TC-009, TC-011, TC-016 |

### Common PowerShell Commands

```powershell
# Clean state
Remove-Item "$env:APPDATA\DailyMotivationBrainHelper" -Recurse -Force
Get-ScheduledTask | Where-Object { $_.TaskName -like "DailyMotivation_*" } | Unregister-ScheduledTask -Confirm:$false

# View logs
Get-Content "$env:TEMP\DailyMotivation_debug.log" -Tail 50 -Wait
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\popup_log.txt" -Tail 10

# View config
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\app_settings.json" | ConvertFrom-Json | Format-List
Get-Content "$env:APPDATA\DailyMotivationBrainHelper\popup_config.json" | ConvertFrom-Json | Format-List

# Manually trigger task
Start-ScheduledTask -TaskName "DailyMotivation_<TaskId>"

# Create test task (1 minute from now)
Import-Module ".\Modules\TaskScheduler.psm1"
New-MotivationTask -FolderPath "C:\TestFolders\ProjectA" -TriggerTime (Get-Date).AddMinutes(1)
```

---

## Appendix B: Related Documentation

- **TEST_PLAN.md** - Overall test strategy and automated test details
- **ACCEPTANCE_CRITERIA.md** - Feature acceptance criteria (AC-001 through AC-018)
- **Tests/README.md** - Automated test suite documentation
- **CLAUDE.md** - Development conventions and architecture decisions
- **PRD.md** - Product requirements (functional and non-functional)

---

**Document Status:** Active
**Next Review:** Before v1.2 release
**Maintained By:** QA Lead / Project Maintainer
