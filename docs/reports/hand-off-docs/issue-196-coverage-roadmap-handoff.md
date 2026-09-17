# Handoff — Issue #196 Coverage Roadmap (43% → 95%)

**Generated:** 2026-09-17
**Branch:** `SevAI_installing_bmad`
**PR:** [#195](https://github.com/SevWren/Daily-Motivation-Brain-Helper/pull/195)
**Parent issue:** [#196](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/196)

---

## Purpose

This document is the context handoff for a fresh agent session continuing the coverage roadmap on `SevAI_installing_bmad`. Grilling, spec, planning, and triage are all complete. The only remaining work is implementing tickets **#197 → #198 → #199 → #200 → #201** in strict dependency order, one per fresh session.

Do **not** duplicate content already in the issues, agent briefs, or CLAUDE.md. Reference them instead.

---

## Repo & Sandbox Quick-start

```
Repo root:       /home/vercel-sandbox/repo
Main file:       DailyMotivation.ps1
Branch:          SevAI_installing_bmad
Token generator: python3 /home/vercel-sandbox/gh_app_token.py /home/vercel-sandbox/sevwrenai.private-key.pem
Push pattern:    TOKEN=$(... | tail -1) && git push "https://x-access-token:${TOKEN}@github.com/SevWren/Daily-Motivation-Brain-Helper.git" SevAI_installing_bmad
```

**Mandate (ephemeral session):** Every file change must be committed and pushed immediately using the token above. The sandbox is temporary — nothing survives the session unless pushed.

---

## What Was Accomplished This Session

| Commit | Description |
|--------|-------------|
| `b0fa929` | `feat(ui)`: extract `FolderBrowserDialog` to `Invoke-FolderBrowserDialog` helper (unrelated to #196 coverage; already pushed) |

### Triage actions completed (2026-09-17)

- Issues #197–#201: labels applied (`enhancement`, `testing`, `ready-for-agent`)
- Agent briefs posted on all five child issues (see URLs in each issue's comment thread)
- `/ask-matt` routing analysis posted as a comment on [#196](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/196)
- GitHub native sub-issues confirmed: all 5 (#197–#201) are properly linked as sub-issues of #196 (`GET /repos/.../issues/196/sub_issues` returns 5 items)

---

## Current State Per Ticket

### #197 — AfterAll guard cleanup `[PARTIALLY DONE — OPEN]`

**What happened:** Commit `4c07701` (already on branch, authored by `sevwrenai[bot]`, 2026-09-14) fixed the `BeforeAll` early-return patterns across Integration and Unit test files. That commit's message is `test(pester): remove BeforeAll platform skip returns (#197)`.

**What remains — 6 `AfterAll` violations still present:**

| File | Line | Block scope |
|------|------|-------------|
| `Tests/Integration/AG20-001.MultiFolderScheduling.Tests.ps1` | 36 | File-scope AfterAll |
| `Tests/Integration/AG20-002.SystemAccountConstraints.Tests.ps1` | 19 | File-scope AfterAll |
| `Tests/Unit/AG20-013.PopupMutex.Tests.ps1` | 23 | File-scope AfterAll |
| `Tests/Unit/AG20-020.UNCPathTimeout.Tests.ps1` | 191 | Describe-scope AfterAll |
| `Tests/Unit/SyncTaskStatuses.Tests.ps1` | 49 | File-scope AfterAll |
| `Tests/Unit/TaskScheduler.Tests.ps1` | 77 | File-scope AfterAll |

Each is `if (-not $IsWindows) { return }` — convert all to `if ($IsWindows) { ... }` wrapping. No logic changes; body content stays identical.

Acceptance gate: `git grep -n "if (-not \$IsWindows) { return }" Tests/` must return zero results.

**Threshold bump in this ticket:** none (prerequisite only).

See agent brief: [#197 comment](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/197#issuecomment-5706903078)

---

### #198 — Business-logic helpers `[NOT STARTED]`

New file: `Tests/Unit/BusinessLogicHelpers.Tests.ps1`
Targets: `Write-OutcomeLog`, `Get-SafeErrorMessage`, `Show-ErrorDialog`, `Show-InfoDialog`
Coverage delta: **40% → 50%** (bump threshold in same commit)

See agent brief: [#198 comment](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/198#issuecomment-5706903174)
Full test specification: in the previous session's planning output (not reproduced here — read the agent brief on the issue).

---

### #199 — Data-layer helpers `[NOT STARTED]`

New file: `Tests/Unit/DataLayerHelpers.Tests.ps1`
Targets: `Get-HistoryData`, `Update-HistoryUI`, `Get-ScheduleTime`, `Update-TaskListUI`
Coverage delta: **50% → 60%** (bump threshold in same commit)
Key pattern: use `PSCustomObject` stubs for WPF control parameters — no real window needed.

See agent brief: [#199 comment](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/199#issuecomment-5706907839)

---

### #200 — STA WPF harness `[NOT STARTED]`

New files: `Tests/WPF/Invoke-STAPester.ps1`, `Tests/WPF/WPFSmoke.Tests.ps1`
Modified: `Invoke-Tests.ps1`, `.github/workflows/test.yml`
Targets: `Initialize-WindowsAssemblies` (→ 100%), `Show-MainWindow` (→ ≥50%), `Show-PopupWindow` (→ ≥50%)
Coverage delta: **60% → 75%** (bump threshold in same commit)
Key technique: `[System.Windows.Threading.DispatcherTimer]` fires 200ms after window opens, records control assertions, closes window — unblocks `ShowDialog()`.

See agent brief: [#200 comment](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/200#issuecomment-5706907936)

---

### #201 — Final mop-up `[BLOCKED on #200]`

Driven by the JaCoCo report produced after #200 merges. Cannot start until #200 CI is green.
Target: **75% → 95%** — raise both `$CoverageThreshold` in `Invoke-Tests.ps1` and `$minPct` in `.github/workflows/test.yml`.

Known anticipated gap functions (do not assume — verify against JaCoCo XML first):
- `New-MotivationTask` — 5-branch `switch -Regex` catch block (WRONG 5 fix from CLAUDE.md)
- Collision-retry exhaustion (3-attempt loop)
- `/setfolder` and `/uninstall` entry-point modes
- `Test-TasksJsonIntegrity` hash-mismatch branch
- `Invoke-FolderScheduling` rollback-failed path

See agent brief: [#201 comment](https://github.com/SevWren/Daily-Motivation-Brain-Helper/issues/201#issuecomment-5706910851)

---

## Critical Constraints (do not skip — sourced from CLAUDE.md and rules files)

Full rules are in `/home/vercel-sandbox/repo/CLAUDE.md` and `/home/vercel-sandbox/repo/.claude/rules/`. The items below are the ones most likely to be violated by a fresh agent writing tests:

1. **Never mock `New-ScheduledTaskAction/Trigger/Settings/Principal`** — use real cmdlets; only mock `Register/Get/Unregister-ScheduledTask` (WRONG 8).
2. **No `<token>` in test names unless inside `-ForEach`** — aborts describe block under `Set-StrictMode -Version Latest` (WRONG 10).
3. **No common params (`ErrorAction` etc.) inside splatted hashtables** — double-bind causes silent failure in Pester mock proxy (WRONG 7).
4. **`AfterAll` cleanup must use `if ($IsWindows) { ... }` wrapping** — not `if (-not $IsWindows) { return }` (this is the #197 fix pattern — enforce it in all new test files too).
5. **No closure keywords (`Closes #N`) in commit messages** without explicit user confirmation of Windows test results (see `.claude/rules/commit-messages.md`).
6. **Tests that touch `Register-ScheduledTask` are Windows-only** — always `-Skip:(-not $IsWindows)`.
7. **Coverage threshold bumps must be in the same commit as the tests that justify them** — do not bump speculatively.

---

## Threshold Ladder

| After ticket | `$CoverageThreshold` (Invoke-Tests.ps1) | `$minPct` (.github/workflows/test.yml) |
|---|---|---|
| Current (pre-#197) | 40 | 40 |
| #198 ships | 50 | 50 |
| #199 ships | 60 | 60 |
| #200 ships | 75 | 75 |
| #201 ships | 95 | 95 |

Both values live at:
- `Invoke-Tests.ps1` line ~101: `$CoverageThreshold = 40`
- `.github/workflows/test.yml` coverage-gate step: `$minPct = 40`

---

## Dependency Order

```
#197  (complete the 6 AfterAll fixes — no deps)
  └─▶ #198  (BusinessLogicHelpers.Tests.ps1)
        └─▶ #199  (DataLayerHelpers.Tests.ps1)
              └─▶ #200  (STA WPF harness)
                    └─▶ #201  (mop-up after JaCoCo report)
```

Each ticket = one **fresh context window**. Clear context between tickets. Start each session by:
1. `cd /home/vercel-sandbox/repo && git pull origin SevAI_installing_bmad`
2. Read the ticket's agent brief comment
3. Run `/implement` → `/tdd` → `/code-review` → commit → push

---

## Key File Locations

| Purpose | Path |
|---------|------|
| Main source | `DailyMotivation.ps1` |
| Test runner | `Invoke-Tests.ps1` |
| CI workflow | `.github/workflows/test.yml` |
| Unit tests | `Tests/Unit/` |
| Integration tests | `Tests/Integration/` |
| WPF tests (to create) | `Tests/WPF/` |
| Coverage output | `coverage.xml` (standard), `coverage-wpf.xml` (#200+) |
| Pester rules | `.claude/rules/pester-tests.md` |
| WPF/resource rules | `.claude/rules/dailymotivation-script.md` |
| Commit message rules | `.claude/rules/commit-messages.md` |
| Skill router | `CLAUDE/skills/engineering/ask-matt/SKILL.md` |

---

## Suggested Skills

| Task | Skill |
|------|-------|
| Implementing each ticket (one per session) | `/implement` |
| Writing each test slice red→green | `/tdd` |
| Reviewing the diff before committing | `/code-review` |
| Bridging between sessions | `/handoff` (this document's pattern) |
| Diagnosing a test failure that resists first glance | `/diagnosing-bugs` |

**Do not use:**
- `/wayfinder` — destination is fully visible
- `/grill-with-docs` — grilling is complete; decisions are in the agent briefs
- `/triage` — the child tickets are already `ready-for-agent`

---

## Session Hygiene Reminder

- Push after every commit. Sandbox is ephemeral.
- Token generation: `python3 /home/vercel-sandbox/gh_app_token.py /home/vercel-sandbox/sevwrenai.private-key.pem` — the output's last line is the token. Redact from any logs.
- Do not use `Closes #N` in commit messages without explicit user confirmation of Windows test results.
- Coverage validation only counts from `windows-latest` CI — Linux results do not satisfy the gate.
