# Configuration Specification

**Last Updated:** 2026-06-03

## Overview
All application configuration is stored in JSON files managed exclusively by the application. The user never edits these files.

## File Locations

| File | Path | Purpose |
|------|------|---------|
| popup_config.json | `%APPDATA%\DailyMotivationBrainHelper\popup_config.json` | Active task config for popup script |
| tasks.json | `%APPDATA%\DailyMotivationBrainHelper\tasks.json` | All scheduled tasks |
| messages.json | `%APPDATA%\DailyMotivationBrainHelper\messages.json` | Message library |
| app_settings.json | `%APPDATA%\DailyMotivationBrainHelper\app_settings.json` | User preferences and state |
| popup_log.txt | `%APPDATA%\DailyMotivationBrainHelper\popup_log.txt` | Structured outcome log |

## popup_config.json Schema
```json
{
  "glyph": "string",
  "title": "string",
  "body": "string",
  "explorer_path": "string (absolute Windows path)",
  "folder_name": "string (leaf name only — B-12)",
  "task_id": "string (UUID — for snooze lookup)"
}
```
**New (B-12):** `folder_name` — leaf directory name displayed as popup subtitle.

> **Test validation:** Schema fully covered in `Tests/Unit/ConfigManager.Tests.ps1` -- `Set-PopupConfig` tests.
> Any schema change must update corresponding test cases.

## app_settings.json Schema
```json
{
  "firstRun": true,
  "lastFolder": "string (absolute path — B-01)",
  "recentFolders": ["path1", "path2", "path3"],
  "theme": "dark"
}
```
**New (B-07):** `firstRun` — set to `false` after welcome overlay is dismissed.
**New (B-01):** `lastFolder` — path of last successfully scheduled folder.
**New (B-02):** `recentFolders` — array of up to 5 paths, FIFO, newest first.

> **Test validation:** Schema fully covered in `Tests/Unit/ConfigManager.Tests.ps1` -- settings and recent-folders tests.
> Any schema change must update corresponding test cases.

## popup_log.txt Format
Pipe-delimited, one entry per line (B-18):
```
[YYYY-MM-DD HH:mm:ss] | task_id | folder_name | folder_path | outcome | snooze_count
```
Outcomes: `Opened`, `Snoozed`, `Dismissed`, `PathMissing`

> **Test validation:** Log format fully covered in `Tests/Unit/ConfigManager.Tests.ps1` -- `Get-OutcomeLog` tests.
> Any format change must update corresponding test cases.

## Encoding
All JSON files saved as UTF-8 with BOM for PowerShell 5.1 compatibility.

## Initialization
`ConfigManager.psm1` exposes `Initialize-AppData` which creates the `%APPDATA%\DailyMotivationBrainHelper\` directory and all JSON files with defaults if they do not exist. Called at every app startup.

## Migration
Future versions must support reading older config formats and migrating forward automatically.

## Status
> v1.1 DRAFT
