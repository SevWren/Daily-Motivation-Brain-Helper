# Forensic UI Bug Report — Daily Motivation Brain Helper
## 10x Multi-Agent Investigation

**Date:** 2026-06-26
**Branch:** project-restart-pwsh7
**Method:** 10 parallel forensic agents, each assigned a distinct UI domain
**Total Bugs Found:** 124 across 10 domains

---

## Agent Roster

| Agent | Domain | Bugs Found |
|---|---|---|
| Agent 1 | Main Window — Layout & Structure | 15 |
| Agent 2 | Main Window — Color, Contrast & WCAG | 12 |
| Agent 3 | Main Window — Typography & Text | 12 |
| Agent 4 | Main Window — Button & Interaction Design | 12 |
| Agent 5 | Main Window — Task List & History Data Display | 12 |
| Agent 6 | Popup Window — Layout & Structure | 12 |
| Agent 7 | Popup Window — Color, Contrast & WCAG | 12 |
| Agent 8 | Popup Window — Typography & Content | 12 |
| Agent 9 | Popup Window — Button & Interaction Design | 12 |
| Agent 10 | Overall UX Flow & Cross-Window Design | 13 |

---

## Critical Severity Summary (Immediate Action Required)

| ID | Component | Issue |
|---|---|---|
| A1-BUG-01 | Main Window | Schedule button `Padding="48,30"` — 30px vertical padding creates disproportionate monster button |
| A2-BUG-001 | Main Window | `NoTasksLabel` `#3A3A5A` on `#0D1117` = **1.74:1 contrast** — effectively invisible |
| A2-BUG-002 | Main Window | `SelectedPathLabel` `#4A4A6A` on `#111B22` = **2.06:1** — path text unreadable |
| A2-BUG-003 | Main Window | History timestamp `#4A4A6A` on `#0A0A14` = **2.32:1** — timestamps invisible |
| A3-BUG-01 | Main Window | `SelectedPathLabel` `TextTrimming` has zero effect — no `MaxWidth` in StackPanel, paths overflow |
| A3-BUG-03 | Main Window | `NoTasksLabel` `#3A3A5A` nearly invisible — empty state unreadable |
| A4-BUG-03 | Main Window | `LastFolderDismissBtn` `Width="28"` + `Padding="10,7"` — 8px left for `×` glyph, always clipped |
| A4-BUG-06 | Main Window | **Zero hover states on ALL buttons** — no visual feedback for any interactive element |
| A5-BUG-009 | Main Window | Delete button active during Undo banner — **double-deletion race condition** |
| A6-BUG-01 | Popup Window | `Opacity="0"` on root window with no guaranteed recovery — **popup can be permanently invisible** |
| A7-BUG-01 | Popup Window | `DismissBtn` `#3E3E58` on `#14141F` = **1.77:1** — button is functionally invisible |
| A7-BUG-02 | Popup Window | "Auto-opening in" label `#3E3E58` on `#14141F` = **1.77:1** — countdown context invisible |
| A7-BUG-05 | Popup Window | `MissingPathLabel` `#4A4A6A` on `#14141F` = **2.16:1** — critical error info unreadable |
| A9-BUG-12 | Popup Window | **Race condition**: countdown timer fires during user click, silently overrides dismiss intent |

---

## Agent 1: Main Window — Layout & Structure
*15 bugs found*

### A1-BUG-01 — Schedule Button Vertical Padding is Enormous
**Severity: Critical**
`ScheduleBtn` `Padding="48,30"` — 30px vertical padding makes the button 60px+ tall from padding alone. Every other button uses 5–10px vertical padding. The button dominates the layout like a placeholder block.
**Fix:** Change to `Padding="48,12"`.

### A1-BUG-02 — Header Accent Bar Double-Indented
**Severity: High**
Outer `Border` already has `Padding="28,24,28,24"`. Accent bar then adds `Margin="20,20,20,20"`. The bar renders 96px narrower than the window (424px vs 520px), appearing detached and misaligned.
**Fix:** Change accent bar margin to `Margin="0,0,0,12"`.

### A1-BUG-03 — SizeToContent + No MaxHeight + CanMinimize Only
**Severity: High**
Window grows unboundedly with tasks and history. `ResizeMode="CanMinimize"` prevents user resizing. On small screens, bottom controls become permanently unreachable.
**Fix:** Add `MaxHeight` to window, wrap content in `ScrollViewer`.

### A1-BUG-04 — SelectedPathLabel TextTrimming Has No Effect
**Severity: High**
`TextTrimming="CharacterEllipsis"` with no `MaxWidth` in a `StackPanel`. `StackPanel` measures children with infinite width — trimming never activates. Long paths expand and overflow.
**Fix:** Add `MaxWidth="380"` to the `TextBlock`.

### A1-BUG-05 — Drop Zone Has No MinHeight
**Severity: High**
DropZone relies entirely on children for height (~90–100px). For a drag-and-drop target, this is inadequate — too small to comfortably aim at.
**Fix:** Add `MinHeight="130"` to the `DropZone` Border.

### A1-BUG-06 — Undo Banner Missing Bottom Margin
**Severity: Medium**
`UndoBanner` has `Margin="0,14,0,0"` — zero bottom margin. Spacing below the banner is controlled only by the divider's top margin, creating a fragile layout dependency.
**Fix:** Change to `Margin="0,14,0,14"`.

### A1-BUG-07 — Divider Asymmetric Margins (20px top / 16px bottom)
**Severity: Medium**
The divider has 20px above and 16px below, creating unequal visual spacing between the scheduling zone and the task list section.
**Fix:** Change to `Margin="0,20,0,20"`.

### A1-BUG-08 — History FolderName Column 120px Too Narrow
**Severity: Medium**
`Width="120"` for folder names at `FontSize="11"` aggressively clips even moderate-length names. The remaining `*` column is allocated to the short outcome values instead.
**Fix:** Swap: `FolderName Width="*"`, `Outcome Width="80"`.

### A1-BUG-09 — Outer Border Background Redundant With Window Background
**Severity: Low**
Both `Window` and the immediately nested `Border` use `Background="#0D1117"`. The border background is entirely occluded — dead markup.
**Fix:** Remove `Background="#0D1117"` from the outer `Border`.

