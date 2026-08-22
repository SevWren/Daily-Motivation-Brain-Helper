---
name: self-reflect
description: Enterprise-grade forensic self-reflection over recent git history. Multi-axis audit with pass/fail gates, mandate compliance matrix, platform drift forensics, test quality review, and ranked generation constraints.
argument-hint: "[7d | 14d | 30d] (defaults to 14d)"
disable-model-invocation: true
---

You are auditing your own prior work with the same adversarial rigour an external auditor would apply.
**Start from the assumption that errors exist. Your task is to find them — not to confirm things went well.**

Every finding requires a commit SHA or file+line citation. Findings without evidence are struck.
Every phase ends on a **GATE** — a binary PASS/FAIL checklist. A failed gate is a blocker; document it and continue, but mark the final report INCOMPLETE.

Read `CLAUDE.md` in full before Phase 1. The mandates there are the audit standard.

---

## Phase 0 — Evidence Harvest

Collect all raw evidence before any analysis. Do not interpret yet.

```bash
# Full commit list with stats
git log --since="<window>" --no-merges --format="%H %ad %s" --date=short

# Per-commit diff inventory (captures actual code changes, not just messages)
git log --since="<window>" --no-merges -p --stat

# File churn — how many commits touched each file
git log --since="<window>" --no-merges --name-only --format="" | sort | uniq -c | sort -rn | head -30

# Fix/regression commits (the highest-signal bucket)
git log --since="<window>" --no-merges --format="%H %s" | grep -iE "(fix|hotfix|revert|regress|bug|patch|broke|broken|access.denied|dispose|schedul|principal|logon|runlevel)"

# Commits touching Windows-sensitive surface areas
git log --since="<window>" --no-merges --format="%H %s" -- \
  "*.ps1" "*.psd1" "*Tests*" "*TaskScheduler*" "*ContextMenu*" "*Config*" "*Window*"

# Grep source for known-bad patterns in current HEAD
git grep -n "\.Dispose()" -- "*.ps1"
git grep -n "ErrorAction" -- "*.ps1" | grep -v "Stop\|SilentlyContinue\|Ignore"
git grep -n "LogonType\|RunLevel\|S4U\|Highest" -- "*.ps1"
git grep -n "\$HOME\|/home/\|/tmp/\|/usr/\|linux\|darwin" -i -- "*.ps1"
git grep -n "<[A-Za-z][A-Za-z0-9_-]*>" -- "*Tests*.ps1"
git grep -n "New-ScheduledTaskAction\|New-ScheduledTaskTrigger\|New-ScheduledTaskSettingsSet\|New-ScheduledTaskPrincipal" -- "*Tests*.ps1" | grep -v "Mock"
git grep -n "PSCustomObject" -- "*Tests*.ps1"
git grep -n "RemoveParameterValidation" -- "*Tests*.ps1"
git grep -n "ErrorAction.*=.*'Stop'\|ErrorAction.*=.*\"Stop\"" -- "*.ps1" | grep "@{"
```

**GATE 0 — Evidence complete**
- [ ] Raw commit log captured (SHA + date + message for every commit in window)
- [ ] Full diffs captured (`-p` output reviewed, not skipped)
- [ ] Churn list captured (top 30 files by commit frequency)
- [ ] All grep outputs captured (zero results is a valid result — document it)
- [ ] `CLAUDE.md` read in full this session

Gate 0 failure = insufficient evidence base. Re-run missing commands before proceeding.

---

## Phase 1 — Mandate Compliance Audit

Build a compliance matrix: every commit in the fix/regression bucket × every mandate below.
Mark each cell: **PASS** (mandate respected), **FAIL** (mandate violated — cite the diff hunk), or **N/A** (mandate irrelevant to this commit).

A single FAIL is a **Critical finding**. Document the exact diff hunk, the mandate violated, and the commit SHA.

### The 7 Mandates (from CLAUDE.md — audit standard)

