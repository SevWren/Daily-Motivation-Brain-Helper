# CLI and execution modes

## Parameters (`DailyMotivation.ps1` / exe)

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Mode` | `string` | `main` | `ValidateSet`: `main`, `/popup`, `/setfolder` |
| `FolderPath` | `string` | `""` | Required for meaningful setfolder use; validated against leading `*?<>|` |
| `NoRun` | `switch` | off | Define functions only; skip entry point (tests) |

When compiled, positional CLI arguments map to `Mode` (and folder path for setfolder).

## Invocations

| Command | Mode | Behavior |
|---------|------|----------|
| `DailyMotivation.exe` | `main` | Main WPF window |
| `DailyMotivation.exe /popup` | `"/popup"` | Popup UI (Task Scheduler) |
| `DailyMotivation.exe /setfolder "C:\path\to\folder"` | `"/setfolder"` | Schedule folder for tomorrow at default hour; MessageBox confirmation |
| `pwsh .\DailyMotivation.ps1 -NoRun` | n/a | Test load only |

### Important: slash-prefixed modes

ps2exe binds `/popup` as the string `"/popup"`. Comparisons must use the slash form:

```powershell
# Correct
if ($Mode -eq '/popup') { }

# Incorrect — never matches compiled CLI
if ($Mode -eq 'popup') { }
```

## Task Scheduler action

Registered OS tasks run:

```text
"<ExePath>" /popup
```

Exe path is captured at schedule time (`$script:ExePath` / `$MyInvocation.MyCommand.Path`). Tests override `$script:ExePath` before `New-MotivationTask`.

## Context menu command

Registry (HKCU):

```text
HKCU\Software\Classes\Directory\shell\ScheduleMotivation
HKCU\Software\Classes\Directory\shell\ScheduleMotivation\command
```

Command value shape:

```text
"<ExePath>" /setfolder "%1"
```

Display name: `Set as tomorrow's folder (Daily Motivation)`.

## Build script

```powershell
.\build.ps1
.\build.ps1 -WhatIf   # ShouldProcess support
```

No additional parameters; input/output paths are fixed relative to the repo root.

## Test runner

See [../testing/strategy.md](../testing/strategy.md) for `Invoke-Tests.ps1` parameters.
