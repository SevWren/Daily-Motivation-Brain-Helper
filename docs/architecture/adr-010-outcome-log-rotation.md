# ADR-010: Outcome Log Rotation at 1 MB with 30-Day Archive Retention

The Outcome Log is append-only and grows without bound unless rotated. Two
thresholds must be chosen: when to rotate and how long to keep archives.

## Decision

- **Rotate when `popup_log.txt` exceeds 1 MB** — create a timestamped archive
  (`popup_log.txt.archive_{yyyyMMdd_HHmmss}`) and start a fresh active log.
- **Delete archives older than 30 days** — keeps roughly one month of history.

At ~50 bytes per record, 1 MB holds approximately 20 000 records — several months
of daily popup interactions for a typical user. 30 days of archived history covers
the window where users are likely to investigate past behavior or share logs for
debugging.

## Considered Options

- **No rotation** — unbounded disk growth; unacceptable
- **Per-day rotation** — 30 daily files; harder to query and manage
- **Fixed record-count window** — loses timestamp continuity; harder to correlate with calendar dates
- **User-configurable thresholds** — unnecessary complexity for current usage patterns

## Consequences

Records older than 30 days are permanently deleted. If longer-term analytics are
ever needed, the rotation policy must be revisited. The 1 MB threshold is not
user-configurable; changing it requires a code change.

## Evidence

`DailyMotivation.ps1` lines 451–462 (rotation and archive deletion logic).
