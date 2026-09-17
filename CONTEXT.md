# Daily Motivation Brain Helper

A Windows desktop utility that fires a motivational popup at a scheduled time,
opening a chosen folder in Explorer to launch a focused work session.

## Language

### The app and its parts

**App**:
The compiled artifact `DailyMotivation.exe` - the thing end users run. When
describing what a user interacts with, use App, not "script" or "tool".
_Avoid_: Tool, Script, Program, Utility

**Script**:
The source file `DailyMotivation.ps1` - the single file that compiles into the
App. Use Script when talking about source-level concerns (sections, functions,
dot-sourcing, building).
_Avoid_: Source file, Entry point

**Exe**:
The compiled artifact on disk (`DailyMotivation.exe`). Distinct from the App in
contexts where the binary path matters (Task Scheduler action, ps2exe output).
_Avoid_: Binary, Compiled script

---

### Execution modes

**Mode**:
One of four execution contexts the Script enters depending on its `$Mode`
parameter: `"main"` (default), `"/popup"`, `"/setfolder"`, or `"/uninstall"`.
When the compiled Exe is invoked from the command line (e.g.
`DailyMotivation.exe /popup`), ps2exe binds the positional argument to `$Mode`,
so the value includes the leading slash. The switch statement matches on
`"/popup"`, `"/setfolder"`, and `"/uninstall"`; any other value (including the
bare default `"main"`) falls through to `Show-MainWindow`. Every function call
happens inside exactly one Mode.
_Avoid_: Invocation type, Run context, Entry path

**main mode**:
Default Mode. Entered when `$Mode` is anything other than `"/popup"`,
`"/setfolder"`, or `"/uninstall"`. Shows the Main Window - folder picker and
task scheduler UI. Implemented by `Show-MainWindow` (~700 LOC).
_Avoid_: Normal mode, UI mode, Interactive mode

**popup mode**:
Triggered by Windows Task Scheduler via `DailyMotivation.exe /popup`. The
`$Mode` parameter equals `"/popup"`. Shows the Popup Window. Never launched by
the user directly. Implemented by `Show-PopupWindow` (~600 LOC).
_Avoid_: Notification mode, Reminder mode, Scheduled run

**setfolder mode**:
Invoked by the Context Menu Verb via `DailyMotivation.exe /setfolder "C:\path"`.
The `$Mode` parameter equals `"/setfolder"`. Creates a new MotivationTask
scheduled for tomorrow at the default trigger hour, writes the PopupConfig,
shows a confirmation MessageBox, then exits.
_Avoid_: Right-click mode, Context mode, Folder-set mode

**uninstall mode**:
Invoked via `DailyMotivation.exe /uninstall`. The `$Mode` parameter equals
`"/uninstall"`. Removes the Context Menu Verb registry key via
Unregister-ContextMenu and shows a confirmation MessageBox, then exits.
CLI-only - no other Mode, MotivationTask, or Context Menu Verb invokes it;
it is reached solely by a user typing the command directly. Despite the
name, it does not remove tasks.json, AppData, config, or the exe itself -
it unregisters the context menu entry only.
_Avoid_: Removal mode, Cleanup mode, Full uninstall (it is not one)

---

### The user's folder

**Selected Folder**:
The directory path the user has chosen (via picker, drag-drop, or Context Menu)
to open at trigger time. Not yet scheduled until the user clicks Schedule.
_Avoid_: Working directory, Project folder, Target path

**FolderPath**:
The fully-qualified string path stored on a MotivationTask and in the
PopupConfig. Always stored as-typed, case-insensitive for comparison.
_Avoid_: Directory, Path, Target

**FolderName**:
The leaf component of a FolderPath (`Split-Path -Leaf`). Used for display only.
For UNC roots (`\\server\share` with no sub-path), FolderPath is used as the
display name instead.
_Avoid_: Directory name, Short name, Label

---

### Scheduling

**MotivationTask**:
The primary domain entity. Represents one scheduled folder-opening reminder.
Has a unique TaskId, a FolderPath, a TriggerTime, a Status, and a SnoozeCount.
Persisted to `tasks.json`.
_Avoid_: Reminder, Entry, Item, Job, Appointment

**TaskId**:
A 16-character random hex string that uniquely identifies a MotivationTask.
Used as the key for Task Scheduler's task name and for Outcome Log entries.
A MotivationTask record without a TaskId is invalid and excluded from all
operations.
_Avoid_: ID, GUID, Identifier, Task name

