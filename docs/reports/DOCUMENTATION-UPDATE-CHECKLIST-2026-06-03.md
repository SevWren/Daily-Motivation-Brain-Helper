# Documentation Update Checklist - Commit 4ba633a

Quick reference checklist for updating documentation to reflect modern PowerShell test infrastructure.

---

## README.md - 4 Updates Required

### ✓ Update 1: Repository Structure (Lines 20-56) [CRITICAL]
**Action:** Replace entire repository structure diagram
**Reason:** Missing Tests/, .build.ps1, Invoke-Tests.ps1, CI/CD files, new docs

**Add these entries:**
- `.github/workflows/test.yml` - CI/CD pipeline
- `Tests/` directory with subdirectories
- `.build.ps1` - Invoke-Build script
- `Invoke-Tests.ps1` - Test runner
- `PesterConfiguration.psd1` - Pester config
- `.PSScriptAnalyzerSettings.psd1` - Code quality rules
- `TESTING.md` - Testing guide
- `MODERN-POWERSHELL-SCAFFOLDING.md` - Infrastructure docs

**Mark as:**
- `build.ps1` - Legacy (use .build.ps1)
- ConfigManager.psm1 - (100+ unit tests)
- TaskScheduler.psm1 - (80+ unit tests)

### ✓ Update 2: Add Testing Section (After Line 83) [CRITICAL]
**Action:** Insert new "Testing & Development" section after Installation
**Includes:**
- Running tests (all, unit, integration, CI mode)
- Build automation (Invoke-Build commands)
- Code quality checks
- CI/CD information

**Commands to document:**
```powershell
.\Invoke-Tests.ps1
.\Invoke-Tests.ps1 -Tag Unit
Invoke-Build
Invoke-Build ?
Invoke-Build Analyze
```

### ✓ Update 3: Build Reference (Line 17) [MEDIUM]
**Current:** `Run build.ps1 from the project root`
**Change to:** `Use Invoke-Build (recommended) or legacy build.ps1`

### ✓ Update 4: Documentation Index (Line 122) [LOW]
**Action:** Expand documentation section
**Add references to:**
- TESTING.md
- MODERN-POWERSHELL-SCAFFOLDING.md
- Tests/README.md
- INITIALIZATION-BUGS.md

---

## CLAUDE.MD - 6 Updates Required

### ✓ Update 1: Build Script Reference (Line 17) [CRITICAL]
**Current:** `Run build.ps1 from the project root`
**Change to:** `Use Invoke-Build (recommended) or legacy build.ps1`
**Fix:** "PS2EXE-NG" → "PS2EXE"

### ✓ Update 2: Repository Layout (Lines 21-45) [CRITICAL]
**Action:** Replace entire layout diagram
**Add:**
- `.github/workflows/test.yml` with comment
- `.build.ps1` marked as RECOMMENDED
- `build.ps1` marked as legacy
- `Invoke-Tests.ps1` with description
- `PesterConfiguration.psd1`
- `.PSScriptAnalyzerSettings.psd1`
- `TESTING.md`
- `MODERN-POWERSHELL-SCAFFOLDING.md`
- `INITIALIZATION-BUGS.md`
- Full `Tests/` structure with test counts
- Mark modules as TESTED with test counts

### ✓ Update 3: How to Run Section (After Line 148) [HIGH]
**Action:** Add "Modern Development Workflow" subsection
**Document:**
- Running tests before committing
- Full build with quality checks
- Quick build (no tests)
- Release build with packaging
- Installing dependencies
- Code analysis
- Viewing all tasks

**Key commands:**
```powershell
.\Invoke-Tests.ps1
Invoke-Build
Invoke-Build QuickBuild
Invoke-Build Release
Invoke-Build InstallDependencies
Invoke-Build Analyze
Invoke-Build ?
```

### ✓ Update 4: Documentation Index (Lines 280-296) [MEDIUM]
**Action:** Add 3 new rows, update 2 existing rows

**New rows:**
- Tests or test infrastructure → TESTING.md, Tests/README.md, MODERN-POWERSHELL-SCAFFOLDING.md
- Build system or CI/CD → .build.ps1, .github/workflows/test.yml, TESTING.md
- Code quality or standards → .PSScriptAnalyzerSettings.psd1, PesterConfiguration.psd1

**Update existing rows:**
- Acceptance criteria / test cases → Add TESTING.md
- Known bugs and patterns → Add INITIALIZATION-BUGS.md

### ✓ Update 5: Conventions Section (After Line 320) [MEDIUM]
**Action:** Add "Testing requirements" subsection
**Include:**
- Write tests for all new features (TDD)
- Maintain 80%+ code coverage
- All tests must pass before committing
- Tag tests appropriately
- Integration tests for bug fixes

**Pre-commit checklist:**
```powershell
Invoke-Build Analyze
Invoke-Build Test
```

### ✓ Update 6: Build EXE Command (Lines 136-141) [MEDIUM]
**Action:** Split into "modern" and "legacy" sections
**Modern section:**
- Use Invoke-Build InstallDependencies
- Use Invoke-Build (full with tests)
- Use Invoke-Build QuickBuild (no tests)
- Output: Output/DailyMotivationBrainHelper.exe

**Legacy section:**
- Keep existing build.ps1 example
- Output: src/DailyMotivation.exe

---

## INITIALIZATION-BUGS.md - 4 Updates Required

