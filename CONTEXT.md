# Daily Motivation Brain Helper

A Windows desktop utility that fires a motivational popup at a scheduled time,
opening a chosen folder in Explorer to launch a focused work session.

## Language

### The app and its parts

**App**:
The compiled artifact `DailyMotivation.exe` — the thing end users run. When
describing what a user interacts with, use App, not "script" or "tool".
_Avoid_: Tool, Script, Program, Utility

**Script**:
The source file `DailyMotivation.ps1` — the single file that compiles into the
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
One of three execution contexts the Script enters depending on its `$Mode`
parameter: `"main"` (default), `"/popup"`, or `"/setfolder"`. When the compiled
Exe is invoked from the command line (e.g. `DailyMotivation.exe /popup`),
ps2exe binds the positional argument to `$Mode`, so the value includes the
leading slash. The switch statement matches on `"/popup"` and `"/setfolder"`;
any other value (including the bare default `"main"`) falls through to
`Show-MainWindow`. Every function call happens inside exactly one Mode.
_Avoid_: Invocation type, Run context, Entry path

**main mode**:
Default Mode. Entered when `$Mode` is anything other than `"/popup"` or
`"/setfolder"`. Shows the Main Window — folder picker and task scheduler UI.
_Avoid_: Normal mode, UI mode, Interactive mode

**popup mode**:
Triggered by Windows Task Scheduler via `DailyMotivation.exe /popup`. The
`$Mode` parameter equals `"/popup"`. Shows the Popup Window. Never launched by
the user directly.
_Avoid_: Notification mode, Reminder mode, Scheduled run

**setfolder mode**:
Invoked by the Context Menu Verb via `DailyMotivation.exe /setfolder "C:\path"`.
The `$Mode` parameter equals `"/setfolder"`. Creates a new MotivationTask
scheduled for tomorrow at the default trigger hour, writes the PopupConfig,
shows a confirmation MessageBox, then exits.
_Avoid_: Right-click mode, Context mode, Folder-set mode

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
_Avoid_: ID, GUID, Identifier, Task name

**TriggerTime**:
The ISO 8601 datetime (`scheduled_time` field) at which Task Scheduler fires the
popup for a MotivationTask.
_Avoid_: Scheduled time, Fire time, Run time, Alarm time

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
A MotivationTask that has the same FolderPath (case-insensitive) and same
calendar date as an existing MotivationTask. Blocked by default; allowed via the
`-Force` flag.
_Avoid_: Conflict, Clash, Double-booking

**Force Schedule**:
Creating a MotivationTask despite a Duplicate being detected. Enabled by passing
`-Force` to `New-MotivationTask`.
_Avoid_: Override, Bypass duplicate check

**Status**:
The lifecycle state of a MotivationTask. Canonical values in
`$script:ValidTaskStatuses`: `PENDING` (created, not yet triggered), `DELETED`
(OS Task was removed or not found at refresh time), `COMPLETED` (terminal success
annotation), and `FAILED` (terminal failure annotation). Values outside this set
are normalized to `UNKNOWN` when tasks are loaded. Duplicate detection only
considers `PENDING` tasks.
_Avoid_: State, Phase, Flag

**Network Path**:
A FolderPath that begins with `\\` (UNC) or is a mapped drive. Scheduled
normally, but a warning dialog is shown in the Main Window immediately after
scheduling to alert the user the path may be unreachable at trigger time.
_Avoid_: Remote path, UNC path (UNC is a sub-type, not a synonym)

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

**Open Folder** (primary Popup action):
The primary Popup action. UI label is `Open Folder →` on button `LetsGoBtn`.
Opens Explorer at the FolderPath, writes `Opened` to the Outcome Log, and closes
the Popup. Historical domain name "Let's Go" refers to the same action — prefer
**Open Folder** in new writing to match the UI.
_Avoid_: Let's Go (legacy term), Confirm, Go button, Launch

**Snooze**:
Defers the Popup by N minutes (5, 15, 30, or 60). Increments the SnoozeCount.
Schedules a new OS Task; the current Popup closes.
_Avoid_: Delay, Postpone, Remind me later

**Dismiss**:
The "Dismiss for Today" Popup action. Removes all PENDING MotivationTasks whose
FolderPath matches the current popup's folder. Writes `Dismissed` to the Outcome
Log and closes the Popup without opening Explorer.
_Avoid_: Cancel, Close, Ignore, Skip

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
always `0` — it is initialised at creation and never updated thereafter.
_Avoid_: Snooze number, Delay count

