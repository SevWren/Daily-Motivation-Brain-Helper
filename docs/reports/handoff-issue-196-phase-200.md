# Handoff — Coverage Roadmap Phase #200 (Option A)

**Updated:** 2026-09-17
**Branch:** `SevAI_installing_bmad` | **PR:** #195
**Next ticket:** [#200](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/200)
**Approach locked:** Option A (standards-compliant, no ShowDialog)

---

## Read this first

Two things to do before writing a single line of code:

1. Read `CLAUDE.md`, `.claude/rules/pester-tests.md`,
   `.claude/rules/dailymotivation-script.md`, and
   `.claude/rules/commit-messages.md` in full.
2. Read `docs/architecture/adr-005-mandate-history.md` — every mandate exists
   because a previous agent violated it and caused a real regression.

Do not duplicate content in CONTEXT.md or the ADRs.

---

## Confirmed state entering this session

| Ticket | Status | Confirmed Windows run | Coverage |
|--------|--------|----------------------|----------|
| #197 — AfterAll guards | CLOSED | 543/0/6 | — |
| #198 — BusinessLogicHelpers | CLOSED | 543/0/6 | 46.93% |
| #199 — DataLayerHelpers | CLOSED | 543/0/6 | 51.56% |
| **#200 — WPF coverage** | **OPEN / ready-for-agent** | — | — |
| #201 — Mop-up | BLOCKED on #200 | — | — |

Current thresholds:
- `Invoke-Tests.ps1` line ~101: `$CoverageThreshold = 49`
- `.github/workflows/test.yml` coverage-gate step: `$minPct = 49`

Both must stay at 49 until #200's Option A tests are confirmed on Windows,
then bump together to **52** in the same commit as the tests.

---

## Repo / sandbox quick-start

```
Repo root:  /home/vercel-sandbox/repo
Branch:     SevAI_installing_bmad
Token gen:  python3 /home/vercel-sandbox/gh_app_token.py \
                /home/vercel-sandbox/sevwrenai.private-key.pem | tail -1
Push:       TOKEN=$(…) && git push \
                "https://x-access-token:${TOKEN}@github.com/SevWren/Daily-Motivation-Brain-Helper.git" \
                SevAI_installing_bmad
```

Every file change must be committed and pushed immediately. Sandbox is ephemeral.

---

## This session's production changes (already pushed)

| Commit | Change |
|--------|--------|
| `b0fa929` | `feat(ui)`: extracted `Invoke-FolderBrowserDialog` helper; `ShowNewFolderButton=$true`; `$script:LastUsedFolder` session memory |
| `d96f02e` | `docs(context)`: 10 domain gaps added to CONTEXT.md (New-MotivationTask, TaskId collision retry, STA Harness, WPF tag, etc.) |

These are unrelated to the coverage roadmap but are on the branch and must not be reverted.

---

## CRITICAL: What the previous #200 attempt did wrong

Commit `fe2f478` added a DispatcherTimer-based STA Harness. It was reverted
as `d6a35f2`. **Do not re-implement that approach.**

### Violation 1 — "No Startup Popups" (CLAUDE.md)

> *"No dialog/prompt on startup in `main` mode on the non-error path."*

Calling `Show-MainWindow` runs the full production startup path including any
first-run dialog. The fresh `$env:APPDATA` redirect looks identical to a
brand-new install, so the first-run message appeared during the test run and
the main UI window was visible to the user throughout the test.

**Rule: Never call `Show-MainWindow` or `Show-PopupWindow` in any way that
causes `ShowDialog()` to execute during automated tests.**

### Violation 2 — `$script:undoFeedbackTimer` unset crash

`Show-MainWindow`'s `Add_Closing` handler reads `$script:undoFeedbackTimer`,
which is set inside the window's `Loaded` event. If the DispatcherTimer fires
and calls `$win.Close()` before `Loaded` completes, the variable is never set.
Under `Set-StrictMode -Version Latest` (enforced by `Invoke-Tests.ps1` and
inherited by every test file) accessing an unset `$script:` variable is a
terminating `RuntimeException` — not `$null`. Result:

```
RuntimeException: The variable '$script:undoFeedbackTimer' cannot be retrieved
because it has not been set.
   at System.Windows.Window.WmClose()
```

This is also WRONG 3 from `dailymotivation-script.md`: *"Grep the entire file
for every reference before removing or relying on any `$script:*` variable."*

### Violation 3 — STA runspace bypassed test infrastructure

Creating a parallel STA runspace bypassed `Set-StrictMode`, existing
BeforeAll/AfterAll guards, and the CI artifact upload structure.

---

## Three approved patterns for WPF-adjacent tests (from existing files)

### Pattern A — Source-text regex (AG19-010.TabOrder, AG19.MainWindowUX)

```powershell
BeforeAll {
    $script:Src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
}
It 'SelectFolderBtn exists in XAML' {
    $script:Src | Should -Match 'x:Name="SelectFolderBtn"'
}
```

**No side effects. Fully headless. Cross-platform. No window opened.**
This is the established project way to verify control presence.

### Pattern B — Early-exit path exploitation (AG20-013.PopupMutex)

`Show-PopupWindow` exits before `ShowDialog()` when `explorer_path` is absent.
AG20-013 calls `Show-PopupWindow` 7 times this way — the window is **never
shown**. The existing mutex tests already cover these paths; do not duplicate.

`Show-MainWindow` has its own safe early-exit:

```powershell
function Show-MainWindow {
    if (-not $script:AssembliesLoaded) {
        [Console]::Error.WriteLine("UI cannot display: ...")
        return   # ← safe, no window opened
    }
    ...
```

Setting `$script:AssembliesLoaded = $false` before calling `Show-MainWindow`
exercises this guard without opening any window. **This path is not yet
covered and is valid for #200.**

### Pattern C — Skip with documented reason (AG20-007.CountdownTimer)

Tests that genuinely need ShowDialog are marked `-Skip` with an explicit
comment stating what would un-skip them. They are TDD specifications.
**Do not make them green by opening real windows.**

---

## Option A — Complete implementation plan for #200

### Confirmed XAML control names (verified against source)

**`Show-MainWindow` controls** (from DailyMotivation.ps1 XAML):

| Control name | Element |
|---|---|
| `SelectFolderBtn` | Primary folder picker button |
| `ScheduleBtn` | Schedule Reminder action button |
| `TodayRadio` | Today RadioButton |
| `TomorrowRadio` | Tomorrow RadioButton |
| `UndoBtn` | Undo button in UndoBanner |
| `DropZone` | Drag-drop target border |
| `TaskList` | Scheduled tasks ItemsControl |
| `HistoryToggleBtn` | View/Hide History button |
| `NoTasksLabel` | "No reminders" placeholder border |

**`Show-PopupWindow` controls** (from DailyMotivation.ps1 XAML):

| Control name | Element |
|---|---|
| `LetsGoBtn` | "Open Folder →" primary action |
| `SnoozeBtn` | Snooze button |
| `SnoozeDropBtn` | Snooze duration dropdown chevron |
| `DismissBtn` | "Dismiss" button |
| `RePickBtn` | "Re-Pick Folder" path-missing action |
| `GlyphText` | Glyph TextBlock |
| `BodyText` | Body message TextBlock |
| `NormalPanel` | Standard popup content StackPanel |
| `PathMissingPanel` | Path-missing panel StackPanel |

---

### File 1: `Tests/Unit/WPFAssemblies.Tests.ps1` (new)

Covers `Initialize-WindowsAssemblies` → **100% LINE coverage**.
Windows-only. No window opened.

```powershell
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    Tests for Initialize-WindowsAssemblies — loads WPF and WinForms
    assemblies required by Show-MainWindow and Show-PopupWindow.
    Windows-only: assemblies do not exist on Linux.
#>

BeforeAll {
    if ($IsWindows) {
        . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
        $script:OriginalAppData = $env:APPDATA
        $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_WPFAssemblies_$(New-Guid)"
        Initialize-AppData
    }
}

AfterAll {
    if ($IsWindows) {
        if (Test-Path $env:APPDATA) {
            Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:APPDATA = $script:OriginalAppData
    }
}

Describe 'Initialize-WindowsAssemblies' -Skip:(-not $IsWindows) {

    BeforeEach {
        # Force re-evaluation on each test
        $script:AssembliesLoaded = $false
        $script:WpfLoaded        = $false
        $script:FormsLoaded      = $false
    }

    It 'sets WpfLoaded to true after loading WPF assemblies' {
        Initialize-WindowsAssemblies
        $script:WpfLoaded | Should -Be $true
    }

    It 'sets FormsLoaded to true after loading WinForms assemblies' {
        Initialize-WindowsAssemblies
        $script:FormsLoaded | Should -Be $true
    }

    It 'sets AssembliesLoaded to true after first call' {
        Initialize-WindowsAssemblies
        $script:AssembliesLoaded | Should -Be $true
    }

    It 'is idempotent — calling twice does not throw and WpfLoaded stays true' {
        Initialize-WindowsAssemblies
        { Initialize-WindowsAssemblies } | Should -Not -Throw
        $script:WpfLoaded | Should -Be $true
    }

    It 'does not throw when called a third time' {
        Initialize-WindowsAssemblies
        Initialize-WindowsAssemblies
        { Initialize-WindowsAssemblies } | Should -Not -Throw
    }
}
```

---

### File 2: `Tests/Unit/WPFControls.Tests.ps1` (new)

Source-text assertions (Pattern A) + Show-MainWindow early-exit (Pattern B).
XAML tests are **cross-platform**. Early-exit test is Windows-only.

```powershell
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }
<#
.SYNOPSIS
    WPF control-tree assertions (Pattern A: source-text regex) and
    Show-MainWindow early-exit coverage (Pattern B).
    XAML tests: cross-platform. Early-exit test: Windows-only.
.NOTES
    No window is opened in any test in this file.
    Source-text regex does not execute function code (0 coverage gain)
    but satisfies control-existence acceptance criteria.
    Pattern B (early-exit) covers the no-assemblies guard at the top
    of Show-MainWindow without calling ShowDialog.
#>

BeforeAll {
    $script:Src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
}

# ── Show-MainWindow control tree (Pattern A, cross-platform) ──────────────
Describe 'Show-MainWindow — XAML control tree' {

    It 'SelectFolderBtn exists'    { $script:Src | Should -Match 'x:Name="SelectFolderBtn"' }
    It 'ScheduleBtn exists'        { $script:Src | Should -Match 'x:Name="ScheduleBtn"' }
    It 'TodayRadio exists'         { $script:Src | Should -Match 'x:Name="TodayRadio"' }
    It 'TomorrowRadio exists'      { $script:Src | Should -Match 'x:Name="TomorrowRadio"' }
    It 'UndoBtn exists'            { $script:Src | Should -Match 'x:Name="UndoBtn"' }
    It 'DropZone exists'           { $script:Src | Should -Match 'x:Name="DropZone"' }
    It 'TaskList exists'           { $script:Src | Should -Match 'x:Name="TaskList"' }
    It 'HistoryToggleBtn exists'   { $script:Src | Should -Match 'x:Name="HistoryToggleBtn"' }
    It 'NoTasksLabel exists'       { $script:Src | Should -Match 'x:Name="NoTasksLabel"' }
}

# ── Show-PopupWindow control tree (Pattern A, cross-platform) ─────────────
Describe 'Show-PopupWindow — XAML control tree' {

    It 'LetsGoBtn exists'          { $script:Src | Should -Match 'x:Name="LetsGoBtn"' }
    It 'SnoozeBtn exists'          { $script:Src | Should -Match 'x:Name="SnoozeBtn"' }
    It 'SnoozeDropBtn exists'      { $script:Src | Should -Match 'x:Name="SnoozeDropBtn"' }
    It 'DismissBtn exists'         { $script:Src | Should -Match 'x:Name="DismissBtn"' }
    It 'RePickBtn exists'          { $script:Src | Should -Match 'x:Name="RePickBtn"' }
    It 'GlyphText exists'          { $script:Src | Should -Match 'x:Name="GlyphText"' }
    It 'BodyText exists'           { $script:Src | Should -Match 'x:Name="BodyText"' }
    It 'NormalPanel exists'        { $script:Src | Should -Match 'x:Name="NormalPanel"' }
    It 'PathMissingPanel exists'   { $script:Src | Should -Match 'x:Name="PathMissingPanel"' }
}

# ── Show-MainWindow early-exit guard (Pattern B, Windows-only) ───────────
Describe 'Show-MainWindow — early-exit when assemblies not loaded' -Skip:(-not $IsWindows) {

    BeforeAll {
        if ($IsWindows) {
            . (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -NoRun
            $script:OriginalAppData = $env:APPDATA
            $env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) "DMBH_MainEarlyExit_$(New-Guid)"
            Initialize-AppData
        }
    }

    AfterAll {
        if ($IsWindows) {
            if (Test-Path $env:APPDATA) {
                Remove-Item -Path $env:APPDATA -Recurse -Force -ErrorAction SilentlyContinue
            }
            $env:APPDATA = $script:OriginalAppData
        }
    }

    It 'returns without throwing when AssembliesLoaded is false' {
        # Pattern B: exercises the no-assemblies early-exit without opening any window.
        # No ShowDialog call is made; the function returns via Console.Error.WriteLine.
        $script:AssembliesLoaded = $false
        { Show-MainWindow } | Should -Not -Throw
    }

    It 'does not open a window when AssembliesLoaded is false' {
        $script:AssembliesLoaded = $false
        Show-MainWindow
        # If a window had opened it would not have closed — test would hang.
        # Reaching this assertion proves no ShowDialog was called.
        $true | Should -Be $true
    }
}
```

---

### No other files to create or modify

| Item | Action |
|------|--------|
| `Tests/WPF/` directory | Does not exist (cleaned by revert `d6a35f2`). Do not recreate. |
| `Invoke-Tests.ps1` | Change `$CoverageThreshold = 49` → `52` in the same commit as the new tests |
| `.github/workflows/test.yml` | Change `$minPct = 49` → `52` in the same commit as the new tests |
| `Invoke-Tests.ps1` STA block | Do not add. No STA harness. |

---

### Revised acceptance criteria for #200 (Option A)

These replace the acceptance criteria in the #200 agent brief (which was
written before the constraint analysis):

