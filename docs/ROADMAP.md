# Roadmap

**Last Updated:** 2026-06-03
**Last Reviewed**: 2026-06-09

## v1.0 — MVP (Current Sprint)

### Engineering Foundation (COMPLETE -- commit 4ba633a)

- Pester 5.x test suite -- 180+ tests
- CI/CD pipeline -- GitHub Actions (tests + build + security scan)
- PSScriptAnalyzer -- zero-warning code quality enforcement
- Invoke-Build automation -- 12 build tasks
- Code coverage tracking -- target 80%+, achieved ~85%
- ConfigManager module: ~90% coverage
- TaskScheduler module: ~85% coverage
- Notification Engine test coverage -- deferred (WPF requires live session)

**Goal:** Complete, no-code end-to-end experience including all 14 approved brainstorm features.

### Core Loop
- Folder picker + drag-and-drop (B-09)
- Schedule for today or tomorrow (B-03)
- Duplicate schedule warning (B-16)
- App writes popup_config.json — user never edits files
- Undo schedule — 30-second grace period (B-04)
- Remember last folder + one-click reschedule (B-01)
- Recent folders list — top 5 (B-02)

### Popup Experience
- Motivational popup with WPF dark theme
- Show folder name in popup subtitle (B-12)
- Snooze with duration choice — 5/15/30/60 min (B-10)
- Dismiss for Today — cancels all re-triggers (B-11)
- Moved folder re-pick prompt (B-05)
- Named mutex — one popup at a time

### Onboarding & Guidance
- First-run welcome screen (B-07)
- Tooltips on all UI controls (B-19)

### Management
- View and delete scheduled tasks
- Task history / outcome log viewer (B-18)
- Default message library (10 messages, random selection)

### Advanced
- Windows Explorer right-click shell extension (B-13)

## v1.1 — Power User
**Goal:** Remove remaining friction and add customisation.

- Custom motivational message management (add/edit/delete)
- Custom schedule time (not just 2 PM)
- System tray icon (was B-08, deferred)
- Auto-start on login (was B-14, deferred)

## v2.0 — Expansion
**Goal:** Multi-session and personalisation.

- Multiple active schedules per day
- Message categories and tagging
- Dark/light theme toggle
- Export/import message library
- Desktop widget showing next scheduled task

## Status
> v1.1 DRAFT
