# CLAUDE.md Update Guidelines

## The constraint that overrides everything else

**Target: under 200 lines.** Every proposed change must be evaluated against this constraint first. If a file is already at or over 200 lines, no additions are permitted until cuts bring it below 180 (leaving 20 lines of headroom).

Source: code.claude.com/docs/en/best-practices — *"If your CLAUDE.md is too long, Claude ignores half of it because important rules get lost in the noise. Ruthlessly prune."*

---

## Decision tree for every line

```
Does removing this line cause Claude to make a specific, identifiable mistake?
│
├─ NO  → Cut it, or move it (see below)
│
└─ YES → Is it a multi-step procedure or task-specific workflow?
         │
         ├─ YES → Move to .claude/skills/<name>/SKILL.md
         │
         └─ NO  → Does it only apply when editing specific file types/paths?
                  │
                  ├─ YES → Move to .claude/rules/<name>.md with paths: frontmatter
                  │
                  └─ NO  → Keep it in CLAUDE.md
```

---

## What to KEEP in CLAUDE.md

Only content where removing it would cause Claude to make a specific mistake in every session:

| Category | Example |
|----------|---------|
| Build commands Claude can't guess | `.\build.ps1` requires ps2exe pre-installed |
| Style rules that differ from defaults | "Use `Interactive` not `S4U` for LogonType" |
| Non-obvious gotchas | "`Get-MotivationTasks` is plural — singular throws CommandNotFoundException" |
| Environment quirks | "`$script:ExePath` is undefined under `-NoRun`; tests must set it" |
| Constraints with silent failure modes | "Never put ErrorAction in a splatted hashtable passed to a mock" |
| Critical architectural decisions | "One file, one exe — never split into src/" |

---

## What to CUT from CLAUDE.md

| Category | Why | Alternative |
|----------|-----|-------------|
| Directory trees / file listings | Claude reads the filesystem | None — Claude reads it |
| Function/class inventories | Claude reads the source | `docs/reference/` |
| Architecture overviews | Claude reads `docs/architecture/` | Link to `docs/architecture/` |
| Standard conventions Claude knows | Already in pretraining | None needed |
| Verbose explanations of how a pattern works | Too long for CLAUDE.md | Link to ADR or doc |
| Historical bug notes ("we fixed X in commit Y") | Past, not future | Git history |
| Content that duplicates README.md or CONTRIBUTING.md | Stale risk, redundant | Link to those files |
| Generic advice ("write clean code") | Claude already does this | Nothing |

---

## What to MOVE (not cut — preserve the value, change the location)

### Move to `.claude/skills/<name>/SKILL.md`

When: the content is a multi-step procedure (3+ steps), a repeatable workflow, or domain knowledge needed only for specific tasks.

Skills are loaded on demand — they never consume context unless invoked. This is the correct home for content that matters sometimes but shouldn't bloat every session.

```yaml
# .claude/skills/run-integration-tests/SKILL.md
---
name: run-integration-tests
description: Run the Windows integration test suite on the real Task Scheduler
disable-model-invocation: true
---
1. Ensure running on Windows 10/11 PowerShell 7
2. Run: .\Invoke-Tests.ps1 -Tag Integration
3. Post terminal output to the relevant GitHub issue before closing it
```

### Move to `.claude/rules/<name>.md`

When: the content only applies when Claude is working with specific file types or paths.

Rules with `paths:` frontmatter load only when Claude reads matching files — they don't appear in every session.

```yaml
# .claude/rules/pester-tests.md
---
paths:
  - "Tests/**/*.ps1"
---
Never mock New-ScheduledTaskAction, New-ScheduledTaskTrigger, New-ScheduledTaskSettingsSet,
or New-ScheduledTaskPrincipal. Only mock the persistence layer.
Never include ErrorAction in a splatted hashtable — specify it on the call directly.
```

---

## What @path imports do NOT do

`@path/to/file` syntax in CLAUDE.md imports the target file — but it **does not reduce context**. The imported file loads into the context window at session start, same as if it were inline. Using imports for "organization" while keeping CLAUDE.md under 200 lines only works if the imported content would have been cut anyway. If you import a 300-line file from a 50-line CLAUDE.md, you now have 350 lines of context.

---

## Validation checklist before finalizing any update

- [ ] File is under 200 lines after all proposed changes
- [ ] Every retained line passes: "Would removing this cause Claude to make a specific mistake?"
- [ ] No line is something Claude can derive by reading the codebase
- [ ] No multi-step procedure — those belong in skills
- [ ] No path-specific instruction — those belong in `.claude/rules/`
- [ ] No `@path` import that increases total context beyond 200 lines
- [ ] Projected line count is shown to the user before applying changes
