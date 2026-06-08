# CRITICAL FIXES REQUIRED — BLOCKERS FOR v1.1 RELEASE
## Daily-Motivation-Brain-Helper

**Status**: 🔴 **RELEASE BLOCKED** — Do not ship v1.1 until these issues are resolved

---

## BLOCKER #1: Build System Path Mismatch (SC-005 + DC-001)

**Severity**: CRITICAL
**Category**: Build System / Path Resolution
**Assigned To**: [DEVELOPER - URGENT]
**Effort**: 4 hours
**Deadline**: IMMEDIATE

### Problem

The build system creates a directory structure that is **incompatible with runtime path resolution**:

**Build Output** (`.build.ps1`):
```
Output/
  DailyMotivationBrainHelper.exe
  DailyMotivation.exe
  src/              ← WRONG - subdirectory created
    Modules/
      ConfigManager.psm1
      TaskScheduler.psm1
    data/
      messages.json
```

**Expected by Runtime Code** (`DailyMotivation.ps1`, `MainApp.ps1`):
```
Output/
  DailyMotivationBrainHelper.exe
  DailyMotivation.exe
  Modules/          ← CORRECT - at root level
    ConfigManager.psm1
    TaskScheduler.psm1
  data/
    messages.json
```

**Root Cause**: `.build.ps1` lines 182-189 copy dependencies to `Output/src/` instead of `Output/`

### Impact

- ❌ Compiled executables cannot find their dependencies
- ❌ Runtime errors: "Module not found"
- ❌ Application fails silently on startup
- ❌ **Cannot release v1.1 in current state**

### Resolution

**File to Fix**: `/home/vercel-sandbox/Daily-Motivation-Brain-Helper/.build.ps1`

**Lines 182-189** — BEFORE (BROKEN):
```powershell
Copy-Item -Path (Join-Path $script:Config.SourcePath 'Modules') `
          -Destination (Join-Path $script:Config.OutputPath 'src') -Recurse -Force
Copy-Item -Path (Join-Path $script:Config.SourcePath 'data') `
          -Destination (Join-Path $script:Config.OutputPath 'src') -Recurse -Force
```

**Lines 182-189** — AFTER (FIXED):
```powershell
Copy-Item -Path (Join-Path $script:Config.SourcePath 'Modules') `
          -Destination $script:Config.OutputPath -Recurse -Force
Copy-Item -Path (Join-Path $script:Config.SourcePath 'data') `
          -Destination $script:Config.OutputPath -Recurse -Force
```

**Change**: Remove `/src` subdirectory; copy directly to `Output/`

### Verification

After fix, run:
```powershell
Invoke-Build Clean, Build
cd Output
.\DailyMotivationBrainHelper.exe  # Should launch without errors
```

Expected directory structure:
```
Output/
  DailyMotivationBrainHelper.exe
  DailyMotivation.exe
  LaunchMotivation.bat
  Modules/
  data/
  MainWindow.xaml
```

---

## BLOCKER #2: Admin Elevation Requirement (DC-002)

**Severity**: CRITICAL
**Category**: Build Configuration / User Experience
**Assigned To**: [DEVELOPER - URGENT]
**Effort**: 1 hour
**Deadline**: IMMEDIATE

### Problem

The legacy `build.ps1` script incorrectly requires admin elevation for **every app launch**:

**File**: `/home/vercel-sandbox/Daily-Motivation-Brain-Helper/build.ps1`
**Line 40**: `Invoke-ps2exe ... -requireAdmin \`

This violates **NPR-003**: "No elevated privileges should be required for normal use"

### Impact

- ❌ Users get UAC prompt every time they launch the app
- ❌ Poor user experience (frustration, uninstalls)
- ❌ Violates documented requirement (NPR-003)
- ❌ Contradicts `.build.ps1` which correctly sets `RequireAdmin = $false`

### Resolution

**File to Fix**: `/home/vercel-sandbox/Daily-Motivation-Brain-Helper/build.ps1`

**Line 40** — BEFORE (BROKEN):
```powershell
Invoke-ps2exe ... \
    -requireAdmin \
    -noConsole \
    ...
```

**Line 40** — AFTER (FIXED):
```powershell
Invoke-ps2exe ... \
    -noConsole \
    ...
