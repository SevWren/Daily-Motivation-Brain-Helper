---
name: self-reflect
description: LLM self-reflection over recent git history — extracts empirical evidence of code patterns, mandate compliance, and Windows/Linux drift to produce ranked future actions.
argument-hint: "[14d | 7d | 30d | this-sprint] (defaults to 14d)"
disable-model-invocation: true
---

Treat the git history as the **sole empirical record**. Every finding must cite a commit SHA or file. No speculation — if it isn't in the history, it isn't a finding.

> **Audience:** You are an LLM agent reflecting on your own prior work in this repo. The human is a reviewer, not the subject. Write findings as first-person agent observations ("I introduced…", "I missed…") and phrase future actions as constraints on your own next generation.

---

## Step 1 — Pin the window

Read `$ARGUMENTS`:
- `7d` — last 7 days
- `14d` (default) — last 14 days
- `30d` — last 30 days
- `this-sprint` — last 14 days (alias)

Run these git commands to build the evidence base:

```bash
git log --since="<window>" --oneline --stat --no-merges
git log --since="<window>" --format="%h %s" --no-merges
git log --since="<window>" --oneline --no-merges | wc -l
git diff --stat $(git log --since="<window>" --format="%H" | tail -1) HEAD
git log --since="<window>" --no-merges --pretty=format:"%h %s" | grep -iE "(fix|bug|hotfix|revert|regression|access.denied|dispose|schedul|linux|windows|pester|task.principal)"
```

**Completion criterion:** You have raw commit list, per-file churn counts, and a filtered list of fix/regression commits. Do not proceed without all three.

---

## Step 2 — Evidence extraction

From the raw data, classify every commit into exactly one bucket:

| Bucket | Pattern |
|--------|---------|
| `feat` | new behaviour, new function, new UI |
| `fix` | bug fix, hotfix, regression correction |
| `refactor` | restructure without behaviour change |
| `test` | new or modified tests only |
| `docs` | documentation, CLAUDE.md, AGENTS.md, CONTEXT.md |
| `chore` | build, deps, CI, config |

Then extract:

**Hotspot files** — files changed in 3+ commits. These are instability signals.

**Recurrence signatures** — the same symptom fixed more than once (same function, same error string, same test name). A recurrence is the highest-signal finding in this entire reflection.

**Windows/Linux drift commits** — commits touching scheduling, registry, Task Scheduler, WPF, or paths. Flag each: was it validated on Windows 10/11, or only on Linux CI?

**Mandate audit** — for each commit in the fix/regression bucket, check against the seven CLAUDE.md mandates:

1. Was `Register-ScheduledTask` wrapped in `try/catch -ErrorAction Stop`?
2. Was `.Dispose()` called on `System.Windows.Window`? (ban — use `.Close()`)
3. Was a `$script:*` variable removed without a grep of all references?
4. Was an error message sanitized to `[PATH]` without naming the failing operation?
5. Was a narrow catch pattern used (missing elevation / S4U / service-unavailable cases)?
6. Was `LogonType` or `RunLevel` changed without a live Windows 10/11 test?
7. Were common parameters (`ErrorAction`, `WarningAction`) placed inside a splatted hashtable?

Mark each violation `BREACHED` or `CLEAN`. If `BREACHED`, cite the commit SHA.

**Completion criterion:** All commits classified, all hotspots named, all recurrences identified, all seven mandates audited with explicit CLEAN/BREACHED verdict.

---

## Step 3 — Self-review

### Strengths

List observed patterns that reduced errors or improved reliability. Each item must cite a commit or file range. Examples of what to look for:
- Mandate compliance maintained across the window
- Test coverage added alongside fixes (not after)
- Windows-specific guard conditions added proactively
- CLAUDE.md or CONTEXT.md updated to capture new learnings

### Weaknesses

List observed failure patterns. Each item must cite a commit SHA. Rank by recurrence count — a pattern that appeared twice outranks one that appeared once. Look for:
- A fix that was reverted or patched within the same window
- A mandate breach (from Step 2)
- A test that only passed on Linux but was committed as validated
- A `$script:*` variable or function removed without checking all callers
- Windows-specific API calls (Task Scheduler, WPF, registry) changed without live test evidence

---

## Step 4 — Self-reflection

Answer these four questions using only the Step 3 findings as evidence:

**What did I actually do?**
One-paragraph factual summary. Commit count, fix/feature ratio, hotspot files, mandate breach count.

**What patterns are visible?**
Name each recurrence signature from Step 2. "I generated X three times across this window" is a pattern. A one-off error is not.

**What should I stop generating?**
One item per recurrence or mandate breach. Phrase as a generation constraint:
> "Do not generate `<pattern>` without first `<guard condition>`."

**What should I start doing differently?**
One item per identified gap. Phrase as a positive generation rule:
> "Before generating any change to `<area>`, always `<verification step>`."

---

## Step 5 — Future actions

Produce a ranked action list. Rank by: recurrence count (highest first), then mandate severity (scheduling > cleanup > error messages).

Format:

```
## Future Actions

### [CRITICAL] <title>
**Evidence:** <commit SHA(s)>
**Pattern:** <what recurred>
**Generation rule:** <exact constraint on next code generation>
**Windows validation required:** yes | no

### [HIGH] <title>
...

### [LOW] <title>
...
```

Every action must have a `Generation rule` — a concrete, checkable constraint that changes what I write next time, not a vague aspiration.

---

## Step 6 — Windows/Linux drift report

This section is always present, even if empty.

List every commit in the window that touched scheduling, WPF, registry, or path handling, and state:

| SHA | File(s) | Change summary | Windows-validated? | Evidence |
|-----|---------|----------------|-------------------|---------|

If a change was not validated on Windows 10/11 (no issue comment with terminal output, no CI Windows runner), mark it `UNVALIDATED`. Unvalidated scheduling changes are the primary source of the Access Denied regression history in this repo.

---

## Output format

```markdown
## Self-Reflection: [window] — [date range]

### Summary
X commits · Y files changed · Z fixes · W recurrences · V mandate breaches

### Strengths
- ...

### Weaknesses
- ...

### What I learned
...

### What I will change
...

### Future Actions
[ranked list from Step 5]

### Windows/Linux Drift
[table from Step 6]
```

Present the output, then surface the **top 3 future actions** as a numbered list below the full report for quick reference.
