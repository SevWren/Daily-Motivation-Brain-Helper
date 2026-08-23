# ADR-009: Dual-Mutex Strategy - Per-User Popup Mutex and Global Config Lock

Two independent mutexes control concurrency. A single global mutex would require
SYSTEM-level ownership (elevation); user-scoped mutexes let unprivileged users
protect their own sessions without admin rights.

## Decision

**Popup mutex** - `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}`

User + session scoped. Ensures only one Popup is visible per user session.
Prevents cross-user DoS (a malicious task cannot flood another user's desktop)
without requiring elevation. Each user on a shared machine may have one active
popup simultaneously.

**Config lock** - `Global\DailyMotivationPopupConfigLock`

Global, unscoped. Serializes writes to `popup_config.json`. A 2-second timeout
prevents indefinite blocking. Last-write-wins is acceptable here because only one
config file is ever written and readers always take the most recent value.

## Considered Options

- **Single global mutex with SYSTEM ownership** - requires elevation; incompatible with standard user installs
- **No mutex / optimistic concurrency** - risks torn reads of `popup_config.json` and duplicate popups
- **File-level locks** - PowerShell lacks portable `flock`-style semantics; fragile across PS versions

## Consequences

If a writer holds the config lock and crashes, the 2-second timeout unblocks
subsequent writers. The popup mutex is session-scoped, so a reboot (new session
ID) naturally releases it.

## Evidence

`DailyMotivation.ps1` line 389 (config lock name), lines 2433–2435 (popup mutex
name construction). Mutex naming documented in `CONTEXT.md` Mutex section.