```

**Change**: Remove `-requireAdmin \` line entirely

### Clarification

- Admin elevation IS required for **one-time setup** (`UpdateScheduledTask.ps1`)
- Admin elevation is NOT required for normal app usage (MainApp.ps1, DailyMotivation.ps1)
- The correct behavior is in `.build.ps1` (Line 136: `RequireAdmin = $false`)

### Verification

After fix, compile and test:
```powershell
.\build.ps1
.\src\DailyMotivation.exe  # Should launch WITHOUT UAC prompt
```

---

## HIGH-PRIORITY FIX #1: Missing AGENTS.md (CG-001)

**Severity**: HIGH
**Category**: Governance / Team Scaling
**Assigned To**: [PRODUCT OWNER]
**Effort**: 4 hours
**Deadline**: Sprint 1 (2 weeks)

### Problem

No `AGENTS.md` file exists in repository root, despite being referenced in:
- CLAUDE.md (line 373)
- docs/agents/ subdirectory (domain.md, issue-tracker.md, triage-labels.md)

### Impact

- New team members lack agent role definitions
- Unclear escalation paths
- Multi-agent workflow coordination undefined
- Role ambiguity during code reviews

### Resolution

**Create**: `/home/vercel-sandbox/Daily-Motivation-Brain-Helper/AGENTS.md`

**Required Sections**:
1. Agent Roles (6 defined: Product, Architecture, QA, UX, Security, Documentation)
2. Responsibilities per role
3. Decision authority boundaries
4. Escalation matrix
5. Triage label taxonomy (cross-link to docs/agents/triage-labels.md)
6. Multi-agent review requirements (when PRD changes, which agents review?)

**Template** (use as starting point):
```markdown
# Multi-Agent Workflow

## Agent Roles

### Product Manager
- **Responsibility**: Requirements ownership, feature approval, user story narrative
- **Authority**: Approves PRD.md changes, feature prioritization
- **Escalation**: Tech Lead (architectural concerns), QA Lead (testability)

### Architecture Agent
- **Responsibility**: System design, module boundaries, SSOT enforcement
- **Authority**: Approves architecture changes, refactoring plans
- **Escalation**: Product Manager (feature scope), Security (threat model)

[... continue for all 6 agent roles ...]

## Review Requirements

When **PRD.md** changes:
- Product Manager (approver)
- QA Agent (review acceptance criteria)
- Documentation Agent (review traceability matrix)

[... continue for all critical documents ...]
```

### Verification

- File exists at repository root
- Linked from README.md and CLAUDE.md
- All 6 agent roles defined with clear responsibilities
- Escalation paths documented

---

## HIGH-PRIORITY FIX #2: Broken Links (DK-001 through DK-005)

**Severity**: HIGH
**Category**: Documentation Quality
**Assigned To**: [DEVELOPER]
**Effort**: 3 hours
**Deadline**: Sprint 1 (2 weeks)

### Problem

5 broken internal links detected:

1. `CLAUDE/skills/productivity/write-a-skill/SKILL.md:57` → `REFERENCE.md` (NOT_FOUND)
2. `Tests/README.md:240` → `../CLAUDE.md` (NOT_FOUND — should be `../CLAUDE.MD`)
3. `Tests/README.md:241` → `../docs/reports/INITIALIZATION-BUG-ANALYSIS-2026-06-03.md` (NOT_FOUND)
4. `docs/INSTALL.md:10` → `../releases` (NOT_FOUND)
5. `docs/README.md:38` → `reports/` (NOT_FOUND)

### Resolution

**Fix #1**: Create `CLAUDE/skills/productivity/write-a-skill/REFERENCE.md` OR remove link
**Fix #2**: Update `Tests/README.md:240` to `../CLAUDE.MD` (case-sensitive)
**Fix #3**: Create `docs/reports/` directory and migrate bug analysis OR remove link
**Fix #4**: Update `docs/INSTALL.md:10` to point to GitHub Releases page: `https://github.com/SevWren/Daily-Motivation-Brain-Helper/releases`
**Fix #5**: Create `docs/reports/` directory with index OR remove from docs/README.md

### Verification

Run markdown link checker:
```bash
npm install -g markdown-link-check
find . -name '*.md' -exec markdown-link-check {} \;
```

All internal links should resolve successfully.

---

## HIGH-PRIORITY FIX #3: Missing FORENSIC_REVIEW.md (DK-008)

