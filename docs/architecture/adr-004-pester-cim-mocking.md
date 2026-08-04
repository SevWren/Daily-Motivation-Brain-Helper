# ADR-004: Pester 5 mocking strategy for Windows Task Scheduler cmdlets

## Status

Accepted

## Context

Windows Task Scheduler cmdlets split into two groups with fundamentally different mocking requirements:

**Persistence layer** (`Register-ScheduledTask`, `Get-ScheduledTask`, `Unregister-ScheduledTask`) — these write to or read from the OS task registry. They must be mocked in tests to prevent actual scheduler writes and to control collision-detection behaviour.

**Builder cmdlets** (`New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`, `New-ScheduledTaskSettingsSet`, `New-ScheduledTaskPrincipal`) — these construct `Microsoft.Management.Infrastructure.CimInstance` objects. `Register-ScheduledTask` has hard type constraints on these parameters; a `PSCustomObject` fails with "Cannot convert … to type CimInstance" regardless of `-RemoveParameterValidation`. Module-qualified calls (`ScheduledTasks\New-ScheduledTaskAction`) are also intercepted by Pester, making delegation impossible.

## Decision

**Mock only the persistence layer. Let all builder cmdlets run as real Windows implementations.**

Capture `Execute`/`Arguments` and other action properties by inspecting the real `CimInstance` objects inside the `Register-ScheduledTask` mock body rather than by mocking `New-ScheduledTaskAction`.

## Consequences

- Tests require a `windows-latest` runner — the builder cmdlets do not exist on Linux. This is already the case for all `TaskScheduler.Tests.ps1` and integration tests (see ADR-003).
- The `Register-ScheduledTask` mock receives real `CimInstance` objects whose `.Execute`, `.Arguments`, `.StartBoundary`, etc. properties can be inspected directly.
- `-RemoveParameterValidation` on `Register-ScheduledTask` is no longer needed or used.

## Considered Options

**Rejected: Mock all Task Scheduler cmdlets with PSCustomObjects + `-RemoveParameterValidation`.**
Attempted in `SingleFile.Tests.ps1` and `AG20-009.ExePathSpaces.Tests.ps1` during the 2026-08-03 CI investigation. Failed because `-RemoveParameterValidation` strips `[Validate*]` attributes only, not type constraints. CI run `30833693332` produced the confirming error:
```
Cannot convert the "@{UserId=runneradmin; LogonType=S4U; RunLevel=Limited}"
value of type "System.Management.Automation.PSCustomObject" to type
"Microsoft.Management.Infrastructure.CimInstance".
```

**Rejected: Module-qualified delegation (`ScheduledTasks\New-ScheduledTaskAction`) inside mock body.**
Pester 5 intercepts module-qualified calls. Delegation caused infinite recursion (CI run `30835261696`).

## Related

- [CLAUDE.md](../../CLAUDE.md) — WRONG 8, WRONG 9, MANDATE rules 8–9
- [ADR-003](adr-003-platform-adapter.md) — platform adapter / Linux-safe test surface
- Issues [#178](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/178) and [#179](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/179) — full root-cause history