- [ ] `Initialize-WindowsAssemblies` reaches 100% LINE coverage
- [ ] ≥ 9 source-text assertions on Show-MainWindow XAML controls
- [ ] ≥ 9 source-text assertions on Show-PopupWindow XAML controls
- [ ] Show-MainWindow no-assemblies early-exit path covered (2 tests)
- [ ] All new test files placed in `Tests/Unit/` alongside existing suite
- [ ] No test opens a visible WPF window or calls ShowDialog
- [ ] No STA runspace created anywhere
- [ ] Coverage threshold advanced from 49% → 52% in both threshold files
- [ ] CI is green on `SevAI_installing_bmad`
- [ ] Agent brief on #200 updated to reflect Option A before closing

**Do NOT use `Closes #200` in any commit message.** Use `Related to #200`
until the user confirms Windows test results per the commit-messages rule.

---

## Carry-forward lessons from #198 and #199

### Pester v5 scoping — helper functions MUST be in BeforeAll

```powershell
# WRONG — invisible inside It closures
function My-Helper { ... }

# CORRECT — script: prefix inside BeforeAll
BeforeAll {
    function script:My-Helper { ... }
}
```

### Empty-array pipeline assertions

```powershell
# WRONG — @() unrolls to zero pipeline items; Pester sees null
$x | Should -Not -BeNull

# CORRECT
($null -ne $x)   | Should -Be $true
@($x).Count      | Should -Be 0
```

