---
name: claude-md-improver
description: Audit and improve CLAUDE.md files. Use when user asks to check, audit, update, improve, or fix CLAUDE.md files, or mentions "CLAUDE.md maintenance" or "project memory optimization".
tools: Read, Glob, Grep, Bash, Edit, WebFetch
---

# CLAUDE.md Improver

Audit and improve CLAUDE.md files so they stay under the official 200-line limit while containing only what Claude cannot derive from reading the code.

**Official constraint (code.claude.com/docs/en/memory):**
> Target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence. Bloated CLAUDE.md files cause Claude to ignore your actual instructions.

**The primary action for a file over 200 lines is pruning, not adding.**

---

## Phase 1 — Discovery

Find all CLAUDE.md files and related instruction files:

```bash
find . \( -name "CLAUDE.md" -o -name "CLAUDE.local.md" -o -name ".claude.md" \) 2>/dev/null
find . -path "./.claude/rules/*.md" 2>/dev/null
find . -path "./.claude/CLAUDE.md" 2>/dev/null
```

Also note what off-load destinations already exist (used in Phase 3):
- `.claude/rules/` — path-scoped rules that only load when Claude touches matching files
- `.claude/skills/` — on-demand workflows that never enter context unless invoked
- `CLAUDE.local.md` — personal/local preferences, gitignored

---

## Phase 2 — Measure and Classify

For each CLAUDE.md file:

1. **Count lines**: `wc -l <file>`
2. **Flag if over 200 lines** — this is the primary quality gate
3. **Classify every line** into one of four buckets:

| Bucket | Definition | Action |
|--------|-----------|--------|
| **Keep** | Claude cannot derive this from reading the code; removing it would cause mistakes | Retain |
| **Cut** | Claude can derive this by reading the code, or it is generic/obvious | Delete |
| **Move to skill** | A multi-step procedure or task-specific workflow | Extract to `.claude/skills/` |
| **Move to rules** | An instruction that only applies to specific file types/paths | Extract to `.claude/rules/` |

Apply the official test to every line: *"Would removing this cause Claude to make mistakes?"* If no — it is Cut or Move, never Keep.

**Official Keep examples:** build commands Claude can't guess, style rules that differ from defaults, testing instructions, repo etiquette, architectural decisions, environment quirks, non-obvious gotchas.

**Official Cut examples:** anything Claude can derive by reading code, standard conventions, detailed API docs, verbose explanations, file-by-file descriptions, information that changes frequently.

---

## Phase 3 — Quality Report

Output this report before making any changes.

```
## CLAUDE.md Quality Report

### Size
- Current lines: X
- Target: under 200 lines
- Status: OVER / WITHIN / WELL WITHIN limit
- Lines to cut before any additions are considered: X

### Classification breakdown
- Keep: X lines
- Cut: X lines (list each — what it says, why it's cuttable)
- Move to skill: X lines (list each — what it says, which skill name)
- Move to rules: X lines (list each — what it says, which path glob)

### Accuracy issues (separate from size)
- Stale or wrong claims: [list with line numbers]
- Missing critical items: [list — ONLY items that would cause mistakes if absent]

### Score: X/100
```

**Scoring:**
- Under 200 lines: +30 points (hard gate — a file over 200 cannot score above 70)
- Every line passes "would removing this cause mistakes?" test: +25 points
- No content Claude can derive from reading the code: +15 points
- Commands/gotchas are accurate and copy-paste ready: +20 points
- No content that belongs in a skill or rule instead: +10 points

---

## Phase 4 — Proposed Changes

**Gate: if the file is over 200 lines, propose cuts first. Do not propose any additions until the cut list brings the file under 200 lines.**

Present changes in this order:

### 1. Cuts (always first)
For each Cut-bucket line:
```
CUT: line X–Y
Content: "..."
Reason: Claude can derive this by reading [specific file/code], OR: generic/obvious
```

### 2. Moves
For each Move-bucket item:
```
MOVE: line X–Y → .claude/skills/<name>/SKILL.md  (or .claude/rules/<name>.md)
Content: "..."
Reason: [multi-step procedure / path-specific rule]
New location: [proposed file path + brief structure]
```

### 3. Additions (only if cuts bring file under 180 lines — leave 20-line headroom)
For each genuinely missing item that would cause mistakes if absent:
```
ADD: after line X
Content: "..."
Reason: Claude cannot derive this from the code; removing it would cause [specific mistake]
```

### 4. Accuracy fixes
For each stale/wrong claim:
```
FIX: line X
Old: "..."
New: "..."
Reason: [what changed in the code]
```

Show the projected line count after all proposed changes.

---

## Phase 5 — Apply

After user approval, apply changes using the Edit tool. After applying:
1. Run `wc -l CLAUDE.md` and confirm under 200
2. Report final line count

## Key rules

- Never propose adding content Claude can derive by reading the codebase
- Never propose adding architecture overviews, directory trees, or function lists — these belong in docs or skills
- The `@path` import syntax does NOT reduce context — imported files load at session start just like CLAUDE.md content
- `.claude/rules/` with `paths:` frontmatter is the correct home for instructions that only apply to specific file types
- Skills with `disable-model-invocation: true` are the correct home for multi-step procedures
- Run `/doctor` in a Claude Code session to get Claude's own proposed cuts for a checked-in CLAUDE.md
