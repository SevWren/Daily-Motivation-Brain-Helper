# Data Model

## ScheduledTask

| Field | Type | Description |
|-------|------|-------------|
| task_id | string (UUID) | Unique identifier |
| folder_path | string | Absolute Windows path to folder |
| scheduled_time | datetime | ISO 8601 — always 14:00 next day |
| created_at | datetime | When the task was created |
| status | enum | PENDING, COMPLETED, SNOOZED, DELETED |
| snooze_count | integer | Number of times snoozed (informational) |

## MotivationalMessage

| Field | Type | Description |
|-------|------|-------------|
| message_id | string (UUID) | Unique identifier |
| glyph | string | Icon/emoji for popup header |
| title | string | Popup title (max 60 chars) |
| body | string | Message body (max 200 chars) |
| is_default | boolean | Whether this is a built-in message |
| created_at | datetime | When the message was added |

## AppConfig (popup_config.json)

| Field | Type | Description |
|-------|------|-------------|
| glyph | string | Current popup glyph |
| title | string | Current popup title |
| body | string | Current popup body |
| explorer_path | string | Folder path for current active task |

## Storage
All data persisted locally in `%APPDATA%\DailyMotivationBrainHelper\` as JSON files. User never interacts with these files directly.

## Status
> DRAFT
