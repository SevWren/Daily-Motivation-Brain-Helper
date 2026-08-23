# ADR-008: Outcome Log Stores SHA-256 Path Digests, Not Plaintext

Folder paths in `popup_log.txt` are stored as SHA-256 hex digests prefixed with
`HASH:` rather than as plaintext. Log files are routinely shared for debugging;
plaintext paths expose sensitive directory structures (e.g.,
`C:\Users\Alice\CompanyName\ProjectX\Confidential`).

## Decision

Write `HASH:{sha256hex}` in place of the FolderPath field in every Outcome Log
record. Use `HASH:NO_PATH` when the path is null or empty.

`tasks.json` and `popup_config.json` continue to store plaintext FolderPath - 
both are functional data required at runtime and are not shared for debugging.
Only the append-only audit log hashes the path, since that log has no operational
need to recover the original value.

## Considered Options

- **Plaintext** - simple but leaks sensitive paths in shared logs
- **AES encryption** - reversible but the key would have to live alongside the log, defeating the purpose
- **Path abbreviation** - insufficient for uniqueness; still reveals folder names

SHA-256 is one-way (irreversible), universally available, and fast. The tradeoff
is that Outcome Log records cannot reconstruct the original path; `tasks.json`
must be consulted separately if the path is needed.

## Evidence

`DailyMotivation.ps1` lines 436–444 (hash generation and log entry format).
Outcome Log format: `CONTEXT.md` Outcome Log section.
