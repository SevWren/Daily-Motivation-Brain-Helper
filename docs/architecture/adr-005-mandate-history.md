# ADR-005: Mandate Enforcement History — Scheduling Bug and CI Infrastructure

## Status

Informational — Active

## Context

This ADR records the incident chronology that produced the binding mandates in `CLAUDE.md`.
The mandates themselves live in `CLAUDE.md`; this document is the evidence base that justified them.
Consult this when you need to understand *why* a mandate exists, not *what* it requires.

---

## Part 1 — "Schedule Failed / Access is denied" Incident History

### The bug

```
Schedule Failed
Could not schedule '[PATH]'
Access is denied.
```

This dialog appeared in `setfolder` mode and `main` mode. The folder was accessible to the user.
The failure originated inside `Register-ScheduledTask`, not filesystem ACL validation.
A secondary symptom — `Window.Dispose()` error after closing — was caused by calling `.Dispose()`
on `System.Windows.Window`, which does not implement `IDisposable`.

### Attempt timeline

| Wave | Period | Commits | Outcome |
|------|--------|---------|---------|
| 1 | 2026-06-25 | `57df3f6c`, `98a5d300` | Changed `LogonType Interactive → S4U`, `RunLevel Highest → Limited`. Neither validated on Windows 10. |
| 2 | 2026-06-30 | `8f4d736d` | `.Dispose()` called on `Show-PopupWindow` WPF window — introduced new error. |
| 3 | 2026-07-01 | `26b7679c` | HOTFIXed `Show-MainWindow` `.Dispose()` call. Same day: `370d9228` replaced all folder paths in error messages with `[PATH]` — useful for privacy but made the dialog ambiguous (operation name lost). |
| 4 | 2026-07-02 | `adbd395f` | Removed `$script:ConfigDefaults` in a bloat-removal pass. That variable is the fallback used in 3 places when config reads fail; its removal introduced a null-reference path that propagated as "Access is denied". Fixed same-day in `97d3a650`. |
| 5 | 2026-07-23 | — | Issue #10 closed based on code review alone (no live Windows test). Bug was still present the following day. |
| 6 | 2026-08-18 | `e0e0da6` | Reverted `LogonType` from `S4U` back to `Interactive` after live Windows 10/11 testing on issue #183 confirmed: `S4U` → "Access is denied" for non-elevated standard users; `Interactive` → task registered and popup displayed correctly. This is the currently validated configuration. |

### Root cause summary

`S4U` logon type can fail on Windows 10 with "Deny log on as a batch job" Group Policy or on Windows 10
Home. `Interactive` is required because the task needs to display a WPF window on the user's active
desktop session — `S4U` is session-less and cannot host UI. The combination of `LogonType Interactive`
+ `RunLevel Limited` was confirmed working via live Windows 10/11 test on 2026-08-18 (issue #183).

---

## Part 2 — Pester 5 / CI Test Infrastructure Incident History

### Context

10 consecutive CI failures occurred on branch `project-restart-pwsh7` (2026-08-03), tracked in issues
#178 and #179. The final resolution required 7 commits. Each of the WRONG patterns below was
attempted and failed before the root cause was confirmed.

### WRONG 7 incident — ErrorAction double-bind

6 of the 10 CI failures were diagnosed as "Save-TasksJson failure with empty exception message." The
hypothesis was wrong — `Save-TasksJson` was never reached. The failure happened at
`Register-ScheduledTask` because `ErrorAction` was included in a splatted `@params` dict AND also
specified directly on the call. Pester's mock proxy binds the common parameter twice, producing a
silent non-terminating error with an empty message. `-ErrorAction Stop` promoted it to a terminating
`RuntimeException`, which the caller caught as `Success=$false` with `Error=""` — indistinguishable
from a genuine downstream failure without examining Pester internals.

### WRONG 8 incident — PSCustomObject / RemoveParameterValidation

Mocking `New-ScheduledTaskAction` with `PSCustomObject` returns was attempted in both
`SingleFile.Tests.ps1` and `AG20-009.ExePathSpaces.Tests.ps1` using
`-RemoveParameterValidation 'Action','Trigger','Settings','Principal'`. It failed every time with:

```
Cannot convert the "@{Execute=...}" value of type "System.Management.Automation.PSCustomObject"
to type "Microsoft.Management.Infrastructure.CimInstance".
```

`-RemoveParameterValidation` strips `[Validate*]` attributes only — it does not strip parameter
type constraints. `Register-ScheduledTask` has hard CIM type constraints that a PSCustomObject
can never satisfy.

### WRONG 9 incident — Module-qualified call recursion

An attempt was made to call `ScheduledTasks\New-ScheduledTaskAction` from inside a Pester mock body
to delegate to the real implementation. Pester 5 intercepts module-qualified calls. This caused
infinite recursion.

---

## Part 3 — Issue Closure Gate Incident History

| Issue | Closed without Windows evidence? | Outcome |
|-------|----------------------------------|---------|
| #10 | Yes — 2026-07-23, code review only | Bug still present the following day |
| #158 | Yes | Reopened same session after error caught |
| #164 | Yes | Reopened same session after error caught |
| #174 | Yes | Reopened same session after error caught |

Pattern: in every case, Linux CI passed and the code appeared correct on review. The failures only
manifested on a real Windows 10/11 machine.

---

## Decision

All incidents above produced binding mandates M1–M7 in `CLAUDE.md` and the Issue Closure Gate.
The mandates are authoritative; this document is read-only evidence. Do not modify the mandates
here — update `CLAUDE.md` directly.

## Consequences

- `CLAUDE.md` mandates are treated as hard constraints, not guidelines.
- Any change to `New-ScheduledTaskPrincipal` parameters requires live Windows 10/11 evidence before the associated issue may be closed.
- The Windows integration test for `New-MotivationTask` (real `Register-ScheduledTask`, `-Skip:(-not $IsWindows)`) must exist and pass before any scheduling fix is declared resolved.
