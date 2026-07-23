# Configuration and data files

All runtime state lives under:

```text
%APPDATA%\DailyMotivationBrainHelper\
```

Resolved at call time by `Initialize-AppData` from `$env:APPDATA` (tests redirect this).

## `config.json` (AppConfig)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `default_trigger_hour` | int 0–23 | `14` | Hour used when scheduling Today/Tomorrow |
| `task_warning_threshold` | int ≥ 0 | `5` | UI warning when task count is high |

Invalid values are reset to defaults on read. File size &gt; 50KB yields schema-only defaults. Saves use write-to-temp then move.

Example:

```json
{
  "default_trigger_hour": 9,
  "task_warning_threshold": 5
}
```

## `popup_config.json` (PopupConfig / Handoff)

Written by main/setfolder; read by popup.

| Key | Description |
|-----|-------------|
| `glyph` | Message glyph, e.g. `[+]` |
| `title` | Message title |
| `body` | Message body |
| `explorer_path` | Folder path to open (**preferred**) |
| `folder_name` | Display name |
| `task_id` | MotivationTask id |
| `folder_path` | Alias of `explorer_path` (written by `Set-PopupConfig`) |
| `message_glyph` / `message_title` / `message_body` | Aliases of glyph/title/body |

Always read `explorer_path` for the folder path.

## `tasks.json`

JSON array of MotivationTask objects:

| Field | Description |
|-------|-------------|
| `task_id` | 16-char hex id |
| `task_name` | OS task name `DailyMotivation_{task_id}` |
| `folder_path` | Selected folder |
| `folder_name` | Leaf name for display |
| `scheduled_time` | `yyyy-MM-ddTHH:mm:ss` |
| `created_at` | ISO-8601 creation time |
| `status` | `PENDING`, `DELETED`, `COMPLETED`, `FAILED` (else normalized to `UNKNOWN`) |
| `snooze_count` | Always `0` on the persisted record; live count is session-only |

## `popup_log.txt` (Outcome Log)

Pipe-delimited lines:

```text
[yyyy-MM-dd HH:mm:ss] | {task_id} | {folder_name} | HASH:{sha256_hex} | {Outcome} | {snooze_count}
```

| Outcome | Meaning |
|---------|---------|
| `Opened` | User (or countdown) opened the folder |
| `Snoozed` | User snoozed |
| `Dismissed` | Dismiss for Today |
| `PathMissing` | Path gone; closed without recovery |

Rotation: file &gt; 1MB → archive `popup_log.txt.archive_yyyyMMdd_HHmmss`; delete archives older than 30 days.

## Environment variables

| Variable | Use |
|----------|-----|
| `APPDATA` | AppData root (required on Windows; redirected in tests) |
| `TEMP` / `TMPDIR` | Temp directory resolution |
| `USERNAME` | Popup mutex name component |

## Mutexes

| Name | Purpose |
|------|---------|
| `Global\DailyMotivationBrainHelperPopup_{USERNAME}_{SessionId}` | Single popup per user session |
| `Global\DailyMotivationPopupConfigLock` | Serialize popup config writes |