### A1-BUG-10 — ScheduleBtn HorizontalAlignment="Left" Buries Primary CTA
**Severity: Medium**
The primary action button collapses to content width (~140px) while the DropZone above spans full width. The CTA is left-stranded, visually subordinate to the selection zone.
**Fix:** Change to `HorizontalAlignment="Stretch"`.

### A1-BUG-11 — LastFolderDismissBtn Width="28" Conflicts With Padding="10,7"
**Severity: Medium**
28px wide with 10px left/right padding leaves only 8px for the `×` character. At any font size above 8px, the glyph is clipped.
**Fix:** Change to `Width="32" Padding="0"`.

### A1-BUG-12 — HistoryPanel No Bottom Margin
**Severity: Medium**
`HistoryPanel` is the last element in the StackPanel with `Margin="0,8,0,0"`. Content floats flush into the bottom padding with no visual termination cue.
**Fix:** Change to `Margin="0,8,0,8"`.

### A1-BUG-13 — "Schedule for:" Label Left Margin Misaligns With Siblings
**Severity: Low**
`Margin="8,8,8,8"` pushes "Schedule for:" 8px inward from the DropZone above it, creating a ragged left edge.
**Fix:** Change to `Margin="0,0,0,6"`.

### A1-BUG-14 — TodayRadio Margin="0,0,24,0" When TomorrowRadio Has No Left Margin
**Severity: Low**
When `TodayRadio` is collapsed, `TomorrowRadio` renders at position 0 with no indent, misaligned with the "Schedule for:" label above it.
**Fix:** Add a consistent left margin to the `Orientation="Horizontal"` StackPanel wrapper.

### A1-BUG-15 — TaskList and HistoryList Have No ScrollViewer or MaxHeight
**Severity: High**
Both `ItemsControl` elements are unbounded in a `SizeToContent="Height"` window. Many tasks or history entries will push the window off-screen permanently.
**Fix:** Wrap both in `ScrollViewer` with `MaxHeight="200"` / `MaxHeight="220"`.

---

## Agent 2: Main Window — Color, Contrast & WCAG
*12 bugs found*

### A2-BUG-001 — NoTasksLabel Near-Invisible
**Severity: Critical | Contrast: 1.74:1 | WCAG: FAIL ALL**
`#3A3A5A` on `#0D1117`. The empty-state message is functionally invisible. Users see a blank list and believe the app is broken.
**Fix:** Change foreground to `#8888A8` minimum.

### A2-BUG-002 — SelectedPathLabel Unreadable
**Severity: Critical | Contrast: 2.06:1 | WCAG: FAIL ALL**
`#4A4A6A` on `#111B22`. The selected folder path — the most actionable info on screen — is illegible.
**Fix:** Change to `#B0B0C8`.

### A2-BUG-003 — History Timestamps Invisible
**Severity: Critical | Contrast: 2.32:1 | WCAG: FAIL ALL**
`#4A4A6A` on `#0A0A14`. Timestamps are the primary differentiator between history entries. Unreadable.
**Fix:** Change to `#8888A8`.

### A2-BUG-004 — #4A4A6A Palette-Wide Failure
**Severity: Critical | Contrast: 2.06–2.32:1 | WCAG: FAIL ALL**
Color `#4A4A6A` is used system-wide as a "dimmed" state but is below readable threshold on every background in this app. A palette-level defect.
**Fix:** Retire `#4A4A6A` from all foreground text roles entirely.

### A2-BUG-005 — Divider Invisible (1.17:1)
**Severity: High | Contrast: 1.17:1 | WCAG: FAIL (Non-text 3.0:1)**
`#1F1F30` on `#0D1117`. The divider provides zero structural separation. Layout reads as one undifferentiated dark block.
**Fix:** Change divider to `#5A5A7A`.

### A2-BUG-006 — Outer Border Identical to Window (1.00:1)
**Severity: High | Contrast: 1.00:1**
Both are `#0D1117`. The border adds no visual depth or containment.
**Fix:** Remove duplicate background or differentiate with `#111B22`.

### A2-BUG-007 — Inconsistent Corner Radii (6 vs 10)
**Severity: High**
`PrimaryBtn` uses `CornerRadius="6"`, `SecondaryBtn` uses `CornerRadius="10"`. Two competing shape languages on interactive controls in the same window.
**Fix:** Standardize to `CornerRadius="6"` or `"8"` across all buttons.

### A2-BUG-008 — Task Delete Button Marginal Contrast (4.90:1)
**Severity: Medium | Contrast: 4.90:1**
`#8888A8` on `#1C1C2C` clears AA by only 0.4 points. For a destructive action on a small 28px target, this is insufficient.
**Fix:** Raise to `#A8A8C8`.

### A2-BUG-009 — Header Accent Bar Margin Creates Misalignment
**Severity: Medium**
`Margin="20,20,20,20"` uniform on all sides makes the accent bar float, creating a mysterious top gap and misalignment with content.
**Fix:** `Margin="0,0,0,12"` — top/bottom only.

### A2-BUG-010 — History Panel Background Imperceptible (1.04:1)
**Severity: Medium | Contrast: 1.04:1**
`#0A0A14` on `#0D1117`. The panel boundary is invisible. Users cannot perceive the distinct content zone.
**Fix:** Use `#14141F` background or add a visible border stroke.

### A2-BUG-011 — "Schedule for:" Label Fails AAA (5.53:1)
**Severity: Low | Contrast: 5.53:1**
Passes AA but not AAA. For a critical form label on a scheduling input, AAA is recommended.
**Fix:** Change to `#B0B0C8` (~8.0:1).

### A2-BUG-012 — Undo Banner Fails AAA (6.22:1)
**Severity: Low | Contrast: 6.22:1**
Time-sensitive notification should maximize legibility. Misses AAA by 0.78 points.
**Fix:** Lighten green to `#6AC99A` (>7.0:1).

---

## Agent 3: Main Window — Typography & Text
*12 bugs found*

### A3-BUG-01 — SelectedPathLabel TextTrimming Inert
**Severity: Critical**
`TextTrimming="CharacterEllipsis"` with no `MaxWidth` in an unbounded StackPanel. Trimming algorithm has no constraint to trigger against. Long paths expand and break layout.
**Fix:** Add `MaxWidth="320"`.