### ✓ Update 1: Testing Requirements (Lines 55-63) [MEDIUM]
**Action:** Keep existing checklist, add "Test Coverage" section after it
**New section includes:**
- 180+ Pester tests created
- List unit test files with counts
- List integration test files
- Commands to run tests
- Links to test documentation
- Note about -Skip tests

**Commands:**
```powershell
.\Invoke-Tests.ps1
.\Invoke-Tests.ps1 -Tag Initialization
Invoke-Build Test
```

### ✓ Update 2: Add CI/CD Section (After Test Coverage) [LOW]
**Action:** New "Continuous Integration" section
**Include:**
- Tests run automatically on push/PR
- Workflow file location
- Jobs: Test, Build, Analyze
- Test results in PR comments
- Code coverage reports
- Link to GitHub Actions

### ✓ Update 3: Documentation References (Lines 80-86) [LOW]
**Action:** Add test-related documentation to list
**Add:**
- Tests/Unit/ConfigManager.Tests.ps1 (Issue #2, #4)
- Tests/Integration/Initialization.Tests.ps1 (Issues #2-#8)
- TESTING.md
- MODERN-POWERSHELL-SCAFFOLDING.md

---

## Quick Reference: New Files Added in Commit 4ba633a

```
Tests/
├── Unit/
│   ├── ConfigManager.Tests.ps1     (382 lines, 100+ tests)
│   └── TaskScheduler.Tests.ps1     (319 lines, 80+ tests)
├── Integration/
│   └── Initialization.Tests.ps1    (327 lines, E2E tests)
├── Fixtures/
│   ├── sample_app_settings.json
│   └── sample_tasks.json
└── README.md

.github/workflows/
└── test.yml                        (128 lines, CI/CD pipeline)

.build.ps1                          (278 lines, Invoke-Build script)
Invoke-Tests.ps1                    (186 lines, test runner)
PesterConfiguration.psd1            (31 lines, Pester config)
.PSScriptAnalyzerSettings.psd1      (53 lines, code quality rules)
TESTING.md                          (440 lines, testing guide)
MODERN-POWERSHELL-SCAFFOLDING.md    (484 lines, infrastructure docs)
```

**Total:** 14 new files, ~2,500 lines of test code and documentation

---

## Key Terminology Changes

| Old | New | Reason |
|-----|-----|--------|
| `build.ps1` | `.build.ps1` with `Invoke-Build` | Modern build automation |
| "PS2EXE-NG" | "ps2exe" | Correct module name |
| Output: `src/` | Output: `Output/` | New build system location |
| No tests | 180+ Pester 5.x tests | Comprehensive test coverage |
| Manual testing | Automated CI/CD | GitHub Actions workflow |

---

## Implementation Order

### Phase 1: Critical Path (Do First)
1. README.md - Repository Structure (Line 20-56)
2. README.md - Testing Section (After Line 83)
3. CLAUDE.MD - Repository Layout (Lines 21-45)
4. CLAUDE.MD - Build Reference (Line 17)

**Why:** Users and agents need accurate file structure immediately

### Phase 2: High Priority (Do Next)
5. CLAUDE.MD - How to Run Section (After Line 148)
6. CLAUDE.MD - Documentation Index (Lines 280-296)
7. INITIALIZATION-BUGS.md - Test Coverage (Lines 55-63)

**Why:** Development workflow and test discovery

### Phase 3: Polish (Can Wait)
8. README.md - Build Reference (Line 17)
9. README.md - Documentation Index (Line 122)
10. CLAUDE.MD - Conventions (After Line 320)
11. CLAUDE.MD - Build EXE Command (Lines 136-141)
12. INITIALIZATION-BUGS.md - CI/CD Section
13. INITIALIZATION-BUGS.md - Documentation References (Lines 80-86)

**Why:** Smaller improvements and consistency fixes

---

## Validation Commands

After updates, verify accuracy:

```powershell
# Check if Tests directory exists
Test-Path Tests

# Count test files
(Get-ChildItem -Path Tests -Recurse -Filter *.Tests.ps1).Count

# Verify build script exists
Test-Path .build.ps1

# List build tasks
Invoke-Build ?

# Run tests
.\Invoke-Tests.ps1 -Coverage $false

# Check CI workflow
Test-Path .github/workflows/test.yml
```

---

## Common Pitfalls to Avoid

1. **Don't remove old build.ps1** - Keep it for backward compatibility, just mark as legacy
2. **Don't change line numbers in this checklist** - They reference CURRENT state, not after changes
3. **Don't forget to update BOTH repository diagrams** - README.md and CLAUDE.MD
4. **Don't skip testing the commands** - Verify all documented commands actually work
5. **Don't mix old and new terminology** - Use "Invoke-Build" consistently, not "build.ps1"

---

## Quick Win: Update Just the Critical Sections

If time is limited, update these 4 sections for maximum impact:

1. **README.md Lines 20-56** - Repository structure
2. **CLAUDE.MD Lines 21-45** - Repository layout
3. **README.md After Line 83** - Add testing section (20 lines)
4. **CLAUDE.MD Line 17** - Fix build reference (1 line)

**Total:** ~80 lines, 20 minutes, covers 80% of the value

---

**Checklist Created:** 2026-06-03
**Files to Update:** 3
**Total Changes:** 14 sections
**Estimated Time:** 2-3 hours for complete update
