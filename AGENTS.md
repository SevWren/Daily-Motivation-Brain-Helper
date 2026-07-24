# AGENTS.md — Daily Motivation Brain Helper

All agent-orientation guidance for this repository is in **[CLAUDE.md](CLAUDE.md)**.

`CLAUDE.md` covers:
- Critical testing environment rules (Windows 10/11 primary; Linux sandbox is secondary for platform-abstraction tests only)
- **MANDATE: Schedule Failed / "Access is denied" bug — correct and incorrect fix patterns** ← read this before touching any scheduling, Task Scheduler, WPF window, or error-handling code
- Architecture and execution modes
- Script sections and key functions
- Config file schemas
- Build and test commands
- Code quality rules (no startup popups, comment hygiene)
- Documentation map

Read `CLAUDE.md` before making any changes to this repository.

## Quick Reference: Scheduling / Permissions Bug

If you are working on anything related to:
- `Register-ScheduledTask` / `New-MotivationTask` / `Invoke-FolderScheduling`
- Task principal configuration (`LogonType`, `RunLevel`)
- Context-menu verb (`setfolder` mode)
- WPF window disposal (`.Dispose()` / `.Close()`)
- Error messages containing "Access is denied" or "Schedule Failed"
- `$script:ConfigDefaults` or any other `$script:*` fallback variable
- Cleanup / bloat-removal commits that touch `DailyMotivation.ps1`

Then the **MANDATE section in CLAUDE.md is mandatory reading before you write a single line of code.**

The short version:
- `Register-ScheduledTask` failures must be caught, diagnosed by operation name, and never shown as "Invalid Folder"
- Never call `.Dispose()` on `System.Windows.Window` — use `.Close()`
- Never remove a `$script:*` variable without grepping all references first
- No scheduling/permissions fix may be declared resolved without a live Windows 10/11 test
- Task principal stays at `LogonType S4U` / `RunLevel Limited` until a real Windows integration test says otherwise