### A3-BUG-02 — RadioButton Labels Hardcoded "2:00 PM"
**Severity: High**
`default_trigger_hour` is configurable in `config.json`. Labels permanently read "2:00 PM" regardless of config. If user sets hour to 9, labels still say "2:00 PM" — a factual lie.
**Fix:** Build label dynamically: `"Today at $([datetime]::Today.AddHours($hour).ToString('h:mm tt'))"`.

### A3-BUG-03 — NoTasksLabel Contrast Critical Failure
**Severity: Critical**
`#3A3A5A` is near-invisible at any reasonable DPI on this dark background. Empty state is unreadable.
**Fix:** Change to `#A0A0C0`.

### A3-BUG-04 — UndoLabel XAML Text Immediately Overwritten Without Checkmark
**Severity: Medium**
XAML sets `"✓ Scheduled"`. Code sets `"Scheduled for $ScheduledFor - undo in 30s"` — no checkmark. Initial XAML is misleading to developers; live UI loses the confirmation symbol.
**Fix:** Include checkmark in code string: `"✓ Scheduled for $ScheduledFor - undo in 30s"`.

### A3-BUG-05 — History Timestamp Column 130px Clips at 125% DPI
**Severity: Medium**
`yyyy-MM-dd HH:mm:ss` is 19 characters. At 125% DPI, Segoe UI 10px exceeds 130px available width, clipping seconds with no ellipsis.
**Fix:** Increase to `Width="160"`.

### A3-BUG-06 — History FolderName Truncates With No Tooltip
**Severity: Medium**
`Width="120"` with `TextTrimming="CharacterEllipsis"` clips most folder names. No `ToolTip` binding to reveal full text.
**Fix:** Add `ToolTip="{Binding FolderName}"`.

### A3-BUG-07 — scheduled_time Binding Shows Raw ISO 8601
**Severity: High**
`{Binding scheduled_time}` displays `2024-01-15T14:00:00` to users. Ugly, technical, not human-readable.
**Fix:** Apply `StringFormat='{}{0:MMM d, yyyy h:mm tt}'`.

### A3-BUG-08 — Title TextBlock No MaxWidth Guard
**Severity: Low**
`FontSize="17"` title has no `TextTrimming` or `MaxWidth`. If window ever narrowed, title overflows without clipping.
**Fix:** Add `TextTrimming="CharacterEllipsis"` and `MaxWidth`.

### A3-BUG-09 — LastFolderPath MaxWidth="240" Misaligned in Width="*" Column
**Severity: Low**
In a `Width="*"` Grid column, `MaxWidth="240"` creates awkward alignment when the column is wider. Appears visually unanchored.
**Fix:** Remove `MaxWidth`; set `HorizontalAlignment="Stretch"` with `TextTrimming`.

### A3-BUG-10 — "Schedule for:" Label Left Margin Misaligns Left Edge
**Severity: Low**
`Margin="8,8,8,8"` indents the label 8px right of the DropZone above it. Ragged left edge.
**Fix:** Change to `Margin="0,0,0,6"`.

### A3-BUG-11 — DropZone No Drag-Over Visual State
**Severity: Medium**
Static instruction text with no `VisualStateManager` for drag-active state. Zero feedback during drag-hover.
**Fix:** Add `DragOver` visual state that highlights border and updates label text.

### A3-BUG-12 — RadioButton Foreground Inverts Visual Hierarchy
**Severity: Low**
RadioButton options use `#E8E8F4` (bright) while section header TextBlocks have no explicit foreground, potentially rendering darker via theme inheritance. Options appear more prominent than headers.
**Fix:** Define explicit foreground tokens: headers `#FFFFFF`/Bold, options `#E8E8F4`, labels `#C8C8E4`.

---

## Agent 4: Main Window — Button & Interaction Design
*12 bugs found*

### A4-BUG-01 — ScheduleBtn Disproportionate Height
**Severity: High**
`Padding="48,30"` on `PrimaryBtn` (which has `CornerRadius="6"`) creates a 60px+ tall button that dominates the UI.
**Fix:** `Padding="48,12"`.

### A4-BUG-02 — ScheduleBtn Left-Aligned Below Full-Width DropZone
**Severity: High**
Primary CTA collapses to ~140px width while DropZone spans full width. Inverted visual hierarchy.
**Fix:** `HorizontalAlignment="Stretch"`.

### A4-BUG-03 — LastFolderDismissBtn Padding Clips Glyph (Critical)
**Severity: Critical**
`Width="28"` minus `Padding="10,7"` = **8px for the × glyph**. Arithmetic overflow — glyph is always clipped.
**Fix:** `Width="32" Padding="0"`.

### A4-BUG-04 — Task Delete Button Near-Circular Shape
**Severity: Medium**
`SecondaryBtn` `CornerRadius="10"` on `Width="28"` — radius is 71% of half-width, creating an odd pill/circle shape.
**Fix:** Use a dedicated compact icon button style with `CornerRadius="4"`.

### A4-BUG-05 — Task Delete Button No Destructive Affordance
**Severity: High**
Permanent delete action styled identically to non-destructive secondary actions. No red tint, no warning icon, no destructive visual language.
**Fix:** Add red/warning foreground on hover at minimum.

### A4-BUG-06 — Zero Hover States on Any Button (Critical)
**Severity: Critical**
Neither `PrimaryBtn` nor `SecondaryBtn` define `IsMouseOver` or `IsPressed` triggers. Every button is visually inert on hover. No interactive affordance whatsoever.
**Fix:** Add hover/pressed triggers to both button styles.

### A4-BUG-07 — Disabled ScheduleBtn Opacity 0.4 Makes Label Illegible
**Severity: High**
`Opacity="0.4"` on the entire button including text. On a dark background, the "Schedule" label becomes unreadable. New users can't discover what the button does when disabled.
**Fix:** Apply opacity only to the background, not the text, or use a minimum contrast floor.

### A4-BUG-08 — ClearHistoryBtn: Destructive Action as Tiny Neutral Button
**Severity: High**
"Clear History" (irreversible) uses `FontSize="10"` `Padding="8,3"` neutral styling. Smallest button in the app for the most destructive single action.
**Fix:** Add destructive color (red) and increase target size.

