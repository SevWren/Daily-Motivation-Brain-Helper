# Configuration Specification

## Overview
All application configuration is stored in JSON files managed exclusively by the application. The user never edits these files.

## File Locations

| File | Path | Purpose |
|------|------|---------|
| popup_config.json | `{app_dir}\popup_config.json` | Active task config for popup script |
| tasks.json | `%APPDATA%\DailyMotivationBrainHelper\tasks.json` | All scheduled tasks |
| messages.json | `%APPDATA%\DailyMotivationBrainHelper\messages.json` | Message library |
| app_settings.json | `%APPDATA%\DailyMotivationBrainHelper\app_settings.json` | User preferences |

## popup_config.json Schema
```json
{
  "glyph": "string",
  "title": "string",
  "body": "string",
  "explorer_path": "string (absolute Windows path)"
}
```

## Encoding
All JSON files must be saved as UTF-8 with BOM to ensure correct parsing by PowerShell 5.1.

## Migration
Future versions must support reading older config formats and migrating them forward automatically.

## Status
> DRAFT
