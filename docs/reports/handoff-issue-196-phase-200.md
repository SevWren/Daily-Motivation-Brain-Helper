# Handoff — Coverage Roadmap Phase #200 (STA Harness)

**Generated:** 2026-09-17
**Branch:** `SevAI_installing_bmad` | **PR:** #195
**Next ticket:** [#200](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/200) — STA Harness for WPF smoke tests

---

## Purpose

Fresh-session context for implementing #200. Tickets #197–#199 are closed and confirmed on Windows. This document captures the non-obvious facts that made those tickets harder than expected so #200 avoids the same traps.

Do not duplicate content already in the agent brief on #200 or in CONTEXT.md.

---

## Confirmed state entering #200

| Ticket | Status | Final commit | Confirmed coverage |
|--------|--------|--------------|--------------------|
| #197 — AfterAll guards | Closed | `f5f149a` | — |
| #198 — BusinessLogicHelpers | Closed | `cb8d2dd` | 46.93% |
| #199 — DataLayerHelpers | Closed | `1ddaeb9` | 51.56% |
| **#200 — STA Harness** | **Open / ready-for-agent** | — | — |
| #201 — Mop-up | Blocked on #200 | — | — |

Current threshold: **49%** (both `Invoke-Tests.ps1` and `.github/workflows/test.yml`). #200 targets 75%.

---

## Repo / sandbox quick-start

```
Repo root:       /home/vercel-sandbox/repo
Main file:       DailyMotivation.ps1
Branch:          SevAI_installing_bmad
Token:           python3 /home/vercel-sandbox/gh_app_token.py /home/vercel-sandbox/sevwrenai.private-key.pem | tail -1
Push:            TOKEN=$(…) && git push "https://x-access-token:${TOKEN}@github.com/SevWren/Daily-Motivation-Brain-Helper.git" SevAI_installing_bmad
```

Every file change must be committed and pushed immediately. Sandbox is ephemeral.

---

## Lessons from #198 and #199 — apply to #200

### 1. Pester v5 scoping: helper functions MUST be in BeforeAll

Functions defined at bare file scope (outside any block) are **not visible inside `It` closures** in Pester v5. This caused 15 failures in #199.

```powershell
# WRONG — function at file scope, invisible inside It blocks
function My-Helper { ... }

# CORRECT — define with script: prefix inside the file-level BeforeAll
BeforeAll {
    function script:My-Helper { ... }
}
```

#200 will need helper stubs for the DispatcherTimer assertions. Define them in BeforeAll.

### 2. Empty-array assertions must avoid the pipeline

`@()` piped to `Should -Not -BeNull` / `Should -Not -BeNullOrEmpty` sends zero objects through the pipeline — Pester interprets that as null input and fails. Caused 3 failures across #199 iterations.

```powershell
# WRONG — @() unrolls to nothing in the pipeline
$control.ItemsSource | Should -Not -BeNull

# CORRECT — check directly without the pipeline
($null -ne $control.ItemsSource) | Should -Be $true
@($control.ItemsSource).Count   | Should -Be 0
```

### 3. Coverage gains are smaller than the roadmap projected

Existing tests already partially cover the target functions. Actual gains per ticket:

| Ticket | Projected | Actual |
|--------|-----------|--------|
| #198 | +7 pp | +3 pp (46.93%) |
| #199 | +10 pp | +4.6 pp (51.56%) |

For #200: Show-MainWindow (~700 LOC) and Show-PopupWindow (~600 LOC) are ~36% of the Script and currently 0% covered. If WPF smoke tests cover 50% of those lines, that is ~18 pp gain → ~70%. 75% is achievable but tight. **Set the threshold conservatively — verify actual coverage before bumping.**

### 4. STA requirement

`Initialize-WindowsAssemblies` loads assemblies on any thread (safe). Creating `Window` objects and calling `ShowDialog()` requires STA. The DispatcherTimer pattern closes the window before `ShowDialog()` blocks indefinitely:

```powershell
$assertions = @{}
$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromMilliseconds(200)
$timer.Add_Tick({
    $timer.Stop()
    $win = [System.Windows.Application]::Current.Windows | Select-Object -First 1
    if ($win) {
        $assertions['SelectFolderBtn'] = $null -ne $win.FindName('SelectFolderBtn')
        # ... more control assertions ...
        $win.Close()
    }
})
$timer.Start()
Show-MainWindow   # blocks until window closes via timer
```

### 5. Show-PopupWindow needs a valid PopupConfig

`Show-PopupWindow` exits early if `explorer_path` is absent. Before calling it in tests, write a minimal `popup_config.json`:

```powershell
Set-PopupConfig -Glyph '[+]' -Title 'Test' -Body 'Test' `
                -ExplorerPath 'C:\Temp' -TaskId 'test-task-id'
```

---

## What #200 must build

See agent brief: [#200 comment](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/200#issuecomment-5706907936)

Summary of artifacts:
1. `Tests/WPF/Invoke-STAPester.ps1` — creates STA runspace, runs Pester on `Tests/WPF/` with `-Tag WPF`
2. `Tests/WPF/WPFSmoke.Tests.ps1` — tagged `WPF`, `-Skip:(-not $IsWindows)`, DispatcherTimer auto-close
3. `Invoke-Tests.ps1` — add STA runner invocation after main Pester run on Windows
4. `.github/workflows/test.yml` — upload `coverage-wpf.xml` artifact, aggregate in coverage-gate

**Acceptance criteria checklist** (from agent brief):
- [ ] `Initialize-WindowsAssemblies` → 100% LINE coverage
- [ ] `Show-MainWindow` → ≥ 50% LINE coverage
- [ ] `Show-PopupWindow` → ≥ 50% LINE coverage
- [ ] ≥ 10 control-existence assertions total
- [ ] Popup Mutex verified released after `Show-PopupWindow` returns
- [ ] `Invoke-Tests.ps1` invokes STA Harness on Windows; fails if WPF tests fail
- [ ] `.github/workflows/test.yml` aggregates `coverage.xml` + `coverage-wpf.xml`
- [ ] Threshold advanced to 75% in both threshold files (same commit as tests)

---

## Key file locations

| Purpose | Path |
|---------|------|
| Test runner | `Invoke-Tests.ps1` — threshold at line ~101, currently `$CoverageThreshold = 49` |
| CI coverage gate | `.github/workflows/test.yml` — `$minPct = 49` in coverage-gate step |
| WPF tests (to create) | `Tests/WPF/` |
| Existing test patterns | `Tests/Unit/BusinessLogicHelpers.Tests.ps1` (BeforeAll helper pattern) |
| Pester rules | `.claude/rules/pester-tests.md` |
| WPF/resource rules | `.claude/rules/dailymotivation-script.md` |

---

## Suggested skills

| Task | Skill |
|------|-------|
| Implementing #200 | `/implement` |
| Writing each test slice red→green | `/tdd` |
| Reviewing diff before committing | `/code-review` |
| Bridging to next session | `/handoff` |
