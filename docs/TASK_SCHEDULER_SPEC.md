# Task Scheduler Specification

## Overview
The Task Scheduler Module wraps Windows Task Scheduler to create, query, and delete scheduled tasks without user interaction with the Task Scheduler UI.

## Task Properties

| Property | Value |
|----------|-------|
| Task Name | `DailyMotivation_{uuid}` |
| Trigger | Daily, one-time, at 14:00 the next calendar day |
| Action | `cmd.exe /c LaunchMotivation.bat` |
| Run Level | Limited (no elevation required) |
| Logon Type | Interactive (runs only when user is logged in) |
| Recovery | On missed trigger: run at next login |

## Missed Trigger Behavior
If the machine is off or asleep at 2 PM:
- Task runs at next user logon on the same day
- If the day has passed, the task is marked expired and user is notified

## API Wrapper
The module must expose:
- `CreateTask(folder_path: string) -> task_id: string`
- `ListTasks() -> List[ScheduledTask]`
- `DeleteTask(task_id: string) -> bool`
- `GetTaskStatus(task_id: string) -> TaskStatus`

## Security
- Tasks run under the current user's account only
- No SYSTEM or Administrator privileges required
- Execution policy bypass is scoped to this task only

## Status
> DRAFT
