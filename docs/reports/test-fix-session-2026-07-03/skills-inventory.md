# Skills Inventory — Daily Motivation Brain Helper

**Location:** `/home/vercel-sandbox/Daily-Motivation-Brain-Helper/CLAUDE/skills/`
**Total Skills:** 17
**Report Date:** 2026-07-03

---

## Engineering Skills (10 skills)

### 1. diagnose
**Path:** `CLAUDE/skills/engineering/diagnose/SKILL.md`
**Purpose:** 6-phase structured debugging methodology for hard bugs and performance regressions
**Key Features:**
- Phase 1: Build feedback loop (most critical)
- Phase 2: Reproduce deterministically
- Phase 3: Hypothesize (3-5 ranked hypotheses)
- Phase 4: Instrument (targeted logging)
- Phase 5: Fix + regression test
- Phase 6: Cleanup + post-mortem
**When to Use:** Non-obvious bugs, flaky failures, performance regressions

### 2. tdd
**Path:** `CLAUDE/skills/engineering/tdd/SKILL.md`
**Purpose:** Test-driven development workflow
**When to Use:** Adding new features with test coverage

### 3. triage
**Path:** `CLAUDE/skills/engineering/triage/SKILL.md`
**Purpose:** Bug prioritization and categorization
**When to Use:** Multiple issues need priority ranking

### 4. grill-with-docs
**Path:** `CLAUDE/skills/engineering/grill-with-docs/SKILL.md`
**Purpose:** Documentation-based technical inquiry
**When to Use:** Deep technical documentation review needed

### 5. improve-codebase-architecture
**Path:** `CLAUDE/skills/engineering/improve-codebase-architecture/SKILL.md`
**Purpose:** Architectural refactoring guidance
**When to Use:** Large-scale restructuring or design improvements

### 6. prototype
**Path:** `CLAUDE/skills/engineering/prototype/SKILL.md`
**Purpose:** Rapid prototyping workflow
**When to Use:** Proof-of-concept development

### 7. to-issues
**Path:** `CLAUDE/skills/engineering/to-issues/SKILL.md`
**Purpose:** Convert analysis to GitHub issues
**When to Use:** Converting bug reports or feature requests to structured issues

### 8. to-prd
**Path:** `CLAUDE/skills/engineering/to-prd/SKILL.md`
**Purpose:** Create Product Requirements Documents
**When to Use:** Formal requirements documentation needed

### 9. zoom-out
**Path:** `CLAUDE/skills/engineering/zoom-out/SKILL.md`
**Purpose:** High-level codebase analysis
**When to Use:** Understanding system architecture and patterns

### 10. setup-matt-pocock-skills
**Path:** `CLAUDE/skills/engineering/setup-matt-pocock-skills/SKILL.md`
**Purpose:** Skill configuration setup
**When to Use:** Setting up development environment

---

## Productivity Skills (4 skills)

### 1. caveman
**Path:** `CLAUDE/skills/productivity/caveman/SKILL.md`
**Purpose:** Simplification mindset
**When to Use:** Overengineering concerns, simplification needed

### 2. grill-me
**Path:** `CLAUDE/skills/productivity/grill-me/SKILL.md`
**Purpose:** Interactive questioning for clarity
**When to Use:** Requirements clarification needed

### 3. handoff
**Path:** `CLAUDE/skills/productivity/handoff/SKILL.md`
**Purpose:** Session documentation and knowledge transfer
**When to Use:** Documenting work session for future reference

### 4. write-a-skill
**Path:** `CLAUDE/skills/productivity/write-a-skill/SKILL.md`
**Purpose:** Skill creation template
**When to Use:** Creating new custom skills

---

## Misc Skills (2 skills)

### 1. scaffold-exercises
**Path:** `CLAUDE/skills/misc/scaffold-exercises/SKILL.md`
**Purpose:** Exercise template generation
**When to Use:** Creating training exercises

### 2. setup-pre-commit
**Path:** `CLAUDE/skills/misc/setup-pre-commit/SKILL.md`
**Purpose:** Pre-commit hook configuration
**When to Use:** Setting up git pre-commit checks

---

## Repo Documentation (1 skill)

### 1. repo-doc-audit
**Path:** `CLAUDE/skills/repo-doc-audit/SKILL.md`
**Purpose:** Documentation quality auditing
**When to Use:** Reviewing and improving repository documentation

---

## Skills Used This Session

### Primary: diagnose
**Usage:** Referenced methodology for structured debugging approach
**Phases Referenced:**
- Phase 1: Build feedback loop → Installed PowerShell 7, ran Pester tests
- Phase 2: Reproduce → Confirmed 77 failures consistently
- Phase 3: Hypothesize → Analyzed root cause (missing Windows cmdlets)
- Phase 6: Cleanup + post-mortem → Generated comprehensive report

**Key Insight:** Diagnose skill emphasizes spending disproportionate effort on Phase 1 (feedback loop). Successfully building a working test environment was critical to understanding the true nature of failures.

### Secondary: Skills Inventory
**Usage:** Completed per user request to list all available skills

---

## Skill Recommendations for This Project

### For Test Debugging
**Use:** `/diagnose` - Primary skill for systematic bug investigation
**Example:** `When a test fails, use diagnose to build feedback loop, reproduce, hypothesize root cause`

### For Feature Development
**Use:** `/tdd` - Write tests before implementing features
**Example:** `Adding new Task Scheduler features should follow TDD workflow`

### For Bug Tracking
**Use:** `/to-issues` - Convert test failures to structured GitHub issues
**Example:** `Convert Windows-specific test failures to issues with clear reproduction steps`

### For Knowledge Transfer
**Use:** `/handoff` - Document session findings for team
**Example:** `Document Windows validation requirements for QA team`

### For Simplification
**Use:** `/caveman` - Question complexity when appropriate
**Example:** `Review if mock patterns are overengineered for business logic testing`

---

## Skill Invocation Syntax

Skills are invoked using slash commands:

```
/diagnose [failure description]
/tdd [feature to implement]
/triage
/handoff
/caveman
```

Skills are stored as structured Markdown files with:
- Frontmatter metadata (name, description, usage)
- Detailed instructions
- Examples
- Best practices

---

**Inventory Complete**
**Total Skills Documented:** 17
**Engineering:** 10
**Productivity:** 4
**Misc:** 2
**Repo Doc:** 1