### Coverage gains vs. projections (calibration)

| Ticket | Projected | Actual |
|--------|-----------|--------|
| #198 | +7 pp | +3 pp → 46.93% |
| #199 | +10 pp | +4.6 pp → 51.56% |
| #200 (Option A) | ~0.4 pp | ~52% target |

Large coverage gains come in #201 from targeted mop-up of catch branches and
entry-point modes — not from XAML assertions which add 0 covered lines.

---

## Key file locations

| Purpose | Path |
|---------|------|
| Threshold — Invoke-Tests | `Invoke-Tests.ps1` line ~101 — `$CoverageThreshold = 49` |
| Threshold — CI gate | `.github/workflows/test.yml` — `$minPct = 49` |
| Pattern A reference | `Tests/Unit/AG19-010.TabOrder.Tests.ps1` |
| Pattern A reference | `Tests/Unit/AG19.MainWindowUX.Tests.ps1` |
| Pattern B reference | `Tests/Unit/AG20-013.PopupMutex.Tests.ps1` |
| Pattern C reference | `Tests/Unit/AG20-007.CountdownTimer.Tests.ps1` |
| Binding rules | `CLAUDE.md` |
| Pester rules | `.claude/rules/pester-tests.md` |
| WPF/resource rules | `.claude/rules/dailymotivation-script.md` |
| Commit rules | `.claude/rules/commit-messages.md` |
| Mandate history | `docs/architecture/adr-005-mandate-history.md` |
| CONTEXT.md | Updated this session (`d96f02e`) — read before writing tests |

---

## Suggested skills

| Task | Skill |
|------|-------|
| Implementing #200 (Option A) | `/implement` |
| Writing each slice | `/tdd` |
| Reviewing diff before committing | `/code-review` |
| Bridging to next session | `/handoff` |

**Do not use** `/wayfinder`, `/grill-with-docs`, or `/triage`. The path is
clear. Read all standards, then implement the two test files above.
