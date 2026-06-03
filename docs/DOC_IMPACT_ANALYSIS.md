# Documentation Impact Analysis

**Generated:** 2026-06-03
**Trigger:** 14 approved brainstorm features (B-01 through B-19, see FEATURE_BRAINSTORM.md)
**Method:** Multi-agent review — each agent assessed impact on documents within their scope

---

## Summary

| Document | Changes Required | Agent Owner |
|----------|-----------------|-------------|
| PRD.md | 14 — new FR-013 through FR-025, update FR-007/008 | Product |
| TRACEABILITY_MATRIX.md | 14 — new rows for each approved feature | Documentation |
| FEATURE_MATRIX.md | 14 — move all features into v1.0 | Product |
| TEST_PLAN.md | 13 — new TC-012 through TC-024 | QA |
| USER_STORIES.md | 12 — new US-008 through US-018 | Product |
| ACCEPTANCE_CRITERIA.md | 12 — new AC-007 through AC-018 | QA |
| UX_SPEC.md | 11 — wireframe updates for each UI change | UX |
| ARCHITECTURE.md | 10 — module responsibility updates | Architecture |
| DATA_MODEL.md | 7 — schema additions for new fields | Architecture |
| GLOSSARY.md | 5 — new domain terms | Documentation |
| NOTIFICATION_ENGINE_SPEC.md | 4 — popup state machine changes | Architecture |
| CONFIGURATION_SPEC.md | 4 — new JSON fields | Architecture |
| TASK_SCHEDULER_SPEC.md | 4 — module interface changes | Architecture |
| RISK_REGISTER.md | 3 — new risks from shell extension + re-pick | PM |
| SSOT.md | 2 — new SSOT-009, clarify SSOT-002 | Documentation |
| ROADMAP.md | 2 — move features to v1.0 | PM |
| CHANGELOG.md | 1 — unreleased entries | Documentation |

**Total: 17 documents, 132 individual change items**

---

## Change Detail by Document

### PRD.md
| Feature | Change |
|---------|--------|
| B-01 | Add FR-013: App shall persist and display last scheduled folder path |
| B-02 | Add FR-014: App shall maintain a recent folders list (max 5) |
| B-03 | Add FR-015: App shall offer same-day scheduling when current time < 14:00 |
| B-04 | Add FR-016: App shall provide a 30-second undo window after scheduling |
| B-05 | Add FR-017: Popup shall detect missing path and offer re-pick dialog |
| B-07 | Add FR-018: App shall display first-run onboarding overlay on initial launch |
| B-09 | Add FR-019: App shall accept folder path via drag-and-drop |
| B-10 | Update FR-007/008: Snooze duration is user-selectable (5/15/30/60 min) |
| B-11 | Add FR-020: Popup shall provide a Dismiss for Today action |
| B-12 | Add FR-021: Popup shall display the scheduled folder name |
| B-13 | Add FR-022: System shall provide Explorer right-click shell extension |
| B-16 | Add FR-023: App shall warn before creating a duplicate scheduled task |
| B-18 | Add FR-024: App shall display a history of past task outcomes |
| B-19 | Add FR-025: All UI controls shall have plain-English tooltip text |

### USER_STORIES.md
| Feature | Change |
|---------|--------|
| B-01 | Add US-008: As a user I want to re-schedule yesterday's folder in one click |
| B-02 | Add US-009: As a user I want to see recently used folders for quick re-scheduling |
| B-03 | Add US-010: As a user I want to schedule a folder for today if it's before 2 PM |
| B-04 | Add US-011: As a user I want to undo a schedule within 30 seconds of creating it |
| B-05 | Add US-012: As a user I want to be prompted to re-pick my folder if it was moved |
| B-07 | Add US-013: As a first-time user I want an in-app explanation of how the tool works |
| B-09 | Add US-014: As a user I want to drag-and-drop a folder to select it |
| B-10 | Update US-004: As a user I want to choose how long to snooze (5/15/30/60 min) |
| B-11 | Add US-015: As a user I want to dismiss today's popup entirely without it recurring |
| B-13 | Add US-016: As a user I want to schedule a folder via right-click in Explorer |
| B-18 | Add US-017: As a user I want to see a history of what folders I opened and when |
| B-19 | Add US-018: As a user I want tooltips explaining what each button does |

