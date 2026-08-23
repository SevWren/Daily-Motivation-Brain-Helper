# ADR-006: Task Scheduler Principal Configuration for Interactive Desktop Popup

The popup must appear on the user's active desktop. After testing all principal
combinations (S4U + Highest, S4U + Limited, Interactive + Limited), only
`LogonType Interactive` + `RunLevel Limited` works reliably on Windows 10/11
standard user accounts without elevation.

## Decision

Use `New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited`.

- **UserId $env:USERNAME** - runs in the logged-in user's context, not SYSTEM
- **LogonType Interactive** - grants access to the user's active desktop session; required for WPF to display
- **RunLevel Limited** - no elevation; any standard user can register and trigger the task

## Considered Options

| LogonType | RunLevel | Result |
|-----------|----------|--------|
| S4U | Highest | Requires elevation; blocks non-admin users entirely |
| S4U | Limited | "Access is denied" on Windows 10 - session-less logon cannot host UI |
| Interactive | Limited | **Chosen** - fires on user's desktop, no elevation required |

S4U is session-less by design. A session-less task cannot open a window on any
desktop. `Highest` (elevation) is rejected because standard users cannot register
elevated tasks, defeating the purpose of a user-space scheduler.

## Consequences

The task only fires when the user is logged in with an active session - by design,
since there is no desktop to show the popup on otherwise.

## Evidence

`DailyMotivation.ps1` lines 782–787. Incident root-cause chronicle: ADR-005.
Mandate: `CLAUDE.md` CORRECT 1 and WRONG 6.
