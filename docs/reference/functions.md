# Function reference

All 32 public functions defined in `DailyMotivation.ps1`. Functions are grouped by script section (see [CLAUDE.md](../../CLAUDE.md) Script Sections table).

Domain terminology: [CONTEXT.md](../../CONTEXT.md). Config schemas: [config.md](config.md). CLI: [cli.md](cli.md).

---

## Section 2 — Platform and assembly initialization

| Function | Purpose |
|----------|---------|
| `Initialize-WindowsAssemblies` | Load WPF/WinForms assemblies; skipped under HeadlessPlatform |

## Section 2.5 — Platform abstraction

`$script:Platform` — set to `$null` in production (uses real Windows APIs); inject a HeadlessPlatform-compatible object in tests to mock scheduling and dialogs. See [ADR-003](../architecture/adr-003-platform-adapter.md).

## Section 3 — Config and logging

| Function | Purpose |
|----------|---------|
| `Initialize-AppData` | Create `%APPDATA%\DailyMotivationBrainHelper\` and set ACL; re-resolves path from `$env:APPDATA` at call time (enables test redirects) |
| `Get-Config` | Read `config.json`; returns defaults on missing/corrupt file; rejects files > 50KB |
| `Save-Config` | Write `config.json` via temp-file-then-move |
| `Get-PopupConfig` | Read `popup_config.json` (Handoff); prefer `explorer_path` key for folder path |
| `Set-PopupConfig` | Write `popup_config.json` under `Global\DailyMotivationPopupConfigLock` mutex; writes both canonical keys and compatibility aliases |
| `Write-OutcomeLog` | Append pipe-delimited outcome record to `popup_log.txt`; stores folder path as `HASH:{sha256}`; rotates at 1MB |
| `Get-SafeErrorMessage` | Sanitize exception messages for user-facing display |
| `Show-ErrorDialog` | Show a modal error dialog with sanitized message |
| `Show-InfoDialog` | Show a modal informational dialog |

## Section 4 — Task management

| Function | Purpose |
|----------|---------|
| `Get-TasksJson` | Read `tasks.json`; wraps result in `@()` for consistent array handling; normalizes unknown statuses to `UNKNOWN` |
| `Save-TasksJson` | Write `tasks.json` |
| `New-MotivationTask` | Create a MotivationTask record, register OS Task in Windows Task Scheduler, write PopupConfig; enforces duplicate detection (same FolderPath + same date); accepts `-Force` to override |
| `Sync-TaskStatuses` | Refresh task statuses by checking whether corresponding OS Tasks still exist in Task Scheduler; sets status to `DELETED` for missing tasks |
| `Get-MotivationTasks` | Return all MotivationTask records from `tasks.json` |
| `Remove-MotivationTask` | Remove a MotivationTask record and unregister its OS Task |

## Section 4.5–5 — UI helpers and scheduling

| Function | Purpose |
|----------|---------|
| `Get-ScheduleTime` | Calculate the TriggerTime datetime given Today/Tomorrow and the configured trigger hour |
| `Update-TaskListUI` | Refresh the task list display in the Main Window |
| `Get-HistoryData` | Read and parse the last 30 entries from the Outcome Log |
| `Update-HistoryUI` | Refresh the history panel in the Main Window |
| `Start-UndoTimer` | Start the undo countdown after a successful schedule |
| `Stop-UndoTimer` | Cancel the undo countdown |
| `Set-SnoozeDuration` | Set the selected snooze duration (5/15/30/60 min) in the Popup |
| `Invoke-FolderScheduling` | Orchestrate the full schedule flow: validate path, call `New-MotivationTask`, show confirmation, start undo timer |

## Section 5 — Context menu

| Function | Purpose |
|----------|---------|
| `Register-ContextMenu` | Write HKCU shell extension verb for "Set as tomorrow's folder"; idempotent (uses `New-Item -Force`); rejects non-`.exe` paths and System32 paths |
| `Unregister-ContextMenu` | Remove HKCU shell extension verb |

## Section 6–7 — Main window

| Function | Purpose |
|----------|---------|
| `Show-MainWindow` | Build and show the WPF main window (main mode entry point); folder picker, task list, history panel, undo banner |

## Section 8–9 — Popup window

| Function | Purpose |
|----------|---------|
| `Show-PopupWindow` | Build and show the popup (popup mode entry point); acquires per-user/session mutex `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}`; reads PopupConfig; starts countdown; handles Open Folder / Snooze / Dismiss / PathMissing |

## Section 10 — Text helpers

| Function | Purpose |
|----------|---------|
| `Escape-XmlText` | Escape special characters for safe XAML embedding |
| `Truncate-TextForDisplay` | Truncate a string to a max length with ellipsis |
| `Strip-MarkupText` | Remove markup characters from a string for plain-text display |
| `Get-RandomMessage` | Return a randomly selected Message object (Glyph, Title, Body) from the `$Messages` array |

---

## Notes

- All functions that use `$env:APPDATA` paths do so via `Initialize-AppData` — never hardcode the path directly.
- Tests override `$script:ExePath` before calling `New-MotivationTask`.
- Load functions without running the app using: `. .\DailyMotivation.ps1 -NoRun`