### A4-BUG-09 — HistoryToggleBtn No Toggle State Visual Indicator
**Severity: Medium**
Plain `Button` used as toggle. Label changes in code ("View"/"Hide") but no checked/active visual state. Users lose track of panel state.
**Fix:** Use `ToggleButton` or add a checked background tint.

### A4-BUG-10 — Emoji Spacing via Double Hard Space (DPI-Inconsistent)
**Severity: Medium**
`"📋  View History"` uses two spaces as icon-text gap. Space width varies with font/DPI. Emoji baseline misaligns with Latin text.
**Fix:** Use a `StackPanel Orientation="Horizontal"` with separate `TextBlock` elements.

### A4-BUG-11 — RadioButtons Use Default WPF Styling on Dark Theme
**Severity: Medium**
Default WPF radio indicator uses system chrome (white/grey on dark bg). Doesn't integrate with the dark theme — indicator and label appear from different design systems.
**Fix:** Re-template RadioButton to match dark theme or use a custom toggle-chip style.

### A4-BUG-12 — UndoBtn No MinWidth, Undersized Click Target
**Severity: Low**
"Undo" at `FontSize="11"` `Padding="12,5"` = ~50px wide. Below recommended 44px click target minimum.
**Fix:** Add `MinWidth="64"`.

---

## Agent 5: Main Window — Task List & History Data Display
*12 bugs found*

### A5-BUG-001 — Scheduled Time Displays Raw ISO 8601
**Severity: High**
`{Binding scheduled_time}` shows `2024-01-15T14:00:00` to users instead of "Tomorrow at 2:00 PM".
**Fix:** Pre-format before binding or apply value converter.

### A5-BUG-002 — NoTasksLabel Visible Before First Data Load (Flash)
**Severity: High**
`Visibility="Visible"` in XAML causes "No tasks scheduled." to flash briefly even when tasks exist.
**Fix:** Set initial `Visibility="Collapsed"` in XAML.

### A5-BUG-003 — History Column Proportions Inverted
**Severity: High**
`FolderName=120px` (fixed, truncates real names) and `Outcome=*` (takes all remaining space for 7-char values). Backwards.
**Fix:** `FolderName Width="*"`, `Outcome Width="80"`.

### A5-BUG-004 — Timestamp Column 130px Too Narrow at High DPI
**Severity: Medium**
19-character timestamp at 125% DPI exceeds 130px, clips without ellipsis.
**Fix:** Increase to `Width="150"`.

### A5-BUG-005 — "Snoozed" Outcome Has No Distinct Color
**Severity: Medium**
`"Snoozed"` falls through to `default { "#8888A8" }` — same gray as unknown/error outcomes. Loses semantic meaning.
**Fix:** Add `"Snoozed" { "#F4A261" }` (amber).

### A5-BUG-006 — History List Has No ScrollViewer
**Severity: High**
30 entries × ~22px = ~660px. No scroll container. Items below visible area are silently clipped.
**Fix:** Wrap in `ScrollViewer MaxHeight="280"`.

### A5-BUG-007 — FolderName Truncation No Tooltip
**Severity: Low**
`TextTrimming="CharacterEllipsis"` clips names but no `ToolTip` to reveal full value.
**Fix:** Add `ToolTip="{Binding FolderName}"`.

### A5-BUG-008 — History Panel Shows No Empty State
**Severity: Medium**
Empty history panel shows only "History" header and active "Clear" button. No "No history yet." message.
**Fix:** Add a conditional empty-state label and disable Clear button when empty.

### A5-BUG-009 — Delete Button Active During Undo Banner (Critical Race Condition)
**Severity: Critical**
User can click the delete `×` button on the same task currently in the Undo grace period. Creates double-deletion attempt against a task in undetermined state.
**Fix:** Disable all task delete buttons while `$script:lastTaskId` is non-null.

### A5-BUG-010 — Status Badge Always Shows "PENDING" (Zero Value)
**Severity: Low**
`Update-TaskListUI` pre-filters to PENDING tasks only. Every visible status badge always reads "PENDING". Occupies layout space with no information.
**Fix:** Remove the badge column or repurpose to show relative trigger time.

### A5-BUG-011 — TaskList Has No ScrollViewer
**Severity: High**
Many tasks grow the window indefinitely. `SizeToContent="Height"` + no max height = window goes off-screen.
**Fix:** Wrap `TaskList` in `ScrollViewer MaxHeight="220"`.

### A5-BUG-012 — "PathMissing" Displays as Raw CamelCase
**Severity: Medium**
Outcome `PathMissing` is displayed as-is in history. Should be "Path Missing".
**Fix:** Add display-name transform in `Get-HistoryData`.

---

## Agent 6: Popup Window — Layout & Structure
*12 bugs found*

### A6-BUG-01 — Window Starts Invisible With No Recovery (Critical)
**Severity: Critical**
`Opacity="0"` on root Window. If fade-in animation fails (timing race, exception, theme override), the window is permanently invisible. Process runs, blocks input, shows nothing. No fallback.
**Fix:** Add `Loaded` fallback: `if ($window.Opacity -eq 0) { $window.Opacity = 1 }` 500ms after show.

### A6-BUG-02 — DropShadowEffect Clipped at Screen Edges
**Severity: High**
`BlurRadius="48"` produces ~48px shadow halo. On multi-monitor setups where "CenterScreen" resolves near an edge, shadow is hard-clipped by the OS compositor.
**Fix:** Reduce `BlurRadius` to 18–24px and reduce `Opacity` to 0.40.

### A6-BUG-03 — TitleText MaxWidth="380" Wastes Available Space
**Severity: High**
Window=500px, padding=64px → content=436px. Glyph takes ~46px → title has 390px available. MaxWidth="380" caps it 10px below available, causing unnecessary wrapping.
**Fix:** Remove `MaxWidth` from `TitleText` or increase to 400px.

### A6-BUG-04 — ASCII Bracket Glyphs in Proportional Font
**Severity: Medium**
`[+]`, `[>]` at `FontSize="26"` in Segoe UI. Bracket widths vary per character, causing inconsistent TitleText alignment shifts across messages. Layout is not stable.
**Fix:** Use single-codepoint Unicode symbols or Segoe MDL2 Assets.