**Severity**: HIGH
**Category**: Distribution Planning
**Assigned To**: [TECH LEAD]
**Effort**: 6 hours
**Deadline**: Sprint 1 (2 weeks)

### Problem

`docs/DISTRIBUTION_STRATEGY.md` references `FORENSIC_REVIEW.md` at lines 25 and 241:
- "these two issues from FORENSIC_REVIEW.md must be resolved first" (GAP-002, ERR-017)
- "Eliminates the majority of findings from FORENSIC_REVIEW.md"

**File does not exist**; distribution planning is blocked.

### Impact

- Cannot finalize distribution strategy
- Critical implementation issues (GAP-002, ERR-017) are referenced but unexplained
- Developers cannot understand risk scope

### Resolution

**Create**: `/home/vercel-sandbox/Daily-Motivation-Brain-Helper/docs/FORENSIC_REVIEW.md`

**Required Sections**:
1. Overview of forensic analysis (what was reviewed, when, by whom)
2. GAP-002 description (what issue? what impact?)
3. ERR-017 description (what error? what mitigation?)
4. All findings from forensic review (categorized by severity)
5. Recommendations for distribution strategy
6. Resolution status for each finding

### Verification

- File exists and is linked from DISTRIBUTION_STRATEGY.md
- GAP-002 and ERR-017 are fully documented
- Distribution strategy can proceed with forensic analysis complete

---

## HIGH-PRIORITY FIX #4: Stale architecture.md (DK-009)

**Severity**: HIGH
**Category**: Documentation Accuracy
**Assigned To**: [DEVELOPER]
**Effort**: 1 hour
**Deadline**: Sprint 1 (2 weeks)

### Problem

Root-level `architecture.md` describes a **Python image-generation application** with:
- `src/core/gui_backend.py`
- `src/logic/mod_fade.py`
- `src/utils/utils_image.py`

This is **NOT** the Daily-Motivation-Brain-Helper project (which is PowerShell/WPF).

The correct architecture is in `docs/SYSTEM ARCHITECTURE.md`.

### Impact

- New developers read wrong architecture document
- Confusion about application structure
- Trust in documentation eroded

### Resolution

**Option A (Recommended)**: Delete `/home/vercel-sandbox/Daily-Motivation-Brain-Helper/architecture.md`

**Option B**: Replace with redirect:
```markdown
# Architecture

This file has been deprecated. See the current architecture at:
- [docs/SYSTEM ARCHITECTURE.md](docs/SYSTEM%20ARCHITECTURE.md) — Runtime architecture and deployment
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — Module design and testing infrastructure

**Last Updated**: 2026-06-08
**Status**: DEPRECATED
```

### Verification

- Stale `architecture.md` removed or clearly marked deprecated
- `docs/ARCHITECTURE.md` and `docs/SYSTEM ARCHITECTURE.md` are the only authoritative architecture docs

---

## Summary Checklist

Before releasing v1.1, verify all fixes complete:

- [ ] **BLOCKER #1**: Build path mismatch fixed (SC-005 + DC-001)
  - `.build.ps1` lines 182-189 updated
  - Build output structure verified (Modules/ at root, not src/Modules/)
  - Compiled EXE launches successfully

- [ ] **BLOCKER #2**: Admin elevation removed (DC-002)
  - `build.ps1` line 40 `-requireAdmin` flag removed
  - UAC prompt does NOT appear on normal app launch

- [ ] **HIGH-PRIORITY #1**: AGENTS.md created (CG-001)
  - File exists at repository root
  - All 6 agent roles defined
  - Escalation paths documented

- [ ] **HIGH-PRIORITY #2**: Broken links fixed (DK-001–DK-005)
  - All 5 broken links resolved
  - Markdown link checker passes

- [ ] **HIGH-PRIORITY #3**: FORENSIC_REVIEW.md created (DK-008)
  - GAP-002 and ERR-017 documented
  - Distribution strategy unblocked

- [ ] **HIGH-PRIORITY #4**: Stale architecture.md removed (DK-009)
  - Root-level file deleted or deprecated
  - Canonical architecture docs clarified

**Once all items checked, v1.1 can proceed to release.**

---

**Audit Date**: 2026-06-08
**Report**: Critical Fixes Required
**Next Steps**: Assign owners, schedule remediation, verify completion before release
