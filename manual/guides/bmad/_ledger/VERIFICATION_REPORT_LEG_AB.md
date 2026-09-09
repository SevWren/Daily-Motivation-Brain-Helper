# BMAD Verification Report -- Leg A + Leg B
**Generated:** 2026-08-24
**Ledger SSOT:** `manual/guides/bmad/_ledger/bmad-feature-ledger.md` (297 rows)
**Guides checked:**
- Developer Guide: `manual/guides/bmad/dev-guide.md`
- Beginner Guide: `manual/guides/bmad/beginner-guide.md`
**Repo grounding sources:**
- `_bmad/config.toml`
- `_bmad/_config/manifest.yaml`

---

## Leg A -- Feature Completeness

### Column key
- **Dev** = present in dev-guide.md (Y or N, with section reference)
- **Beg** = present in beginner-guide.md (Y or N, with section reference)
- **Verdict** = PASS / PARTIAL / FAIL

---

### Category: Installation (INST-001 -- INST-032)

| Feature ID | Feature Name | Dev | Beg | Verdict |
|---|---|---|---|---|
| INST-001 | `npx bmad-method install` base command | Y §1.2 | Y §15.1 | PASS |
| INST-002 | `--yes` / `-y` flag | Y §1.3 table | Y §15.1 | PASS |
| INST-003 | `--directory <path>` flag | Y §1.3 table | Y §15.1 | PASS |
| INST-004 | `--modules <a,b,c>` flag | Y §1.3 table | Y §15.3 | PASS |
| INST-005 | `--tools <a,b>` flag | Y §1.3 table | Y §15.1 | PASS |
| INST-006 | `--list-tools` flag | Y §1.3 table | N | PARTIAL |
| INST-007 | `--action <type>` flag | Y §1.3 table | Y §15.3 (update example) | PASS |
| INST-008 | `--custom-source <urls>` flag | Y §1.3 table, §3.3 | Y §15.4 | PASS |
| INST-009 | `--shims` flag | Y §1.3 table | N | PARTIAL |
| INST-010 | `--no-shims` flag | Y §1.3 table | N | PARTIAL |
| INST-011 | `--channel <stable|next>` flag | Y §1.3 table, §1.5 | N | PARTIAL |
| INST-012 | `--all-stable` flag | Y §1.3 table | N | PARTIAL |
| INST-013 | `--all-next` flag | Y §1.3 table | N | PARTIAL |
| INST-014 | `--next=<code>` flag | Y §1.3 table, §16.3 | N | PARTIAL |
| INST-015 | `--pin <code>=<tag>` flag | Y §1.3 table, §16.3 | Y §15.5 | PASS |
| INST-016 | `--set <module>.<key>=<value>` flag | Y §1.3 table | N | PARTIAL |
| INST-017 | `--list-options [module]` flag | Y §1.3 table | N | PARTIAL |
| INST-018 | `--user-name` legacy flag | Y §1.3 table | N | PARTIAL |
| INST-019 | `--communication-language` legacy flag | Y §1.3 table | N | PARTIAL |
| INST-020 | `--document-output-language` legacy flag | Y §1.3 table | N | PARTIAL |
| INST-021 | `--output-folder` legacy flag | Y §1.3 table | N | PARTIAL |
| INST-022 | Quick Update mode | Y §1.4 | Y §15.2 | PASS |
| INST-023 | Modify Install mode | Y §1.4 | Y §15.2 | PASS |
| INST-024 | `npx bmad-method@next install` | Y §1.5 | N | PARTIAL |
| INST-025 | GITHUB_TOKEN environment variable | Y §1.6 | Y §16.1 | PASS |
| INST-026 | v4 to v6 migration | Y §16.5 | N | PARTIAL |
| INST-027 | Community modules catalog browser | Y §3.3 (discovery mode) | Y §15.4 | PASS |
| INST-028 | `--custom-source` HTTPS URL install | Y §3.3, §1.3 table | Y §15.4 | PASS |
| INST-029 | `--custom-source` SSH URL install | Y §3.3 (Git URL) | N (only HTTPS shown) | PARTIAL |
| INST-030 | `--custom-source` local path install | Y §3.3 | N | PARTIAL |
| INST-031 | Discovery mode vs Direct mode | Y §3.3 | N | PARTIAL |
| INST-032 | Web bundles install path | Y §15 (mentioned as not installed) | N | PARTIAL |

---

### Category: Modules (MOD-001 -- MOD-007)

| Feature ID | Feature Name | Dev | Beg | Verdict |
|---|---|---|---|---|
| MOD-001 | `core` module | Y §3.1 | Y §15.1, §14.3 (68 skills) | PASS |
| MOD-002 | `bmm` module | Y §3.1 | Y §15.1, §15.3 | PASS |
| MOD-003 | `bmb` module | Y §3.2 table | Y §15.3 table | PASS |
| MOD-004 | `cis` module | Y §3.2 table | Y §15.3 table | PASS |
| MOD-005 | `gds` module | Y §3.2 table | Y §15.3 table | PASS |
| MOD-006 | `tea` module | Y §3.2 table, §11.6 | Y §15.3 table | PASS |
| MOD-007 | Community modules marketplace | Y §3.3 | Y §15.4 | PASS |

---

### Category: Skills/Commands (SKILL-001 -- SKILL-068)

The dev guide section 4.3 covers SKILL-001 through SKILL-049 explicitly in a numbered table (rows 1-49), and rows 50-68 are summarized as "50-68 Additional skills -- See `.claude/skills/`" without individual entries. The beginner guide covers skills through its Quick Reference Card (Appendix) and in-body sections. The analysis below assesses each skill individually.