**M1 — Register-ScheduledTask error handling**
`Register-ScheduledTask` must be called with `-ErrorAction Stop` inside a `try/catch`. The catch block must cover: Access Denied (`0x80070005`), elevation required, S4U logon failure (`0x8007052e`), service unavailable (`0x80041315`), file not found (`0x80070002`), and a default HResult fallback. A `Register-ScheduledTask` failure must never surface as "Invalid Folder".

**M2 — WPF Window disposal**
`System.Windows.Window` has no `Dispose()` method. Call `.Close()` only. For all other objects, guard with `$obj -is [System.IDisposable]` before `.Dispose()`. `DriveInfo` is not IDisposable.

**M3 — $script:* variable removal**
No `$script:*` module-level variable may be removed without grepping the entire file for every reference. A variable with no obvious callers in the happy path may still be a required fallback (e.g. `$script:ConfigDefaults`).

**M4 — Error message operation naming**
Path sanitization to `[PATH]` is correct. But every error message must name the failing operation. "Access is denied" without the operation name is a violation. "OS task registration was denied" is correct.

**M5 — Catch pattern coverage**
A catch block on `Register-ScheduledTask` that matches only `'Access Denied|not have permission'` is a violation. It misses elevation, S4U logon failure, service unavailable, and file-not-found cases.

**M6 — Task principal parameters**
Current validated values: `LogonType Interactive`, `RunLevel Limited`. Any change to `New-ScheduledTaskPrincipal` parameters requires live Windows 10/11 test evidence attached to the issue before the commit may be considered resolved.

**M7 — Pester splatting and mock patterns**
Common parameters (`ErrorAction`, `WarningAction`, `Verbose`, `Debug`) must never appear inside a splatted hashtable passed to a mocked cmdlet — specify them directly on the call. `New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`, `New-ScheduledTaskSettingsSet`, and `New-ScheduledTaskPrincipal` must never be mocked. Test names must not contain `<token>` syntax unless used with `-ForEach` data.

**GATE 1 — Mandate audit complete**
- [ ] Every commit in the fix/regression bucket has been evaluated against all 7 mandates
- [ ] Every FAIL has a cited diff hunk and commit SHA
- [ ] Compliance matrix is fully populated (no blank cells)
- [ ] Any N/A is justified (not used as a shortcut to skip evaluation)

---

## Phase 2 — Platform Forensics

This repo targets **Windows 10/11**. Every commit that touches scheduling, WPF, registry, or path handling must be evaluated for platform assumptions.

### Windows validation evidence chain

For each commit in the platform-sensitive bucket, answer these questions from evidence — not from code logic:

1. **Was a Windows validation run posted?** Check: issue comments, PR comments, commit message. A passing Linux CI run does not count.
2. **Is the commit guarded by `-Skip:(-not $IsWindows)`?** If yes, was the Windows runner result attached before the associated issue was closed?
3. **Does the commit touch `New-ScheduledTaskPrincipal`, `Register-ScheduledTask`, `Get-ScheduledTask`, or `Unregister-ScheduledTask`?** If yes, M1 and M6 apply — re-evaluate.

### Linux assumption patterns — scan every changed .ps1 file

| Pattern | Risk | What to look for |
|---------|------|-----------------|
| Forward-slash paths | High | `"C:/..."`, `Join-Path` with `/` separator literals |
| `$HOME` or `$env:HOME` | High | Should be `$env:USERPROFILE` or `$env:APPDATA` |
| `/tmp/` or `/var/` | Critical | Never valid on Windows |
| `$IsLinux`, `$IsMacOS` used as a guard | Medium | Confirm Windows path still executes |
| Case-sensitive path comparisons | Medium | Windows paths are case-insensitive |
| `pwsh` assumed available at runtime | High | Compiled exe runs .NET Framework, not PS7 |
| PS7-only syntax in runtime code paths | High | `??=`, ternary `?:`, `ForEach-Object -Parallel` |
| `.ps1` path in Task Scheduler action | Critical | Must be `.exe` path — guard exists, confirm it wasn't removed |

For each pattern found: cite file, line, commit SHA, and assess whether it was introduced or was pre-existing.

