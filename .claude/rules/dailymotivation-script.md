---
description: WPF, resource cleanup, and ExePath rules — loads when editing the main script
paths:
  - "DailyMotivation.ps1"
---

# DailyMotivation.ps1 — WPF and Resource Rules

> Binding on all agents and contributors. See [ADR-005](docs/architecture/adr-005-mandate-history.md) for incident history.

## WRONG 2 — Calling `.Dispose()` on a WPF `System.Windows.Window`

`System.Windows.Window` does not implement `IDisposable`. Calling it throws:
```
Method invocation failed because [System.Windows.Window] does not contain a method named 'Dispose'.
```
**Rule:** Use `.Close()` on windows. For all other objects, guard with `$obj -is [System.IDisposable]` before `.Dispose()`. `DriveInfo` is not IDisposable.

## WRONG 3 — Removing `$script:*` variables without checking all call sites

**Rule:** Grep the entire file for every reference before removing any `$script:*` variable. A variable with no obvious callers in the happy path may still be a required fallback (e.g. `$script:ConfigDefaults`).

## CORRECT — WPF window and resource cleanup

```powershell
$window.Close()                                              # windows: Close(), never Dispose()
if ($null -ne $timer)  { try { $timer.Stop(); $timer.Dispose() } catch {} }
if ($null -ne $mutex)  { try { $mutex.Dispose() } catch {} }
if ($null -ne $dialog) { try { $dialog.Dispose() } catch {} }
# XmlNodeReader ($reader): always dispose in a finally block
#   finally { if ($reader) { $reader.Dispose() } }
# $window.Dispose()    <- WRONG: no such method on System.Windows.Window
# $driveInfo.Dispose() <- WRONG: DriveInfo is not IDisposable
```

## CORRECT — ExePath resolution for ps2exe compiled executables

ps2exe may leave `$MyInvocation.MyCommand.Path` empty or as a `.ps1` path at runtime:

```powershell
$script:ExePath = $MyInvocation.MyCommand.Path
if (-not $script:ExePath -or $script:ExePath -notmatch '\.exe$') {
    $script:ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
}
```

The fallback triggers on empty path **or** non-`.exe` extension. Guard `Register-ContextMenu` to reject `.ps1` paths — the context-menu verb must point to the compiled `.exe`, not the source script.

## Runtime compatibility

Compiled exe targets .NET Framework 4.x. Avoid PS7-only syntax in runtime code paths:
- `??` null-coalescing operator
- `?.` null-conditional operator
- Ternary `condition ? a : b`
- `Join-String` cmdlet
- `ForEach-Object -Parallel`