| Feature ID | Feature Name | Dev | Beg | Verdict |
|---|---|---|---|---|
| SKILL-001 | `bmad-advanced-elicitation` | Y §4.3 row 1, §11.4 | Y §9.5 | PASS |
| SKILL-002 | `bmad-agent-analyst` | Y §4.3 row 2, §5.1 | Y §2.1, Appendix | PASS |
| SKILL-003 | `bmad-agent-architect` | Y §4.3 row 3, §5.1 | Y §2.1, §6.2, Appendix | PASS |
| SKILL-004 | `bmad-agent-dev` | Y §4.3 row 4, §5.1 | Y §2.1, §2.3, Appendix | PASS |
| SKILL-005 | `bmad-agent-pm` | Y §4.3 row 5, §5.1 | Y §2.1, Appendix | PASS |
| SKILL-006 | `bmad-agent-ux-designer` | Y §4.3 row 6, §5.1 | Y §2.1, §5.2, Appendix | PASS |
| SKILL-007 | `bmad-architecture` | Y §4.3 row 7, §8.5 | Y §6.1, Appendix | PASS |
| SKILL-008 | `bmad-brainstorming` | Y §4.3 row 8, §10.3 | Y §8.2, Appendix | PASS |
| SKILL-009 | `bmad-build` | Y §4.3 row 9, §7.1 | Y §3.1--3.5, Appendix | PASS |
| SKILL-010 | `bmad-build-auto` | Y §4.3 row 10, §7.2 | Y §4.3, Appendix | PASS |
| SKILL-011 | `bmad-checkpoint-preview` | Y §4.3 row 11, §9.3 | Y §7.4 | PASS |
| SKILL-012 | `bmad-code-review` | Y §4.3 row 12, §11.2 | Y §9.1, Appendix | PASS |
| SKILL-013 | `bmad-correct-course` | Y §4.3 row 13, §11.5 | Y §9.6, Appendix | PASS |
| SKILL-014 | `bmad-create-architecture` | Y §4.3 row 14 (deprecated note) | N (not mentioned; only bmad-architecture mentioned) | PARTIAL |
| SKILL-015 | `bmad-create-epics-and-stories` | Y §4.3 row 15, §8.6 | Y §4.4, Appendix | PASS |
| SKILL-016 | `bmad-create-prd` | Y §4.3 row 16 (sub-workflow note) | N (only bmad-prd mentioned) | PARTIAL |
| SKILL-017 | `bmad-create-story` | Y §4.3 row 17, §8.7 | Y §4.5 | PASS |
| SKILL-018 | `bmad-customize` | Y §4.3 row 18, §12.5 | Y §12.5 | PASS |
| SKILL-019 | `bmad-deep-recon` | Y §4.3 row 19, §10.1 | Y §8.3, Appendix | PASS |
| SKILL-020 | `bmad-dev-auto` | Y §4.3 row 20, §7.3 | Y §10.3, Appendix | PASS |
| SKILL-021 | `bmad-dev-story` | Y §4.3 row 21, §7.3 | Y §10.3, Appendix | PASS |
| SKILL-022 | `bmad-document-project` | Y §4.3 row 22 (deprecated) | N | PARTIAL |
| SKILL-023 | `bmad-domain-research` | Y §4.3 row 23 (deprecated) | Y §8.4 | PASS |
| SKILL-024 | `bmad-edit-prd` | Y §4.3 row 24 (sub-workflow) | N (only bmad-prd mentioned) | PARTIAL |
| SKILL-025 | `bmad-editorial-review` | Y §4.3 row 25 (deprecated) | Y §9.3 | PASS |
| SKILL-026 | `bmad-editorial-review-prose` | Y §4.3 row 26 (deprecated) | Y §9.3 (mentioned) | PASS |
| SKILL-027 | `bmad-editorial-review-structure` | Y §4.3 row 27 (deprecated) | Y §9.3 (mentioned) | PASS |
| SKILL-028 | `bmad-forge-idea` | Y §4.3 row 28, §10.2 | Y §8.1, Appendix | PASS |
| SKILL-029 | `bmad-generate-project-context` | Y §4.3 row 29 (deprecated) | N | PARTIAL |
| SKILL-030 | `bmad-help` | Y §4.3 row 30 | Y §10.1, Appendix | PASS |
| SKILL-031 | `bmad-market-research` | Y §4.3 row 31 (deprecated) | Y §8.4 | PASS |
| SKILL-032 | `bmad-party-mode` | Y §4.3 row 32, §13.1 | Y §11.1--11.3, Appendix | PASS |
| SKILL-033 | `bmad-prd` | Y §4.3 row 33, §8.2 | Y §4.2, Appendix | PASS |
| SKILL-034 | `bmad-prfaq` | Y §4.3 row 34, §8.1 | Y §4.7, Appendix | PASS |
| SKILL-035 | `bmad-product-brief` | Y §4.3 row 35, §8.1 | Y §4.6, Appendix | PASS |
| SKILL-036 | `bmad-project-context` | Y §4.3 row 36, §14.1 | Y §13.1--13.3, Appendix | PASS |
| SKILL-037 | `bmad-qa-generate-e2e-tests` | Y §4.3 row 37, §11.3 | Y §9.4, Appendix | PASS |
| SKILL-038 | `bmad-quick-dev` | Y §4.3 row 38 | Y §10.2, Appendix | PASS |
| SKILL-039 | `bmad-retrospective` | Y §4.3 row 39, §9.2 | Y §7.3, Appendix | PASS |
| SKILL-040 | `bmad-review` | Y §4.3 row 40, §11.1 | Y §9.2, Appendix | PASS |
| SKILL-041 | `bmad-review-adversarial-general` | Y §4.3 row 41 (deprecated) | Y §9.2 (mentioned) | PASS |
| SKILL-042 | `bmad-review-edge-case-hunter` | Y §4.3 row 42 (deprecated) | Y §9.2 (mentioned) | PASS |
| SKILL-043 | `bmad-review-verification-gap` | Y §4.3 row 43 (deprecated) | Y §9.2 (mentioned) | PASS |
| SKILL-044 | `bmad-spec` | Y §4.3 row 44, §8.3 | Y §4.3, Appendix | PASS |
| SKILL-045 | `bmad-sprint-planning` | Y §4.3 row 45, §9.1 | Y §7.1, Appendix | PASS |
| SKILL-046 | `bmad-sprint-status` | Y §4.3 row 46 (deprecated shim) | Y §16.6 | PASS |
| SKILL-047 | `bmad-technical-research` | Y §4.3 row 47 (deprecated) | Y §8.4 | PASS |
| SKILL-048 | `bmad-ux` | Y §4.3 row 48, §8.4 | Y §5.1, Appendix | PASS |
| SKILL-049 | `bmad-validate-prd` | Y §4.3 row 49 (sub-workflow) | N (only bmad-prd mentioned) | PARTIAL |
| SKILL-050 | `code-review` | N (rows 50-68 are dismissed as "see directory") | N | FAIL |
| SKILL-051 | `codebase-design` | N (rows 50-68 dismissed) | N | FAIL |
| SKILL-052 | `diagnosing-bugs` | N | N | FAIL |
| SKILL-053 | `domain-modeling` | N | N | FAIL |
| SKILL-054 | `grill-me` | N | N | FAIL |
| SKILL-055 | `grilling` | N | N | FAIL |
| SKILL-056 | `handoff` | N | N | FAIL |
| SKILL-057 | `implement` | N | N | FAIL |
| SKILL-058 | `improve-codebase-architecture` | N | N | FAIL |
| SKILL-059 | `loop-me` | N | N | FAIL |
| SKILL-060 | `tdd` | N | N | FAIL |
| SKILL-061 | `to-spec` | N | N | FAIL |
| SKILL-062 | `to-tickets` | N | N | FAIL |
| SKILL-063 | `triage` | N | N | FAIL |
| SKILL-064 | `wayfinder` | N | N | FAIL |
| SKILL-065 | `writing-beats` | N | N | FAIL |
| SKILL-066 | `writing-for-agents` | N | N | FAIL |
| SKILL-067 | `writing-fragments` | N | N | FAIL |
| SKILL-068 | `writing-shape` | N | N | FAIL |

**Note on SKILL-050 through SKILL-068:** The dev guide §4.3 table explicitly terminates at row 49 and states "50-68 Additional skills -- See `.claude/skills/` directory listing for full enumeration." This is a deliberate omission, not accidental. None of the 19 skills (code-review, codebase-design, diagnosing-bugs, domain-modeling, grill-me, grilling, handoff, implement, improve-codebase-architecture, loop-me, tdd, to-spec, to-tickets, triage, wayfinder, writing-beats, writing-for-agents, writing-fragments, writing-shape) appear by name or description in either guide beyond the generic note.

---

### Category: Agent-Roles (AGENT-001 -- AGENT-010)

| Feature ID | Feature Name | Dev | Beg | Verdict |
|---|---|---|---|---|
| AGENT-001 | Mary -- Business Analyst | Y §5.1 table | Y §2.1 | PASS |
| AGENT-002 | John -- Product Manager | Y §5.1 table | Y §2.1 | PASS |
| AGENT-003 | Sally -- UX Designer | Y §5.1 table | Y §2.1 | PASS |
| AGENT-004 | Winston -- System Architect | Y §5.1 table | Y §2.1 | PASS |
| AGENT-005 | Amelia -- Senior Software Engineer | Y §5.1 table | Y §2.1 | PASS |
| AGENT-006 | Paige -- Technical Writer (on hiatus) | Y §5.1 note | N (not mentioned) | PARTIAL |
| AGENT-007 | Agent activation 8-step flow | Y §5.2 (8 numbered steps) | N (§2.3 mentions activation but not the 8-step sequence) | PARTIAL |
| AGENT-008 | Fictional / custom agent in roster | Y §12.3 | Y §11.4 | PASS |
| AGENT-009 | TEA module -- Murat agent | Y §11.6 | N (TEA module listed in §15.3 but Murat agent not named) | PARTIAL |
| AGENT-010 | CIS module agents | N (CIS module listed §3.2 but individual agent names not given) | N (CIS module listed §15.3 but agents not named) | FAIL |

