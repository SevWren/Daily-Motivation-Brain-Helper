# CLAUDE.md Quality Criteria

## The primary constraint

**Official limit: under 200 lines.** A file over 200 lines cannot score above 70/100 regardless of content quality, because length directly reduces adherence — Claude begins ignoring rules as the file grows.

Source: code.claude.com/docs/en/memory — *"target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence."*

---

## Scoring Rubric (100 points total)

### 1. Size compliance (30 points) — hard gate

| Lines | Score |
|-------|-------|
| Under 150 | 30 |
| 150–200 | 20 |
| 200–300 | 10 (cap: total score cannot exceed 70) |
| Over 300 | 0 (cap: total score cannot exceed 50) |

**A file over 200 lines is failing by definition. Score other criteria but apply the cap.**

### 2. Content discipline (25 points)

Apply the official test to every line: *"Would removing this cause Claude to make mistakes?"*

| Result | Score |
|--------|-------|
| Every line passes the test | 25 |
| 1–3 lines fail the test | 15 |
| 4–10 lines fail the test | 5 |
| More than 10 lines fail | 0 |

**Automatic failures (lines that always fail the test):**
- Directory trees or file listings Claude can read from the codebase
- Function/class inventories that are in source files
- Architecture overviews that duplicate what's in `docs/`
- Standard language/framework conventions Claude already knows
- Verbose explanations of how a pattern works (cite a doc instead)
- One-off historical notes or bug fix records

### 3. Accuracy (20 points)

| State | Score |
|-------|-------|
| All commands work, all file paths exist, no stale claims | 20 |
| 1–2 stale or wrong items | 12 |
| 3–5 stale or wrong items | 5 |
| More than 5 wrong items | 0 |

### 4. Actionability (15 points)

| State | Score |
|-------|-------|
| All commands are copy-paste ready; gotchas are specific and verifiable | 15 |
| Mostly actionable, 1–2 vague items | 8 |
| Several vague or unverifiable instructions | 3 |
| Mostly theoretical | 0 |

### 5. Correct use of alternatives (10 points)

| State | Score |
|-------|-------|
| Multi-step procedures are in skills; path-specific rules are in `.claude/rules/`; nothing in CLAUDE.md that should be elsewhere | 10 |
| 1–2 items that belong in a skill or rule | 5 |
| Multiple items that should be off-loaded | 0 |

---

## Grade thresholds

| Grade | Score | Meaning |
|-------|-------|---------|
| A | 90–100 | Under 150 lines, every line earns its place |
| B | 70–89 | Under 200 lines, minor content discipline issues |
| C | 50–69 | Over 200 lines OR significant content discipline failures |
| D | 30–49 | Seriously over-length OR mostly stale |
| F | 0–29 | Severely bloated, mostly incorrect, or missing entirely |

---

## Red flags (automatic C or below)

- File over 200 lines
- Architecture section with directory trees or function lists
- Sections that restate what `README.md` or `docs/` already says
- Instructions that only apply when editing a specific file type (should be a path-scoped rule)
- Multi-step workflows with more than 3 steps (should be a skill)
- `@path` imports used to "organize" without reducing context (imports load at startup)
- Generic advice like "write clean code" or "always test"
