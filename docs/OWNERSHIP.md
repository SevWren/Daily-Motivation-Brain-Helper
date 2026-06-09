# Code and Documentation Ownership

**Last Updated:** 2026-06-09
**Version:** 1.0

This document defines ownership and approval authority for all components of the Daily Motivation Brain Helper project. It establishes who maintains what, who must approve changes, and how to escalate decisions.

---

## Table of Contents

1. [Module Ownership](#module-ownership)
2. [Documentation Ownership](#documentation-ownership)
3. [Build System Ownership](#build-system-ownership)
4. [Test Infrastructure Ownership](#test-infrastructure-ownership)
5. [Architecture Ownership](#architecture-ownership)
6. [Decision Authority Matrix](#decision-authority-matrix)
7. [Review Requirements](#review-requirements)
8. [Contact Information](#contact-information)
9. [Escalation Paths](#escalation-paths)

---

## Module Ownership

### ConfigManager Module (`src/Modules/ConfigManager.psm1`)

**Primary Owner:** @SevWren
**Agent Role:** Architecture Agent

**Responsibilities:**
- Maintain all JSON read/write operations
- Manage settings persistence (`app_settings.json`)
- Handle history log operations (`popup_log.txt`)
- Maintain configuration schema
- Enforce data model consistency

**Key Functions:**
- `Get-MotivationConfig` - Read configuration
- `Set-MotivationConfig` - Write configuration
- `Add-PopupLogEntry` - Log popup outcomes
- `Get-RecentFolders` - Recent folders list (FR-014)
- `Set-LastFolder` - Remember last folder (FR-013)
- `Set-FirstRunFlag` - First-run tracking (FR-018)

**Review Requirements:**
- Architecture Agent approval for schema changes
- QA Agent review for test coverage (target: 90%+)
- Documentation Agent review for glossary updates

**Test Coverage:** ~90% (100+ tests in `Tests/Unit/ConfigManager.Tests.ps1`)

**Quality Gates:**
- All changes must maintain 90%+ coverage
- Zero PSScriptAnalyzer warnings
- All unit tests must pass

---

### TaskScheduler Module (`src/Modules/TaskScheduler.psm1`)

**Primary Owner:** @SevWren
**Agent Role:** Architecture Agent

**Responsibilities:**
- Wrap Windows Task Scheduler COM API
- Create scheduled tasks (FR-003)
- List and delete tasks (FR-011)
- Handle duplicate detection (FR-023)
- Manage trigger times (FR-004, FR-015)

**Key Functions:**
- `New-MotivationTask` - Create task with validation
- `Get-MotivationTasks` - List all scheduled tasks
- `Remove-MotivationTask` - Delete task by ID
- `Test-DuplicateTask` - Duplicate detection

**Review Requirements:**
- Architecture Agent approval for API changes
- QA Agent review for test coverage (target: 85%+)
- Security Agent review for privilege escalation concerns

**Test Coverage:** ~85% (80+ tests in `Tests/Unit/TaskScheduler.Tests.ps1`)

**Quality Gates:**
- All changes must maintain 85%+ coverage
- Zero PSScriptAnalyzer warnings
- Integration tests must pass

**Security Considerations:**
- No elevation at runtime (SSOT-007)
- Task runs under current user account
- See `docs/SECURITY.md` for security model

---

### Notification Engine (`src/DailyMotivation.ps1`)

**Primary Owner:** @SevWren
**Agent Roles:** UX Agent (primary), Architecture Agent (secondary)

**Responsibilities:**
- Display motivational popup at scheduled time (FR-005)
- Handle user interactions (Open/Snooze/Dismiss)
- Path validation and moved folder re-pick (FR-017)
- Snooze duration selection (FR-020)
- Folder name display (FR-021)
- Named mutex enforcement (SSOT-006)

**Review Requirements:**
- UX Agent approval for UI/UX changes
- QA Agent review for manual test cases (TC-003 through TC-020)
- Security Agent review for external process launches

**Test Coverage:** 0% automated (WPF limitations)
**Manual Testing:** All changes require full manual test suite execution

**Quality Gates:**
- Manual test cases TC-003 through TC-020 must pass
- Zero PSScriptAnalyzer warnings
- Debug log analysis confirms no exceptions

**Known Limitations:**
- Cannot be automated with Pester without desktop session
- Highest quality risk in codebase
- See `docs/NOTIFICATION_ENGINE_SPEC.md` for testing approach

---

### Main Application (`src/MainApp.ps1`)

**Primary Owner:** @SevWren
**Agent Roles:** UX Agent (primary), Product Manager (secondary)

**Responsibilities:**
- Main window WPF entry point
- Welcome overlay first-run experience (FR-018)
- Folder picker and drag-drop (FR-001, FR-019)
- Remember last folder banner (FR-013)
- Recent folders list (FR-014)
- Undo banner with countdown (FR-016)
- Task management UI (FR-011)
- History viewer (FR-024)
- Tooltips (FR-025)

**Review Requirements:**
- UX Agent approval for interaction flows
- Product Manager approval for feature additions
- QA Agent review for integration test coverage

**Test Coverage:** 16 integration tests (`Tests/Integration/Initialization.Tests.ps1`)

**Quality Gates:**
- Integration tests must pass
- Manual UI testing required for visual changes
- Tooltip consistency with UX_SPEC.md

---

### Shell Extension (`src/ShellExtension/`)

**Primary Owner:** @SevWren
**Agent Roles:** Security Agent (primary), Architecture Agent (secondary)

**Responsibilities:**
- COM shell extension DLL (FR-022)
- Explorer right-click context menu integration
- PowerShell bridge (`ShellBridge.ps1`)
- Registry operations (registration)

**Files:**
- `MotivationShellExt.cs` - COM implementation
- `Register-ShellExtension.ps1` - Compile and register
- `ShellBridge.ps1` - PowerShell bridge

**Review Requirements:**
- Security Agent approval mandatory (COM, registry, elevation)
- Architecture Agent approval for bridge design
- QA Agent review for integration testing strategy

**Test Coverage:** Manual only (requires Explorer restart)

**Security Considerations:**
- Requires Admin elevation for registration
- COM DLL runs in Explorer process space
- Registry modifications to `HKEY_CLASSES_ROOT`
- See `docs/SECURITY.md` Section 4.3 for threat assessment

**Quality Gates:**
- Security review required for all changes
- Manual test case TC-021 must pass
- Code signing recommended for distribution

---

## Documentation Ownership

### Product Requirements (`docs/PRD.md`)

**Primary Owner:** @SevWren
**Agent Role:** Product Manager

**Approval Authority:** Product Manager has final decision on all requirements (FR-001 through FR-025)

**Review Requirements:**
- QA Agent review for acceptance criteria testability
- Architecture Agent review for SSOT compliance
- Documentation Agent updates traceability matrix

**Related Documents:**
- `docs/USER_STORIES.md` - User story narrative
- `docs/FEATURE_BRAINSTORM.md` - Approved features B-01 through B-19
- `docs/ROADMAP.md` - Feature prioritization

**Change Process:**
1. Product Manager proposes requirement change
2. Multi-agent review per AGENTS.md Section "When PRD.md Changes"
3. Update TRACEABILITY_MATRIX.md
4. Update ACCEPTANCE_CRITERIA.md
5. Update TEST_PLAN.md with new test cases

---

### Architecture Documentation (`docs/ARCHITECTURE.md`, `docs/SSOT.md`)

**Primary Owner:** @SevWren
**Agent Role:** Architecture Agent

**Approval Authority:** Architecture Agent has final decision on system design and SSOT rules

**Review Requirements:**
- QA Agent review for test impact
- Documentation Agent review for glossary updates
- Security Agent review if security model affected

**Critical Rules (SSOT.md):**
- SSOT-001 through SSOT-009 are canonical system invariants
- No change may violate these rules without explicit SSOT amendment
- All agents must enforce SSOT compliance

**Related Documents:**
- `docs/DATA_MODEL.md` - Configuration schema
- `docs/SYSTEM ARCHITECTURE.md` - Detailed system design
- `docs/modules/ConfigManager-API.md` - ConfigManager reference
- `docs/modules/TaskScheduler-API.md` - TaskScheduler reference

---

### UX Documentation (`docs/UX_SPEC.md`, `docs/USE_CASES.md`)

**Primary Owner:** @SevWren
**Agent Role:** UX Agent

**Approval Authority:** UX Agent has final decision on user experience design

**Review Requirements:**
- QA Agent review for manual test case updates
- Documentation Agent review for USE_CASES.md consistency

**Design Principles (must be enforced):**
1. Zero learning curve - no instructions needed
2. 3-click max - core actions complete in 3 clicks or fewer
3. No jargon - zero technical terms in user-facing text
4. Self-explaining - every control has a tooltip (FR-025)

**Related Documents:**
- `docs/GLOSSARY.md` - User-facing terminology
- `docs/USER_STORIES.md` - User narrative

---

### Test Documentation (`docs/TEST_PLAN.md`, `Tests/README.md`, `TESTING.md`)

**Primary Owner:** @SevWren
**Agent Role:** QA Agent

**Approval Authority:** QA Agent has final decision on test strategy and quality gates

**Review Requirements:**
- Documentation Agent review for traceability updates
- Architecture Agent review if test approach reveals design issues

**Quality Gates (enforced in CI/CD):**
- 80%+ code coverage on testable modules
- Zero PSScriptAnalyzer warnings
- All Pester tests passing

**Test Coverage Status:**
- ConfigManager: ~90% (100+ tests)
- TaskScheduler: ~85% (80+ tests)
- Integration: 16 end-to-end scenarios
- Notification Engine: Manual only (0% automated)

**Manual Test Cases:**
- TC-003 through TC-020: Popup interaction flows
- TC-021: Shell extension
- See `docs/TEST_PLAN.md` for full catalog

---

### Security Documentation (`docs/SECURITY.md`, `docs/RISK_REGISTER.md`)

**Primary Owner:** @SevWren
**Agent Role:** Security Agent

**Approval Authority:** Security Agent has final decision on security policy and can block any feature that introduces unacceptable risk

**Review Requirements:**
- Architecture Agent review for security model alignment
- Product Manager review if security constraints impact feasibility

**Security Model (canonical):**
- Application runs entirely locally with no network access
- Operates under current user account (no elevation at runtime)
- No credentials, tokens, or personal data stored or transmitted
- Only external interaction: launching Windows Explorer

**Critical Reviews Required For:**
- Features involving file system access
- Features involving external processes
- Features involving data storage
- Shell extension (COM DLL, registry access)

---

### Cross-Reference Documentation (`docs/GLOSSARY.md`, `docs/TRACEABILITY_MATRIX.md`)

**Primary Owner:** @SevWren
**Agent Role:** Documentation Agent

**Approval Authority:** Documentation Agent has final decision on terminology and traceability

**Review Requirements:**
- Product Manager review for requirements coverage
- Architecture Agent review for technical terminology accuracy
- All agents must use canonical terms from GLOSSARY.md

**Responsibilities:**
- Maintain domain vocabulary consistency
- Update traceability matrix when requirements change
- Validate cross-references across all documentation
- Enforce term usage in all documentation

**Critical Documents:**
- `docs/GLOSSARY.md` - Canonical terminology (e.g., "scheduled task" not "job")
- `docs/TRACEABILITY_MATRIX.md` - Requirements to test mapping
- `docs/GAP_ANALYSIS.md` - Coverage tracking

---

### Contributing Guide (`docs/CONTRIBUTING.md`)

**Primary Owner:** @SevWren
**Agent Role:** QA Agent (primary), Documentation Agent (secondary)

**Approval Authority:** Joint approval by QA Agent and Documentation Agent

**Maintained By:**
- QA Agent: Test requirements, quality gates, build system usage
- Documentation Agent: PR process, documentation standards

---

### Agent Governance (`AGENTS.md`)

**Primary Owner:** @SevWren
**Agent Role:** All agents (collective ownership)

**Approval Authority:** Requires consensus of all agents or escalation to Level 3 (Multi-Agent Deadlock)

**Review Requirements:**
- All agents must review changes to their role definitions
- Product Manager approval for decision authority hierarchy changes
- Documentation Agent validation of review requirements

**Change Process:**
1. Propose change via GitHub Issue labeled `governance`
2. All agents review within 72 hours
3. Consensus required or escalation to Level 3
4. Update version number and change history

---

## Build System Ownership

### Build Automation (`.build.ps1`)

**Primary Owner:** @SevWren
**Agent Role:** QA Agent

**Responsibilities:**
- Maintain Invoke-Build tasks
- Define build pipeline stages (Clean → Analyze → Test → Build → Release)
- Manage dependency installation

**Available Tasks:**
- `Default` - Full build with tests
- `Clean` - Remove build artifacts
- `Analyze` - Run PSScriptAnalyzer
- `Test` - Run Pester test suite
- `Build` - Compile with ps2exe
- `QuickBuild` - Build without tests
- `Release` - Create release package
- `InstallDependencies` - Install dev tools

**Review Requirements:**
- QA Agent approval for task changes
- Architecture Agent review for new build stages

**Quality Gates:**
- PSScriptAnalyzer zero warnings
- Pester tests all passing
- Coverage >= 80%

---

### CI/CD Pipeline (`.github/workflows/test.yml`)

**Primary Owner:** @SevWren
**Agent Role:** QA Agent

**Responsibilities:**
- Automated test execution on every push/PR
- Code coverage reporting
- PSScriptAnalyzer SARIF upload for GitHub Security
- PR status checks (blocking merge on failure)

**Three Jobs:**
1. **test** - PSScriptAnalyzer + Pester + coverage upload + PR comment
2. **build** - PS2EXE compilation (runs after test passes)
3. **analyze** - PSScriptAnalyzer SARIF for code scanning

**Review Requirements:**
- QA Agent approval for workflow changes
- Architecture Agent review for new CI stages

**Quality Gates (PR merge is blocked if any fail):**
- All Pester tests must pass
- Code coverage >= 80%
- Zero PSScriptAnalyzer warnings

---

### Test Runner (`Invoke-Tests.ps1`)

**Primary Owner:** @SevWren
**Agent Role:** QA Agent

**Responsibilities:**
- Local test execution wrapper
- Tag-based test filtering (Unit, Integration)
- CI mode with coverage reports
- Output formatting

**Usage:**
```powershell
.\Invoke-Tests.ps1              # All tests
.\Invoke-Tests.ps1 -Tag Unit    # Unit only
.\Invoke-Tests.ps1 -CI          # Coverage mode
```

**Review Requirements:**
- QA Agent approval for parameter changes

---

### Pester Configuration (`PesterConfiguration.psd1`)

**Primary Owner:** @SevWren
**Agent Role:** QA Agent

**Responsibilities:**
- Define test discovery paths
- Configure code coverage paths
- Set output verbosity
- Define test result output format

**Review Requirements:**
- QA Agent approval for coverage path changes

---

### PSScriptAnalyzer Settings (`.PSScriptAnalyzerSettings.psd1`)

**Primary Owner:** @SevWren
**Agent Role:** QA Agent

**Responsibilities:**
- Define code quality rules
- Configure severity thresholds
- Maintain rule exceptions (with justification)

**Review Requirements:**
- QA Agent approval for rule changes
- Architecture Agent review for exception requests

**Current Rules:**
- Zero warnings enforced
- All default rules enabled
- No exceptions granted

---

## Test Infrastructure Ownership

### Unit Tests (`Tests/Unit/`)

**Primary Owner:** @SevWren
**Agent Role:** QA Agent

**Responsibilities:**
- Maintain module-level unit tests
- Achieve 80%+ coverage on all testable modules
- Mock external dependencies (Task Scheduler COM, file system)

**Test Files:**
- `ConfigManager.Tests.ps1` - 100+ tests, ~90% coverage
- `TaskScheduler.Tests.ps1` - 80+ tests, ~85% coverage

**Review Requirements:**
- QA Agent approval for new test patterns
- Architecture Agent review if tests reveal design issues

**Quality Standards:**
- Follow Pester 5.x best practices
- Use `BeforeAll`, `BeforeEach`, `AfterAll`, `AfterEach` properly
- Mock all external I/O
- Test edge cases and error paths

---

### Integration Tests (`Tests/Integration/`)

**Primary Owner:** @SevWren
**Agent Role:** QA Agent

**Responsibilities:**
- End-to-end scenario testing
- Cross-module interaction validation
- Initialization bug coverage (Issues #2-#8)

**Test Files:**
- `Initialization.Tests.ps1` - 16 scenarios

**Review Requirements:**
- QA Agent approval for new scenarios
- Product Manager review for business logic validation

**Scope:**
- Multi-module workflows
- File system operations (using temp directories)
- Task Scheduler interactions (cleanup after each test)

---

### Test Fixtures (`Tests/Fixtures/`)

**Primary Owner:** @SevWren
**Agent Role:** QA Agent

**Responsibilities:**
- Maintain test data files
- Provide sample configurations
- Manage mock data

**Review Requirements:**
- QA Agent approval for fixture changes

---

## Architecture Ownership

### System Design Decisions

**Primary Owner:** @SevWren
**Agent Role:** Architecture Agent

**Approval Authority:** Architecture Agent has final decision on:
- Module boundaries and responsibilities
- Technology stack additions
- SSOT rule amendments
- Refactoring proposals

**Review Requirements:**
- Product Manager review if constraints impact feature feasibility
- Security Agent review if design affects security model
- QA Agent review for testability implications

**Key Decisions (see ARCHITECTURE.md):**
- PowerShell 5.1 + WPF for UI
- Windows Task Scheduler for scheduling
- JSON files in `%APPDATA%` for persistence
- COM-visible DLL for shell extension
- Named mutex for popup deduplication

---

### Technology Stack

**Current Stack:**
- PowerShell 5.1
- WPF (Windows Presentation Foundation)
- Windows Task Scheduler COM API
- .NET Framework 4.x (shell extension only)
- Pester 5.x (testing)
- PSScriptAnalyzer (linting)
- Invoke-Build (build automation)
- ps2exe (compilation)

**Review Requirements for Additions:**
- Architecture Agent approval required
- Security Agent review for external dependencies
- QA Agent review for testing implications

---

### Module Boundaries (SSOT Enforcement)

**Enforced By:** Architecture Agent

**Canonical Module Responsibilities:**

| Module | Owns | Must Not Do |
|--------|------|-------------|
| ConfigManager | All JSON I/O, settings, history log | Task Scheduler operations, UI logic |
| TaskScheduler | Windows Task Scheduler COM API wrapper | File I/O, configuration, UI logic |
| DailyMotivation.ps1 | Popup UI, user interaction, path validation | Configuration persistence, task creation |
| MainApp.ps1 | Main window UI, folder picker, task management | Direct Task Scheduler access (use TaskScheduler module) |

**Violation Handling:**
- Architecture Agent blocks any PR that violates module boundaries
- Escalate to Level 2 (Cross-Domain Conflict) if disagreement

---

## Decision Authority Matrix

This matrix defines final decision authority when domains overlap.

| Decision Type | Primary Authority | Can Block | Escalation Path |
|--------------|-------------------|-----------|-----------------|
| **SSOT Violations** | Architecture Agent | Yes (blocks any change) | Level 4: Fundamental Principle Conflict |
| **Feature Scope** | Product Manager | Yes (can reject features) | Level 2: Architecture Agent if technical constraints |
| **Security Concerns** | Security Agent | Yes (blocks any change) | Level 4: Fundamental Principle Conflict |
| **Quality Gates** | QA Agent | Yes (blocks PR merge) | Level 2: Architecture Agent if design issue |
| **User Experience** | UX Agent | Yes (for UI/UX matters) | Level 2: Product Manager if scope impact |
| **Documentation Consistency** | Documentation Agent | Yes (for terminology) | Level 2: Product Manager for glossary conflicts |
| **Test Strategy** | QA Agent | Yes (defines coverage requirements) | Level 2: Architecture Agent if testability issue |
| **Build System** | QA Agent | Yes (defines quality gates) | Level 2: Architecture Agent for pipeline architecture |
| **Module API Changes** | Architecture Agent | Yes (module boundary enforcement) | Level 2: Product Manager if feature impact |
| **Technology Stack** | Architecture Agent | Yes (can reject additions) | Level 2: Security Agent for security implications |

---

## Review Requirements

### When PRD.md Changes

**Required Reviews:**
- Product Manager (approver) - requirements ownership
- QA Agent (reviewer) - validate acceptance criteria testability
- Architecture Agent (reviewer) - assess SSOT compliance and feasibility
- Documentation Agent (reviewer) - update traceability matrix

**Optional Reviews (context-dependent):**
- UX Agent - if changes affect user interaction flows
- Security Agent - if changes involve file system, processes, or data storage

**Deliverables:**
- Updated TRACEABILITY_MATRIX.md
- Updated ACCEPTANCE_CRITERIA.md
- Updated TEST_PLAN.md (new test cases)

---

### When ARCHITECTURE.md or SSOT.md Changes

**Required Reviews:**
- Architecture Agent (approver) - system design ownership
- QA Agent (reviewer) - assess test impact and coverage changes
- Documentation Agent (reviewer) - update glossary if new terms introduced

**Optional Reviews:**
- Security Agent - if changes affect security model
- Product Manager - if architectural constraints impact feature scope

**Deliverables:**
- Updated module API documentation (`docs/modules/`)
- Updated GLOSSARY.md (if terminology changes)
- Updated TEST_PLAN.md (if test approach changes)

---

### When UX_SPEC.md Changes

**Required Reviews:**
- UX Agent (approver) - UX design ownership
- QA Agent (reviewer) - assess manual test case updates needed
- Documentation Agent (reviewer) - validate consistency with USE_CASES.md

**Deliverables:**
- Updated TEST_PLAN.md (manual test cases TC-003 through TC-020)
- Updated GLOSSARY.md (if user-facing terms change)

---

### When TEST_PLAN.md or Test Files Change

**Required Reviews:**
- QA Agent (approver) - test strategy ownership
- Documentation Agent (reviewer) - update traceability matrix

**Optional Reviews:**
- Architecture Agent - if test changes reveal architectural issues
- UX Agent - if manual test cases change

**Deliverables:**
- Updated TRACEABILITY_MATRIX.md
- Updated coverage reports

---

### When Code Changes (Pull Requests)

**Required Reviews:**
- QA Agent - enforce quality gates (80% coverage, zero warnings)
- Architecture Agent - enforce module boundaries and SSOT compliance

**Optional Reviews:**
- Security Agent - if code touches file system, processes, or sensitive operations
- UX Agent - if code changes affect user-facing text or interactions

**Quality Gates (blocking):**
- All Pester tests passing
- Code coverage >= 80% on testable modules
- Zero PSScriptAnalyzer warnings
- No SSOT violations
- Module boundaries respected

**Deliverables:**
- Test cases for new functionality
- Updated documentation if APIs change
- Debug log analysis (for UI changes)

---

### When SECURITY.md Changes

**Required Reviews:**
- Security Agent (approver) - security policy ownership
- Architecture Agent (reviewer) - validate architectural compliance

**Deliverables:**
- Updated RISK_REGISTER.md
- Updated threat assessment if security model changes

---

### When Build System Changes (`.build.ps1`, `.github/workflows/`)

**Required Reviews:**
- QA Agent (approver) - build system ownership
- Architecture Agent (reviewer) - pipeline architecture

**Deliverables:**
- Updated CONTRIBUTING.md (if developer workflow changes)
- Updated TESTING.md (if test runner changes)

---

## Contact Information

### Primary Maintainer

**Name:** SevWren
**GitHub:** @SevWren
**Role:** Project owner and sole human maintainer

**Responsibilities:**
- Final decision on Level 4 escalations (Fundamental Principle Conflicts)
- Release management
- Distribution strategy
- Community management
- Governance updates

---

### Agent Roles

This project uses a multi-agent workflow defined in `AGENTS.md`. Each agent role represents a specific domain of expertise and approval authority.

| Agent Role | Domain | Primary Artifacts |
|-----------|--------|-------------------|
| Product Manager | Requirements, features, prioritization | PRD.md, USER_STORIES.md, ROADMAP.md |
| Architecture Agent | System design, SSOT, module boundaries | ARCHITECTURE.md, SSOT.md, DATA_MODEL.md |
| QA Agent | Testing, quality gates, build automation | TEST_PLAN.md, Tests/, .build.ps1, CI/CD |
| UX Agent | User experience, interaction design | UX_SPEC.md, USE_CASES.md, tooltips |
| Security Agent | Security model, threat assessment | SECURITY.md, RISK_REGISTER.md |
| Documentation Agent | Terminology, traceability, cross-references | GLOSSARY.md, TRACEABILITY_MATRIX.md |

**See AGENTS.md for detailed role definitions, review requirements, and escalation paths.**

---

### Issue Tracker

**Platform:** GitHub Issues
**Repository:** [Daily-Motivation-Brain-Helper](https://github.com/SevWren/Daily-Motivation-Brain-Helper) (assumed)

**Triage Process:**
1. Create issue with `needs-triage` label
2. Product Manager reviews within 48 hours
3. Apply domain label and priority
4. Route to appropriate agent with `ready-for-agent` or `ready-for-human` label

**See:**
- `docs/agents/issue-tracker.md` - CLI conventions
- `docs/agents/triage-labels.md` - Label taxonomy
- `AGENTS.md` Section "Issue Tracker Integration"

---

## Escalation Paths

### Level 1: Peer Agent Review (24-48 hours)

**Trigger:** Routine changes within agent's domain

**Process:**
1. Agent proposes change
2. Peer agents review per review requirements
3. All required reviewers approve or request changes

**Resolution:** Merge when all approvals obtained

---

### Level 2: Cross-Domain Conflict (48-72 hours)

**Trigger:** Disagreement between two agents on decision authority

**Escalation Path:**
- Technical matters → Architecture Agent
- Feature scope matters → Product Manager

**Example:** UX Agent proposes feature that QA Agent flags as untestable
- Escalate to Architecture Agent for design review
- Architecture Agent mediates solution (e.g., manual test approach)

---

### Level 3: Multi-Agent Deadlock (72 hours max)

**Trigger:** Three or more agents cannot reach consensus

**Escalation Path:**
1. Review PROJECT_CHARTER.md and VISION.md for guidance
2. Convene synchronous decision meeting (all agents)
3. Architecture Agent documents decision rationale
4. Product Manager has tiebreaker authority for feature scope
5. Architecture Agent has tiebreaker authority for technical design

**Example:** Feature proposal conflicts with multiple design principles
- All agents review against charter principles
- Synchronous discussion to find compromise
- Product Manager decides if feature aligns with vision

---

### Level 4: Fundamental Principle Conflict (human decision required)

**Trigger:** Proposed change conflicts with core project principles

**Core Principles (cannot be overridden by agents):**
- SSOT rules (SSOT-001 through SSOT-009)
- Security model (local-only, no network access, no elevation)
- Design principles (zero learning curve, 3-click max, no jargon)

**Escalation Path:**
1. Agent flags conflict and documents analysis
2. Create GitHub Issue labeled `governance` and `needs-human`
3. Human maintainer (@SevWren) reviews and decides
4. Decision documented in AGENTS.md or relevant SSOT/SECURITY.md

**Example:** Product Manager proposes cloud sync feature
- Security Agent flags: "Violates security model (no network access)"
- Escalated to Level 4
- Human maintainer decision required to amend security model or reject feature

---

### Level 5: Governance Amendment (human approval required)

**Trigger:** Change to AGENTS.md governance rules, decision authority hierarchy, or agent role definitions

**Process:**
1. Propose amendment via GitHub Issue labeled `governance`
2. All agents review within 72 hours
3. Requires consensus or escalation to human maintainer
4. Human maintainer (@SevWren) approves governance changes
5. Update AGENTS.md version number and change history

---

## Workflow Summary

```
Change Proposed
    |
    v
Domain Agent Creates PR
    |
    v
Multi-Agent Review (per review requirements)
    |
    +-- All approve --> Merge --> Update traceability
    |
    +-- Conflict --> Level 1: Peer Review --> Resolve
    |       |
    |       +-- Still conflict --> Level 2: Cross-Domain Escalation
    |               |
    |               +-- Still conflict --> Level 3: Multi-Agent Deadlock
    |                       |
    |                       +-- Principle violation --> Level 4: Human Decision
    |
    +-- Governance change --> Level 5: Human Approval
```

---

## Appendix: Key Governance Documents

This ownership document should be read in conjunction with:

1. **AGENTS.md** - Multi-agent workflow governance (complete agent role definitions)
2. **CONTRIBUTING.md** - Developer workflow and code quality standards
3. **docs/PRD.md** - Requirements ownership (FR-001 through FR-025)
4. **docs/SSOT.md** - System invariants (SSOT-001 through SSOT-009)
5. **docs/ARCHITECTURE.md** - Module boundaries and system design
6. **docs/SECURITY.md** - Security model and constraints
7. **docs/TEST_PLAN.md** - Test strategy and coverage requirements
8. **docs/TRACEABILITY_MATRIX.md** - Requirements to implementation mapping

---

## Status

> v1.0 ACTIVE

This document establishes code ownership for the Daily Motivation Brain Helper project. All contributors and agents must follow these ownership and review requirements.

**Change History:**
- 2026-06-09: Initial version 1.0 created (CG-007)

---

## CODEOWNERS File

This document is enforced by `.github/CODEOWNERS`, which automatically requests reviews from @SevWren for all changes.

For automated GitHub review requests, see `.github/CODEOWNERS`.

For agent-based review workflows, see `AGENTS.md` Section "Multi-Agent Review Requirements".
