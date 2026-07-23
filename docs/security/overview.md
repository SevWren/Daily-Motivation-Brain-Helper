# Security overview

## Assets

| Asset | Location | Sensitivity |
|-------|----------|-------------|
| Selected folder paths | `tasks.json`, `popup_config.json` | Medium (local paths / work habits) |
| Outcome history | `popup_log.txt` | Lower (paths hashed) |
| Context menu command | HKCU registry | Medium (must point at trusted exe) |
| Motivational messages | in-script / popup config | Low |

## Trust boundary

The app runs **as the interactive user**. It does not require elevation. Compromise of the user account implies compromise of AppData and HKCU.

## Controls

### Path validation

`New-MotivationTask` rejects:

- Empty paths
- `..` traversal sequences
- Invalid characters `<>*?`
- Paths that cannot be normalized via `[IO.Path]::GetFullPath`

### Context menu registration

`Register-ContextMenu`:

- Only registers when `ExePath` ends with `.exe` (blocks registering the `.ps1` source)
- Rejects paths under `System32` / `SysWOW64`
- Uses HKCU only (no admin, no machine-wide keys)

### Popup isolation

- Mutex: `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}`
- Prevents multiple concurrent popups per user session and reduces cross-user interference

### Config write locking

`Set-PopupConfig` uses `Global\DailyMotivationPopupConfigLock` around atomic temp-file writes.

### Outcome log privacy

`Write-OutcomeLog` stores **SHA-256** of the folder path (`HASH:…`), not the plaintext path. Log rotates above 1MB; archives older than 30 days are removed.

### AppData ACLs

`Initialize-AppData` attempts to set an explicit FullControl ACL for the current user on the AppData directory.

### Error surfaces

`Get-SafeErrorMessage` / dialog helpers reduce leaking raw internal exception detail into user-facing UI where applied.

### Static analysis

CI runs PSScriptAnalyzer on `DailyMotivation.ps1` and a PS7-syntax gate for ps2exe-incompatible operators.

## Residual risks

- User can schedule any folder they can access; the app will open it in Explorer at trigger time
- Last writer to `popup_config.json` wins if concurrent schedules race
- Historical plaintext logs may exist from older builds before hashing

## Tests

See `Tests/Unit/Security.Tests.ps1` for automated coverage of key controls.