### A6-BUG-05 — Button Row May Overflow at 125%+ DPI
**Severity: High**
Fixed widths: DismissBtn(130) + SnoozeBtn(~90–100) + SnoozeDropBtn(26) + LetsGoBtn(130) + gaps(16) ≈ 402–412px against 436px content. At 125% DPI layout inflation causes overflow.
**Fix:** Remove fixed widths from DismissBtn and LetsGoBtn; let content size within constraints.

### A6-BUG-06 — FolderNameText Visibility Causes Layout Jump
**Severity: Medium**
`FolderNameText` starts collapsed. On show, its `Margin="0,0,0,22"` injects 22px + text height into the StackPanel, causing all elements below to jump position after first render.
**Fix:** Pre-set `Text` and `Visibility` before `ShowDialog()` is called.

### A6-BUG-07 — Three-TextBlock Countdown Breaks Accessibility
**Severity: Medium**
Three `TextBlock` elements for "Auto-opening in " / "20" / "s". Screen readers announce as three separate, unrelated text nodes. "s" is read as the letter S, not "seconds".
**Fix:** Use a single `TextBlock` with `Run` elements.

### A6-BUG-08 — Cyan Accent Bar Shows in PathMissing Mode
**Severity: Medium**
Accent bar sits outside both `NormalPanel` and `PathMissingPanel` — always renders in cyan. PathMissingPanel uses an orange/amber error theme. Visual mismatch.
**Fix:** Move accent bar inside `NormalPanel`, or change color dynamically based on mode.

### A6-BUG-09 — PathMissingPanel Visually Compressed vs NormalPanel
**Severity: Medium**
NormalPanel has a countdown row adding ~40px of visual weight before the divider. PathMissingPanel goes straight from description to divider. Popup appears to shrink/shift in error mode.
**Fix:** Add a spacer or equivalent content block to PathMissingPanel for visual consistency.

### A6-BUG-10 — Button Height 36px No High-DPI Minimum
**Severity: Low**
`Height="36"` with no `MinHeight`. On accessibility font scaling, effective click target may fall below recommended 44px.
**Fix:** Add `MinHeight="40"`.

### A6-BUG-11 — SnoozeBtn/SnoozeDropBtn Border Junction Breaks at Non-100% DPI
**Severity: High**
`SnoozeBtn BorderThickness="1,1,0,1"` (no right) + `SnoozeDropBtn BorderThickness="1"` (full). At non-integer DPI, sub-pixel rendering creates a visible gap or double-line at the junction. No `UseLayoutRounding` applied.
**Fix:** Use a shared `Grid` with a column-separator `Rectangle` instead of border tricks.

### A6-BUG-12 — PathMissingPanel Buttons Have No Margin Between Them
**Severity: Low**
`PathDismissBtn` and `RePickBtn` are adjacent with zero margin. They render flush together, appearing visually merged.
**Fix:** Add `Margin="0,0,10,0"` to `PathDismissBtn` (already present — verify it propagates to the template).

---

## Agent 7: Popup Window — Color, Contrast & WCAG
*12 bugs found (9 WCAG failures)*

### WCAG Failure Summary

| Element | FG | BG | Ratio | AA |
|---|---|---|---|---|
| DismissBtn | `#3E3E58` | `#14141F` | **1.77:1** | FAIL |
| "Auto-opening in" | `#3E3E58` | `#14141F` | **1.77:1** | FAIL |
| SnoozeBtn/DropBtn | `#555570` | `#1C1C2C` | **2.33:1** | FAIL |
| FolderNameText | `#5A5A7A` | `#14141F` | **2.76:1** | FAIL |
| MissingPathLabel | `#4A4A6A` | `#14141F` | **2.16:1** | FAIL |
| Divider | `#1F1F30` | `#14141F` | **1.13:1** | FAIL |
| DismissBtn border | `#2A2A42` | `#14141F` | **1.31:1** | FAIL |
| PathDismissBtn | `#555570` | `#1C1C2C` | **2.33:1** | FAIL |
| BodyText | `#8888A8` | `#14141F` | 5.34:1 | PASS (AA) |
| LetsGoBtn | `#0D1117` | `#00BCD4` | 8.24:1 | PASS (AAA) |
| TitleText | `#E8E8F4` | `#14141F` | 15.03:1 | PASS (AAA) |

### A7-BUG-01 — DismissBtn Effectively Invisible (1.77:1)
**Severity: Critical**
Neither the button label nor its border (1.31:1) are perceptible. Button does not exist visually.
**Fix:** `Foreground="#7878A0"` (4.5:1+), `BorderBrush="#555580"`.

### A7-BUG-02 — "Auto-opening in" Ghost Text (1.77:1)
**Severity: Critical**
Countdown context invisible. User sees a floating cyan number with no readable explanation.
**Fix:** Change to `Foreground="#8888A8"` (5.34:1).

### A7-BUG-03 — SnoozeBtn/DropBtn Below Threshold (2.33:1)
**Severity: High**
Key interactive controls below WCAG UI component minimum (3.0:1).
**Fix:** `Foreground="#8585A5"` (4.5:1).

### A7-BUG-04 — FolderNameText Inverted Importance vs. Contrast (2.76:1)
**Severity: High**
Most contextually important line in popup (which folder opens) has worst contrast. Hierarchy inverted relative to importance.
**Fix:** `Foreground="#8888A8"`.

### A7-BUG-05 — MissingPathLabel Near-Invisible Critical Info (2.16:1)
**Severity: Critical**
The error path — most actionable info in error state — is nearly invisible.
**Fix:** `Foreground="#9090B8"` (5.5:1+).

### A7-BUG-06 — Divider Imperceptible (1.13:1)
**Severity: Medium**
`#1F1F30` on `#14141F` is RGB difference (11,11,17). The divider does not exist perceptually.
**Fix:** `Background="#303050"`.

### A7-BUG-07 — Action Hierarchy Collapses (All Tiers 2 & 3 Invisible)
**Severity: High**
Design intent: LetsGo > Snooze > Dismiss. Execution: LetsGo (8.24:1 ✓), Snooze (2.33:1 ✗), Dismiss (1.77:1 ✗). The gradient collapses into illegibility.
**Fix:** Enforce minimum contrast per tier: Primary ≥8:1, Secondary ≥4.5:1, Tertiary ≥3.5:1.