### UX_SPEC.md
| Feature | Change |
|---------|--------|
| B-01 | Add Last Folder banner to Home screen wireframe |
| B-02 | Add Recent Folders section to Home screen wireframe |
| B-03 | Update Schedule button — show Today/Tomorrow radio options |
| B-04 | Add Undo banner wireframe and 30-second countdown bar |
| B-07 | Add First-Run Welcome overlay wireframe |
| B-09 | Add drag-drop zone specification to Home screen |
| B-10 | Update Popup wireframe — snooze split-button with duration menu |
| B-11 | Update Popup wireframe — add Dismiss for Today button |
| B-12 | Update Popup wireframe — add folder name subtitle |
| B-18 | Add History panel wireframe |
| B-19 | Add tooltip spec table for every control |

### ARCHITECTURE.md
| Feature | Change |
|---------|--------|
| B-01 | Config Manager now writes/reads lastFolder in app_settings.json |
| B-02 | Config Manager now writes/reads recentFolders[] in app_settings.json |
| B-04 | Main Window owns undo timer state |
| B-07 | Main Window responsible for first-run detection and onboarding overlay |
| B-09 | Folder Picker Module handles drag-drop events in addition to picker dialog |
| B-10 | Snooze Engine interface updated — duration parameter added |
| B-11 | Snooze Engine adds DISMISSED terminal state |
| B-12 | Notification Engine reads folder_name from popup_config.json |
| B-13 | New module: Shell Extension (COM DLL + registry + PowerShell bridge) |
| B-18 | New module: History Viewer (reads popup_log.txt, renders in UI) |

### DATA_MODEL.md
| Feature | Change |
|---------|--------|
| B-01 | app_settings.json: add lastFolder field |
| B-02 | app_settings.json: add recentFolders[] field (max 5) |
| B-03 | ScheduledTask: triggerTime is now caller-specified datetime |
| B-10 | ScheduledTask: add snooze_duration_minutes field |
| B-11 | ScheduledTask: add DISMISSED to status enum |
| B-12 | popup_config.json: add folder_name field |
| B-18 | popup_log.txt: define structured parseable log entry format |

### NOTIFICATION_ENGINE_SPEC.md
| Feature | Change |
|---------|--------|
| B-05 | Add Missing Path state — popup transforms to re-pick UI |
| B-10 | Update button spec: Snooze is a split-button with 4 duration options |
| B-11 | Add Dismiss for Today button and DISMISSED terminal state |
| B-12 | Update XAML spec: add folder_name subtitle TextBlock |

### CONFIGURATION_SPEC.md
| Feature | Change |
|---------|--------|
| B-01 | app_settings.json: document lastFolder field |
| B-02 | app_settings.json: document recentFolders[] schema |
| B-12 | popup_config.json: document folder_name field |
| B-18 | popup_log.txt: document structured log entry format |

### TASK_SCHEDULER_SPEC.md
| Feature | Change |
|---------|--------|
| B-03 | New-MotivationTask accepts arbitrary TriggerTime |
| B-10 | Snooze re-trigger passes duration to New-MotivationTask |
| B-13 | Document ShellBridge.ps1 as consumer of Scheduler Module |
| B-16 | Document duplicate-check pre-condition in New-MotivationTask |

### ACCEPTANCE_CRITERIA.md
| Feature | New Criterion |
|---------|--------------|
| B-01 | AC-007: Last folder banner appears on second launch |
| B-03 | AC-008: Today option visible when current time < 14:00 |
| B-04 | AC-009: Undo banner appears; clicking Undo removes task |
| B-05 | AC-010: Popup shows re-pick prompt when folder is missing |
| B-07 | AC-011: Welcome overlay appears on first launch only |
| B-09 | AC-012: Dragging folder onto app window selects it |
| B-10 | AC-013: Snooze duration fires correct re-trigger interval |
| B-11 | AC-014: Dismiss for Today cancels all re-triggers |
| B-12 | AC-015: Popup displays correct folder name as subtitle |
| B-16 | AC-016: Duplicate warning shown before duplicate task creation |
| B-18 | AC-017: History panel lists past outcomes |
| B-19 | AC-018: All controls have visible tooltips |

