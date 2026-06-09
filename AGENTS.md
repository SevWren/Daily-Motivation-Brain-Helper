# Multi-Agent Workflow Governance

**Last Updated:** 2026-06-09
**Version:** 1.0

This document defines the roles, responsibilities, decision authorities, and escalation paths for all agents working on the Daily Motivation Brain Helper project. It establishes clear boundaries to prevent conflicts and ensure efficient multi-agent collaboration.

---

## Agent Roles

### Product Manager Agent

**Responsibility:**
- Requirements ownership and maintenance of PRD.md
- Feature approval and prioritization decisions
- User story narrative and acceptance criteria authorship
- Feature scope definition and boundary enforcement
- Business impact assessment for proposed changes
- Stakeholder communication (user needs, feature requests)

**Authority:**
- Approves all PRD.md changes (functional requirements FR-XXX)
- Final decision on feature prioritization and sprint planning
- Approves acceptance criteria modifications
- Determines when features move from brainstorm to committed status
- Can reject features that conflict with product vision

**Escalation Paths:**
- **To Architecture Agent:** When feature requires significant system design changes or violates SSOT principles
- **To QA Agent:** When acceptance criteria are untestable or ambiguous
- **To UX Agent:** When user experience implications are unclear
- **To Security Agent:** When feature introduces new security considerations

**Key Artifacts Owned:**
- docs/PRD.md (requirements FR-001 through FR-025)
- docs/USER_STORIES.md
- docs/FEATURE_BRAINSTORM.md
- docs/ROADMAP.md

---

### Architecture Agent

**Responsibility:**
- System design and module boundary definitions
- SSOT (Single Source of Truth) rule enforcement
- Architecture documentation maintenance
- Technical debt assessment and refactoring proposals
- Module inventory and dependency management
- Technology stack decisions
- Integration pattern definitions

**Authority:**
- Approves architecture changes in ARCHITECTURE.md
- Approves changes to SSOT.md (system invariants SSOT-001 through SSOT-009)
- Reviews and approves refactoring plans
- Enforces module boundaries and separation of concerns
- Can reject implementations that violate SSOT principles
- Final decision on technology stack additions

**Escalation Paths:**
- **To Product Manager:** When architectural constraints impact feature feasibility or scope
- **To Security Agent:** When design decisions have security implications
- **To QA Agent:** When testability concerns require architectural changes
- **To Documentation Agent:** When architecture changes require glossary updates

**Key Artifacts Owned:**
- docs/ARCHITECTURE.md
- docs/SSOT.md
- docs/DATA_MODEL.md
- docs/SYSTEM ARCHITECTURE.md

**Critical Reviews Required:**
- PRD.md changes that introduce new system components
- Any modification to module boundaries or responsibilities
- Technology stack additions or changes

---

### QA Agent

**Responsibility:**
- Test strategy and test plan maintenance
- Test case authorship and coverage tracking
- Acceptance criteria validation for testability
- Quality gate enforcement (80% coverage, zero PSScriptAnalyzer warnings)
- CI/CD pipeline health monitoring
- Bug triage and severity assessment
- Test infrastructure maintenance (Pester, PSScriptAnalyzer)

**Authority:**
- Approves TEST_PLAN.md changes
- Approves acceptance criteria (can reject untestable criteria)
- Defines quality gates and coverage thresholds
- Final decision on test case sufficiency
- Can block PRs that fail quality gates
- Determines bug severity and priority

**Escalation Paths:**
- **To Product Manager:** When acceptance criteria are untestable or incomplete
- **To Architecture Agent:** When design makes testing impractical
- **To Documentation Agent:** When test cases need traceability updates
- **To UX Agent:** When UI changes break manual test scenarios

