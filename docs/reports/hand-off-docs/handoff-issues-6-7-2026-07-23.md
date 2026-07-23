# Handoff: Remaining Work for Issues #6 and #7

**Date**: 2026-07-23
**Branch**: `project-restart-pwsh7`
**Prepared by**: Multi-agent review system (Maton Tasks)
**Status**: Both issues are PARTIALLY RESOLVED — production logic is correct; two surface-level gaps remain in #6, one test gap remains in #7.

---

## Issue #6 — Silent exit behavior masks real initialization problems

**GitHub**: https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/6
**Overall status**: ⚠️ Partially resolved — 2 gaps remain.

### Background

Most silent-exit paths have already been replaced with user-facing dialogs (`Show-ErrorDialog`). The architecture comment at line 64 makes the intent explicit:
> "WPF and WinForms loads are split so WinForms can be used as a fallback error-display mechanism when WPF fails, instead of a silent hard exit."

Two paths were missed.

---

### Gap 1 — Entry-point `Initialize-AppData` call is unguarded

**File**: `DailyMotivation.ps1`
**Lines**: 3010–3013

**Current code** (line 3010):
```powershell
    Initialize-AppData          # ← bare call, no try/catch

    switch ($Mode) {
```

**Problem**: If both the primary (`%APPDATA%`) and fallback (`%TEMP%`) directory creation fail inside `Initialize-AppData`, it throws a terminating error. Because line 3010 has no surrounding `try/catch`, that exception propagates as an unhandled PowerShell runtime error — the user sees a raw, unsanitised stack trace rather than a custom dialog.