**TriggerTime**:
The datetime at which Task Scheduler fires the popup for a MotivationTask. Stored
as ISO 8601 (`scheduled_time` field); invalid stored values are silently skipped
during duplicate detection. TriggerTime is Local time - a task scheduled at 14:00
fires at 14:00 by the user's local clock, not UTC.
_Avoid_: Scheduled time, Fire time, Run time, Alarm time, Execution time

**Schedule** (verb):
The user action of creating a MotivationTask. Involves: picking a folder,
choosing Today or Tomorrow, clicking the Schedule button. Results in a
MotivationTask being written to `tasks.json` and an OS Task being registered.
_Avoid_: Create, Set, Add, Register a reminder

**OS Task**:
The Windows Task Scheduler entry registered for a MotivationTask. Named
`DailyMotivation_{TaskId}`. Distinct from the MotivationTask record itself.
_Avoid_: Scheduled task (ambiguous), Windows task, Cron job

**Duplicate**:
A PENDING MotivationTask that has the same FolderPath (case-insensitive) and same
calendar date as another existing PENDING MotivationTask. Blocked by default;
allowed via the `-Force` flag.
_Avoid_: Conflict, Clash, Double-booking, Collision

**Force Schedule**:
Creating a MotivationTask despite a Duplicate being detected. Code-level concept
only; the UI shows "Already Scheduled" and asks "Schedule again anyway?" before
passing `-Force` to the scheduling function.
_Avoid_: Override, Bypass duplicate check

**tasks.json**:
The persistence file for all MotivationTask records, stored in AppData Dir. The
canonical source of truth for each task's TaskId, FolderPath, TriggerTime,
Status, and SnoozeCount across sessions.
_Avoid_: Task file, Task database

**New-MotivationTask**:
The function that implements the Schedule verb. Writes a MotivationTask record
to `tasks.json`, registers an OS Task in Windows Task Scheduler, and handles
Duplicate detection. The single authoritative entry point for creating any
MotivationTask.
_Avoid_: Create task, Register task, Add task

**TaskId collision retry**:
The internal loop inside `New-MotivationTask` that detects an OS-layer name
clash — an existing OS Task already named `DailyMotivation_{TaskId}` — and
retries with a freshly generated TaskId, up to a fixed attempt limit. Distinct
from **Duplicate** detection, which is a domain-level check on FolderPath and
date. A TaskId collision is an OS scheduler namespace conflict; a Duplicate is
a scheduling intent conflict.
_Avoid_: Retry loop, Deduplication loop, Collision (when describing Duplicate)

**Status**:
The lifecycle state of a MotivationTask. At runtime only `PENDING` (created, not
yet triggered) and `DELETED` (OS Task missing or removed at reconciliation time)
are assigned. `COMPLETED` and `FAILED` are reserved for future use and are never
set by current code. Values outside the canonical set are normalized to `UNKNOWN`
and immediately discarded at load time - UNKNOWN records are excluded from all
operations including the Task List, Duplicate detection, Snooze, and Remove. Only
tasks created by the App carry a valid Status.
_Avoid_: State, Phase, Flag

**Network Path**:
A FolderPath that begins with `\\` (UNC) or is a mapped drive. Scheduled
normally, but a warning dialog is shown in the Main Window immediately after
scheduling to alert the user the path may be unreachable at trigger time. The
warning is shown only in main mode; setfolder mode does not display a Network
Path warning.
_Avoid_: Remote path, UNC path (UNC is a sub-type, not a synonym)

**Today / Tomorrow Selector**:
The RadioButton group in main mode that determines the calendar date of a
MotivationTask's TriggerTime. "Today" fires at the default trigger hour on the
current day; "Tomorrow" fires at the default trigger hour the following day. The
Today option is hidden after the default trigger hour passes on the current day.
_Avoid_: Date picker, Time picker, Toggle

**Task List**:
The scrollable panel in main mode displaying all valid, non-DELETED MotivationTasks
with their FolderNames, scheduled TriggerTimes, and Statuses. Only tasks created by
the App appear; records with UNKNOWN status are discarded at the data layer before
reaching the Task List. The primary surface for viewing and removing pending
reminders.
_Avoid_: Task view, Task panel, Reminder list

**History Panel**:
The collapsible section in main mode displaying the most recent 30 entries from
the Outcome Log, showing timestamps, FolderNames, and Outcomes. Toggled via a
"View History" / "Hide History" button.
_Avoid_: Log viewer, Activity panel, Recent activity