### TEST_PLAN.md
| Feature | New Test Case |
|---------|--------------|
| B-01 | TC-012: Last folder banner shown on second app open |
| B-02 | TC-013: Recent folders list populates after scheduling |
| B-03 | TC-014: Today option visible before 14:00; hidden after |
| B-04 | TC-015: Undo removes task within 30s; auto-clears after 30s |
| B-05 | TC-016: Popup re-pick prompt when folder moved/deleted |
| B-07 | TC-017: Welcome overlay on first run only |
| B-09 | TC-018: Drag-drop selects folder path correctly |
| B-10 | TC-019: Each snooze duration fires re-trigger at correct interval |
| B-11 | TC-020: Dismiss for Today cancels all pending re-triggers |
| B-12 | TC-021: Popup folder name matches scheduled folder |
| B-16 | TC-022: Duplicate warning fires; Yes proceeds; Cancel aborts |
| B-18 | TC-023: History panel shows correct entries from log |
| B-19 | TC-024: All interactive controls display tooltip on hover |

### TRACEABILITY_MATRIX.md
New rows for US-008 through US-018, FR-013 through FR-025, AC-007 through AC-018, TC-012 through TC-024.

### FEATURE_MATRIX.md
All 14 approved features move to v1.0 column.

### RISK_REGISTER.md
| Feature | New Risk |
|---------|---------|
| B-13 | R-009: Shell extension DLL registration requires admin |
| B-13 | R-010: Shell extension may conflict with antivirus/EDR |
| B-05 | R-011: Re-pick dialog (WinForms in WPF context) needs careful testing |

### SSOT.md
| Feature | Change |
|---------|--------|
| B-11 | Add SSOT-009: DISMISSED is terminal; dismissed tasks do not re-trigger |
| B-03 | Clarify SSOT-002: TriggerTime may be today or tomorrow (not hardcoded) |

### GLOSSARY.md
Add: Undo Window, Dismiss for Today, Shell Extension, History Viewer, Recent Folders

### ROADMAP.md
Move all 14 approved features from v1.1/v2.0 into v1.0.

### CHANGELOG.md
Add Unreleased entries for all 14 approved features.

---

## Addendum: Test Infrastructure Impact (Commit 4ba633a -- 2026-06-03)

**Trigger:** Modern PowerShell engineering scaffold added (Pester, Invoke-Build, CI/CD)
**Audit methodology:** 5-agent parallel review of 60+ files
**Agent audit reports:** See `docs/reports/` for full reports

### Documentation Changes Required (25 files identified)

| Document | Change Type | Status |
|----------|------------|--------|
| README.md | Add Tests/ to structure, add Testing section | Done (commit 8d6cb0d) |
| CLAUDE.MD | Fix build ref, update layout, add testing conventions | Done (commit 8d6cb0d) |
| src/README.md | Add Test Infrastructure section | Done (commit 8d6cb0d) |
| docs/CONTRIBUTING.md | Add Development Workflow, TDD guidelines | Done (commit 8d6cb0d) |
| docs/TEST_PLAN.md | Add Automated Testing section | Done (commit 8d6cb0d) |
| docs/CHANGELOG.md | Add commit 4ba633a entry | Done (commit 8d6cb0d) |
| docs/ARCHITECTURE.md | Add QA section | Done (Phase 2) |
| docs/INSTALL.md | Fix build ref, add Developer Setup | Done (Phase 2) |
| docs/PRD.md | Add validation matrix | Done (Phase 2) |
| docs/TRACEABILITY_MATRIX.md | Add test coverage section | Done (Phase 2) |
| docs/DISTRIBUTION_STRATEGY.md | Add build system section | Done (Phase 2) |
| docs/SPRINT_PLAN.md | Add Sprint 0 | Done (Phase 2) |
| docs/ROADMAP.md | Add infra milestone | Done (Phase 2) |
| docs/NOTIFICATION_ENGINE_SPEC.md | Add zero-coverage warning | Done (Phase 2) |
| docs/CONFIGURATION_SPEC.md | Add test validation notes | Done (Phase 2) |
| docs/README.md | Add test doc entries | Done (Phase 3) |
| docs/NPR.md | Add NPR-008, NPR-009, NPR-010 | Done (Phase 3) |
| docs/RISK_REGISTER.md | Add R-012, R-013, R-014 | Done (Phase 3) |
| docs/GLOSSARY.md | Add test terminology | Done (Phase 3) |
| docs/FEATURE_MATRIX.md | Add infra feature rows | Done (Phase 3) |
| docs/NEXT_STEPS.md | Add TDD workflow note | Done (Phase 3) |
| docs/FORENSIC_REVIEW.md | Add regression protection section | Done (Phase 3) |
| Archive session files to docs/reports/ | File moves (11 files) | Done (Phase 0) |
