# Data Model

**Last Updated:** 2026-06-03

## ScheduledTask

| Field | Type | Description |
|-------|------|-------------|
| task_id | string (UUID) | Unique identifier |
| folder_path | string | Absolute Windows path to folder |
| folder_name | string | Leaf directory name (Split-Path -Leaf) |
| scheduled_time | datetime | ISO 8601 — caller-specified (today or tomorrow @ 14:00) |
| created_at | datetime | When the task was created |
| status | enum | PENDING, COMPLETED, SNOOZED, DISMISSED, DELETED |
| snooze_count | integer | Number of times snoozed |
| snooze_duration_minutes | integer | Most recently used snooze duration (5/15/30/60) |

**Updated (B-03):** `scheduled_time` is no longer always next-day; it is caller-specified.
**Updated (B-10):** Added `snooze_duration_minutes`.
**Updated (B-11):** Added `DISMISSED` to status enum.

---

## MotivationalMessage

| Field | Type | Description |
|-------|------|-------------|
| message_id | string (UUID) | Unique identifier |
| glyph | string | Icon/emoji for popup header |
| title | string | Popup title (max 60 chars) |
| body | string | Message body (max 200 chars) |
| is_default | boolean | True for built-in messages (read-only) |
| created_at | datetime | When added |

---

## popup_config.json

| Field | Type | Description |
|-------|------|-------------|
| glyph | string | Current popup glyph |
| title | string | Current popup title |
| body | string | Current popup body |
| explorer_path | string | Full folder path |
| folder_name | string | Leaf folder name for popup subtitle (B-12) |
| task_id | string | Owning task ID (for snooze re-trigger lookup) |

**New (B-12):** `folder_name` field.

---

## app_settings.json

| Field | Type | Description |
|-------|------|-------------|
| firstRun | boolean | True until user dismisses welcome overlay (B-07) |
| lastFolder | string | Path of most recently scheduled folder (B-01) |
| recentFolders | string[] | Up to 5 recently scheduled folder paths, newest first (B-02) |
| theme | string | Reserved for future use |

**New (B-07):** `firstRun` field.
**New (B-01):** `lastFolder` field.
**New (B-02):** `recentFolders` array.

---

## popup_log.txt — Structured Log Entry Format

Each line is pipe-delimited for machine parsing by the History Viewer (B-18):

```
[YYYY-MM-DD HH:mm:ss] | task_id | folder_name | folder_path | outcome | snooze_count
```

**Example:**
```
[2026-06-03 14:00:12] | a1b2c3 | ClientA | D:\Projects\ClientA | Opened | 0
[2026-06-03 14:35:07] | d4e5f6 | mc_game | D:\Github\mc_game | Snoozed | 3
[2026-06-03 14:00:00] | g7h8i9 | OldProject | D:\Archive\Old | Dismissed | 1
```

**New (B-18):** Structured format replaces free-text log entries.

---

## Storage Locations

| File | Path |
|------|------|
| popup_config.json | `%APPDATA%\DailyMotivationBrainHelper\popup_config.json` |
| tasks.json | `%APPDATA%\DailyMotivationBrainHelper\tasks.json` |
| messages.json | `%APPDATA%\DailyMotivationBrainHelper\messages.json` |
| app_settings.json | `%APPDATA%\DailyMotivationBrainHelper\app_settings.json` |
| popup_log.txt | `%APPDATA%\DailyMotivationBrainHelper\popup_log.txt` |

## Status
> v1.1 DRAFT