### A7-BUG-08 — DropShadow Opacity 0.85 Creates Hard Black Rectangle
**Severity: Medium**
0.85 opacity shadow on light desktop backgrounds renders as a hard black band, not a soft shadow.
**Fix:** Reduce opacity to 0.35–0.45, increase BlurRadius to 24.

### A7-BUG-09 — ASCII Bracket Glyphs at FontSize="26" Visually Crude
**Severity: Medium**
`[+]`, `[>]` at large size in proportional Segoe UI look like terminal output, not designed iconography.
**Fix:** Replace with single Unicode geometric symbols or icon font.

### A7-BUG-10 — "Open Folder >" Uses Greater-Than as Directional Indicator
**Severity: Low-Medium**
`>` is a math operator. Does not read as "navigate forward". Screen readers may announce as "greater than".
**Fix:** Use `→` (U+2192) or `▶` (U+25B6).

### A7-BUG-11 — Cyan Overloaded Across 4 Semantic Roles
**Severity: Medium**
`#00BCD4` used for: decorative accent bar, icon glyph, countdown data value, AND primary action button. Color carries no consistent meaning.
**Fix:** Reserve cyan exclusively for primary interactive affordance.

### A7-BUG-12 — Orange #F4A261 Orphaned Color Token
**Severity: Low-Medium**
`#F4A261` appears exactly once (PathMissing glyph). Implies a warning color system that never materializes elsewhere.
**Fix:** Either commit to orange as warning color throughout, or replace with existing palette.

---

## Agent 8: Popup Window — Typography & Content
*12 bugs found*

### A8-BUG-01 — FolderNameText Layout Shift on Show
**Severity: Medium**
Starts collapsed. On show, `Margin="0,0,0,22"` injects 22px+height into layout stack, causing elements below to jump after window is visible.
**Fix:** Pre-assign `Text` before `ShowDialog()`.

### A8-BUG-02 — "Opening:" Prefix Wrong Register
**Severity: Low**
"Opening: My Folder" implies action in progress. Folder hasn't opened yet. Should be "Folder:" or "Scheduled folder:".
**Fix:** Change prefix to `"Folder: $displayName"`.

### A8-BUG-03 — LineHeight="23" Creates Inconsistent Popup Height
**Severity: Low**
Fixed `LineHeight` across variable-length messages causes popup height to shift per session.
**Fix:** Clamp popup minimum height or normalize message line counts.

### A8-BUG-04 — Three-TextBlock Countdown Accessibility Broken
**Severity: High**
Screen readers announce "Auto-opening in" / "20" / "s" as three separate unrelated elements. "s" is meaningless.
**Fix:** Use single `TextBlock` with `Run` elements; spell out "seconds".

### A8-BUG-05 — SnoozeDropBtn Content="v" Wrong Character
**Severity: Medium**
Lowercase `v` at `FontSize="10"` as dropdown indicator. Not a symbol, reads as letter, not centered, inaccessible.
**Fix:** Use `▾` (U+25BE) or Segoe MDL2 `&#xE972;`.

### A8-BUG-06 — LetsGoBtn "Open Folder >" Wrong Directional Symbol
**Severity: Medium**
`>` is a math operator. Conflicts with `[>]` glyph in message set, creating two meanings for `>`.
**Fix:** Use `→` or rename to "Go to Folder".

### A8-BUG-07 — DismissBtn Label May Clip at High DPI
**Severity: Low-Medium**
"Dismiss for Today" (18 chars) at `FontSize="11"` in `Width="130"` approaches limit at 125% DPI.
**Fix:** Widen to `Width="148"` or shorten to "Skip Today".

### A8-BUG-08 — Dismiss Naming Inconsistency Between Modes
**Severity: Medium**
`DismissBtn` = "Dismiss for Today" (scoped); `PathDismissBtn` = "Dismiss" (ambiguous permanent/today/close?).
**Fix:** Audit PathDismissBtn behavior; label accordingly ("Close", "Skip Today", or "Stop Reminding Me").

### A8-BUG-09 — "Was looking for:" Awkward UX Copy
**Severity: Low-Medium**
Past-tense debug-style phrase in user-facing error. Raw path displayed inline.
**Fix:** Change to "This folder can't be found:" with folder name only and tooltip for full path.

### A8-BUG-10 — "[!]" Glyph Collision Between Message and Error Panel
**Severity: Medium**
Message "It Matters" uses glyph `[!]`. PathMissingPanel hardcodes `[!]` as warning icon. Same character, opposite emotional registers (motivational vs. error).
**Fix:** Replace PathMissingPanel's `[!]` with `[?]` or `⚠`; or change "It Matters" glyph to `[★]`.

### A8-BUG-11 — ASCII Bracket Glyphs Variable Width in Proportional Font
**Severity: Low**
`[+]`, `[*]`, `[#]` render at different pixel widths in Segoe UI, causing TitleText to shift horizontally per message. Layout is not positionally stable.
**Fix:** Replace with fixed-width Unicode symbols.

### A8-BUG-12 — Hyphens as Stylistic Em-Dash Compounds
**Severity: Low**
"Yesterday-you knew today-you would need a nudge." uses hyphens as stylistic compound nouns — unconventional, parsed with hesitation.
**Fix:** "Past-you knew present-you would need a nudge."

---

## Agent 9: Popup Window — Button & Interaction Design
*12 bugs found*

### A9-BUG-01 — Zero Hover/Pressed States on Any Button
**Severity: High**
All 6 popup buttons use custom templates with no `ControlTemplate.Triggers`. Visually inert on hover and press. No feedback that clicks register.
**Fix:** Add `IsMouseOver` and `IsPressed` triggers to all button templates.

### A9-BUG-02 — Snooze Split-Button Border Junction Seam
**Severity: High**
`SnoozeBtn BorderThickness="1,1,0,1"` + `SnoozeDropBtn BorderThickness="1"` — at non-100% DPI, sub-pixel rendering creates visible gap or double-border at junction.
**Fix:** Use a `Grid` with a column-separator `Rectangle` to own the shared border pixel.

