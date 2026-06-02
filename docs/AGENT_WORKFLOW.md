# Agent Workflow

This document defines the multi-agent review framework for AI-assisted development of this project.

## Agents

### Product Agent
**Reviews:** User stories, scope, feature completeness  
**Artifacts:** USER_STORIES.md, USE_CASES.md, FEATURE_MATRIX.md, PRD.md  
**Key Question:** Does every feature trace to a user story?

### Architecture Agent
**Reviews:** System design, module boundaries, dependencies  
**Artifacts:** ARCHITECTURE.md, TASK_SCHEDULER_SPEC.md, NOTIFICATION_ENGINE_SPEC.md  
**Key Question:** Are modules deep enough? Is there unnecessary coupling?

### UX Agent
**Reviews:** Simplicity, accessibility, user flow completeness  
**Artifacts:** UX_SPEC.md, NPR.md  
**Key Question:** Can a non-technical user complete every core action without instructions?

### QA Agent
**Reviews:** Acceptance criteria, edge cases, test coverage  
**Artifacts:** ACCEPTANCE_CRITERIA.md, TEST_PLAN.md  
**Key Question:** Is every functional requirement covered by at least one acceptance criterion?

### Security Agent
**Reviews:** Folder path handling, local storage security, scheduler permissions  
**Artifacts:** TASK_SCHEDULER_SPEC.md, CONFIGURATION_SPEC.md  
**Key Question:** Does the app operate with least privilege at all times?

### Documentation Agent
**Reviews:** Traceability, SSOT consistency, changelog currency  
**Artifacts:** TRACEABILITY_MATRIX.md, SSOT.md, CHANGELOG.md  
**Key Question:** Does every requirement trace from user story through implementation to test?

## Synchronization Rule
Any change to PRD.md must trigger a review pass by Product Agent, QA Agent, and Documentation Agent before merge.

## Status
> DRAFT