**GATE 2 — Platform audit complete**
- [ ] Every scheduling/WPF/registry/path commit evaluated for Windows validation evidence
- [ ] Every Linux assumption pattern either confirmed absent or documented as a finding
- [ ] All unvalidated scheduling changes are marked `UNVALIDATED` in the drift table
- [ ] No commit in the window closed a scheduling issue without Windows evidence

---

## Phase 3 — Test Quality Audit

A test that only passes on Linux while claiming to validate Windows behavior is a **false green** — worse than no test because it produces false confidence.

Evaluate every new or modified test file in the window against these axes:

### Axis A — Platform correctness

- Tests using `Register-ScheduledTask`, `Get-ScheduledTask`, `Unregister-ScheduledTask`, or registry paths: are they guarded by `-Skip:(-not $IsWindows)` or running inside a `BeforeAll` that injects `HeadlessPlatform`?
- Platform-abstraction tests (`*.Platform.Tests.ps1`): confirm they use `HeadlessPlatform` injection and do **not** claim to validate real Windows Task Scheduler behavior.
- Regular tests (`*.Tests.ps1` without `.Platform.`): confirm they are Windows-only (either skipped on Linux or documented as requiring Windows).

### Axis B — Pester v5 correctness

- `Mock` definitions inside `BeforeAll` at file scope: valid in Pester v5, invalid in v4. Confirm the file imports `Pester -MinimumVersion 5.0`.
- `-ForEach` on `It` blocks: confirm the data source exists and every `<token>` in the test name has a matching key.
- `Should -Be`, `Should -Not -BeNullOrEmpty`: confirm assertions are on the right object (not on `$null` by accident).
- `New-PesterConfiguration` usage: confirm `Run.Exit`, XML output, and coverage settings match `PesterConfiguration.psd1`.

### Axis C — Mock fidelity

For every `Mock` in a changed test file:
- Is `New-ScheduledTaskAction`, `New-ScheduledTaskTrigger`, `New-ScheduledTaskSettingsSet`, or `New-ScheduledTaskPrincipal` mocked? **Violation** — these must run as real Windows cmdlets to produce `CimInstance` types.
- Is `PSCustomObject` returned from a mock for a cmdlet that expects `CimInstance`? **Violation** — `CimInstance` type constraints are not removed by `-RemoveParameterValidation`.
- Does any `@splat` dict include `ErrorAction`, `WarningAction`, `Verbose`, or `Debug`? **Violation** — double-bind causes silent non-terminating errors.
- Does any mock body call the real cmdlet via module qualification (`Module\Cmdlet`)? **Violation** — Pester 5 still intercepts these; it causes infinite recursion.

### Axis D — Test completeness

- Was a regression test added for every bug fix in the window?
- Does each regression test exercise the **real bug pattern** at the correct seam (not a too-shallow unit test that misses the chain)?
- Is the Windows integration test for `New-MotivationTask` present in the test suite? (`-Skip:(-not $IsWindows)` real `Register-ScheduledTask`, no mocking.) If absent, document as a standing gap.

**GATE 3 — Test audit complete**
- [ ] Every new/modified test file evaluated on all four axes
- [ ] Every Axis C violation documented as a Critical finding
- [ ] Platform correctness confirmed for every scheduling test
- [ ] Windows integration test presence/absence documented

---

## Phase 4 — Code Archaeology

Read the full diff for every changed function. Evaluate against these axes. Do not skim.

### Axis A — .NET Framework 4.x runtime compatibility

The compiled exe targets .NET Framework 4.x (ps2exe constraint). PS7-only features in runtime code paths are invisible at development time and only fail at runtime on the compiled exe.

Scan for in-window changes to runtime code (not test code) that use:
- Ternary operator `condition ? a : b` (PS7+, not .NET 4.x)
- Null coalescing assignment `??=` (PS7+)
- `ForEach-Object -Parallel` (PS7+)
- `[System.Text.Json.*]` (not available in .NET 4.x — use `ConvertTo-Json`/`ConvertFrom-Json`)
- Named captures in `-match` accessed via `$Matches` with PS7 syntax

### Axis B — WPF and resource lifecycle