---

### Category: Workflows (WF-001 -- WF-045)

| Feature ID | Feature Name | Dev | Beg | Verdict |
|---|---|---|---|---|
| WF-001 | Phase 1 Analysis -- Brainstorming | Y §8.1 | Y §8.2 | PASS |
| WF-002 | Phase 1 Analysis -- Deep Recon (draft mode) | Y §10.1 table | Y §8.3 | PASS |
| WF-003 | Phase 1 Analysis -- Deep Recon (process mode) | Y §10.1 table | Y §8.3 | PASS |
| WF-004 | Phase 1 Analysis -- Deep Recon (run mode) | Y §10.1 table | Y §8.3 | PASS |
| WF-005 | Phase 1 Analysis -- Product Brief | Y §8.1 | Y §4.6 | PASS |
| WF-006 | Phase 1 Analysis -- PRFAQ | Y §8.1 | Y §4.7 | PASS |
| WF-007 | Phase 1 Analysis -- Forge Idea | Y §10.2 | Y §8.1 | PASS |
| WF-008 | Phase 2 Planning -- PRD create intent | Y §8.2 | Y §4.2 | PASS |
| WF-009 | Phase 2 Planning -- PRD update intent | Y §8.2 table | N (bmad-prd mentioned but update intent not explained) | PARTIAL |
| WF-010 | Phase 2 Planning -- PRD validate intent | Y §8.2 table | N (validate intent not explained in beginner guide) | PARTIAL |
| WF-011 | Phase 2 Planning -- UX design | Y §8.4 | Y §5.1 | PASS |
| WF-012 | Phase 2 Planning -- Spec | Y §8.3 | Y §4.3 | PASS |
| WF-013 | Phase 3 Solutioning -- Architecture | Y §8.5 | Y §6.1 | PASS |
| WF-014 | Phase 3 Solutioning -- Create Epics and Stories | Y §8.6 | Y §4.4 | PASS |
| WF-015 | Phase 3 Solutioning -- Sprint Planning (readiness gate) | Y §9.1 | Y §7.1 | PASS |
| WF-016 | Phase 3 Solutioning -- Sprint Planning (generate tracking) | Y §9.1 | Y §7.1 | PASS |
| WF-017 | Phase 3 Solutioning -- Sprint Planning (status view) | Y §9.1 | Y §7.2 | PASS |
| WF-018 | Phase 3 Solutioning -- Sprint Planning (validate/repair) | Y §9.1 | N (not mentioned) | PARTIAL |
| WF-019 | Phase 4 Implementation -- Build | Y §7.1 | Y §3.1 | PASS |
| WF-020 | Phase 4 Implementation -- Build Auto | Y §7.2 | Y §4.3 | PASS |
| WF-021 | Phase 4 Implementation -- Code Review | Y §11.2 | Y §9.1 | PASS |
| WF-022 | Phase 4 Implementation -- Correct Course | Y §11.5 | Y §9.6 | PASS |
| WF-023 | Phase 4 Implementation -- Retrospective | Y §9.2 | Y §7.3 | PASS |
| WF-024 | Project Context -- Setup intent | Y §14.1 | Y §13.2 | PASS |
| WF-025 | Project Context -- Adopt intent | Y §14.1 table | N (not in beginner guide) | PARTIAL |
| WF-026 | Project Context -- Refresh intent | Y §14.1 table | Y §13.3 | PASS |
| WF-027 | Project Context -- Record intent | Y §14.1 table | Y §13.3 | PASS |
| WF-028 | Project Context -- Audit intent | Y §14.1 table | N (not mentioned) | PARTIAL |
| WF-029 | Checkpoint Preview | Y §9.3 | Y §7.4 | PASS |
| WF-030 | Advanced Elicitation | Y §11.4 | Y §9.5 | PASS |
| WF-031 | Brownfield on-ramp | N (not covered -- §14.1 covers project-context but established-projects onramp not described) | N | FAIL |
| WF-032 | Quick Fixes workflow | Y §7.4 | Y §10.2 | PASS |
| WF-033 | Web bundles session workflow | Y §15 (brief mention) | N | PARTIAL |
| WF-034 | Deep Recon -- Refresh existing report | Y §10.1 ("Refresh" bullet) | N (not mentioned) | PARTIAL |
| WF-035 | Deep Recon -- Deepen one dimension | Y §10.1 ("Deepen" bullet) | N (not mentioned) | PARTIAL |
| WF-036 | Spec -- Break into stories.yaml | Y §8.3 (stories.yaml output described) | Y §4.3 (stories.yaml mentioned) | PASS |
| WF-037 | Build Auto -- Folder+ID dispatch | Y §7.2 | N (not mentioned in beginner guide) | PARTIAL |
| WF-038 | Build Auto -- spec resume from status | Y §7.2 (status machine described) | N (status machine not explained) | PARTIAL |
| WF-039 | bmad-help auto-run at workflow end | Y §10.1 (bmad-help description) | Y §10.1 (last sentence) | PASS |
| WF-040 | Retrospective headless mode | N (not mentioned in dev guide) | N | FAIL |
| WF-041 | TEA -- Test Design workflow | Y §11.6 (list) | N (TEA workflows not individually described) | PARTIAL |
| WF-042 | TEA -- ATDD workflow | Y §11.6 (list) | N | PARTIAL |
| WF-043 | TEA -- Test Review workflow | Y §11.6 (list) | N | PARTIAL |
| WF-044 | TEA -- Traceability workflow | Y §11.6 (list) | N | PARTIAL |
| WF-045 | TEA -- Release Gate workflow | Y §11.6 (list) | N | PARTIAL |

---

### Category: Configuration (CONF-001 -- CONF-029)

| Feature ID | Feature Name | Dev | Beg | Verdict |
|---|---|---|---|---|
| CONF-001 | `_bmad/config.toml` | Y §6.1, Appendix B | Y §14.1 | PASS |
| CONF-002 | `_bmad/config.user.toml` | Y §6.1, Appendix B | Y §14.1 | PASS |
| CONF-003 | `_bmad/custom/config.toml` | Y §6.2, Appendix B | Y §14.1 | PASS |
| CONF-004 | `_bmad/custom/config.user.toml` | Y §6.2, Appendix B | Y §14.1 | PASS |
| CONF-005 | `_bmad/<module>/config.yaml` | Y §6.1 | Y §14.1 (`_bmad/bmm/config.yaml`) | PASS |
| CONF-006 | `_bmad/_config/manifest.yaml` | Y §3.4, §6.1, Appendix B | Y §14.5 | PASS |
| CONF-007 | `_bmad/_config/skill-manifest.csv` | Y §6.1 (table row) | N | PARTIAL |
| CONF-008 | `_bmad/_config/files-manifest.csv` | Y §6.1 (table row) | N | PARTIAL |
| CONF-009 | `_bmad/_config/bmad-help.csv` | Y §6.1 (table row) | N | PARTIAL |
| CONF-010 | `_bmad/scripts/resolve_customization.py` | Y §5.2 step 1, §6.6 | Y §14.1 (`_bmad/scripts/`) | PASS |
| CONF-011 | `_bmad/scripts/resolve_config.py` | Y §6.7 table | N (not individually named in beginner guide) | PARTIAL |
| CONF-012 | `_bmad/scripts/config_utils.py` | Y §6.7 table | N | PARTIAL |
| CONF-013 | `_bmad/scripts/memlog.py` | Y §6.7 table | N | PARTIAL |
| CONF-014 | `_bmad/scripts/render_skill.py` | Y §6.7 table | N | PARTIAL |
| CONF-015 | `_bmad/core/config.yaml` | Y §6.1 (table row) | N (not mentioned individually) | PARTIAL |
| CONF-016 | `_bmad/bmm/config.yaml` | Y §6.1 | Y §14.1 | PASS |
| CONF-017 | `_bmad/core/module-help.csv` | N (not individually mentioned; §6.1 covers system files but not this specific file) | N | FAIL |
| CONF-018 | `_bmad/bmm/module-help.csv` | N | N | FAIL |
| CONF-019 | `uv` requirement for resolver scripts | Y §1.1 prerequisites table, §6.6 | Y §15.1 | PASS |
| CONF-020 | `core.project_name` setting | Y §2 (config excerpt) | Y §14.1 (mentions project name in table) | PASS |
| CONF-021 | `core.document_output_language` setting | Y §2 (config excerpt) | N (not individually named) | PARTIAL |
| CONF-022 | `core.output_folder` setting | Y §2 (config excerpt) | N (not individually named) | PARTIAL |
| CONF-023 | `core.user_name` setting | Y §6.1 (table note: sourced from scope:user) | N | PARTIAL |
| CONF-024 | `core.communication_language` setting | Y §6.1 (mentioned in table) | N | PARTIAL |
| CONF-025 | `modules.bmm.user_skill_level` setting | Y §12.4 | N | PARTIAL |
| CONF-026 | `modules.bmm.planning_artifacts` path | Y §2 (config excerpt) | N (path itself not named) | PARTIAL |
| CONF-027 | `modules.bmm.implementation_artifacts` path | Y §2 (config excerpt) | N | PARTIAL |
| CONF-028 | `modules.bmm.project_knowledge` path | Y §2 (config excerpt) | N | PARTIAL |
| CONF-029 | `sprint_plan.py` deterministic script | Y §9.1 | N (not mentioned) | PARTIAL |

