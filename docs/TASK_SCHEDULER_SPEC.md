# Task Scheduler Specification

**Last Updated:** 2026-06-03

## Overview
The Task Scheduler Module wraps Windows Task Scheduler to create, query, and delete scheduled tasks without user interaction with the Task Scheduler UI.

## Module API

```powershell
# Create a new scheduled task
New-MotivationTask -FolderPath <string> -TriggerTime <datetime> -> task_id: string

# List all active tasks
Get-MotivationTasks -> ScheduledTask[]

# Delete a task by ID
Remove-MotivationTask -TaskId <string> -> bool

# Get status of a specific task
Get-MotivationTaskStatus -TaskId <string> -> TaskStatus
```

**Updated (B-03):** `New-MotivationTask` accepts an explicit `TriggerTime` parameter. The caller determines whether to schedule for today or tomorrow. The module does not hardcode "tomorrow at 14:00."

## Pre-Conditions for New-MotivationTask (B-16)

Before registering a new task, the module MUST:
1. Call `Get-MotivationTasks` and filter for tasks where `folder_path -eq $FolderPath` AND `scheduled_time.Date -eq $TriggerTime.Date` AND `status -eq 'PENDING'`
2. If any match found: return a `[DuplicateTaskWarning]` result to the caller — do NOT create the task
3. The caller (Main App) is responsible for displaying the warning dialog and optionally retrying with `Force=$true`

## Task Properties

| Property | Value |
|----------|-------|
| Task Name | `DailyMotivation_{task_id}` |
| Trigger | One-time, at caller-specified `TriggerTime` |
| Action | `cmd.exe /c "%APPDATA%\DailyMotivationBrainHelper\LaunchMotivation.bat"` |
| Run Level | Limited (no elevation required) |
| Logon Type | Interactive |
| Run At Logon If Missed | True (NPR-004 recovery) |

## Snooze Re-Trigger (B-10)

When snooze is activated in `DailyMotivation.ps1`:
```powershell
$snoozeTime = (Get-Date).AddMinutes($selectedDuration)
New-MotivationTask -FolderPath $config.explorer_path -TriggerTime $snoozeTime
```
The new snooze task inherits the same `folder_path` and `popup_config.json` content as the parent task.

## Shell Extension Consumer (B-13)

`ShellBridge.ps1` is a thin consumer of this module:
```powershell
Import-Module TaskScheduler.psm1
$tomorrow = (Get-Date).Date.AddDays(1).AddHours(14)
New-MotivationTask -FolderPath $args[0] -TriggerTime $tomorrow
```
The shell extension invokes `ShellBridge.ps1` with the right-clicked folder path as `$args[0]`.

## Security
- Tasks run under current user account only (no SYSTEM or Administrator)
- ExecutionPolicy bypass scoped to this task only

## Status
> v1.1 DRAFT
