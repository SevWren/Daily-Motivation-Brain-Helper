# ADR-012: TriggerTime Storage Format - K Specifier (Local + UTC Offset)

TriggerTime values in `tasks.json` use the `yyyy-MM-ddTHH:mm:ssK` format. Two
more obvious alternatives - the round-trip `"o"` specifier and UTC-always - were
rejected for reasons not visible in the code.

## Decision

Serialize TriggerTime as Local time with UTC offset suffix using the `K` specifier
(e.g., `2026-08-27T14:00:00+10:00`). This preserves the user's intended local
fire time while remaining unambiguous for parsing.

## Considered Options

- **`"o"` (round-trip specifier)** - produces fractional seconds
  (e.g., `2026-08-27T14:00:00.0000000+10:00`). .NET Framework 4.x (the ps2exe
  compile target) and .NET 6+ produce different fractional-second representations
  of the same moment, causing `[datetime]::Parse` to return different values in
  the compiled Exe vs. PowerShell 7 tests. `K` omits fractional seconds and
  eliminates the divergence entirely.
- **UTC-always (`Z` suffix)** - requires converting user-chosen local times to UTC
  at write time and back to local for display. All existing `tasks.json` files
  store Local+offset; migrating to UTC-always has no rollback path. Windows Task
  Scheduler accepts local time natively, making UTC conversion a round-trip with
  no benefit.

## Consequences

TriggerTime values are not portable across timezone changes. If a user moves to a
different timezone, existing tasks will fire at the original wall-clock hour in the
new timezone. This is intentional: "schedule at 14:00" means 14:00 wherever the
user is when the Popup fires.

Changing this format requires a `tasks.json` migration. There is no
backward-compatible path.

## Evidence

`DailyMotivation.ps1` TriggerTime serialization. Commits `6542e47`
(DateTimeKind Unspecified normalized to Local before K serialization) and
`b5f26ab` (sub-second tick mismatch between .NET Framework 4.x and .NET 6+
exposed in tests). Test files `AG18-024.Tests.ps1` and `AG20-011.Tests.ps1`.
