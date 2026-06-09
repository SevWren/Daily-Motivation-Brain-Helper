# Feature Brainstorm — Approval Record

**Session Date:** 2026-06-02
**Last Reviewed**: 2026-06-09
**Method:** 6-agent parallel brainstorm (Product, UX, Architecture, QA, Security, Documentation)
**Total Proposed:** 20 features
**Approved:** 14 | **Rejected:** 6

---

## Approved Features (14)

### B-01 — Remember Last Folder (Quick Reschedule)
**Category:** Scheduling Shortcuts | **Effort:** Low | **Sprint:** 1 | **Merged Into:** TASK-004

App remembers the last scheduled folder. On next open, shows a one-click banner: "Schedule same folder as last time? [Yes, Schedule] [Choose Different]"

**Why approved:** The #1 repeat action is scheduling the same folder. Eliminates picker navigation for daily users.

---

### B-02 — Recent Folders List
**Category:** Scheduling Shortcuts | **Effort:** Low | **Sprint:** 3 | **Merged Into:** TASK-008

A list (max 5) of recently scheduled folders, each with a one-click "Schedule Again" button.

**Why approved:** Users rotate between 2–3 active projects. This eliminates folder navigation entirely for repeat use.

---

### B-03 — Schedule For Today (Before 2 PM)
**Category:** Scheduling Shortcuts | **Effort:** Low | **Sprint:** 1 | **Merged Into:** TASK-003

If the user opens the app before 2 PM, offer "Today at 2:00 PM" alongside "Tomorrow at 2:00 PM" as scheduling options.

**Why approved:** Adds flexibility for same-day use without changing the default tomorrow experience.

---

### B-04 — Undo Schedule (30-Second Grace Period)
**Category:** Feedback & Recovery | **Effort:** Low | **Sprint:** 2 | **Merged Into:** TASK-NEW-01

After scheduling, a 30-second undo banner with countdown progress bar. Clicking [Undo] removes the task before it's committed.

**Why approved:** Accidental schedules are frustrating. One-click correction within 30 seconds is effortless recovery.

---

### B-05 — Folder No Longer Exists — Re-Pick Prompt
**Category:** Feedback & Recovery | **Effort:** Medium | **Sprint:** 2 | **Merged Into:** TASK-007

At popup time, if the scheduled folder path is missing, the popup transforms to show: "This folder was moved. [Choose New Location] [Dismiss]"

**Why approved:** TC-009 currently fails silently. Path changes between scheduling and 2 PM are common when reorganizing projects.

---

### B-07 — First-Run Welcome Screen
**Category:** Onboarding & Discovery | **Effort:** Low | **Sprint:** 1 | **Merged Into:** TASK-001

On first launch, a fullscreen overlay explains the 3-step loop with icons: Pick Folder → Schedule → Opens at 2 PM. Single "Got it" button dismisses forever.

**Why approved:** Non-technical users open a blank window with no context. A 10-second in-app explanation replaces all documentation.

---

### B-09 — Drag-and-Drop Folder Onto App Window
**Category:** Scheduling Shortcuts | **Effort:** Medium | **Sprint:** 1 | **Merged Into:** TASK-002

User can drag a folder from Windows Explorer and drop it directly onto the app window.

**Why approved:** Power users have their folder already open in Explorer. Drag-drop is faster than navigating a picker tree.

---

### B-10 — Snooze Duration Choice
**Category:** Popup Enhancements | **Effort:** Low | **Sprint:** 2 | **Merged Into:** TASK-005

Snooze button becomes a split-button with dropdown: [5 min ✓] [15 min] [30 min] [1 hour]. Default remains 5 min per spec.

**Why approved:** 5 minutes is too short during a meeting; 1 hour is too long for a break. Context varies without changing the default.

---

### B-11 — Dismiss for Today
**Category:** Popup Enhancements | **Effort:** Low | **Sprint:** 2 | **Merged Into:** TASK-005

Third popup button "Dismiss for Today" — cancels all remaining snooze re-triggers without opening the folder.

**Why approved:** Sometimes 2 PM is genuinely the wrong time. The current model forces infinite snooze. This is a graceful exit.

---

### B-12 — Show Folder Name in Popup
**Category:** Popup Enhancements | **Effort:** Very Low | **Sprint:** 1 | **Merged Into:** TASK-004

Popup displays a subtitle: "Opening: [FolderName]" so the user knows exactly what will open.

**Why approved:** Zero context in the current popup about what's about to open. Adding the folder name is trivial and essential.

---

### B-13 — Windows Explorer Right-Click Shell Extension
**Category:** Scheduling Shortcuts | **Effort:** High | **Sprint:** 4 | **Merged Into:** TASK-NEW-02

Adds "Schedule for Tomorrow at 2 PM" to the Windows Explorer right-click context menu on folders.

**Why approved:** The most natural scheduling moment is when you're already in Explorer. Eliminates launching the app entirely.

---

### B-16 — Duplicate Schedule Warning
**Category:** Feedback & Recovery | **Effort:** Very Low | **Sprint:** 1 | **Merged Into:** TASK-003

Before creating a task, check for an existing task for the same folder/date. If found, show: "Already scheduled for [date]. Schedule again? [Yes] [Cancel]"

**Why approved:** Silent duplication creates two popups and two Explorer windows. A one-line check prevents user confusion.

---

### B-18 — Task History / Outcome Log Viewer
**Category:** Transparency & Trust | **Effort:** Low | **Sprint:** 3 | **Merged Into:** TASK-NEW-03

In-app panel showing past outcomes: Date | Folder | Result (Opened / Snoozed N times / Dismissed / Missed). Read from `popup_log.txt`.

**Why approved:** `popup_log.txt` exists but is invisible to users. Non-technical users deserve a human-readable history inside the app.

---

### B-19 — Tooltip Explanations on All UI Controls
**Category:** Onboarding & Discovery | **Effort:** Low | **Sprint:** 1 | **Merged Into:** TASK-001

Every button and input has a `ToolTip` with plain-English description. Example: "Schedule For Tomorrow — Creates a reminder that opens this folder at 2:00 PM tomorrow."

**Why approved:** Self-documenting UI reduces every support question without requiring any user action.

---

## Rejected Features (6)

| ID | Feature | Reason |
|----|---------|--------|
| B-06 | Preview Popup Button | Not approved by user |
| B-08 | System Tray Icon | Not approved by user |
| B-14 | Auto-Start on Windows Login | Not approved by user |
| B-15 | Paste Path from Clipboard | Not approved by user |
| B-17 | Missed Task Recovery UI | Not approved by user |
| B-20 | "What Happens Next" Panel | Not approved by user |

Rejected features are excluded from all planning documents. They may be reconsidered in a future brainstorm session.