For every change touching `Show-MainWindow`, `Show-PopupWindow`, or any function that creates WPF controls:
- Is `.Dispose()` called on any `System.Windows.Window`? **Violation** (M2).
- Is `.Close()` called where `.Dispose()` was? **Correct**.
- For `DispatcherTimer`, `Mutex`, `FolderBrowserDialog`: is the call guarded by `$obj -is [System.IDisposable]`?
- Are event handlers detached before the window closes? (Memory leak risk on repeated popup invocations.)

### Axis C — Module-level variable integrity

For every `$script:*` variable removed or renamed in the window:
- Was the entire file grepped for all references before removal?
- Is the variable a fallback path (used when a config read returns null)? If yes, its removal is a **Critical finding** regardless of whether callers appear in the happy path.

### Axis D — ExePath resolution integrity

The compiled exe may have `$MyInvocation.MyCommand.Path` empty at runtime. Confirm the current resolution order in the source matches CLAUDE.md CORRECT 2:
1. `$MyInvocation.MyCommand.Path` (non-empty check)
2. `[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName`

If any in-window change altered this guard or the `.ps1` path rejection in `Register-ContextMenu`, document as a Critical finding.

### Axis E — Startup popup prohibition

The application must never display a popup, dialog, or blocking message on startup in `main` mode. Scan every in-window change to the `main` mode entry path and `Show-MainWindow` for calls to `Show-ErrorDialog`, `Show-InfoDialog`, `[System.Windows.MessageBox]::Show`, or any modal dialog constructor.

**GATE 4 — Code archaeology complete**
- [ ] Every changed function in the window read (not skimmed) against all five axes
- [ ] Every .NET 4.x compatibility issue documented
- [ ] Every WPF lifecycle issue documented
- [ ] $script:* variable removals audited
- [ ] ExePath resolution integrity confirmed
- [ ] Startup popup prohibition confirmed

---

## Phase 5 — Self-Review

Synthesise the findings from Phases 1–4 into two inventories. Every item must cite phase + finding ID.

### Strengths

Patterns of correct generation confirmed by evidence. A strength is confirmed only when:
- A mandate was satisfied across multiple commits (not just one)
- A test was added at the correct seam alongside a fix
- A Windows-specific guard was added proactively before a regression occurred
- Documentation (`CLAUDE.md`, `CONTEXT.md`, ADRs) was kept in sync with code changes

Do not list a strength if the corresponding gate has a failure — partial compliance is not a strength.

### Weaknesses

Every gate failure, mandate breach, platform drift finding, and test quality violation. Classify each by root cause:

| Root cause code | Description |
|----------------|-------------|
| `PLATFORM-ASSUMPTION` | Applied Linux/cross-platform reasoning to a Windows-only API |
| `PREMATURE-CLOSURE` | Declared a bug fixed or issue resolved before gate criteria were met |
| `MANDATE-BLINDNESS` | Generated code without consulting the relevant CLAUDE.md mandate |
| `MOCK-EQUIVALENCE` | Treated a passing mocked test as proof of real Windows behavior |
| `SCOPE-CREEP` | Generated beyond what was asked, introducing untested surface area |
| `STALE-PATTERN` | Applied a pattern that was correct in a prior commit but was later superseded |
| `NEGATIVE-TRANSFER` | Applied a correct pattern from a different code area where it does not apply |
| `INCOMPLETE-COVERAGE` | Wrote a fix without a regression test at the correct seam |

Each weakness entry: finding ID · commit SHA · root cause code · one-sentence description.

**GATE 5 — Self-review complete**
- [ ] Every gate failure appears as a weakness
- [ ] Every weakness has a root cause code
- [ ] No strength is listed that has an associated gate failure
- [ ] Strengths are backed by multi-commit evidence, not single instances

---

## Phase 6 — Self-Reflection

Answer these questions from evidence only. First-person. No hedging.

**What did I generate that was wrong?**
List each incorrect output: what I generated, what the correct output should have been, and the commit where it appears or was later corrected.