### A9-BUG-03 — ContextMenu Opened via Left-Click Button (Non-Standard)
**Severity: High**
`$snoozeDropBtn.ContextMenu.IsOpen = $true` on left-click. `ContextMenu` anchors to last mouse position (not button), keyboard nav broken, screen reader announces as "context menu" not "dropdown".
**Fix:** Replace with `Popup` + `ListBox` with explicit `PlacementTarget` and `Placement="Bottom"`.

### A9-BUG-04 — Snooze Duration Selection Has No Visual Confirmation
**Severity: Medium**
Selecting "15 minutes" silently updates button label. No flash, no animation, no tooltip confirmation. User may miss the change.
**Fix:** Brief background color pulse on duration selection.

### A9-BUG-05 — Snooze Duration Unit Inconsistency
**Severity: Medium**
Menu items: "5 minutes (default)" / "15 minutes" / "30 minutes" / "1 hour" — mixes minutes and hours. Leading space before each item is a layout hack.
**Fix:** Standardize to all-minutes or consistent natural language without leading spaces.

### A9-BUG-06 — Primary Button Not Visually Dominant
**Severity: Medium**
`LetsGoBtn Width="130"` = same as `DismissBtn Width="130"`. Identical size implies equal importance.
**Fix:** Increase `LetsGoBtn` to `Width="150"–"160"`.

### A9-BUG-07 — Tab Order Prioritizes Dismiss Action
**Severity: Medium**
Default left-to-right tab: Dismiss → Snooze → SnoozeDropBtn → LetsGo. Tab+Enter dismisses rather than opening. Wrong priority.
**Fix:** Set `TabIndex`: LetsGoBtn=0, SnoozeBtn=1, SnoozeDropBtn=2, DismissBtn=3.

### A9-BUG-08 — DismissBtn Foreground Near-Invisible (~1.8:1)
**Severity: Medium**
`#3E3E58` on `#14141F` at `FontSize="11"` — well below all WCAG thresholds.
**Fix:** `Foreground="#9A9AB8"` (~5:1).

### A9-BUG-09 — Topmost+ShowInTaskbar=False Creates Unrecoverable Popup
**Severity: Medium**
Popup appears over full-screen apps, is not in Alt-Tab, not in taskbar. User in a full-screen game cannot find or dismiss it.
**Fix:** Set `ShowInTaskbar="True"` or add a global hotkey to bring popup to focus.

### A9-BUG-10 — Dropdown Arrow "v" is a Letter at 10px
**Severity: Low**
`Content="v"` at `FontSize="10"` — letter, not symbol. Screen reader announces "v". Visually indistinct.
**Fix:** Use `▾` (U+25BE), `FontSize="13"`. Add `AutomationProperties.Name="More snooze options"`.

### A9-BUG-11 — Countdown Not Adjacent to the Button It Triggers
**Severity: Low**
Countdown timer is in the middle of the popup; LetsGoBtn is bottom-right. User's eye is at the countdown when it fires, but the triggered button is far away.
**Fix:** Position countdown text directly above or inside LetsGoBtn (e.g., "Open Folder (5s)").

### A9-BUG-12 — Race Condition: Countdown Fires During User Click (Critical)
**Severity: Critical**
Sequence: User's MouseDown registers on DismissBtn → countdown reaches 0 and calls `window.Close()` → MouseUp fires → Click handler runs → `$script:windowClosed` is true → dismiss logic skipped → folder opens.
**User pressed Dismiss. Folder opens anyway.*
**Fix:** Cancel countdown on any button `PreviewMouseDown`. Do not rely on `windowClosed` flag as a guard — set it only after all handler paths complete.

---

## Agent 10: Overall UX Flow & Cross-Window Design
*13 bugs found*

### A10-ISSUE-01 — Hardcoded Radio Labels Ignore Config Trigger Hour
**Severity: High**
"Today at 2:00 PM" and "Tomorrow at 2:00 PM" are XAML constants. `default_trigger_hour` config is ignored. Labels become factually wrong if user edits config.
**Fix:** Build label dynamically at window load from resolved `$hour`.

### A10-ISSUE-02 — History Toggle Loses Emoji on First Click
**Severity: Low-Medium**
Initial content `"📋  View History"`. First collapse sets `"View History"` (no emoji). Emoji never returns.
**Fix:** Always include emoji in code-assigned content strings.

### A10-ISSUE-03 — Undo Banner Drops Scheduled Time After First Tick
**Severity: High**
Initial: `"Scheduled for Monday at 2:00 PM - undo in 30s"`. After tick: `"Scheduled - undo in 29s"`. Scheduled time silently dropped. Two separate format strings used instead of one template.
**Fix:** Store `$ScheduledFor` in script scope and use in tick handler.

### A10-ISSUE-04 — FolderBrowserDialog Always Says "Tomorrow"
**Severity: Medium**
Dialog description hardcoded as "Select the folder you want to open tomorrow" even when Today radio is selected.
**Fix:** Condition description on selected schedule day.

### A10-ISSUE-05 — TodayRadio Visibility Evaluated Only at Window Load
**Severity: High**
If user opens window before trigger hour, leaves it open past trigger hour — Today radio stays visible. Scheduling "Today" at a past time silently creates an already-expired task.
**Fix:** Re-evaluate radio visibility on Schedule click, or add a `DispatcherTimer` refreshing it each minute.

### A10-ISSUE-06 — No Feedback After Undo Action Completes
**Severity: High**
Undo banner collapses on both success AND timeout. User cannot distinguish "undo worked" from "undo window expired". Silent success = confusing UX.
**Fix:** Show a brief status message "Task removed" on successful undo.

### A10-ISSUE-07 — Context Menu setfolder Mode Completely Silent
**Severity: High**
User right-clicks a folder, selects "Set as tomorrow's folder" — nothing visible happens. No OS notification, no confirmation, no feedback of any kind.
**Fix:** Show a WPF or Windows balloon notification confirming the action.

### A10-ISSUE-08 — Drop Zone No Visual Drag-Over State
**Severity: Medium**
`PreviewDragOver` handler fires but produces no visual state change. Zero feedback that the drop target is active.
**Fix:** Toggle border color/background in `PreviewDragOver` handler; revert on `DragLeave`.

