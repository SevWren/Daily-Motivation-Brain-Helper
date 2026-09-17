# Handoff — Coverage Roadmap Phase #200 (Revised)

**Updated:** 2026-09-17
**Branch:** `SevAI_installing_bmad` | **PR:** #195
**Next ticket:** [#200](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/200)

---

## Purpose

Fresh-session context for implementing #200 using **Option A** — the approach
validated against all project standards. Read this entire document before
touching any code. The previous attempt (`fe2f478`) was reverted because it
violated binding mandates. Those violations are fully documented below so the
next session does not repeat them.

Do not duplicate content already in CONTEXT.md or the project ADRs.

---

## Current state

| Ticket | Status | Last commit | Confirmed coverage |
|--------|--------|-------------|-------------------|
| #197 — AfterAll guards | Closed | `f5f149a` | — |
| #198 — BusinessLogicHelpers | Closed | `cb8d2dd` | 46.93% |
| #199 — DataLayerHelpers | Closed | `1ddaeb9` | 51.56% |
| **#200 — WPF coverage** | **Open / ready-for-agent** | `d6a35f2` (revert) | — |
| #201 — Mop-up | Blocked on #200 | — | — |

Current thresholds: `$CoverageThreshold = 49` in `Invoke-Tests.ps1` and
`$minPct = 49` in `.github/workflows/test.yml`. Both must stay at 49 until
#200's new tests are confirmed on Windows.

---

## Repo / sandbox quick-start

```
Repo root:  /home/vercel-sandbox/repo
Branch:     SevAI_installing_bmad
Token:      python3 /home/vercel-sandbox/gh_app_token.py /home/vercel-sandbox/sevwrenai.private-key.pem | tail -1
Push:       TOKEN=$(…) && git push "https://x-access-token:${TOKEN}@github.com/SevWren/Daily-Motivation-Brain-Helper.git" SevAI_installing_bmad
```

Every change must be committed and pushed immediately. Sandbox is ephemeral.

---

## CRITICAL: What the previous attempt did wrong

Commit `fe2f478` was reverted as `d6a35f2`. Read this section in full before
writing any test that touches `Show-MainWindow` or `Show-PopupWindow`.

### Violation 1 — "No Startup Popups" mandate (CLAUDE.md)

> *"No dialog/prompt on startup in `main` mode on the non-error path."*

Calling `Show-MainWindow` in a test runs the **full production startup path**,
including any first-run dialog. A fresh `$env:APPDATA` redirect looks identical
to a brand-new install, so the first-run message appeared to the user running
the test suite. The main UI window was also visible the entire time the
DispatcherTimer was counting down.

**Rule: Never call `Show-MainWindow` or `Show-PopupWindow` in a way that causes
`ShowDialog()` to execute during an automated test run.**

### Violation 2 — `$script:undoFeedbackTimer` unset crash

`Show-MainWindow`'s `Add_Closing` handler references `$script:undoFeedbackTimer`,
which is set inside the window's `Loaded` event. If the DispatcherTimer fires
and calls `$win.Close()` before `Loaded` completes, `$script:undoFeedbackTimer`
is never set. Under `Set-StrictMode -Version Latest` (enforced by
`Invoke-Tests.ps1`, inherited by all test files) accessing an unset `$script:`
variable is a **terminating exception** — not `$null`. This produced:

```
RuntimeException: The variable '$script:undoFeedbackTimer' cannot be retrieved
because it has not been set.
   at System.Windows.Window.WmClose()
```

**Rule: Never rely on DispatcherTimer timing to work around window lifecycle
initialization. Script-scoped variables set inside `Loaded` events are not
set until that event fires, which may be after a 200ms timer tick.**

### Violation 3 — STA runspace bypassed test infrastructure

The STA runspace approach created a parallel Pester execution outside the
normal `Invoke-Tests.ps1` flow. This bypasses `Set-StrictMode`, the existing
BeforeAll/AfterAll guards, and the CI artifact upload structure.

---

## Established test patterns for WPF-adjacent coverage (from existing files)

Three patterns are used in this project. All are approved. **Use only these.**

### Pattern A — Source-text regex (AG19-010.TabOrder, AG19.MainWindowUX)

```powershell
BeforeAll {
    $script:SourceText = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
}

It 'SelectFolderBtn control exists in XAML' {
    $script:SourceText | Should -Match 'x:Name="SelectFolderBtn"'
}
```

**Zero side effects. Fully headless. Cross-platform. No window opened.**
This is the established way to assert control presence in this project.

### Pattern B — Early-exit path exploitation (AG20-013.PopupMutex)

`Show-PopupWindow` exits early before `ShowDialog()` when `explorer_path` is
absent from the config. The existing AG20-013 tests call `Show-PopupWindow` 7
times using this path to test mutex behavior — **the window is never shown**.

`Show-MainWindow` has the same kind of early-exit:
```powershell
function Show-MainWindow {
    if (-not $script:AssembliesLoaded) {
        [Console]::Error.WriteLine("UI cannot display: ...")
        return   # ← safe, no window
    }
    ...
```
Setting `$script:AssembliesLoaded = $false` before calling `Show-MainWindow`
exercises this guard path safely, without opening any window.

### Pattern C — Skip with documented reason (AG20-007.CountdownTimer)

Tests that genuinely require WPF ShowDialog (countdown behavior, etc.) are
marked `-Skip` with an explicit comment stating what would un-skip them. They
are TDD specifications — red tests that document the gap. Do not remove them
and do not try to make them green by opening real windows.

---

## Option A — Approved implementation plan for #200

**Principle:** Use Pattern A and Pattern B only. Never call ShowDialog. Never
open a visible window in the test suite. Mark any test that would require
ShowDialog as Pattern C (Skip + documented reason).

### Deliverable 1: `Tests/Unit/WPFAssemblies.Tests.ps1`

New file in `Tests/Unit/` (not a new subdirectory — runs with the existing
suite). Tests `Initialize-WindowsAssemblies` directly. Windows-only
(`-Skip:(-not $IsWindows)`).

```powershell
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
    It 'sets WpfLoaded to true after loading' {
        $script:AssembliesLoaded = $false; $script:WpfLoaded = $false
        Initialize-WindowsAssemblies
        $script:WpfLoaded | Should -Be $true
    }
    It 'sets FormsLoaded to true after loading' {
        $script:AssembliesLoaded = $false; $script:FormsLoaded = $false
        Initialize-WindowsAssemblies
        $script:FormsLoaded | Should -Be $true
    }
    It 'sets AssembliesLoaded to true after first call' {
        $script:AssembliesLoaded = $false
        Initialize-WindowsAssemblies
        $script:AssembliesLoaded | Should -Be $true
    }
    It 'is idempotent — calling twice does not throw' {
        Initialize-WindowsAssemblies
        { Initialize-WindowsAssemblies } | Should -Not -Throw
        $script:WpfLoaded | Should -Be $true
    }
}
```

**Expected coverage from this file:** `Initialize-WindowsAssemblies` → **100%**

### Deliverable 2: `Tests/Unit/WPFControls.Tests.ps1`

New file in `Tests/Unit/`. Uses Pattern A to assert all required XAML control
names and structural elements. **Cross-platform. No `-Skip` needed.**

```powershell
BeforeAll {
    $script:Src = Get-Content (Join-Path $PSScriptRoot '..\..\DailyMotivation.ps1') -Raw
}

Describe 'Show-MainWindow — XAML control tree' {
    It 'SelectFolderBtn exists' { $script:Src | Should -Match 'x:Name="SelectFolderBtn"' }
    It 'ScheduleBtn exists'     { $script:Src | Should -Match 'x:Name="ScheduleBtn"' }
    It 'TodayRadio exists'      { $script:Src | Should -Match 'x:Name="TodayRadio"' }
    It 'TomorrowRadio exists'   { $script:Src | Should -Match 'x:Name="TomorrowRadio"' }
    It 'UndoBtn exists'         { $script:Src | Should -Match 'x:Name="UndoBtn"' }
    It 'SelectFolderBtn has ToolTip attribute' {
        $script:Src | Should -Match 'x:Name="SelectFolderBtn"[^/]*ToolTip='
    }
}

Describe 'Show-PopupWindow — XAML control tree' {
    It 'LetsGoBtn exists'       { $script:Src | Should -Match 'x:Name="LetsGoBtn"' }
    It 'SnoozeBtn exists'       { $script:Src | Should -Match 'x:Name="SnoozeBtn"' }
    It 'DismissBtn exists'      { $script:Src | Should -Match 'x:Name="DismissBtn"' }
    It 'SnoozeDropBtn exists'   { $script:Src | Should -Match 'x:Name="SnoozeDropBtn"' }
    It 'RePickBtn exists'       { $script:Src | Should -Match 'x:Name="RePickBtn"' }
}

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
        $script:AssembliesLoaded = $false
        { Show-MainWindow } | Should -Not -Throw
    }
}
```

**Expected coverage from this file:** XAML tests add 0 new covered lines
(source-text assertions don't execute function code), but they satisfy the
control-existence acceptance criteria. The early-exit test covers the guard
path at the top of `Show-MainWindow` (~3 lines).

### What is NOT in Option A

- No STA runspace
- No DispatcherTimer
- No ShowDialog calls
- No `Tests/WPF/` directory (the previous `Invoke-STAPester.ps1` and
  `WPFSmoke.Tests.ps1` were deleted by the revert `d6a35f2`)
- No changes to `Invoke-Tests.ps1` or `.github/workflows/test.yml` beyond
  the threshold bump

### Threshold for Option A

Realistic gain: `Initialize-WindowsAssemblies` (~10 lines) + `Show-MainWindow`
early-exit (~3 lines) = ~0.4 pp. Starting from 51.56% → approximately **52%**.

**Set threshold to 52%.** Do not set it to 75% — that was based on the
reverted approach. The gap to 75% is addressed in #201 (final mop-up) after a
fresh JaCoCo report shows what remains.

### Revised acceptance criteria for #200 (Option A)

- [ ] `Initialize-WindowsAssemblies` reaches 100% LINE coverage
- [ ] ≥ 10 XAML control-existence assertions across main window and popup (Pattern A)
- [ ] `Show-MainWindow` no-assemblies early-exit path is covered (Pattern B)
- [ ] All new tests are in `Tests/Unit/` alongside the existing suite
- [ ] No new test opens a visible WPF window or calls `ShowDialog()`
- [ ] Coverage threshold advanced from 49% → 52% in both threshold files
- [ ] CI is green on `SevAI_installing_bmad`
- [ ] Agent brief on #200 is updated to reflect Option A before closing

---

## Carry-forward lessons from all previous tickets

### Pester v5 scoping — helper functions MUST be in BeforeAll

```powershell
# WRONG — invisible inside It blocks
function My-Helper { ... }

# CORRECT
BeforeAll {
    function script:My-Helper { ... }
}
```

### Empty-array pipeline assertions

```powershell
# WRONG — @() unrolls to nothing
$x | Should -Not -BeNull

# CORRECT
($null -ne $x) | Should -Be $true
@($x).Count    | Should -Be 0
```

### Coverage gains vs. projections

| Ticket | Projected | Actual |
|--------|-----------|--------|
| #198 | +7 pp | +3 pp (46.93%) |
| #199 | +10 pp | +4.6 pp (51.56%) |
| #200 (Option A) | ~0.4 pp | TBD |

The large jumps will come in #201 from targeted mop-up of uncovered branches,
not from WPF windows.

---

## Key file locations

| Purpose | Path |
|---------|------|
| Threshold (Invoke-Tests) | `Invoke-Tests.ps1` line ~101 — `$CoverageThreshold = 49` |
| Threshold (CI) | `.github/workflows/test.yml` — `$minPct = 49` |
| Established XAML test pattern | `Tests/Unit/AG19-010.TabOrder.Tests.ps1` |
| Established source-text pattern | `Tests/Unit/AG19.MainWindowUX.Tests.ps1` |
| Established early-exit pattern | `Tests/Unit/AG20-013.PopupMutex.Tests.ps1` |
| All binding rules | `CLAUDE.md`, `.claude/rules/pester-tests.md`, `.claude/rules/dailymotivation-script.md` |
| Mandate history | `docs/architecture/adr-005-mandate-history.md` |

---

## Suggested skills

| Task | Skill |
|------|-------|
| Implementing #200 (Option A) | `/implement` |
| Writing each test slice | `/tdd` |
| Reviewing diff before committing | `/code-review` |
| Bridging to next session | `/handoff` |

**Do NOT use** `/wayfinder` (path is clear) or `/grill-with-docs` (options
already decided). Read all standards files before writing any code.
