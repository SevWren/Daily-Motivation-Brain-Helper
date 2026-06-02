# Motivation System Specification

## Overview
The Motivation System manages the library of motivational messages displayed in popups.

## Default Message Library
A set of built-in messages ships with the application. These cannot be deleted but can be disabled.

## Message Selection
- By default, a random message is selected from the active message pool at task creation time
- The selected message is stored with the task (not re-randomized at display time)

## User-Managed Messages
- Users can add custom messages via the main UI (v1.1+)
- Users can edit or delete custom messages
- Built-in messages are read-only

## Message Format
```json
{
  "glyph": "⚡",
  "title": "Time to Show Up",
  "body": "Every great outcome starts with showing up."
}
```

## Constraints
- Title: max 60 characters
- Body: max 200 characters
- Glyph: single emoji or ASCII symbol

## Status
> DRAFT