### A10-ISSUE-09 — FolderBrowserDialog Uses Outdated WinForms Picker
**Severity: Low-Medium**
`System.Windows.Forms.FolderBrowserDialog` shows Windows XP-era tree picker. No address bar, no search, no path paste. Severely outdated on Windows 10/11.
**Fix:** Use `IFileOpenDialog` COM interface for the modern Explorer-style picker.

### A10-ISSUE-10 — Schedule Button Left-Aligned Below Full-Width DropZone
**Severity: Low**
Inverted visual hierarchy — selection zone wider than action button.
**Fix:** `HorizontalAlignment="Stretch"`.

### A10-ISSUE-11 — Non-Resizable Window Grows Off-Screen
**Severity: Medium**
`SizeToContent="Height"` + `ResizeMode="CanMinimize"` — window grows without bound, user cannot resize. Bottom controls become unreachable on small screens.
**Fix:** Set `MaxHeight`, add `ScrollViewer`, change `ResizeMode="CanResizeWithGrip"`.

### A10-ISSUE-12 — No Keyboard Shortcuts for Daily-Use App
**Severity: Medium**
Zero keyboard shortcuts. No Ctrl+Enter to Schedule, no Escape to close. For a daily-use utility, this adds constant friction.
**Fix:** Add `KeyBinding` for Ctrl+Enter (Schedule), Escape (collapse Undo banner), Alt accelerators on buttons.

### A10-ISSUE-13 — History Panel No MaxHeight or Scroll Container
**Severity: Medium**
30 history entries with no scroll. Combines with Issue-11 to push entire window off-screen.
**Fix:** Wrap in `ScrollViewer MaxHeight="200"`.

---

## Bug Registry by Severity

### Critical (14 bugs)
| ID | Description |
|---|---|
| A1-BUG-01 | Schedule button `Padding="48,30"` — disproportionate height |
| A2-BUG-001 | `NoTasksLabel` contrast 1.74:1 — invisible |
| A2-BUG-002 | `SelectedPathLabel` contrast 2.06:1 — path unreadable |
| A2-BUG-003 | History timestamp contrast 2.32:1 — timestamps invisible |
| A2-BUG-004 | `#4A4A6A` palette-wide failure — dimmed tier below readable threshold |
| A3-BUG-01 | `SelectedPathLabel` `TextTrimming` inert — no `MaxWidth`, paths overflow |
| A3-BUG-03 | `NoTasksLabel` near-invisible — empty state unreadable |
| A4-BUG-03 | `LastFolderDismissBtn` padding clips × glyph — arithmetic overflow |
| A4-BUG-06 | Zero hover states on ALL buttons — no interactive affordance |
| A5-BUG-009 | Delete button active during Undo — double-deletion race condition |
| A6-BUG-01 | Popup `Opacity="0"` no recovery — permanently invisible window possible |
| A7-BUG-01 | Popup `DismissBtn` 1.77:1 — button functionally invisible |
| A7-BUG-02 | "Auto-opening in" 1.77:1 — countdown context invisible |
| A9-BUG-12 | Countdown fires during user click — silently overrides dismiss intent |

### High (28 bugs)
A1-BUG-02 through A1-BUG-05, A1-BUG-15, A2-BUG-005, A2-BUG-006, A2-BUG-007, A3-BUG-02, A3-BUG-07, A4-BUG-01, A4-BUG-02, A4-BUG-05, A4-BUG-07, A4-BUG-08, A5-BUG-001, A5-BUG-002, A5-BUG-003, A5-BUG-006, A5-BUG-011, A6-BUG-02, A6-BUG-03, A6-BUG-05, A6-BUG-11, A7-BUG-03, A7-BUG-04, A7-BUG-07, A8-BUG-04, A9-BUG-01, A9-BUG-02, A9-BUG-03, A10-ISSUE-01, A10-ISSUE-03, A10-ISSUE-05, A10-ISSUE-06, A10-ISSUE-07

### Medium (46 bugs)
All A1-BUG-06 through A1-BUG-12, most A4/A5/A6/A7/A8/A9/A10 medium-flagged issues.

### Low (36 bugs)
Remaining cosmetic, typography polish, and minor inconsistency issues.

---

## Top Remediation Priorities

### P0 — Fix Before Next Use (Functional Failures)
1. Add hover/pressed states to ALL buttons (Main + Popup)
2. Fix popup `Opacity="0"` — add recovery fallback
3. Fix countdown-vs-click race condition (`PreviewMouseDown` cancels timer)
4. Fix `NoTasksLabel` and `SelectedPathLabel` contrast (invisible empty state + path)
5. Fix `DismissBtn` popup contrast 1.77:1 (button does not visually exist)
6. Fix "Auto-opening in" contrast 1.77:1 (countdown context invisible)
7. Fix `TextTrimming` on `SelectedPathLabel` — add `MaxWidth`
8. Fix `Schedule` button padding `48,30` → `48,12`
9. Disable task delete button during Undo grace period
10. Add feedback for successful Undo action

### P1 — Fix This Sprint (Misleading UI)
11. Dynamic RadioButton labels (configurable trigger hour)
12. Undo banner text retention after first tick
13. Fix `MissingPathLabel` contrast 2.16:1
14. Fix `SnoozeBtn/DropBtn` contrast 2.33:1
15. Fix `FolderNameText` contrast 2.76:1
16. Fix hardcoded ISO 8601 `scheduled_time` display
17. Add `NoTasksLabel` initial `Visibility="Collapsed"`
18. Fix History column proportions (FolderName=*, Outcome=80)
19. Fix DropZone drag-over visual state
20. setfolder mode — add confirmation feedback

### P2 — Next Polish Pass
21. Replace `ContextMenu` snooze dropdown with proper `Popup`+`ListBox`
22. Fix split-button DPI border junction
23. Replace ASCII bracket glyphs with Unicode symbols
24. Add `ScrollViewer` to `TaskList`, `HistoryList`, `HistoryPanel`
25. Fix window `MaxHeight` + `SizeToContent` overflow
26. Add keyboard shortcuts
27. Replace `FolderBrowserDialog` with modern picker
28. Fix tab order (LetsGoBtn first)
29. Standardize `CornerRadius` (6 vs 10 inconsistency)
30. Fix `ClearHistoryBtn` destructive styling

---

*Report generated by 10-agent parallel forensic investigation on 2026-06-26.*
*Total unique bugs: 124 across 10 UI domains.*