**Path Missing**:
The error state when the FolderPath stored in the PopupConfig no longer exists on
disk at the time the Popup appears. Shows the path-missing panel instead of the
normal Popup content.
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
_Avoid_: Popup settings, Shared state, Config (ambiguous — see AppConfig)

**Handoff**:
The write-then-read cycle of the PopupConfig. main mode or setfolder mode writes
it at Schedule time; popup mode reads it at trigger time.
_Avoid_: Data pass, State share, IPC

**AppConfig**:
The JSON file (`config.json`) storing persistent app-level settings:
`default_trigger_hour` and `task_warning_threshold`. Never read by popup mode.
_Avoid_: Config (ambiguous — see PopupConfig), Settings, Preferences

**AppData Dir**:
The directory `%APPDATA%\DailyMotivationBrainHelper\`. All persistent state lives
here. Resolved at call time by `Initialize-AppData` to support test redirects.
_Avoid_: App folder, Data directory, Config directory

**Outcome Log**:
The file `popup_log.txt` in AppData Dir. Pipe-delimited records:
`[timestamp] | TaskId | FolderName | HASH:{sha256} | Outcome | SnoozeCount`.
The folder path is **not** stored in plaintext — only a SHA-256 hex digest
prefixed with `HASH:` (or `HASH:NO_PATH` when empty). Append-only, with rotation
when the file exceeds 1MB (archives older than 30 days are deleted).
_Avoid_: Log file, History, Activity log

---

### Windows integration

**Context Menu Verb**:
The right-click entry "Set as tomorrow's folder (Daily Motivation)" registered
under `HKCU:\Software\Classes\Directory\shell\ScheduleMotivation`. Invokes
setfolder mode. Registered on every successful Schedule via `Register-ContextMenu`
(idempotent — re-registering with `New-Item -Force` is safe).
_Avoid_: Right-click option, Shell extension, Registry entry

**Mutex**:
Two named Windows mutexes are used:
- **Popup mutex** — `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}`
  ensures only one Popup is visible per user session (user/session isolation
  prevents cross-user DoS). Exposed at runtime as `$script:PopupMutexName`.
- **Config lock** — `Global\DailyMotivationPopupConfigLock` serializes writes to
  `popup_config.json` in `Set-PopupConfig`.
_Avoid_: Lock, Guard, Semaphore

**Undo**:
A timed window (shown immediately after Schedule) that lets the user cancel the
MotivationTask they just created. Uses a ProgressBar countdown. Calls
`Remove-MotivationTask` and cancels the Undo timer on click.
_Avoid_: Cancel, Revert, Delete (Undo is always time-bounded; Delete is permanent)

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
**Pester v5 feature** — in Pester v4, Mocks must be inside a `Describe` or
`Context` block.
_Avoid_: Setup block, Fixture (use BeforeAll/AfterAll/BeforeEach/AfterEach)

**ForEach (data-driven tests)**:
The Pester v5 `-ForEach` parameter on `It` blocks, used to run the same
assertion against multiple inputs. Example from `SingleFile.Tests.ps1`:
`It "Function '<_>' should be defined" -ForEach $requiredFunctions { ... }`.
This is a **Pester v5 feature** — in Pester v4 the equivalent is `-TestCases`.
_Avoid_: TestCases (v4 term), parameterised tests

**Invoke-Tests.ps1**:
The project's test runner script. Wraps `Invoke-Pester` with a
`New-PesterConfiguration` call, supports `-Tag`, `-ExcludeTag`, `-CI`, and
`-Coverage` parameters. Use this instead of calling `Invoke-Pester` directly.
In CI mode (`-CI`) it sets `Run.Exit = $true` and emits NUnit XML and JaCoCo
coverage artifacts.
_Avoid_: Test script, Run script

---

## Relationships

- The **App** has exactly three **Modes**: main, popup, and setfolder
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
- Each **Snooze** increments the popup-session **SnoozeCount** and schedules a
  new **OS Task**; only the final session action is written to the **Outcome Log**
- **Dismiss** removes all PENDING **MotivationTasks** for the same FolderPath
  and writes `Dismissed` to the **Outcome Log**
- The **Context Menu Verb** is registered on every successful **Schedule**
  (idempotent); it is not limited to the first Schedule
- All persistent state lives in the **AppData Dir**: `config.json` (**AppConfig**),
  `popup_config.json` (**PopupConfig**), `tasks.json` (**MotivationTask** list),
  `popup_log.txt` (**Outcome Log**)
- The **Script** compiles 1:1 into the **Exe** via ps2exe; there is no other
  build artifact

---

## Example dialogue

> **Dev:** "I want to add a way for users to change the trigger hour."
> **Domain expert:** "That's an **AppConfig** change — update `default_trigger_hour` in `config.json`. The user sees a time picker in **main mode**. When they **Schedule**, the new value is used as the **TriggerTime**."

> **Dev:** "What happens if the user schedules the same folder twice?"
> **Domain expert:** "It's a **Duplicate** — blocked by default. The UI shows a confirmation dialog. If the user says yes, we **Force Schedule**, which creates a second **MotivationTask** with a different **TaskId** for the same folder and date."

> **Dev:** "When the popup fires and the folder is gone, what state are we in?"
> **Domain expert:** "**Path Missing**. The Popup shows the path-missing panel instead of the normal **Message** + **Open Folder** flow. If the user closes without re-picking, the **Outcome** written to the log is `PathMissing`."

> **Dev:** "How does the popup know which folder to open if main mode already closed?"
> **Domain expert:** "That's the **Handoff**. main mode (or setfolder mode) writes the **PopupConfig** at **Schedule** time. popup mode reads it at **TriggerTime**. The two modes never run concurrently — the **Handoff** is the only bridge."

> **Dev:** "Should I delete the MotivationTask when the user clicks Open Folder?"
> **Domain expert:** "No. **Open Folder** writes `Opened` to the **Outcome Log** and closes the **Popup**. The **MotivationTask** record stays in `tasks.json` — it's history. The **OS Task** in Task Scheduler is a one-shot trigger; it's gone after firing."

> **Dev:** "How do I wire up the right-click to set a folder?"
> **Domain expert:** "Register the **Context Menu Verb**. That calls the **App** in **setfolder mode** with the folder path. setfolder mode creates a new **MotivationTask** for tomorrow at the default trigger hour, writes the **PopupConfig**, shows a confirmation MessageBox, then exits."

> **Dev:** "Why does my `if ($Mode -eq \"popup\")` branch never fire?"
> **Domain expert:** "Because ps2exe binds the CLI argument `/popup` as the string `\"/popup\"` (with the leading slash) to `$Mode`. The switch statement matches on `\"/popup\"`, not `\"popup\"`. Always use the slash-prefixed form in any code that inspects `$Mode`."

---

## Flagged ambiguities

- **"Config"** — Used alone, this is ambiguous. `config.json` is **AppConfig**;
  `popup_config.json` is **PopupConfig**. Always use the qualified form.
- **"Task"** — Overloaded. A **MotivationTask** is the domain record in
  `tasks.json`. An **OS Task** is the Windows Task Scheduler entry. Never use
  "task" alone when the distinction matters.
- **"Scheduled task"** — Forbidden unqualified. Use **MotivationTask** for the
  domain entity or **OS Task** for the Windows scheduler entry.
- **"Dismiss"** and **"Undo"** — Both close UI without opening Explorer, but
  they are different. **Dismiss** ends a **Popup** session (removes matching
  PENDING MotivationTasks, logs `Dismissed`). **Undo** cancels a
  freshly-created **MotivationTask** from the main window (no log entry; task is
  deleted). Dismiss is scoped to the popup; Undo is scoped to the main window.
- **"Status = DELETED"** — This is a runtime annotation applied during
  `Get-MotivationTasks` when the **OS Task** is missing, not a user-initiated
  delete. A user-initiated remove is `Remove-MotivationTask`, not a status flip.
- **"Snooze"** — In the Popup it is an action (user defers). In the
  `MotivationTask` record, `snooze_count` is always `0` — the running count is
  tracked in the popup-session variable `$script:snoozeCount` and written only to
  the **Outcome Log**. Keep the verb sense and the record field distinct.
- **"Mode values"** — When checking `$Mode` in code, always use the
  slash-prefixed strings `"/popup"` and `"/setfolder"`. The bare strings
  `"popup"` and `"setfolder"` will never match because ps2exe passes CLI
  arguments with their leading slash intact.
- **"Pester"** — Always specify the version. The codebase requires **Pester
  v5.x**. Pester v4 will silently fail because file-scoped `BeforeAll` Mocks
  and the `-ForEach` parameter on `It` blocks are Pester v5 features.
- **"FolderPath in PopupConfig"** — The JSON key for the folder path in
  `popup_config.json` is `explorer_path`, not `folder_path` or `FolderPath`.
  Reading `$config.FolderPath` or `$config.folder_path` returns `$null`.