---

### The popup lifecycle

**Popup**:
The notification window shown in popup mode. Contains a Message, the FolderName,
a Countdown timer, and three action buttons: Open Folder, Snooze, Dismiss.
_Avoid_: Notification, Alert, Toast, Window (too generic)

**Message**:
A motivational content unit with three fields: Glyph, Title, Body. Selected
randomly from the Messages array at Schedule time and frozen in the PopupConfig.
_Avoid_: Notification message, Content, Prompt, Quote

**Glyph**:
A three-character ASCII bracket icon in the format `[X]` (e.g. `[+]`, `[!]`,
`[~]`). The format is: opening bracket, one character, closing bracket.
_Avoid_: Icon, Badge, Emoji, Symbol

**Countdown**:
A 20-second auto-open timer shown in the Popup. When it reaches zero, the App
behaves as if the user clicked Open Folder.
_Avoid_: Auto-open timer, Timer, Clock

**Pause**:
A Countdown pause/resume toggle in the Popup. The button label alternates between
"Pause" (timer running) and "Resume" (timer stopped). Available only in the
normal Popup state, not when Path Missing is displayed. Paused state is not
preserved across a Snooze.
_Avoid_: Freeze, Halt, Stop

**Open Folder** (primary Popup action):
The primary Popup action. UI label is `Open Folder →` on button `LetsGoBtn`.
Opens Explorer at the FolderPath, writes `Opened` to the Outcome Log, and closes
the Popup. Historical domain name "Let's Go" refers to the same action - prefer
**Open Folder** in new writing to match the UI.
_Avoid_: Let's Go (legacy term), Confirm, Go button, Launch

**Snooze**:
Creates a new MotivationTask scheduled N minutes in the future (5, 15, 30, or 60),
replacing the original after the Popup closes. Increments the SnoozeCount. Not
available in Path Missing state. Requires the originating MotivationTask to still
be PENDING at the time of execution; if it has been removed, no replacement task
is created.
_Avoid_: Delay, Postpone, Defer, Remind me later

**Dismiss**:
The "Dismiss for Today" Popup action. Removes all PENDING MotivationTasks whose
FolderPath matches the current popup's folder. Writes `Dismissed` to the Outcome
Log and closes the Popup without opening Explorer. Scoped to the Popup only - 
the dismiss button on the last-folder banner in the Main Window
(`LastFolderDismissBtn`) hides the banner only and does not remove any
MotivationTask or write to the Outcome Log.
_Avoid_: Cancel, Close, Ignore, Skip

**Re-Pick Folder** (Popup action):
The "Choose new location" action available in the path-missing panel. Opens a
folder picker allowing the user to substitute a new FolderPath for the current
popup session. Updates the PopupConfig with the new path, opens Explorer at the
new location, and closes the Popup. Writes `Opened` to the Outcome Log - not
`PathMissing`.
_Avoid_: Browse, Change path, Select folder, Retry

**Outcome**:
What the user did when the Popup appeared. One of: `Opened`, `Snoozed`,
`Dismissed`, or `PathMissing`. Written pipe-delimited to the Outcome Log.
`PathMissing` is written when the FolderPath no longer exists and the user
closes the Popup without re-picking a folder.
_Avoid_: Result, Action, Response, Decision

**SnoozeCount**:
A popup-session counter tracked in `$script:snoozeCount` and written to the
Outcome Log entry. Counts how many times the user Snoozed during a single popup
session. The `snooze_count` field on the persisted MotivationTask record is
always `0` - it is initialised at creation and never updated thereafter.
_Avoid_: Snooze number, Delay count

**Path Missing**:
The error state when the FolderPath stored in the PopupConfig no longer exists on
disk at the time the Popup appears. Detected at trigger time only - scheduling
always succeeds regardless of path availability at Schedule time. Shows the
path-missing panel instead of normal Popup content. The user can close the Popup
(logging `PathMissing` as the Outcome) or use **Re-Pick Folder** to substitute a
new path (logging `Opened` instead).
_Avoid_: Folder not found, Missing folder, Invalid path

---

### The handoff between modes

**PopupConfig**:
The JSON file (`popup_config.json`) written by main mode or setfolder mode and
read exclusively by popup mode. It is the sole data channel between modes.
Primary keys: `glyph`, `title`, `body`, `explorer_path` (folder path),
`folder_name`, `task_id`. `Set-PopupConfig` also writes compatibility aliases
`folder_path` (same as `explorer_path`) and `message_glyph` / `message_title` /
`message_body` (same as glyph/title/body). Prefer `explorer_path` when reading.
_Avoid_: Popup settings, Shared state, Config (ambiguous - see AppConfig)

