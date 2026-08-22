---
description: Pester 5 mock patterns — loads when editing test files
paths:
  - "Tests/**/*.ps1"
---

# Pester 5 / CI Test Infrastructure — Correct and Incorrect Patterns

> Binding on all agents and contributors. See [ADR-005](docs/architecture/adr-005-mandate-history.md) for incident history.

## WRONG 7 — `ErrorAction` in a splatted hashtable passed to a mocked cmdlet

Including any PowerShell common parameter in a `@splat` dict AND on the call causes Pester's mock proxy to double-bind it — producing a silent non-terminating error with an empty message that `-ErrorAction Stop` promotes to a terminating exception.

```powershell
# WRONG — double-bind, silent failure
$params = @{ TaskName = $taskName; Action = $action; ErrorAction = 'Stop' }
Register-ScheduledTask @params -ErrorAction Stop

# CORRECT — common params on the call only
$params = @{ TaskName = $taskName; Action = $action }
Register-ScheduledTask @params -ErrorAction Stop
```

**Rule:** Never put `ErrorAction`, `WarningAction`, `Verbose`, or `Debug` in a splatted hashtable. To capture `ErrorAction` inside a mock body, declare it in the mock's own `param()` block — that is the approved workaround.

## WRONG 8 — Mocking `New-ScheduledTask*` helpers with PSCustomObjects

`-RemoveParameterValidation` strips `[Validate*]` only — it does not strip type constraints. `Register-ScheduledTask` requires real `CimInstance` objects for `Action`, `Trigger`, `Settings`, `Principal`. A `PSCustomObject` always fails.

```powershell
# WRONG
Mock New-ScheduledTaskAction { return [PSCustomObject]@{ Execute = $Execute } }
Mock Register-ScheduledTask -RemoveParameterValidation 'Action','Trigger','Settings','Principal' { ... }

# CORRECT — let builder cmdlets run real; only mock the persistence layer
Mock Register-ScheduledTask { ... }
Mock Get-ScheduledTask { ... }
Mock Unregister-ScheduledTask { ... }
```

**Rule:** Never mock `New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`, `New-ScheduledTaskSettingsSet`, or `New-ScheduledTaskPrincipal`. See AG8-007 in `SingleFile.Tests.ps1` for the canonical pattern.

**Known violation:** `TaskScheduler.Tests.ps1` lines ~423 and ~433 mock `New-ScheduledTaskPrincipal` returning `PSCustomObject` — a legacy outlier. Do not replicate this pattern.

## WRONG 9 — Module-qualified calls to escape Pester interception

Pester 5 intercepts `ScheduledTasks\New-ScheduledTaskAction`. Attempting to call the real cmdlet from inside a mock body via module qualification causes infinite recursion.

**Rule:** No escape from Pester mocking via module qualification. If real cmdlet behavior is needed, do not mock the cmdlet.

## WRONG 10 — `<token>` syntax in test names outside `-ForEach`

Pester 5 expands `<key>` as a template variable. Under `Set-StrictMode -Version Latest` (set by `Invoke-Tests.ps1`, inherited by all test files) an undefined `$key` aborts the entire describe block.

```powershell
# WRONG — aborts describe block under StrictMode
It 'Should set task_name to DailyMotivation_<id> format' { ... }

# CORRECT
It 'Should set task_name to DailyMotivation_ followed by a 16-char hex id' { ... }
```

**Rule:** No `<token>` in test names unless the token is a `-ForEach` data key in scope.
