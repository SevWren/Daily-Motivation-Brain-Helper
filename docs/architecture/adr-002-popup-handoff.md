# ADR-002: File-based popup handoff (PopupConfig)

## Status

Accepted

## Context

Main mode (or setfolder mode) schedules work and then exits. At trigger time, Task Scheduler starts a **new process** in popup mode. The two processes do not share memory.

## Decision

Use `%APPDATA%\DailyMotivationBrainHelper\popup_config.json` as the sole handoff channel:

- Writers: main mode / setfolder mode via `Set-PopupConfig`
- Reader: popup mode via `Get-PopupConfig`
- Writes serialized with mutex `Global\DailyMotivationPopupConfigLock`

The OS Task action is always `DailyMotivation.exe /popup` (not embedding the folder path on the command line).

## Consequences

### Positive

- Survives process boundaries cleanly
- Avoids long command lines and quoting issues for folder paths
- Easy to inspect during debugging

### Negative

- Last write wins if multiple schedules race (mitigated by task model and config lock)
- Must keep JSON schema documented and backward compatible where aliases exist

## Alternatives considered

- Pass folder path as CLI args to `/popup` — rejected (escaping, length, privacy in process lists)
- Named pipes / IPC server — rejected as overkill for one-shot notifications
