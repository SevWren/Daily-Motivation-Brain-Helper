# Changelog

All notable changes to this project will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

## [Unreleased — v1.0 in development]

### Planning
- Added SPRINT_PLAN.md with revised 16-task plan across 4 sprints
- Added FEATURE_BRAINSTORM.md with approval record (14 approved / 6 rejected)
- Added DOC_IMPACT_ANALYSIS.md (17 docs, 132 change items)
- Updated all 17 planning docs for approved brainstorm features

### Approved Features Queued for Implementation
- B-01: Remember Last Folder (Quick Reschedule)
- B-02: Recent Folders List (top 5)
- B-03: Schedule For Today option (before 2 PM)
- B-04: Undo Schedule — 30-second grace period
- B-05: Moved Folder Re-Pick Prompt in popup
- B-07: First-Run Welcome Screen
- B-09: Drag-and-Drop Folder onto App Window
- B-10: Snooze Duration Choice (5/15/30/60 min)
- B-11: Dismiss for Today button
- B-12: Show Folder Name in Popup subtitle
- B-13: Windows Explorer Right-Click Shell Extension
- B-16: Duplicate Schedule Warning
- B-18: Task History / Outcome Log Viewer
- B-19: Tooltips on All UI Controls

### Prototype (existing src/)
- DailyMotivation.ps1 — WPF motivational popup, countdown, fade-in
- LaunchMotivation.bat — Task Scheduler wrapper with defensive flags
- UpdateScheduledTask.ps1 — One-time task registration script
- popup_config.json — Active task configuration