**Proposed fix**:
```powershell
    try {
        Initialize-AppData
    }
    catch {
        Show-ErrorDialog -Message "Failed to initialize application data: $($_.Exception.Message)" `
                         -Title "Startup Error"
        exit 1
    }

    switch ($Mode) {
```

**Notes**:
- `Show-ErrorDialog` (lines 474–522) already handles the case where WPF itself is not loaded — it falls back to WinForms MessageBox, then `Console.Error.WriteLine`. No additional guard needed.
- `exit 1` after the dialog is intentional — initialization failure is unrecoverable.
- This mirrors the existing pattern in `Initialize-WindowsAssemblies` (lines 82–93), which already wraps its failure path in exactly this way.

---

### Gap 2 — Popup mode XAML load failure is a silent `return`

**File**: `DailyMotivation.ps1`
**Lines**: ~2446–2459 (inside `Show-PopupWindow`)

**Current code**:
```powershell
    try {
        $reader = [System.Xml.XmlNodeReader]::new($PopupXaml)
        $window = [Windows.Markup.XamlReader]::Load($reader)
        if ($null -eq $window) {
            if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
            return   # ← silent, no log
        }
    }
    catch {
        if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
        return       # ← silent, no log
    }
```

**Problem**: If the popup XAML fails to load (corrupted .NET installation, resource issue), the application exits silently — no dialog, no log entry. The user has no indication that anything went wrong.

**Why it's tricky**: The `/popup` mode runs as a background scheduled task, so a full WPF dialog here could be disruptive. However, a log entry is always appropriate.

**Proposed fix** — add a `Write-Warning` (surfaces in the PowerShell error stream / event log if running as a scheduled task) before both `return` paths:
```powershell
    try {
        $reader = [System.Xml.XmlNodeReader]::new($PopupXaml)
        $window = [Windows.Markup.XamlReader]::Load($reader)
        if ($null -eq $window) {
            Write-Warning "Show-PopupWindow: XamlReader returned null — popup window could not be created."
            if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
            return
        }
    }
    catch {
        Write-Warning "Show-PopupWindow: Failed to load popup XAML — $_"
        if ($mutexOwned -and $mutex) { try { $mutex.ReleaseMutex() } catch {} }
        return
    }
```

**Why not `Show-ErrorDialog` here?** The popup runs headlessly as a scheduled task. Showing a dialog on every XAML failure (e.g., if .NET is degraded) would spawn a blocking dialog with no user session to dismiss it. `Write-Warning` is the correct level — it is visible in the scheduled task's execution log and in the PowerShell error stream without being intrusive.

---

### Acceptance criteria to close #6

- [ ] `Initialize-AppData` call at line 3010 is wrapped in `try/catch` → `Show-ErrorDialog` → `exit 1`
- [ ] Popup XAML `$null` path and `catch` path both emit `Write-Warning` before returning
- [ ] No other silent `return`/`exit` paths exist without at minimum a `Write-Warning` (run a grep: `grep -n "^\s*return\b" DailyMotivation.ps1` and audit each one)

---

## Issue #7 — %TEMP% fallback not used consistently across scripts

**GitHub**: https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/7
**Overall status**: ⚠️ Partially resolved — production logic is correct; unit test coverage for the fallback path is absent.

### Background

The production code is correct and consistent:

- **Line 37** — single canonical temp dir:
  ```powershell
  $script:TempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:TMPDIR) { $env:TMPDIR } else { "/tmp" }
  ```
- **Lines 176–189** (`Initialize-AppData`) — on primary directory creation failure, falls back to `$script:TempDir` and reassigns all 5 path variables:
  ```powershell
  catch {
      $fallback = Join-Path $script:TempDir "DailyMotivationBrainHelper"
      Write-Warning "Initialize-AppData: Could not create '$script:AppDataDir'. Falling back to '$fallback'."
      try {
          [void](New-Item -ItemType Directory -Path $fallback -Force -ErrorAction Stop)
          $script:AppDataDir   = $fallback
          $script:ConfigPath   = Join-Path $script:AppDataDir "config.json"
          $script:PopupCfgPath = Join-Path $script:AppDataDir "popup_config.json"
          $script:TasksPath    = Join-Path $script:AppDataDir "tasks.json"
          $script:LogPath      = Join-Path $script:AppDataDir "popup_log.txt"
      }
      catch {
          Write-Error "Initialize-AppData: Fallback directory '$fallback' also failed: $_"
          throw
      }
  }
  ```

The only gap is that **no unit test exercises this fallback branch**.

---

### Gap — No unit test for `%TEMP%` fallback path

**File**: `Tests/Unit/Config.Tests.ps1`

**What the existing tests do** (lines 57–114): They redirect `$env:APPDATA` to a fresh GUID-based writable temp path before calling `Initialize-AppData`. Directory creation always succeeds — the fallback branch at lines 176–189 is never reached.

**What is missing**: A test that forces directory creation to fail, then asserts:
1. `$script:AppDataDir` is set to a path under `$script:TempDir`
2. All config files are created under that fallback path
3. `$script:ConfigPath`, `$script:PopupCfgPath`, `$script:TasksPath`, `$script:LogPath` all resolve under the fallback dir

**Proposed test** — add to `Tests/Unit/Config.Tests.ps1` inside the existing `Describe 'Initialize-AppData'` block:

```powershell
Context 'When AppData directory creation fails (TEMP fallback)' {
    BeforeEach {
        # Point APPDATA at a path that cannot be created
        # (rooted under an existing read-only system path or a non-existent drive)
        $script:OriginalAppData = $env:APPDATA
        $env:APPDATA = 'Z:\NonExistentDrive\ShouldFail'

        # Ensure TempDir is set (dot-sourced with -NoRun doesn't run Section 11)
        if (-not $script:TempDir) {
            $script:TempDir = [System.IO.Path]::GetTempPath()
        }
    }

    AfterEach {
        $env:APPDATA = $script:OriginalAppData
        # Clean up any fallback dir that was created
        $fallback = Join-Path $script:TempDir "DailyMotivationBrainHelper"
        if (Test-Path $fallback) {
            Remove-Item -Path $fallback -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Should fall back to TempDir when APPDATA creation fails' {
        Initialize-AppData
        $expectedBase = Join-Path $script:TempDir "DailyMotivationBrainHelper"
        $script:AppDataDir | Should -Be $expectedBase
    }

    It 'Should set all path vars under the fallback dir' {
        Initialize-AppData
        $expectedBase = Join-Path $script:TempDir "DailyMotivationBrainHelper"
        $script:ConfigPath   | Should -BeLike "$expectedBase*"
        $script:PopupCfgPath | Should -BeLike "$expectedBase*"
        $script:TasksPath    | Should -BeLike "$expectedBase*"
        $script:LogPath      | Should -BeLike "$expectedBase*"
    }

    It 'Should create config files under the fallback dir' {
        Initialize-AppData
        Test-Path $script:ConfigPath   | Should -Be $true
        Test-Path $script:PopupCfgPath | Should -Be $true
        Test-Path $script:TasksPath    | Should -Be $true
    }
}
```

**Implementation notes**:
- `'Z:\NonExistentDrive\ShouldFail'` reliably fails `New-Item` on Windows without needing mocks; on Linux the dot-sourced tests are already guarded by `-Skip:(-not $IsWindows)` patterns where needed.
- Do not use `Mock New-Item` — the project convention (per `docs/reports` history) prefers real filesystem operations in unit tests to avoid mock/prod divergence.
- If the CI runner happens to have a `Z:\` drive, use `$env:SystemRoot + '\System32\drivers\etc\ImpossibleSubdir_' + (New-Guid)` instead — that path is always read-only.

---

### Acceptance criteria to close #7

- [ ] `Config.Tests.ps1` has a `Context 'When AppData directory creation fails (TEMP fallback)'` block with at minimum 3 tests:
  - `$script:AppDataDir` is set to a path under `$script:TempDir`
  - All 4 file path vars resolve under the fallback dir
  - Config files are actually created under the fallback dir
- [ ] Tests pass in CI (GitHub Actions `test.yml`)

---

## Closing #8 (META)

Issue #8 tracks #2, #4, #5, #6, #7. Once #6 and #7 are fully closed, close #8 with:
> "All child issues resolved. #2, #4, #5 closed 2026-07-23. #6 and #7 closed [date]. End-to-end initialization robustness verified."

---

## Quick reference — files to touch

| File | Change |
|------|--------|
| `DailyMotivation.ps1` line 3010 | Wrap `Initialize-AppData` in `try/catch` → `Show-ErrorDialog` → `exit 1` |
| `DailyMotivation.ps1` ~lines 2446–2459 | Add `Write-Warning` before each silent `return` in popup XAML load block |
| `Tests/Unit/Config.Tests.ps1` | Add TEMP fallback `Context` block inside `Describe 'Initialize-AppData'` |
