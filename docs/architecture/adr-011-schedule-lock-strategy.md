# ADR-011: Schedule Lock - Third Mutex for Atomic Task Lifecycle Operations

A third named mutex, `Global\DailyMotivationScheduleLock`, was added to make the
full read-modify-save cycle atomic across the three functions that mutate
`tasks.json`: `New-MotivationTask`, `Sync-MotivationTasks`, and
`Remove-MotivationTask`. ADR-009 covers the Popup mutex and Config lock; this
decision extends that strategy to a third mutex and supersedes the "dual" framing
in ADR-009's title.

## Decision

A single coarse `Global\DailyMotivationScheduleLock` spans the entire operation in
each mutating function - from the initial `Get-TasksJson` read through the final
`Save-TasksJson` write. This makes Duplicate detection, reconciliation, and removal
atomic with respect to each other and with respect to concurrent Schedule calls
(e.g., main mode and setfolder mode running simultaneously on the same machine).

Fine-grained per-step locking was rejected because holding both the ScheduleLock
and the Config lock in sequence would create a lock-ordering dependency. If
acquisition order were ever inverted across call sites, the result would be a
deadlock with no timeout escape. A single coarse lock eliminates the ordering
problem at the cost of holding the lock slightly longer per operation.

## Considered Options

- **Fine-grained per-step locks** - reduces contention window but introduces a
  deadlock risk between ScheduleLock and Config lock if acquisition order diverges
  across call sites
- **File-level optimistic concurrency** - PowerShell lacks portable atomic
  compare-and-swap for file writes; concurrent Schedule calls would produce
  interleaved `tasks.json` writes
- **Serialise all scheduling through a background job** - unnecessary complexity
  for the expected concurrency level (one user, occasional overlapping invocations)

## Consequences

The lock is held for the duration of the read-modify-save cycle, which includes OS
Task registration via `Register-ScheduledTask`. That call is synchronous and may
block for several seconds. A 10-second `WaitOne` timeout is used on acquisition; if
the lock cannot be acquired within that window, the operation proceeds without it
(degraded safety, not a deadlock).

## Evidence

`DailyMotivation.ps1` lines 798-805 (`New-MotivationTask`), lines 1077-1080
(`Sync-MotivationTasks`), lines 1205-1208 (`Remove-MotivationTask`). CONTEXT.md
Mutex section updated to list all three mutexes.