---

### Category: Customization (CUST-001 -- CUST-036)

| Feature ID | Feature Name | Dev | Beg | Verdict |
|---|---|---|---|---|
| CUST-001 | Three-layer per-skill override model | Y §6.3 | N (concept mentioned obliquely §12.2 but three-layer model not named or diagrammed) | PARTIAL |
| CUST-002 | `_bmad/custom/{skill-name}.toml` team override | Y §6.2, §12.1 | Y §12.2, §12.4 | PASS |
| CUST-003 | `_bmad/custom/{skill-name}.user.toml` personal override | Y §6.2 | Y §12.4 | PASS |
| CUST-004 | `customize.toml` defaults file per skill | Y §6.3 | Y §16.3 (troubleshooting: "do not copy entire customize.toml") | PASS |
| CUST-005 | Four-layer central config merge | Y §6.4 | N (not named or described) | PARTIAL |
| CUST-006 | Scalar override merge rule | Y §6.5 table | N | PARTIAL |
| CUST-007 | Table deep-merge rule | Y §6.5 table | N | PARTIAL |
| CUST-008 | Keyed array-of-tables merge rule | Y §6.5 table | N | PARTIAL |
| CUST-009 | Append-only array merge rule | Y §6.5 table | N | PARTIAL |
| CUST-010 | No removal mechanism in overrides | Y §6.5 last paragraph | N | PARTIAL |
| CUST-011 | `agent.persistent_facts` customization field | Y §5.3 table, §12.1 example | Y §12.2 | PASS |
| CUST-012 | `agent.principles` customization field | Y §5.3 table | N | PARTIAL |
| CUST-013 | `agent.activation_steps_prepend` field | Y §5.3 table | N | PARTIAL |
| CUST-014 | `agent.activation_steps_append` field | Y §5.3 table | N | PARTIAL |
| CUST-015 | `agent.menu` customization (merge by `code`) | Y §5.3 table, §12.1 example | Y §12.3 | PASS |
| CUST-016 | `agent.name` and `agent.title` read-only fields | Y §5.3 last line | Y §16.3 item 4 | PASS |
| CUST-017 | `agent.icon` customization field | Y §5.3 table | N | PARTIAL |
| CUST-018 | `agent.role` customization field | Y §5.3 table | N | PARTIAL |
| CUST-019 | `agent.communication_style` customization field | Y §5.3 table | N | PARTIAL |
| CUST-020 | `workflow.persistent_facts` customization field | Y §12.2 example | N (not explicitly named; workflow customization example in dev-guide §12.2 uses `persistent_facts` but beginner guide does not cover workflow customization fields) | PARTIAL |
| CUST-021 | `workflow.on_complete` customization field | Y §12.2 example | N | PARTIAL |
| CUST-022 | `workflow.activation_steps_prepend` field | Y §6.5 (merge rules cover general activation) / implicitly via §12 | N | PARTIAL |
| CUST-023 | `workflow.activation_steps_append` field | Y (same as above) | N | PARTIAL |
| CUST-024 | `workflow.external_sources` field | Y §12.6 table | N | PARTIAL |
| CUST-025 | `workflow.external_handoffs` field | Y §12.6 table | N | PARTIAL |
| CUST-026 | `workflow.doc_standards` field | Y §12.6 table | N | PARTIAL |
| CUST-027 | Template/checklist path overrides | Y §12.6 table | N | PARTIAL |
| CUST-028 | `file:` reference in persistent_facts | Y §12.1 example | Y §12.2 (explicit note on `file:` prefix) | PASS |
| CUST-029 | `{project-root}` token in override files | Y §12.1 example | Y §12.2 (explicit note on `{project-root}`) | PASS |
| CUST-030 | Rebrand agent in central config (Recipe 5a) | Y §12.3 | N (fictional agent recipe shown §11.4 but rebrand recipe not) | PARTIAL |
| CUST-031 | Add fictional/custom agent to roster (Recipe 5b) | Y §12.3 | Y §11.4 | PASS |
| CUST-032 | Pin team install settings via central config (Recipe 5c) | Y §12.4 | N | PARTIAL |
| CUST-033 | Workflow activation order (6-step sequence) | Y (§5.2 covers agent 8-step; workflow 6-step not explicitly named; CUST-033 describes workflow activation specifically, which differs from AGENT-007's agent 8-step) | N | PARTIAL |
| CUST-034 | `bmad-customize` skill as guided authoring helper | Y §12.5 | Y §12.5 | PASS |
| CUST-035 | IDE session file reinforcement pattern | N (not mentioned in dev guide) | N | FAIL |
| CUST-036 | `resolve_customization.py` CLI invocation | Y §6.6 (explicit CLI examples) | N | PARTIAL |

---

### Category: Verification/Quality (VER-001 -- VER-021)

| Feature ID | Feature Name | Dev | Beg | Verdict |
|---|---|---|---|---|
| VER-001 | Stable channel | Y §1.5 | N (§15.5 mentions pinning but stable channel concept not named) | PARTIAL |
| VER-002 | Next channel | Y §1.5 | N | PARTIAL |
| VER-003 | Pinned channel | Y §1.5 | Y §15.5 | PASS |
| VER-004 | Sprint Planning readiness gate verdicts | Y §9.1 | Y §7.1 | PASS |
| VER-005 | bmad-review adversarial lens | Y §11.1 table | Y §9.1, §9.2 | PASS |
| VER-006 | bmad-review edge-case lens | Y §11.1 table | Y §9.1, §9.2 | PASS |
| VER-007 | bmad-review verification-gap lens | Y §11.1 table | Y §9.1, §9.2 | PASS |
| VER-008 | bmad-review structure lens | Y §11.1 table | Y §9.2 | PASS |
| VER-009 | bmad-review prose lens | Y §11.1 table | Y §9.2 | PASS |
| VER-010 | Build intent compression and spec approval | Y §7.1 phase sequence | Y §3.1--3.4 | PASS |
| VER-011 | Build deferred-work.md | Y §7.4 | N (quick-dev path mentioned but deferred-work.md artifact not named) | PARTIAL |
| VER-012 | Retrospective acceptance verdict | Y §9.2 | Y §7.3 | PASS |
| VER-013 | Spec preservation validation | Y §8.3 (SPEC.md as only writer) | N (spec described but preservation validation not explained) | PARTIAL |
| VER-014 | Build Auto spec status machine | Y §7.2 state machine diagram | N (statuses not listed in beginner guide) | PARTIAL |
| VER-015 | Build Auto blocking conditions | Y §7.2 (13 blocking conditions listed) | Y §16.7 (non-convergence only -- not all 13 named) | PARTIAL |
| VER-016 | PRD validation report | Y §8.2 | N (validate intent not explained in beginner guide) | PARTIAL |
| VER-017 | sprint-status.yaml `--dry-run` drift report | N (not mentioned in dev guide) | N | FAIL |
| VER-018 | `bmad-checkpoint-preview` detail pass risk tags | Y §9.3 step 3 | N (checkpoint described but risk tags not named) | PARTIAL |
| VER-019 | Deep Recon claim verification levels | N (not mentioned: normal/high/max not described in dev guide) | N | FAIL |
| VER-020 | Deep Recon research firewall | Y §13.2 | N | PARTIAL |
| VER-021 | AGENTS.md bmad:context markers | Y §14.1 | Y §13.2 step 5 | PASS |

---

### Category: Architecture/Artifacts (ARCH-001 -- ARCH-032)

| Feature ID | Feature Name | Dev | Beg | Verdict |
|---|---|---|---|---|
| ARCH-001 | `_bmad-output/` directory structure | Y §2 (directory tree) | Y §1.2, §14.2 | PASS |
| ARCH-002 | `_bmad-output/planning-artifacts/` | Y §2 | Y §14.2 | PASS |
| ARCH-003 | `_bmad-output/implementation-artifacts/` | Y §2 | Y §14.2 | PASS |
| ARCH-004 | `manifest.yaml` artifact | Y §3.4 | Y §14.5 | PASS |
| ARCH-005 | `sprint-status.yaml` artifact | Y §9.1 | Y §7.1 | PASS |
| ARCH-006 | `spec-<slug>.md` artifact | Y §7.1 | N (spec file path not named; "plan" described but not the file name pattern) | PARTIAL |
| ARCH-007 | `SPEC.md` artifact | Y §8.3 | Y §4.3 | PASS |
| ARCH-008 | `stories.yaml` artifact | Y §7.2, §8.3 | Y §4.3 | PASS |
| ARCH-009 | `prd.md` + `addendum.md` artifacts | Y §8.2 | Y §4.2 | PASS |
| ARCH-010 | `DESIGN.md` + `EXPERIENCE.md` artifacts | Y §8.4 | Y §5.1 | PASS |
| ARCH-011 | `ARCHITECTURE-SPINE.md` artifact | Y §8.5 | Y §6.1 | PASS |
| ARCH-012 | `brief.md` artifact | Y §8.1 | Y §4.6 | PASS |
| ARCH-013 | `prfaq-{project}.md` artifact | Y §8.1 (row 34) | N (prfaq described but output filename not given) | PARTIAL |
| ARCH-014 | `forge-report.html` artifact | Y §10.2 | Y §8.1 | PASS |
| ARCH-015 | `forged-idea.md` artifact | Y §10.2 | Y §8.1 | PASS |
| ARCH-016 | `brainstorm.html` artifact | Y §10.3 | Y §8.2 | PASS |
| ARCH-017 | `brainstorm-intent.md` artifact | Y §10.3 | N (brainstorming described but optional brainstorm-intent.md not named) | PARTIAL |
| ARCH-018 | `research.md` artifact | Y §10.1 | Y §8.3 | PASS |
| ARCH-019 | `validation-report.html` + `.md` artifact | Y §8.2 | N | PARTIAL |
| ARCH-020 | `deferred-work.md` artifact | Y §7.4 | N | PARTIAL |
| ARCH-021 | `epic-<N>-context.md` artifact | Y §7.2 | N | PARTIAL |
| ARCH-022 | `bmad-build-auto-result-<slug>.md` fallback artifact | Y §7.2 | N | PARTIAL |
| ARCH-023 | `.memlog.md` artifact | Y §6.7 (memlog.py) | N | PARTIAL |
| ARCH-024 | Skill directory structure (`SKILL.md`) | Y §4.2 | Y §14.3 | PASS |
| ARCH-025 | `module-help.csv` per module | N (not described in dev guide; CONF-017/018 also failed) | N | FAIL |
| ARCH-026 | `v6-shims/README.md` | N (not described in either guide) | N | FAIL |
| ARCH-027 | IDE skill directory locations | Y §4.1, §4.2 | Y §14.3 | PASS |
| ARCH-028 | Party Mode session keepsake HTML | Y §13.1 | N (party mode described at length in §11 but HTML keepsake not mentioned) | PARTIAL |
| ARCH-029 | Build Auto `deferred` frontmatter entries | Y §7.2 | N | PARTIAL |
| ARCH-030 | Build Auto `baseline_revision` frontmatter | Y §7.2 | N | PARTIAL |
| ARCH-031 | Web bundle ZIP structure | Y §15 (brief) | N | PARTIAL |
| ARCH-032 | `_bmad/render/` directory | N (not mentioned in either guide) | N | FAIL |

---

### Category: Troubleshooting (TRBL-001 -- TRBL-017)

| Feature ID | Feature Name | Dev | Beg | Verdict |
|---|---|---|---|---|
| TRBL-001 | "Could not resolve stable tag" / API rate limit | Y §17 table | Y §16.1 | PASS |
| TRBL-002 | "Tag 'vX.Y.Z' not found" error | Y §17 table | Y §16.2 | PASS |
| TRBL-003 | Pinned install keeps upgrading | Y §17 table | N (pinning described but this failure mode not) | PARTIAL |
| TRBL-004 | `--pin bmm=X` silently ignored | Y §1.5 note, §17 table | Y §15.5 note | PASS |
| TRBL-005 | Customization not appearing | Y §17 table | Y §16.3 | PASS |
| TRBL-006 | Updates broke customization | Y §17 table | Y §16.3 item 3 | PASS |
| TRBL-007 | Skills not appearing after install | Y §17 table | Y §16.5 | PASS |
| TRBL-008 | Expected skills are missing | Y §17 table | Y §16.5 item 4 | PASS |
| TRBL-009 | Stale skills from removed module | Y §16.4, §17 table | N (not mentioned) | PARTIAL |
| TRBL-010 | Build Auto `blocked` on `no subagents` | Y §17 table | N (non-convergence covered §16.7 but no-subagents case not) | PARTIAL |
| TRBL-011 | Build Auto `intent gap` mid-review | Y §17 (review repair) | Y §16.7 (non-convergence; not specifically "intent gap" terminology) | PARTIAL |
| TRBL-012 | Sprint status script failure fallback | N (not mentioned) | N | FAIL |
| TRBL-013 | MCP tool name unknown in override | N (MCP mentioned nowhere in either guide) | N | FAIL |
| TRBL-014 | Web bundle persona drift | N (mentioned in §15 as not installed; no persona drift troubleshooting) | N | FAIL |
| TRBL-015 | `agent.name`/`agent.title` override has no effect | Y §5.3 note, §17 (implied via customization troubleshooting) | Y §16.3 item 4 | PASS |
| TRBL-016 | v4 legacy `.bmad-method` folder detected | Y §16.5 | N | PARTIAL |
| TRBL-017 | Sprint status `blocked spec supplied` vs `story already blocked` | N (not mentioned) | N | FAIL |

---

## Leg A Failures

### FAIL entries (absent from both guides)

| Feature ID | Feature Name | Category |
|---|---|---|
| SKILL-050 | `code-review` | Skills/Commands |
| SKILL-051 | `codebase-design` | Skills/Commands |
| SKILL-052 | `diagnosing-bugs` | Skills/Commands |
| SKILL-053 | `domain-modeling` | Skills/Commands |
| SKILL-054 | `grill-me` | Skills/Commands |
| SKILL-055 | `grilling` | Skills/Commands |
| SKILL-056 | `handoff` | Skills/Commands |
| SKILL-057 | `implement` | Skills/Commands |
| SKILL-058 | `improve-codebase-architecture` | Skills/Commands |
| SKILL-059 | `loop-me` | Skills/Commands |
| SKILL-060 | `tdd` | Skills/Commands |
| SKILL-061 | `to-spec` | Skills/Commands |
| SKILL-062 | `to-tickets` | Skills/Commands |
| SKILL-063 | `triage` | Skills/Commands |
| SKILL-064 | `wayfinder` | Skills/Commands |
| SKILL-065 | `writing-beats` | Skills/Commands |
| SKILL-066 | `writing-for-agents` | Skills/Commands |
| SKILL-067 | `writing-fragments` | Skills/Commands |
| SKILL-068 | `writing-shape` | Skills/Commands |
| AGENT-010 | CIS module agents | Agent-Roles |
| WF-031 | Brownfield on-ramp (established projects) | Workflows |
| WF-040 | Retrospective headless mode | Workflows |
| CONF-017 | `_bmad/core/module-help.csv` | Configuration |
| CONF-018 | `_bmad/bmm/module-help.csv` | Configuration |
| CUST-035 | IDE session file reinforcement pattern | Customization |
| VER-017 | sprint-status.yaml `--dry-run` drift report | Verification/Quality |
| VER-019 | Deep Recon claim verification levels | Verification/Quality |
| ARCH-025 | `module-help.csv` per module | Architecture/Artifacts |
| ARCH-026 | `v6-shims/README.md` | Architecture/Artifacts |
| ARCH-032 | `_bmad/render/` directory | Architecture/Artifacts |
| TRBL-012 | Sprint status script failure fallback | Troubleshooting |
| TRBL-013 | MCP tool name unknown in override | Troubleshooting |
| TRBL-014 | Web bundle persona drift | Troubleshooting |
| TRBL-017 | Sprint status `blocked spec supplied` vs `story already blocked` | Troubleshooting |

**Total FAIL: 35 feature IDs**

---

### PARTIAL entries (present in one guide only, or critically incomplete in both)

The following feature IDs are PARTIAL. They are listed here for completeness; full per-row detail is in the category tables above.

**Installation:** INST-006, INST-009, INST-010, INST-011, INST-012, INST-013, INST-014, INST-016, INST-017, INST-018, INST-019, INST-020, INST-021, INST-024, INST-026, INST-029, INST-030, INST-031, INST-032

**Agent-Roles:** AGENT-006, AGENT-007, AGENT-009

**Workflows:** WF-009, WF-010, WF-018, WF-025, WF-028, WF-033, WF-034, WF-035, WF-037, WF-038, WF-041, WF-042, WF-043, WF-044, WF-045

**Skills/Commands:** SKILL-014, SKILL-016, SKILL-022, SKILL-024, SKILL-029, SKILL-049

**Configuration:** CONF-007, CONF-008, CONF-009, CONF-011, CONF-012, CONF-013, CONF-014, CONF-015, CONF-021, CONF-022, CONF-023, CONF-024, CONF-025, CONF-026, CONF-027, CONF-028, CONF-029

**Customization:** CUST-001, CUST-005, CUST-006, CUST-007, CUST-008, CUST-009, CUST-010, CUST-012, CUST-013, CUST-014, CUST-017, CUST-018, CUST-019, CUST-020, CUST-021, CUST-022, CUST-023, CUST-024, CUST-025, CUST-026, CUST-027, CUST-030, CUST-032, CUST-033, CUST-036

**Verification/Quality:** VER-001, VER-002, VER-011, VER-013, VER-014, VER-015, VER-016, VER-018, VER-020

**Architecture/Artifacts:** ARCH-006, ARCH-013, ARCH-017, ARCH-019, ARCH-020, ARCH-021, ARCH-022, ARCH-023, ARCH-028, ARCH-029, ARCH-030, ARCH-031

**Troubleshooting:** TRBL-003, TRBL-009, TRBL-010, TRBL-011, TRBL-016

**Total PARTIAL: approximately 97 feature IDs**

---

## Leg B -- Repo-Grounding and Artifact Sufficiency

### B1. Beginner Guide Repo-Grounding

The beginner guide's header states: "Every example in this guide uses the real files in this project." Below each procedural step with an example is assessed.

**Steps that ARE correctly grounded to real repo content:**

1. §1.2 directory tree -- cites `_bmad/`, `_bmad/config.toml`, `_bmad-output/`, `.claude/skills/`, exact skill names (`bmad-help/`, `bmad-build/`, `bmad-agent-dev/`). All verified present.
2. §1.2 project description -- correctly names `DailyMotivation.ps1` and `Tests/`.
3. §2.3 Amelia menu triggers -- `BD`, `QA`, `CR`, `SP`, `ER` match `_bmad/config.toml` agent descriptor triggers.
4. §3.2 build example -- references `DailyMotivation.ps1` snooze options (5, 15, 30, 60 minutes). The CLAUDE.md does not contradict these values, and `DailyMotivation.ps1` is a real file. Grounded.
5. §4.2 PRD output path -- `_bmad-output/planning-artifacts/prd.md` matches `_bmad/config.toml` `planning_artifacts` value.
6. §6.1 architecture reference -- cites `docs/architecture/adr-005-mandate-history.md` and `New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited`, which is verified against `CLAUDE.md` CORRECT 1 rule. Grounded.
7. §9.4 Pester v5 note -- references `Tests/` folder and Pester v5 rules from `CLAUDE.md`. Grounded.
8. §12.2 customization example -- file path `_bmad/custom/bmad-agent-dev.toml` is correct. Persistent_facts reference to `CLAUDE.md` is grounded.
9. §12.3 menu item example -- references `docs/architecture/adr-005-mandate-history.md` and `DailyMotivation.ps1` line 801. The `New-MotivationTask` catch block at ~line 801 is confirmed in `CLAUDE.md` WRONG 5 "Open violation" note.
10. §14.5 manifest.yaml excerpt -- lists `bmm version v6.11.0 channel stable source bundled`, which matches the actual `manifest.yaml` content exactly (though the manifest uses `source: built-in` not `source: bundled` -- see grounding gap below).
11. §15.1 install command -- `npx bmad-method install --yes --directory . --modules bmm --tools claude-code` matches dev-guide §1.2. Grounded.

**Steps with generic placeholders or unverified specifics:**

1. **§3.2, Step 4 spec example** -- The plan shown reads:
   > `Files to change: DailyMotivation.ps1 (snooze duration array, ~line 400)`
   > `Tests to update: Tests/Snooze.Tests.ps1 (if it exists)`

   The file `Tests/Snooze.Tests.ps1` is presented with "(if it exists)" qualification. The guide cannot verify whether this file actually exists in the repo; it is a plausible but hypothetical filename. This is not a generic placeholder ("your-project") but is an unverifiable concrete path. The "(if it exists)" qualifier partially mitigates this.

2. **§3.2, Step 4 spec example, "~line 400"** -- The snooze duration array location is given as approximately line 400. There is no verification in any repo file that the snooze array is at line 400. The CLAUDE.md references the catch block at ~line 801. The ~line 400 claim for the snooze array is ungrounded.

3. **§14.5 manifest.yaml excerpt** -- The guide shows `source: bundled`. The actual `manifest.yaml` shows `source: built-in`. This is a factual discrepancy -- the guide reproduces a slightly different value from what the real file contains.

4. **§15.4 community module install example** -- Uses `https://github.com/example/my-bmad-module` which is an explicit placeholder URL, not a real repo. The guide does not flag this as illustrative; it reads as an example command. This is the one case of a generic placeholder in an example command.

5. **§7.1 sprint-status.yaml path** -- The guide states the file is created in "your planning artifacts folder" without naming the exact path `_bmad-output/implementation-artifacts/sprint-status.yaml`. The dev guide §9.1 clarifies that sprint-status.yaml is in the implementation artifacts folder, not planning artifacts, yet §4.2 in the beginner guide says the PRD is saved to `_bmad-output/planning-artifacts/prd.md`. The beginner guide §7.1 calls it "your planning artifacts folder" but sprint-status.yaml actually goes in `implementation-artifacts/`. This is a factual error in the grounding.

**Summary of B1 issues:**
- `Tests/Snooze.Tests.ps1 (if it exists)` at §3.2 Step 4 -- unverifiable file path
- `~line 400` for snooze array at §3.2 Step 4 -- unverifiable line number
- `source: bundled` at §14.5 -- incorrect; actual manifest has `source: built-in`
- `https://github.com/example/my-bmad-module` at §15.4 -- generic placeholder URL
- "your planning artifacts folder" at §7.1 for sprint-status.yaml -- factually wrong; sprint-status.yaml is in `implementation-artifacts/`, not `planning-artifacts/`

---

### B2. Developer Guide Repo-Grounding

**Does every configuration/architecture reference cite actual files in the repo?**

Assessed against `_bmad/config.toml`, `_bmad/_config/manifest.yaml`, `.claude/skills/`, `Tests/`, and `DailyMotivation.ps1`.

**Correctly grounded:**

1. §2 config excerpt -- the TOML excerpt shown exactly matches the real `_bmad/config.toml` contents:
   ```toml
   [core]
   project_name = "Daily-Motivation-Brain-Helper"
   document_output_language = "English"
   output_folder = "_bmad-output"
   [modules.bmm]
   planning_artifacts = "{project-root}/_bmad-output/planning-artifacts"
   implementation_artifacts = "{project-root}/_bmad-output/implementation-artifacts"
   project_knowledge = "{project-root}/docs"
   ```
   This is a verbatim match.

2. §3.4 manifest excerpt -- shows `name: core, version: v6.11.0, channel: stable, source: bundled`. The actual manifest has `source: built-in`, not `source: bundled`. **Discrepancy: the dev guide says `source: bundled`; the real file says `source: built-in`.**

3. §5.1 agent table -- lists five agents with exact names, titles, icons, modules, teams matching `_bmad/config.toml`. Grounded.

4. §7.1 build example -- cites `DailyMotivation.ps1` (`New-MotivationTask ~line 801`), which is confirmed in `CLAUDE.md`. Grounded.

5. §11.3 QA workflow -- references `Tests/` folder and Pester v5. Grounded.

6. §12.1 customization example -- cites `_bmad/custom/bmad-agent-dev.toml`, references `CLAUDE.md` and `Tests/**/*.ps1`. Grounded.

7. §12.1 second example -- cites `docs/architecture/adr-005-mandate-history.md` and `DailyMotivation.ps1 lines 780-850`. The CLAUDE.md ADR-005 reference is confirmed. The line range 780-850 is stated; CLAUDE.md mentions "~line 801" for the catch block, so 780-850 is a plausible window. The `New-ScheduledTaskPrincipal` parameter values match `CLAUDE.md` CORRECT 1 exactly. Grounded.

8. §12.2 workflow example -- cites "Windows-only WPF app (ps2exe compiled)" and "STA threading requirements", which are consistent with the project's stated nature in `CLAUDE.md`. Grounded.

9. §12.3 custom agent example -- uses `config.user.toml` for "PowerShell Sage" persona. This file path is correct.

**Ungrounded claims in dev guide:**

1. **§3.4 manifest excerpt, `source: bundled`** -- the real `manifest.yaml` shows `source: built-in`. The dev guide says `source: bundled`. This is a direct factual error.

2. **§4.2 skill file structure shows `scripts/`, `references/`, `assets/`, `step-*.md / workflow.md`** -- these sub-directories are described as present in a skill directory. The ledger confirms SKILL.md and customize.toml exist; the additional paths (`scripts/`, `references/`, `assets/`, `step-*.md`) are described generically without repo-specific verification. Since the dev guide §4.3 row 50-68 explicitly defers to `ls .claude/skills/`, the internal skill structure claim cannot be grounded from the available files.

3. **§8.3, `bmad-spec` output path** -- states `_bmad-output/specs/spec-{slug}/`. However the `_bmad/config.toml` only defines `planning_artifacts` and `implementation_artifacts` directories. The `specs/` sub-path is not present in `config.toml`. This sub-directory is asserted without being traceable to a config value.

4. **§11.3, `test-summary.md`** -- claims QA output goes to `_bmad-output/implementation-artifacts/test-summary.md`. This path is not traceable to any config file in the repo. Ungrounded assertion.

5. **§13.1, party mode "Code Review Crew" and "Anti-Consensus Club"** -- these named shipped parties are asserted as present. The ledger lists them in ARCH-028. Neither `_bmad/config.toml` nor `manifest.yaml` references these named parties. They cannot be grounded from available repo files.

**Summary of B2 issues:**
- `source: bundled` in §3.4 manifest excerpt -- should be `source: built-in` per actual `manifest.yaml`
- Skill sub-directory structure (`scripts/`, `references/`, `assets/`, `step-*.md`) at §4.2 -- generic, not repo-verified
- `_bmad-output/specs/spec-{slug}/` at §8.3 -- `specs/` not in `config.toml`; may be wrong or a separate convention not documented in config
- `test-summary.md` path at §11.3 -- not traceable to any config value
- Named custom parties ("Code Review Crew", "Anti-Consensus Club") at §13.1 -- not verifiable from available repo files

---

### B3. Ambiguous Steps

The following instructional steps in either guide require the reader to infer, assume, or fill in information themselves. Each is quoted verbatim.

**Beginner Guide:**

1. **§3.2 Step 3 (clarifying question):**
   > "BMAD may ask clarifying questions. For example: `bmad-build: Should the 90-minute option appear before or after the 60-minute option?`"

   The word "may" leaves the reader uncertain whether this step will happen. There is no guidance on what to do if BMAD does NOT ask questions and proceeds directly. Reader must infer whether to intervene.

2. **§3.2 Step 4 (plan approval):**
   > "You will see a message like: **'Does this look right? Type 'approve' to continue or describe what to change.'**"

   The phrase "a message like" signals the actual wording will differ. The reader must infer what the actual approval prompt looks like and must guess whether "approve" is the exact word to type or just illustrative.

3. **§3.2 Step 6 (review output):**
   > "Review findings: None critical."

   If review findings ARE present (the critical path), the guide gives no instruction on what to do. The reader must infer.

4. **§3.3 (answering questions):**
   > "If you don't know the answer, say 'I'm not sure, use your best judgment'"

   The guide implies this is a safe answer but does not explain what happens when BMAD uses its judgment -- whether the reader can override afterward. Ambiguous in consequence.

5. **§7.1 sprint-status.yaml creation:**
   > "This creates `sprint-status.yaml` in your planning artifacts folder."

   As noted in B1, the actual location is `implementation-artifacts/`, not `planning-artifacts/`. The reader who follows this literally will look in the wrong place.

6. **§10.3 bmad-dev-story and bmad-dev-auto:**
   > "Use Amelia's `BD` trigger for most implementation work: `/bmad-agent-dev` `BD -- Implement Story 2.1 from the planning artifacts`"

   "Story 2.1" is a placeholder identifier. The reader must infer what actual story IDs look like in their sprint-status.yaml and how to reference them. The guide does not explain story ID format.

7. **§15.4 community modules:**
   > "Then when asked 'Would you like to browse community modules?' select Yes."

   The guide does not specify at which point in the interactive flow this question appears, making it difficult to know what to do if the prompt wording differs.

8. **§11.4 fictional agent -- party mode:**
   > "Then in party mode, you can ask 'bring in Security Hawk' and that character will join."

   The guide does not explain how the system knows to route "bring in Security Hawk" to the custom agent, or what happens if the phrase doesn't match. Reader must infer.

**Developer Guide:**

9. **§9.1 sprint_plan.py behavior:**
   > "PASS/CONCERNS/FAIL verdict on whether plan is implementable without invented decisions"

   The guide does not explain what distinguishes CONCERNS from FAIL, or what the reader should do if they receive CONCERNS. Ambiguous action path.

10. **§16.2 (Add a Module):**
    > "`--tools` is omitted on update; reuses tools from first install"

    This is stated but not explained. A reader switching machines or using a fresh environment would not know whether to include `--tools` or not. Ambiguous in new-machine scenario.

11. **§12.1 agent customization example:**
    > "Example -- add persistent facts to Amelia so she always considers Pester v5 constraints in this repo:"

    The example instructs creating `_bmad/custom/bmad-agent-dev.toml` but does not say whether this file already exists or whether to append to it if it does. A reader who already has that file would risk overwriting existing content. No guidance provided.

---

### B4. Missing Artifacts

**1. Four-phase workflow sequence diagram or flowchart**
- Currently missing from both guides.
- Appendix D of the dev guide gives a text table of phases and workflows, but not a visual flow showing how phases chain into each other (what document feeds the next phase, decision gates, optional vs. required phases). A flowchart would answer the beginner's most common question: "do I need to do all four phases, or can I skip directly to Build?"

**2. Three-layer / four-layer merge priority diagram**
- Currently missing from both guides (dev guide has text tables in §6.3--6.4; beginner guide does not cover merge rules at all).
- An annotated diagram showing which file wins over which, with arrows and "never touched by installer" callouts, would make the override model unambiguous. The text description in §6.3--6.4 is correct but requires careful reading to understand that a user file in `_bmad/custom/` silently beats the installer-managed file.

**3. Annotated `config.toml` excerpt**
- The dev guide shows the raw TOML in §2. The beginner guide mentions the file in §14.1.
- Neither guide has an annotated version with callouts explaining which keys the reader can safely change vs. which are installer-controlled, and what each setting actually affects at runtime. A side-annotated version would eliminate the "don't edit config.toml directly" confusion.

**4. Decision tree: "What skill do I need?"**
- The beginner guide §2.2 has a simplified table (8 rows). The dev guide has no decision aid.
- A decision tree branching on: "Is this a code change? Is it a bug fix or new feature? Is there an existing PRD? Do I need UX? Is the blast radius small?" would route users to the correct skill without requiring them to read multiple sections.

**5. Complete config file inventory table with "safe to edit?" column**
- The dev guide Appendix B has a config inventory but does not explicitly answer "safe to edit?" for each file.
- The beginner guide §14.1 has a partial table. Neither guide has a single consolidated table listing all 14+ config files with: file path, owner, scope, overwritten by installer (Y/N), safe for human edits (Y/N), and recommended use case. This is the single most important reference a new user needs to avoid data loss.

**6. Quick-start checklist for first use**
- Both guides begin with narrative prose. Neither provides a checklist of the minimum steps to make a first successful code change using BMAD.
- A checklist of 5-7 steps (verify uv installed, open project in Claude Code, run /bmad-help, run /bmad-build with a small change, review result, optionally run /bmad-checkpoint-preview) would give beginners a clear success path without reading the whole guide.

**7. SKILL-050 through SKILL-068 reference table**
- These 19 skills (code-review, codebase-design, diagnosing-bugs, domain-modeling, grill-me, grilling, handoff, implement, improve-codebase-architecture, loop-me, tdd, to-spec, to-tickets, triage, wayfinder, writing-beats, writing-for-agents, writing-fragments, writing-shape) are entirely absent from both guides.
- A table with skill name, one-line description, and when to use it would close all 19 FAIL rows in one addition.

---

## Overall Leg A+B Verdict

`LEG_AB_VERDICT: FAIL`

**Itemized failures:**

### Leg A failures (feature completeness)

1. **35 feature IDs are FAIL** (absent from both guides): SKILL-050 through SKILL-068 (19 skills), AGENT-010, WF-031, WF-040, CONF-017, CONF-018, CUST-035, VER-017, VER-019, ARCH-025, ARCH-026, ARCH-032, TRBL-012, TRBL-013, TRBL-014, TRBL-017.

2. **Approximately 97 feature IDs are PARTIAL** (present in one guide but not both, or superficially present in both but lacking critical detail). Key high-impact partials:
   - All 22 CLI installer flags beyond `--yes`, `--directory`, `--modules`, `--tools`, `--pin` are absent from the beginner guide.
   - The three-layer override model, four-layer central config merge, all merge rules (CUST-001, CUST-005--CUST-010) are absent from the beginner guide.
   - 15 TEA workflow entries (WF-041--WF-045) present only in the dev guide (no individual descriptions in beginner guide).
   - Build Auto spec status machine, blocking conditions, folder+ID dispatch (VER-014, VER-015, WF-037, WF-038) absent from beginner guide.

### Leg B failures (repo-grounding and artifact sufficiency)

3. **`source: bundled` vs `source: built-in`** -- Both the dev guide (§3.4) and beginner guide (§14.5) show the manifest excerpt with `source: bundled`. The actual `_bmad/_config/manifest.yaml` shows `source: built-in`. This is a direct factual discrepancy in both guides against the real repo file.

4. **`sprint-status.yaml` folder attribution** -- Beginner guide §7.1 states sprint-status.yaml is created in "your planning artifacts folder." The `_bmad/config.toml` defines separate `planning_artifacts` and `implementation_artifacts` paths. Sprint-status.yaml is an implementation artifact. This is a factual error that will cause readers to look in the wrong directory.

5. **`_bmad-output/specs/spec-{slug}/` path** -- Dev guide §8.3 asserts this output path for bmad-spec. The `_bmad/config.toml` defines no `specs/` path; only `planning_artifacts` and `implementation_artifacts` are defined. This path is ungrounded against the repo config.

6. **`test-summary.md` path** -- Dev guide §11.3 asserts output goes to `_bmad-output/implementation-artifacts/test-summary.md`. Not traceable to any config value in the repo.

7. **`Tests/Snooze.Tests.ps1` at ~line 400** -- Beginner guide §3.2 uses a specific filename (`Snooze.Tests.ps1`) and line number (`~line 400`) that cannot be verified from available repo files.

8. **Generic placeholder URL** -- Beginner guide §15.4 uses `https://github.com/example/my-bmad-module` as an example without flagging it as illustrative. The guide's own stated requirement is "every example uses real files in this project," which this violates.

9. **11 instructional steps are ambiguous** (B3 items 1--11): approvals that say "type approve" or "a message like," consequences of choosing CONCERNS vs FAIL in readiness gate, whether to append vs create `bmad-agent-dev.toml`, story ID format, etc.

10. **7 missing artifacts** (B4 items 1--7): workflow sequence diagram, merge priority diagram, annotated config.toml, decision tree, consolidated config inventory table, first-use checklist, and SKILL-050--SKILL-068 reference table.

---

*Verification report generated: 2026-08-24*
*Verifier: bmad-completeness-verifier subagent*
*Scope: Leg A (297 ledger rows) + Leg B (4 grounding and sufficiency questions)*