**Key Artifacts Owned:**
- docs/TEST_PLAN.md
- Tests/Unit/*.Tests.ps1
- Tests/Integration/*.Tests.ps1
- .github/workflows/test.yml (CI pipeline)
- .build.ps1 (build automation)

**Critical Reviews Required:**
- PRD.md changes (review acceptance criteria for testability)
- ARCHITECTURE.md changes (assess test impact)
- All code changes (enforce quality gates)

---

### UX Agent

**Responsibility:**
- User experience design and specification
- UI/UX design principles enforcement
- Usability assessment and recommendations
- Tooltip and help text authorship
- First-run experience design
- Interaction pattern consistency
- Accessibility considerations

**Authority:**
- Approves UX_SPEC.md changes
- Reviews and approves UI text, tooltips, error messages
- Final decision on interaction patterns and flows
- Can reject implementations that violate design principles
- Defines terminology for user-facing elements

**Escalation Paths:**
- **To Product Manager:** When UX constraints impact feature scope
- **To QA Agent:** When UX changes require new manual test cases
- **To Documentation Agent:** When user-facing terminology needs glossary updates
- **To Architecture Agent:** When UX requirements need new modules (e.g., welcome overlay)

**Key Artifacts Owned:**
- docs/UX_SPEC.md
- docs/USE_CASES.md
- User-facing text in all UI components

**Critical Reviews Required:**
- PRD.md changes that affect user interaction
- Any UI text or error message changes
- New features with user-facing components

**Design Principles Enforced:**
1. Zero learning curve - no user should need instructions
2. 3-click max - core actions complete in 3 clicks or fewer
3. No jargon - zero technical terms in user-facing text
4. Self-explaining - every control has a tooltip (FR-025)

---

### Security Agent

**Responsibility:**
- Security model enforcement
- Threat assessment for new features
- Security policy maintenance
- Privilege escalation analysis
- Data privacy and credential handling review
- Vulnerability assessment
- Security best practices enforcement

**Authority:**
- Approves SECURITY.md changes
- Reviews and approves features with security implications
- Can block features that introduce unacceptable risks
- Requires security review for external integrations
- Defines security constraints for architecture decisions

**Escalation Paths:**
- **To Architecture Agent:** When security requires architectural changes
- **To Product Manager:** When security constraints make features infeasible
- **To QA Agent:** When security testing is required
- **To Documentation Agent:** When security model changes need documentation

**Key Artifacts Owned:**
- docs/SECURITY.md
- docs/RISK_REGISTER.md

**Critical Reviews Required:**
- PRD.md changes that involve file system access, external processes, or data storage
- ARCHITECTURE.md changes that affect security model
- Any feature involving credentials, tokens, or sensitive data
- Shell extension implementation (COM DLL, registry access)

**Security Model Constraints:**
- Application runs entirely locally with no network access
- Operates under current user account (no elevation at runtime)
- No credentials, tokens, or personal data stored or transmitted
- Only external interaction: launching Windows Explorer

---

### Documentation Agent

**Responsibility:**
- Documentation accuracy and consistency
- Glossary maintenance and term enforcement
- Traceability matrix maintenance
- Cross-reference validation
- Domain vocabulary consistency across all docs
- ADR (Architecture Decision Record) management
- Gap analysis and coverage tracking

**Authority:**
- Approves changes to GLOSSARY.md and TRACEABILITY_MATRIX.md
- Final decision on domain terminology
- Enforces use of canonical terms across all documentation
- Can reject documentation that uses inconsistent vocabulary
- Maintains document version control and update tracking

**Escalation Paths:**
- **To Product Manager:** When requirements need clarification or have conflicts
- **To Architecture Agent:** When SSOT principles need documentation updates
- **To QA Agent:** When test coverage gaps are identified
- **To UX Agent:** When user-facing terms conflict with glossary

**Key Artifacts Owned:**
- docs/GLOSSARY.md
- docs/TRACEABILITY_MATRIX.md
- docs/GAP_ANALYSIS.md
- docs/README.md
- docs/CONTRIBUTING.md
- docs/agents/* (all agent guidance documentation)

**Critical Reviews Required:**
- All documentation changes (enforce vocabulary consistency)
- PRD.md changes (maintain traceability matrix)
- ARCHITECTURE.md changes (update glossary if new terms introduced)
- TEST_PLAN.md changes (validate traceability)

---

## Multi-Agent Review Requirements

This section defines which agents must review changes to critical documents.

### When PRD.md Changes

**Required Reviews:**
- **Product Manager** (approver) - requirements ownership
- **QA Agent** (reviewer) - validate acceptance criteria testability
- **Architecture Agent** (reviewer) - assess SSOT impact and architectural feasibility
- **Documentation Agent** (reviewer) - update traceability matrix

**Optional Reviews (context-dependent):**
- **UX Agent** - if changes affect user interaction flows
- **Security Agent** - if changes involve file system, processes, or data storage

### When ARCHITECTURE.md Changes

**Required Reviews:**
- **Architecture Agent** (approver) - system design ownership
- **QA Agent** (reviewer) - assess test impact and coverage changes
- **Documentation Agent** (reviewer) - update glossary if new terms introduced

**Optional Reviews:**
- **Security Agent** - if changes affect security model
- **Product Manager** - if architectural constraints impact feature scope

### When SSOT.md Changes

**Required Reviews:**
- **Architecture Agent** (approver) - SSOT rule enforcement
- **Product Manager** (reviewer) - validate business logic alignment
- **QA Agent** (reviewer) - assess test coverage for new invariants
- **Documentation Agent** (reviewer) - ensure traceability

### When TEST_PLAN.md or Test Files Change

**Required Reviews:**
- **QA Agent** (approver) - test strategy ownership
- **Documentation Agent** (reviewer) - update traceability matrix

**Optional Reviews:**
- **Architecture Agent** - if test changes reveal architectural issues
- **UX Agent** - if manual test cases change

### When UX_SPEC.md Changes

**Required Reviews:**
- **UX Agent** (approver) - UX design ownership
- **QA Agent** (reviewer) - assess manual test case updates needed
- **Documentation Agent** (reviewer) - validate consistency with USE_CASES.md

### When SECURITY.md Changes

**Required Reviews:**
- **Security Agent** (approver) - security policy ownership
- **Architecture Agent** (reviewer) - validate architectural compliance

### When GLOSSARY.md or TRACEABILITY_MATRIX.md Changes

**Required Reviews:**
- **Documentation Agent** (approver) - documentation artifacts ownership
- **Product Manager** (reviewer) - validate requirements coverage
- **Architecture Agent** (reviewer) - confirm technical terminology accuracy

### When Code Changes

**Required Reviews:**
- **QA Agent** - enforce quality gates (80% coverage, zero warnings)
- **Architecture Agent** - enforce module boundaries and SSOT compliance

**Optional Reviews:**
- **Security Agent** - if code touches file system, processes, or sensitive operations
- **UX Agent** - if code changes affect user-facing text or interactions

---

## Escalation Matrix

### Level 1: Peer Agent Review
**Trigger:** Routine changes within agent's domain
**Process:** Agent proposes change, peer agents review per review requirements above
**Timeline:** 24-48 hours for review cycle

### Level 2: Cross-Domain Conflict
**Trigger:** Disagreement between two agents on decision authority
**Escalation Path:** Escalate to Architecture Agent for technical matters, Product Manager for feature scope matters
**Timeline:** 48-72 hours for resolution

### Level 3: Multi-Agent Deadlock
**Trigger:** Three or more agents cannot reach consensus
**Escalation Path:** Escalate to Project Charter principles and VISION.md for guidance; convene all agents for synchronous decision
**Timeline:** 72 hours maximum for decision

### Level 4: Fundamental Principle Conflict
**Trigger:** Proposed change conflicts with core project principles (SSOT, design principles, security model)
**Escalation Path:** Flag for human maintainer review with detailed conflict analysis
**Timeline:** N/A (requires human decision)

---

## Decision Authority Hierarchy

For clarity, when decision authority overlaps:

1. **SSOT violations** → Architecture Agent has final authority (can block any change)
2. **Feature scope** → Product Manager has final authority
3. **Security concerns** → Security Agent has final authority (can block any change)
4. **Quality gates** → QA Agent has final authority (can block PR merges)
5. **User experience** → UX Agent has final authority for UI/UX matters
6. **Documentation consistency** → Documentation Agent has final authority for terminology

---

## Triage Label Taxonomy

This project uses GitHub Issues for task tracking. See [docs/agents/triage-labels.md](docs/agents/triage-labels.md) for detailed label definitions.

### Standard Labels

| Label | Meaning | Applied By |
|-------|---------|------------|
| `needs-triage` | Maintainer needs to evaluate this issue | Any agent when creating issue |
| `needs-info` | Waiting on reporter for more information | Any agent during investigation |
| `ready-for-agent` | Fully specified, ready for autonomous agent work | Product Manager or QA Agent after requirements validated |
| `ready-for-human` | Requires human implementation or decision | Any agent when encountering blocking issues |
| `wontfix` | Will not be actioned | Product Manager (feature scope) or Architecture Agent (SSOT violation) |

### Domain-Specific Labels

| Label | Meaning | Applied By |
|-------|---------|------------|
| `requirements` | PRD.md or acceptance criteria change | Product Manager |
| `architecture` | System design or SSOT change | Architecture Agent |
| `testing` | Test coverage or quality gate issue | QA Agent |
| `ux` | User experience or interface issue | UX Agent |
| `security` | Security concern or threat assessment | Security Agent |
| `documentation` | Documentation update or consistency issue | Documentation Agent |

### Priority Labels

| Label | Meaning | Applied By |
|-------|---------|------------|
| `priority:critical` | Blocks release or violates SSOT | Architecture Agent or Product Manager |
| `priority:high` | Affects core functionality or user experience | Product Manager or UX Agent |
| `priority:medium` | Important but not blocking | Any agent |
| `priority:low` | Nice to have, deferred consideration | Product Manager |

---

## Issue Tracker Integration

This project uses GitHub Issues. See [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md) for CLI conventions.

### Creating Issues

When an agent identifies work requiring human attention or cross-agent coordination:

```bash
gh issue create \
  --title "[AGENT-TYPE] Brief description" \
  --body "Detailed context, references to docs, proposed solution" \
  --label "needs-triage,<domain-label>"
```

### Triage Process

1. **Product Manager** reviews all `needs-triage` issues within 48 hours
2. Apply domain-specific labels to route to appropriate agent
3. Apply `ready-for-agent` when fully specified, or `needs-info` if clarification required
4. Apply `ready-for-human` for complex decisions or implementations requiring human judgment

### Closing Issues

Issues should reference:
- Documentation updated (file paths)
- Traceability maintained (requirements linked)
- Tests updated (if applicable)

---

## Domain Documentation Reading Order

Before exploring codebase, agents must read:

1. **AGENTS.md** (this file) - understand roles and workflows
2. **docs/agents/domain.md** - how to consume domain documentation
3. **docs/PRD.md** - functional requirements
4. **docs/SSOT.md** - system invariants that MUST NOT be violated
5. **docs/ARCHITECTURE.md** - system structure and module boundaries
6. **docs/GLOSSARY.md** - canonical terminology (use these terms consistently)

See [docs/agents/domain.md](docs/agents/domain.md) for detailed guidance on using domain documentation.

---

## Conflict Resolution Examples

### Example 1: Feature vs. SSOT Conflict

**Scenario:** Product Manager proposes new feature that would allow multiple popups simultaneously

**Resolution:**
1. QA Agent flags during review: "Violates SSOT-006 (one popup at a time)"
2. Product Manager escalates to Architecture Agent
3. Architecture Agent confirms SSOT-006 violation, blocks feature
4. Product Manager revises feature scope or requests SSOT amendment with justification

**Outcome:** SSOT principles are preserved unless explicit decision to amend

### Example 2: UX vs. Testability Conflict

**Scenario:** UX Agent proposes drag-and-drop feature with complex gesture handling

**Resolution:**
1. QA Agent flags during review: "Cannot write automated tests for drag gestures"
2. UX Agent and QA Agent discuss alternatives
3. Agreement: Implement drag-drop with manual test case coverage (TC-018)
4. Update TEST_PLAN.md with manual test case
5. Both agents approve

**Outcome:** Feature proceeds with documented test approach

### Example 3: Security vs. Feature Conflict

**Scenario:** Product Manager proposes cloud sync feature

**Resolution:**
1. Security Agent reviews PRD change: "Violates security model (no network access)"
2. Security Agent blocks feature
3. Product Manager escalates: "Critical user request"
4. Escalates to Level 4 (Fundamental Principle Conflict)
5. Human maintainer decision required

**Outcome:** Security model maintained unless human explicitly overrides

---

## Workflow Summary

```
Issue Created
    |
    v
Product Manager Triage (apply labels)
    |
    +-- needs-info --> Reporter clarifies --> back to triage
    |
    +-- ready-for-agent --> Route to domain agent
    |       |
    |       v
    |   Agent creates PRD/doc changes
    |       |
    |       v
    |   Multi-agent review (per review requirements above)
    |       |
    |       v
    |   All reviewers approve --> Merge --> Update traceability --> Close issue
    |       |
    |       v
    |   Conflict --> Escalation matrix
    |
    +-- ready-for-human --> Human implementation
    |
    +-- wontfix --> Close with justification
```

---

## Status

> v1.0 ACTIVE

This document supersedes any informal agent coordination patterns. All agents must follow these governance rules.

**Change History:**
- 2026-06-09: Initial version 1.0 created (CG-001)