**Why did I generate it?**
Map each item above to its root cause code from Phase 5. Then go one level deeper: what information was available to me at generation time that I failed to use? (e.g. "CLAUDE.md mandate M6 was in context; I did not apply it because I prioritised making the test pass on Linux.")

**What recurred?**
A recurrence is the same root cause code appearing in two or more separate commits. Recurrences are the highest-signal findings in this entire reflection — they indicate a **systematic generation bias**, not a one-off mistake. Weight each: 2 occurrences = HIGH, 3+ occurrences = CRITICAL.

**What would a correct generation have looked like?**
For each Critical or HIGH recurrence, write the exact code or decision that would have been correct. This is the positive target — not what to avoid, but what to produce instead.

**GATE 6 — Self-reflection complete**
- [ ] Every weakness from Phase 5 addressed with a "why"
- [ ] Every recurrence identified and weighted
- [ ] Every Critical/HIGH recurrence has a positive target output

---

## Phase 7 — Future Actions

Produce a ranked action list from the Phase 6 findings. Rank by: recurrence weight (CRITICAL first) then mandate severity (M1 > M6 > M2 > M3 > M4 > M5 > M7).

Each action is a **generation constraint** — a rule that changes what I write next time, not a reminder to "be more careful."

Format each action:

```
### [CRITICAL | HIGH | MEDIUM | LOW] <short title>

**Root cause:** <code from Phase 5>
**Evidence:** <commit SHA(s) or finding ID(s)>
**Recurrence weight:** <1× | 2× | 3×+>
**Mandate:** <M1–M7 or N/A>

**Generation constraint:**
Before generating any change to <specific area>, I must:
1. <first mandatory check — concrete and verifiable>
2. <second mandatory check if needed>

**Pass criterion:** <the exact observable condition that confirms this constraint was met>
**Fail signal:** <the exact observable condition that reveals this constraint was violated>

**Windows validation required:** YES | NO
```

Every constraint must be checkable by a reviewer reading the diff — "think harder" is not a constraint.

---

## Phase 8 — Audit Report

Produce the full report in this format. Do not abbreviate sections.

```
═══════════════════════════════════════════════════════════
SELF-REFLECTION AUDIT REPORT
Window: <date range>  |  Commits: <N>  |  Generated: <today>
═══════════════════════════════════════════════════════════

GATE SUMMARY
────────────
Gate 0 (Evidence):       PASS | FAIL
Gate 1 (Mandates):       PASS | FAIL  — <N> breaches
Gate 2 (Platform):       PASS | FAIL  — <N> unvalidated changes
Gate 3 (Tests):          PASS | FAIL  — <N> violations
Gate 4 (Code):           PASS | FAIL  — <N> findings
Gate 5 (Self-review):    PASS | FAIL
Gate 6 (Reflection):     PASS | FAIL
Overall:                 COMPLETE | INCOMPLETE

MANDATE COMPLIANCE MATRIX
─────────────────────────
       M1  M2  M3  M4  M5  M6  M7
<SHA>  --  --  --  --  --  --  --
...

PLATFORM DRIFT TABLE
────────────────────
SHA | File(s) | Change summary | Windows-validated? | Evidence

FINDINGS INVENTORY
──────────────────
[CRITICAL] <id>: <one-line description> (SHA: <sha>, Root cause: <code>)
[HIGH]     <id>: ...
[MEDIUM]   <id>: ...
[LOW]      <id>: ...

STRENGTHS
─────────
- <evidence-backed strength>

WEAKNESSES
──────────
- <finding id> | <root cause code> | <description>

RECURRENCES (highest signal)
─────────────────────────────
- <root cause code> × <N> occurrences — <CRITICAL | HIGH>

FUTURE ACTIONS
──────────────
[ranked list from Phase 7]

STANDING GAPS (known issues not addressed this window)
──────────────────────────────────────────────────────
- Windows integration test for New-MotivationTask: <PRESENT | ABSENT>
- <any other persistent gaps identified>
═══════════════════════════════════════════════════════════
```

After the full report, output a **CRITICAL ACTIONS** block — the top 3 generation constraints extracted verbatim from Phase 7, boxed separately for immediate reference.