**Handoff**:
The write-then-read cycle of the PopupConfig. main mode or setfolder mode writes
it at Schedule time; popup mode reads it at trigger time.
_Avoid_: Data pass, State share, IPC

**AppConfig**:
The JSON file (`config.json`) storing persistent app-level settings:
`default_trigger_hour` (0-23, default 14), `task_warning_threshold`
(non-negative integer 0-100, default 5, reserved for future use - never read
at runtime by any Mode), and `snooze_duration_minutes` (one of 5/15/30/60,
default 5 - the Popup's last-chosen Snooze duration, written by
`Set-SnoozeDuration` and read by popup mode at Popup open to restore the
prior selection).
_Avoid_: Config (ambiguous - see PopupConfig), Settings, Preferences

**AppData Dir**:
The directory `%APPDATA%\DailyMotivationBrainHelper\`. All persistent state lives
here.
_Avoid_: App folder, Data directory, Config directory

**Outcome Log**:
The file `popup_log.txt` in AppData Dir. Pipe-delimited records:
`[timestamp] | TaskId | FolderName | HASH:{sha256} | Outcome | SnoozeCount`.
The folder path is **not** stored in plaintext - only a SHA-256 hex digest
prefixed with `HASH:` (or `HASH:NO_PATH` when empty). Append-only, with rotation
at 1 MB and 30-day archive retention (see ADR-010).
_Avoid_: Log file, History, Activity log

**Write-OutcomeLog**:
The function that appends a single pipe-delimited Outcome record to the Outcome
Log. Acquires the log Mutex before writing to prevent interleaved entries from
concurrent popup sessions. Hashes the FolderPath to `HASH:{sha256}` before
writing, so no plaintext path ever reaches the log file.
_Avoid_: Log write, Append log, Write log

---

### Windows integration

**Context Menu Verb**:
The right-click entry "Set as tomorrow's folder (Daily Motivation)" registered
under `HKCU:\Software\Classes\Directory\shell\ScheduleMotivation`. Invokes
setfolder mode. Registered (a) unconditionally on every main-mode launch
before the Main Window is shown (self-heal) and (b) again after every
successful Schedule, both via `Register-ContextMenu` (idempotent -
re-registering with `New-Item -Force` is safe). Removed only by uninstall mode
via `Unregister-ContextMenu`.
_Avoid_: Right-click option, Shell extension, Registry entry

**Mutex**:
Three named Windows mutexes are used:
- **Popup mutex** - `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}`
  ensures only one Popup is visible per user session (user/session isolation
  prevents cross-user DoS). Exposed at runtime as `$script:PopupMutexName`.
- **Config lock** - `Global\DailyMotivationPopupConfigLock` serializes writes to
  `popup_config.json` in `Set-PopupConfig`.
- **Schedule lock** - `Global\DailyMotivationScheduleLock` serializes the full
  read-duplicate-check-register-save cycle in `New-MotivationTask`,
  `Sync-MotivationTasks`, and `Remove-MotivationTask`, making each atomic with
  respect to concurrent Schedule calls. See ADR-011.
_Avoid_: Lock, Guard, Semaphore

**Undo**:
A timed window (shown immediately after Schedule) that lets the user cancel the
MotivationTask they just created. Uses a ProgressBar countdown. Calls
`Remove-MotivationTask` and cancels the Undo timer on click.
_Avoid_: Cancel, Revert, Delete (Undo is always time-bounded; Delete is permanent)

**Invoke-FolderBrowserDialog**:
The helper function that opens a WinForms `FolderBrowserDialog`. Called from `Show-MainWindow` (the Select Folder button) and from the **Re-Pick Folder** handler in popup mode. Always sets `ShowNewFolderButton = $true`. Pre-populates `SelectedPath` from `$script:LastUsedFolder` when non-empty; writes the chosen path back to `$script:LastUsedFolder` on success. Returns `$null` when the user cancels or the dialog throws.
_Avoid_: Folder picker, Open dialog, Browse dialog

**$script:LastUsedFolder**:
Session memory variable (initialized to `""` at startup) that stores the most recently chosen path from `Invoke-FolderBrowserDialog`. Pre-populates the dialog's starting directory on the next call within the same App session. Not persisted to disk — resets on each new App launch.
_Avoid_: Last path, Recent folder, Saved folder

---

### Build and test

**NoRun**:
The `-NoRun` switch on the Script. When set, all functions are defined but the
entry-point block is skipped. Required by every Pester test that dot-sources the
Script.
_Avoid_: Test mode, Dry run, Skip execution

**Dot-Source**:
The test loading pattern: `. .\DailyMotivation.ps1 -NoRun`. Loads all Script
functions into the test scope without running the app.
_Avoid_: Import, Load, Source

**STA**:
Single-Threaded Apartment model. Required for WPF. Baked in by ps2exe via the
`-STA` flag. Any test that instantiates WPF controls must also run STA.
_Avoid_: Thread model, COM apartment (STA is the canonical term in this codebase)

**Pester**:
The test framework used by all test files. Requires **Pester v5.x** (`Import-Module
Pester -MinimumVersion 5.0`). The test suite uses Pester v5 semantics throughout
and is not compatible with Pester v4. Install with:
`Install-Module -Name Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck`
_Avoid_: Any unversioned reference to "Pester" when the version distinction matters

**PesterConfiguration**:
The Pester v5 configuration object used by `Invoke-Tests.ps1` via
`New-PesterConfiguration`. A static snapshot is also stored in
`PesterConfiguration.psd1` for CI and direct `Invoke-Pester` invocations.
Configures run path, output verbosity, NUnit XML test results, and JaCoCo code
coverage. Not compatible with Pester v4's `$PesterPreference` approach.
_Avoid_: Pester settings, PesterPreference (v4 term)

**BeforeAll / AfterAll**:
Pester v5 blocks that run once before or after all tests in their scope. In this
codebase, file-scoped `BeforeAll` blocks perform dot-sourcing, redirect
`$env:APPDATA` to a temp directory, call `Initialize-AppData`, and define Mocks.
File-scoped `AfterAll` blocks restore `$env:APPDATA` and clean up temp
directories. This file-scope placement of `Mock` inside `BeforeAll` is a
**Pester v5 feature** - in Pester v4, Mocks must be inside a `Describe` or
`Context` block.
_Avoid_: Setup block, Fixture (use BeforeAll/AfterAll/BeforeEach/AfterEach)

**ForEach (data-driven tests)**:
The Pester v5 `-ForEach` parameter on `It` blocks, used to run the same
assertion against multiple inputs. Example from `SingleFile.Tests.ps1`:
`It "Function '<_>' should be defined" -ForEach $requiredFunctions { ... }`.
This is a **Pester v5 feature** - in Pester v4 the equivalent is `-TestCases`.
_Avoid_: TestCases (v4 term), parameterised tests

**Invoke-Tests.ps1**:
The project's test runner script. Wraps `Invoke-Pester` with a
`New-PesterConfiguration` call, supports `-Tag`, `-ExcludeTag`, `-CI`, and
`-Coverage` parameters. Use this instead of calling `Invoke-Pester` directly.
In CI mode (`-CI`) it sets `Run.Exit = $true` and emits NUnit XML and JaCoCo
coverage artifacts.
_Avoid_: Test script, Run script

**Initialize-WindowsAssemblies**:
The function that loads WPF (`PresentationFramework`, `PresentationCore`,
`WindowsBase`) and WinForms assemblies into the runspace. Must be called before
any window is shown and must run on an STA thread. Idempotent — safe to call
more than once; subsequent calls return immediately.
_Avoid_: Load assemblies, Init WPF, Setup assemblies

**$script:AssembliesLoaded**:
Script-scoped boolean flag, initialized to `$false` at startup and set to `$true` by `Initialize-WindowsAssemblies` after both WPF and WinForms loads are attempted. Used by `Show-MainWindow` as an early-exit guard — if `$false`, the function writes to `[Console]::Error` and returns without opening any window. Under `Set-StrictMode -Version Latest`, reading this variable before it is initialized is a terminating `RuntimeException`.
_Avoid_: Assemblies flag, WPF ready, Loaded flag

**$script:WpfLoaded**:
Script-scoped boolean sub-flag set to `$true` within `Initialize-WindowsAssemblies` after `PresentationFramework`, `PresentationCore`, and `WindowsBase` load successfully. Checked by `Show-ErrorDialog`, `Show-InfoDialog`, and `Show-PopupWindow` before WPF-specific calls. Distinct from `$script:AssembliesLoaded`: `$script:WpfLoaded` is WPF-specific; `$script:AssembliesLoaded` is the composite "both loads attempted" gate used by `Show-MainWindow`.
_Avoid_: WPF flag, WPF ready, Presentation loaded

**$script:FormsLoaded**:
Script-scoped boolean sub-flag set to `$true` within `Initialize-WindowsAssemblies` after `System.Windows.Forms` loads successfully. Enables the WinForms fallback path in `Show-ErrorDialog` and powers `Invoke-FolderBrowserDialog`.
_Avoid_: Forms flag, WinForms ready

**$script:Window**:
The script-scoped variable holding the live WPF window reference during a main
mode or popup mode session. Setting it to `$null` in tests suppresses all WPF
dispatch calls in `Update-*UI` functions, enabling cross-platform data-path
testing without opening a real window. The canonical seam for WPF-bypass in
unit tests.
_Avoid_: Window reference, Window handle, Window variable

**Get-HistoryData**:
Reads the Outcome Log and returns the most recent 30 records formatted for
display in the History Panel, with an `OutcomeColor` hex value derived from
each record's Outcome. Returns an empty array when the log file is absent or
contains no valid entries.
_Avoid_: Read history, Fetch history, Load history

**Update-HistoryUI**:
Sorts records returned by `Get-HistoryData` and assigns them to the History
Panel control's `ItemsSource`. WPF assignment is suppressed when
`$script:Window` is `$null`.
_Avoid_: Render history, Refresh history

**Get-ScheduleTime**:
Converts the Today/Tomorrow Selector state and the `default_trigger_hour` from
AppConfig into a concrete TriggerTime `[datetime]`. Returns today-at-hour when
the Today radio is visible and checked; returns tomorrow-at-hour otherwise.
_Avoid_: Calculate time, Resolve trigger time, Compute schedule

**Update-TaskListUI**:
Queries `Get-MotivationTasks`, filters out DELETED tasks, sorts PENDING tasks
ascending by TriggerTime, and assigns the display-formatted list to the Task
List control's `ItemsSource`. WPF assignment is suppressed when
`$script:Window` is `$null`.
_Avoid_: Render tasks, Refresh task list, Load task list

**Get-SafeErrorMessage**:
Sanitises a raw exception message before display or logging by redacting Windows
drive paths to `[PATH]`, UNC paths to `[UNC_PATH]`, credential keywords to
`[REDACTED]`, `$env:` variable paths to `[ENV_PATH]`, and stripping stack trace
lines. Ensures FolderPaths are never exposed in error dialogs.
_Avoid_: Sanitize error, Clean error, Scrub message

**Show-ErrorDialog / Show-InfoDialog**:
Windows-only functions that display a modal message box via WPF (preferred),
falling back to WinForms, then to console output when neither is available.
`Show-ErrorDialog` passes its message through `Get-SafeErrorMessage` before
display. Both are no-ops on non-Windows platforms when no assembly is loaded.
_Avoid_: Alert dialog, Message box, Error popup, Info popup

**WPF test pattern — Source-text regex (Pattern A)**:
A headless, cross-platform test pattern that reads `DailyMotivation.ps1` as a raw string and asserts control presence via regex (e.g., `$src | Should -Match 'x:Name="SelectFolderBtn"'`). No functions are invoked and no window is opened. Adds zero code-coverage lines but satisfies XAML control-existence acceptance criteria. Reference files: `Tests/Unit/AG19-010.TabOrder.Tests.ps1`, `Tests/Unit/AG19.MainWindowUX.Tests.ps1`.
_Avoid_: XAML test, Source scan, Grep test

**WPF test pattern — Early-exit path exploitation (Pattern B)**:
A test pattern that exercises code paths in `Show-MainWindow` or `Show-PopupWindow` that return before any `ShowDialog()` call. For `Show-MainWindow`: set `$script:AssembliesLoaded = $false` before calling — it returns immediately via `[Console]::Error.WriteLine`. For `Show-PopupWindow`: call without a valid `explorer_path` in the PopupConfig — it exits before building the window. No window is opened; no STA runspace is required. Reference file: `Tests/Unit/AG20-013.PopupMutex.Tests.ps1`.
_Avoid_: No-window test, Guard test, Early-return test

**WPF test pattern — Skip-as-specification (Pattern C)**:
A test pattern for behaviors that genuinely require `ShowDialog()` and cannot be exercised headlessly. The test is written and marked `-Skip` with an explicit comment stating the condition that would un-skip it. Serves as a TDD specification — a written record of what is not yet covered and why. Never satisfy a Pattern C test by opening a real window in automated tests. Reference file: `Tests/Unit/AG20-007.CountdownTimer.Tests.ps1`.
_Avoid_: Skipped test, Pending test, TODO test

---

## Relationships

- The **App** has exactly four **Modes**: main, popup, setfolder, and uninstall
- **main mode** creates **MotivationTasks**, writes the **PopupConfig**, and
  registers the **Context Menu Verb**
- **setfolder mode** creates a new **MotivationTask** scheduled for tomorrow,
  writes the **PopupConfig**, shows a confirmation MessageBox, and exits
- Each **MotivationTask** has exactly one **OS Task** in Windows Task Scheduler
- At **TriggerTime**, the OS Task invokes the **App** in **popup mode**
- **popup mode** reads the **PopupConfig** (the **Handoff**) and shows the **Popup**
- The **Popup** displays exactly one **Message** (Glyph + Title + Body), frozen at
  Schedule time
- The user's action in the **Popup** produces exactly one **Outcome** per session:
  `Opened`, `Snoozed`, `Dismissed`, or `PathMissing`
- Each **Snooze** creates a new **MotivationTask** scheduled N minutes later
  (removing the original after the Popup closes) and increments the popup-session
  **SnoozeCount**; only the final session action is written to the **Outcome Log**
- **Dismiss** removes all PENDING **MotivationTasks** for the same FolderPath
  and writes `Dismissed` to the **Outcome Log**
- **Re-Pick Folder** opens a new folder picker, substitutes the path in the
  PopupConfig, opens Explorer, and logs `Opened` (not `PathMissing`)
- **Undo** removes the just-created **MotivationTask** and cancels its **OS
  Task** without writing to the **Outcome Log**
- **Pause** is scoped to the current **Popup** session; paused state is not
  preserved when the user **Snoozes** (a new Popup session begins)
- The **Context Menu Verb** is registered (a) unconditionally every time the
  App launches into main mode, before the Main Window is shown - a self-heal
  in case the user manually deleted the registry key - and (b) again after
  every successful **Schedule** in main mode. Both registrations are
  idempotent. **setfolder mode** does not register it itself; it relies on
  either (a) or (b) having already installed the verb.
- All persistent state lives in the **AppData Dir**: `config.json` (**AppConfig**),
  `popup_config.json` (**PopupConfig**), `tasks.json` (**MotivationTask** list),
  `popup_log.txt` (**Outcome Log**), `popup_debug.txt` (diagnostic log written by
  popup mode and Remove-MotivationTask)
- The **Script** compiles 1:1 into the **Exe** via ps2exe; there is no other
  build artifact

---

## Example dialogue

> **Dev:** "I want to add a way for users to change the trigger hour."
> **Domain expert:** "That's an **AppConfig** change - update `default_trigger_hour` in `config.json`. The user sees a time picker in **main mode**. When they **Schedule**, the new value is used as the **TriggerTime**."

> **Dev:** "What happens if the user schedules the same folder twice?"
> **Domain expert:** "It's a **Duplicate** - blocked by default. The UI shows a confirmation dialog. If the user says yes, we **Force Schedule**, which creates a second **MotivationTask** with a different **TaskId** for the same folder and date."

> **Dev:** "When the popup fires and the folder is gone, what state are we in?"
> **Domain expert:** "**Path Missing**. The Popup shows the path-missing panel instead of the normal **Message** + **Open Folder** flow. If the user closes without re-picking, the **Outcome** written to the log is `PathMissing`."

> **Dev:** "How does the popup know which folder to open if main mode already closed?"
> **Domain expert:** "That's the **Handoff**. main mode (or setfolder mode) writes the **PopupConfig** at **Schedule** time. popup mode reads it at **TriggerTime**. The two modes never run concurrently - the **Handoff** is the only bridge."

> **Dev:** "Should I delete the MotivationTask when the user clicks Open Folder?"
> **Domain expert:** "No. **Open Folder** writes `Opened` to the **Outcome Log** and closes the **Popup**. The **MotivationTask** record stays in `tasks.json` - it's history. The **OS Task** in Task Scheduler is a one-shot trigger; it's gone after firing."

> **Dev:** "How do I wire up the right-click to set a folder?"
> **Domain expert:** "Register the **Context Menu Verb**. That calls the **App** in **setfolder mode** with the folder path. setfolder mode creates a new **MotivationTask** for tomorrow at the default trigger hour, writes the **PopupConfig**, shows a confirmation MessageBox, then exits."

> **Dev:** "What happens if the user pauses the Countdown and then clicks Snooze?"
> **Domain expert:** "The **Pause** state is scoped to the current **Popup** session. When the user clicks **Snooze**, a new **MotivationTask** is created and a fresh **Popup** opens at the snoozed time with the **Countdown** running from the start. Paused state does not carry over."

> **Dev:** "What is the difference between **Re-Pick Folder** and just dismissing?"
> **Domain expert:** "**Re-Pick Folder** is available only when **Path Missing** is detected. It opens a picker, updates the **PopupConfig** in-session, opens Explorer at the new path, and logs `Opened` - not `PathMissing`. **Dismiss** removes all PENDING **MotivationTasks** for that folder and logs `Dismissed` without opening anything."

> **Dev:** "Why does my `if ($Mode -eq \"popup\")` branch never fire?"
> **Domain expert:** "Because ps2exe binds the CLI argument `/popup` as the string `\"/popup\"` (with the leading slash) to `$Mode`. The switch statement matches on `\"/popup\"`, not `\"popup\"`. Always use the slash-prefixed form in any code that inspects `$Mode`."

---

## Flagged ambiguities

- **"Config"** - Used alone, this is ambiguous. `config.json` is **AppConfig**;
  `popup_config.json` is **PopupConfig**. Always use the qualified form.
- **"Task"** - Overloaded. A **MotivationTask** is the domain record in
  `tasks.json`. An **OS Task** is the Windows Task Scheduler entry. Never use
  "task" alone when the distinction matters.
- **"Scheduled task"** - Forbidden unqualified. Use **MotivationTask** for the
  domain entity or **OS Task** for the Windows scheduler entry.
- **"Dismiss"** and **"Undo"** - Both close UI without opening Explorer, but
  they are different. **Dismiss** ends a **Popup** session (removes matching
  PENDING MotivationTasks, logs `Dismissed`). **Undo** cancels a
  freshly-created **MotivationTask** from the main window (no log entry; task is
  deleted). Dismiss is scoped to the popup; Undo is scoped to the main window.
  "Dismiss" also appears on the path-missing panel ("Close" button, logs
  `PathMissing`, removes nothing), on the last-folder banner in the Main
  Window (hides the banner only, no task removal, no log entry), and on the
  Undo banner itself (`DismissBannerBtn`, the small "x") - closing that banner
  only stops the Undo countdown and hides the banner; unlike Undo, it does NOT
  call Remove-MotivationTask, so the just-created MotivationTask stays
  scheduled. Always specify which dismiss action you mean.
- **"Status = DELETED"** - This is a runtime annotation applied during
  `Get-MotivationTasks` when the **OS Task** is missing, not a user-initiated
  delete. A user-initiated remove is `Remove-MotivationTask`, not a status flip.
- **"Snooze"** - In the Popup it is an action (creates a new MotivationTask).
  In the `MotivationTask` record, `snooze_count` is always `0` - the running
  count is tracked in the popup-session variable `$script:snoozeCount` and
  written only to the **Outcome Log**. Keep the verb sense and the record field
  distinct.
- **"Mode values"** - When checking `$Mode` in code, always use the
  slash-prefixed strings `"/popup"`, `"/setfolder"`, and `"/uninstall"`. The
  bare strings `"popup"`, `"setfolder"`, and `"uninstall"` will never match
  because ps2exe passes CLI arguments with their leading slash intact.
- **"Pester"** - Always specify the version. The codebase requires **Pester
  v5.x**. Pester v4 will silently fail because file-scoped `BeforeAll` Mocks
  and the `-ForEach` parameter on `It` blocks are Pester v5 features.
- **"FolderPath in PopupConfig"** - The JSON key for the folder path in
  `popup_config.json` is `explorer_path`, not `folder_path` or `FolderPath`.
  Reading `$config.FolderPath` or `$config.folder_path` returns `$null`.
- **"Re-Pick Folder" vs "Selected Folder"** - **Selected Folder** is the
  user's in-progress choice in the main window before scheduling. **Re-Pick
  Folder** is the path-missing Popup action that substitutes a new path for the
  current session only. One is main mode pre-schedule state; the other is popup
  mode recovery.
- **"Schedule" (verb)** - Ambiguous in code. The user action is **Schedule**
  (pick folder, click button, create MotivationTask). The OS call is
  `Register-ScheduledTask`. Keep them distinct: say "the user schedules" vs
  "the OS Task is registered."

---

_Last updated: 2026-09-17_
