# BMAD Feature Ledger

> Generated from: `/home/vercel-sandbox/llms-full.txt` (4313 lines, ~256 KB)
> Installed config: `_bmad/config.toml`, `_bmad/bmm/config.yaml`, `_bmad/_config/manifest.yaml`
> Skills enumerated from: `.claude/skills/` (68 skill directories)
> Generated: 2026-08-24

| Feature ID | Feature Name | Category | Source Section in llms-full.txt | One-line description |
|---|---|---|---|---|
| INST-001 | `npx bmad-method install` base command | Installation | how-to/install-bmad.md | Primary installer entry point; interactive first-time flow asking six questions |
| INST-002 | `--yes` / `-y` flag | Installation | how-to/install-bmad.md (Flag reference table) | Skip all prompts and accept flag values plus defaults; required for headless CI |
| INST-003 | `--directory <path>` flag | Installation | how-to/install-bmad.md (Flag reference table) | Install into a specific directory instead of the current working directory |
| INST-004 | `--modules <a,b,c>` flag | Installation | how-to/install-bmad.md (Flag reference table) | Exact module set to install; core auto-added; not a delta  -  list everything to keep |
| INST-005 | `--tools <a,b>` flag | Installation | how-to/install-bmad.md (Flag reference table) | IDE/tool selection; required for fresh `--yes` installs |
| INST-006 | `--list-tools` flag | Installation | how-to/install-bmad.md (Flag reference table) | Print all supported tool/IDE IDs with target directories and exit |
| INST-007 | `--action <type>` flag | Installation | how-to/install-bmad.md (Flag reference table) | Set action to `install`, `update`, or `quick-update`; defaults based on existing install state |
| INST-008 | `--custom-source <urls>` flag | Installation | how-to/install-bmad.md (Flag reference table) | Install custom modules from Git URLs or local paths; comma-separated for multiple |
| INST-009 | `--shims` flag | Installation | how-to/install-bmad.md (Flag reference table) | Install deprecated compatibility shim skills when selected modules still provide them |
| INST-010 | `--no-shims` flag | Installation | how-to/install-bmad.md (Flag reference table) | Explicitly omit deprecated shim skills; removes them on existing install during update |
| INST-011 | `--channel <stable\|next>` flag | Installation | how-to/install-bmad.md (Flag reference table) | Apply channel to all external modules; aliased as `--all-stable` / `--all-next` |
| INST-012 | `--all-stable` flag | Installation | how-to/install-bmad.md (Flag reference table) | Alias for `--channel=stable`; installs highest released semver tag for all externals |
| INST-013 | `--all-next` flag | Installation | how-to/install-bmad.md (Flag reference table) | Alias for `--channel=next`; installs main branch HEAD for all external modules |
| INST-014 | `--next=<code>` flag | Installation | how-to/install-bmad.md (Flag reference table) | Put one specific module on the next channel; repeatable for multiple modules |
| INST-015 | `--pin <code>=<tag>` flag | Installation | how-to/install-bmad.md (Flag reference table) | Pin one module to a specific git tag; repeatable; beats `--next=` and `--channel` |
| INST-016 | `--set <module>.<key>=<value>` flag | Installation | how-to/install-bmad.md (Flag reference table) | Set any module config option non-interactively as a post-install patch; repeatable |
| INST-017 | `--list-options [module]` flag | Installation | how-to/install-bmad.md (Flag reference table) | Print every `--set` key for built-in and locally-cached official modules, then exit |
| INST-018 | `--user-name` legacy flag | Installation | how-to/install-bmad.md (Flag reference table) | Legacy shortcut equivalent to `--set core.user_name=<value>`; still supported |
| INST-019 | `--communication-language` legacy flag | Installation | how-to/install-bmad.md (Flag reference table) | Legacy shortcut equivalent to `--set core.communication_language=<value>` |
| INST-020 | `--document-output-language` legacy flag | Installation | how-to/install-bmad.md (Flag reference table) | Legacy shortcut equivalent to `--set core.document_output_language=<value>` |
| INST-021 | `--output-folder` legacy flag | Installation | how-to/install-bmad.md (Flag reference table) | Legacy shortcut equivalent to `--set core.output_folder=<value>`; still supported |
| INST-022 | Quick Update mode | Installation | how-to/install-bmad.md (Updating an existing install) | Re-runs install with existing settings; applies patches and minor stable upgrades; refuses major upgrades |
| INST-023 | Modify Install mode | Installation | how-to/install-bmad.md (Updating an existing install) | Full interactive flow; add/remove modules, reconfigure settings, switch channels |
| INST-024 | `npx bmad-method@next install` | Installation | how-to/install-bmad.md (First-time install) | Runs the prerelease installer which ships a newer snapshot of core and bmm |
| INST-025 | GITHUB_TOKEN environment variable | Installation | how-to/install-bmad.md (Rate limit note) | Set to raise GitHub API limit from 60/hr to 5000/hr for external module tag resolution |
| INST-026 | v4 to v6 migration | Installation | how-to/upgrade-to-v6.md | Automatic detection of legacy `.bmad-method` folder with backup/removal guidance |
| INST-027 | Community modules catalog browser | Installation | how-to/install-custom-modules.md | Interactive browser for community-contributed modules: browse by category, featured, keyword search |
| INST-028 | `--custom-source` HTTPS URL install | Installation | how-to/install-custom-modules.md | Install module from any HTTPS Git URL including subdir path (`/tree/main/my-module`) |
| INST-029 | `--custom-source` SSH URL install | Installation | how-to/install-custom-modules.md | Install module from SSH Git URL (`git@github.com:org/repo.git`) |
| INST-030 | `--custom-source` local path install | Installation | how-to/install-custom-modules.md | Install module from local filesystem path; supports `~` tilde expansion |
| INST-031 | Discovery mode vs Direct mode | Installation | how-to/install-custom-modules.md (Module Discovery) | Discovery uses `.claude-plugin/marketplace.json`; Direct scans for SKILL.md directories |
| INST-032 | Web bundles install path | Installation | how-to/use-web-bundles.md | Install from bmadcode.com/web-bundles for Gemini Gem or ChatGPT Custom GPT deployment |
| MOD-001 | `core` module | Modules | reference/modules.md; _bmad/_config/manifest.yaml | Universal core framework; always installed; ships help, review, customization, and thinking skills |
| MOD-002 | `bmm` module (BMad Method) | Modules | reference/modules.md; _bmad/_config/manifest.yaml | Agile suite; ships named agents, workflow skills, sprint planning, and spec workflows |
| MOD-003 | `bmb` module (BMad Builder) | Modules | reference/modules.md | Meta-module for creating custom agents, workflows, and domain-specific modules |
| MOD-004 | `cis` module (Creative Intelligence Suite) | Modules | reference/modules.md | AI-powered creativity tools: Innovation Strategist, Design Thinking Coach, SCAMPER frameworks |
| MOD-005 | `gds` module (Game Dev Studio) | Modules | reference/modules.md | Structured game development workflows for Unity, Unreal, Godot, and custom engines |
| MOD-006 | `tea` module (Test Architect Enterprise) | Modules | reference/modules.md; reference/testing.md | Enterprise test strategy with Murat agent and nine structured workflows; P0-P3 prioritization |
| MOD-007 | Community modules marketplace | Modules | reference/modules.md; how-to/install-custom-modules.md | Curated modules in bmad-plugins-marketplace; pinned to approved commits for safety |
| SKILL-001 | `bmad-advanced-elicitation` | Skills/Commands | reference/core-tools.md; .claude/skills/ | Push LLM output through iterative refinement methods (Socratic, pre-mortem, red team, first principles) |
| SKILL-002 | `bmad-agent-analyst` | Skills/Commands | reference/agents.md; .claude/skills/ | Load Mary (Business Analyst) persona with menu of analysis workflows |
| SKILL-003 | `bmad-agent-architect` | Skills/Commands | reference/agents.md; .claude/skills/ | Load Winston (System Architect) persona for technical design and architecture workflows |
| SKILL-004 | `bmad-agent-dev` | Skills/Commands | reference/agents.md; .claude/skills/ | Load Amelia (Senior Software Engineer) persona for story execution and code implementation |
| SKILL-005 | `bmad-agent-pm` | Skills/Commands | reference/agents.md; .claude/skills/ | Load John (Product Manager) persona for PRD creation and requirements discovery |
| SKILL-006 | `bmad-agent-ux-designer` | Skills/Commands | reference/agents.md; .claude/skills/ | Load Sally (UX Designer) persona for UX design specifications |
| SKILL-007 | `bmad-architecture` | Skills/Commands | .claude/skills/ | Produce architecture spine of invariants as ARCHITECTURE-SPINE.md or desired format |
| SKILL-008 | `bmad-brainstorming` | Skills/Commands | reference/core-tools.md; .claude/skills/ | Facilitate interactive brainstorming session; produces brainstorm.html keepsake |
| SKILL-009 | `bmad-build` | Skills/Commands | explanation/build.md; .claude/skills/ | Canonical implementation workflow accepting direct intent, issue, spec, or planned story |
| SKILL-010 | `bmad-build-auto` | Skills/Commands | reference/build-auto.md; .claude/skills/ | One unattended iteration of the Build development loop; exposes terminal statuses for orchestrators |
| SKILL-011 | `bmad-checkpoint-preview` | Skills/Commands | explanation/checkpoint-preview.md; .claude/skills/ | LLM-assisted human-in-the-loop review: orientation, walkthrough, detail pass, testing, wrap-up |
| SKILL-012 | `bmad-code-review` | Skills/Commands | .claude/skills/ | Adversarial code review using parallel review layers and structured triage |
| SKILL-013 | `bmad-correct-course` | Skills/Commands | .claude/skills/ | Manage significant changes during sprint execution; update plan or re-route |
| SKILL-014 | `bmad-create-architecture` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-architecture (create intent) |
| SKILL-015 | `bmad-create-epics-and-stories` | Skills/Commands | reference/workflow-map.md; .claude/skills/ | Break requirements into epics and user stories; produces epic files |
| SKILL-016 | `bmad-create-prd` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-prd (create intent) |
| SKILL-017 | `bmad-create-story` | Skills/Commands | .claude/skills/ | Deprecated: `bmad-build` is now official; only use when explicitly invoked by name |
| SKILL-018 | `bmad-customize` | Skills/Commands | reference/core-tools.md; .claude/skills/ | Author and verify customization overrides for installed BMad skills without hand-authoring TOML |
| SKILL-019 | `bmad-deep-recon` | Skills/Commands | explanation/deep-recon.md; .claude/skills/ | Decision-grade research: draft prompt, process report, or run in-session with parallel web fan-out |
| SKILL-020 | `bmad-dev-auto` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-build-auto; do not use unless invoked by name |
| SKILL-021 | `bmad-dev-story` | Skills/Commands | .claude/skills/ | Deprecated: `bmad-build` is now official implementation method; only use when invoked by name |
| SKILL-022 | `bmad-document-project` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-project-context |
| SKILL-023 | `bmad-domain-research` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-deep-recon (domain type) |
| SKILL-024 | `bmad-edit-prd` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-prd (update intent) |
| SKILL-025 | `bmad-editorial-review` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-review |
| SKILL-026 | `bmad-editorial-review-prose` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-review |
| SKILL-027 | `bmad-editorial-review-structure` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-review |
| SKILL-028 | `bmad-forge-idea` | Skills/Commands | explanation/forge-idea.md; .claude/skills/ | Pressure-test an idea through adversarial interrogation until hardened, killed, or clarified |
| SKILL-029 | `bmad-generate-project-context` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-project-context |
| SKILL-030 | `bmad-help` | Skills/Commands | reference/core-tools.md; .claude/skills/ | Context-aware guide: scans project, detects completed phases, recommends next steps |
| SKILL-031 | `bmad-market-research` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-deep-recon (market type) |
| SKILL-032 | `bmad-party-mode` | Skills/Commands | explanation/party-mode.md; .claude/skills/ | Orchestrate multi-agent roundtable discussions with installed agents or custom personas |
| SKILL-033 | `bmad-prd` | Skills/Commands | reference/workflow-map.md; .claude/skills/ | Create, update, or validate a PRD; three intents in one skill |
| SKILL-034 | `bmad-prfaq` | Skills/Commands | .claude/skills/ | Working Backwards PRFAQ challenge that stress-tests a product concept customer-first |
| SKILL-035 | `bmad-product-brief` | Skills/Commands | reference/workflow-map.md; .claude/skills/ | Create, update, or validate a product brief; produces brief.md + addendum.md |
| SKILL-036 | `bmad-project-context` | Skills/Commands | how-to/project-context.md; .claude/skills/ | Set up, refresh, or audit repo AGENTS.md block so AI agents work well in the repo |
| SKILL-037 | `bmad-qa-generate-e2e-tests` | Skills/Commands | reference/testing.md; .claude/skills/ | Generate E2E and API automated tests for existing features using detected test framework |
| SKILL-038 | `bmad-quick-dev` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-build; do not use unless invoked by name |
| SKILL-039 | `bmad-retrospective` | Skills/Commands | explanation/retrospective.md; .claude/skills/ | Evidence-based epic retrospective; verdict: accepted, accepted-with-open-items, or rejected |
| SKILL-040 | `bmad-review` | Skills/Commands | reference/core-tools.md; .claude/skills/ | Multi-lens review (adversarial, edge-case, verification-gap, structure, prose) over any artifact |
| SKILL-041 | `bmad-review-adversarial-general` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-review |
| SKILL-042 | `bmad-review-edge-case-hunter` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-review |
| SKILL-043 | `bmad-review-verification-gap` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-review |
| SKILL-044 | `bmad-spec` | Skills/Commands | reference/workflow-map.md; .claude/skills/ | Distill any intent into SPEC.md kernel (Why/Capabilities/Constraints/Non-goals/Success) + companions |
| SKILL-045 | `bmad-sprint-planning` | Skills/Commands | explanation/sprint-planning.md; .claude/skills/ | Gate readiness, generate sprint-status.yaml, summarize status, validate/repair tracking file |
| SKILL-046 | `bmad-sprint-status` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-sprint-planning (status view) |
| SKILL-047 | `bmad-technical-research` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-deep-recon (technical type) |
| SKILL-048 | `bmad-ux` | Skills/Commands | reference/workflow-map.md; .claude/skills/ | Plan UX patterns and design specifications; produces DESIGN.md + EXPERIENCE.md spine pair |
| SKILL-049 | `bmad-validate-prd` | Skills/Commands | .claude/skills/ | Deprecated  -  forwards to bmad-prd (validate intent) |
| SKILL-050 | `code-review` | Skills/Commands | .claude/skills/ | Review changes since a fixed point along Standards and Spec axes using parallel sub-agents |
| SKILL-051 | `codebase-design` | Skills/Commands | .claude/skills/ | Shared vocabulary for designing deep modules; interface improvement and seam decisions |
| SKILL-052 | `diagnosing-bugs` | Skills/Commands | .claude/skills/ | Diagnosis loop for hard bugs and performance regressions |
| SKILL-053 | `domain-modeling` | Skills/Commands | .claude/skills/ | Build and sharpen project domain model; ubiquitous language and ADR recording |
| SKILL-054 | `grill-me` | Skills/Commands | .claude/skills/ | Grill the user about a plan, decision, or idea; stress-test thinking |
| SKILL-055 | `grilling` | Skills/Commands | .claude/skills/ | Relentlessly grill a plan or idea using adversarial questioning |
| SKILL-056 | `handoff` | Skills/Commands | .claude/skills/ | Handoff skill for transferring context between sessions or agents |
| SKILL-057 | `implement` | Skills/Commands | .claude/skills/ | Implementation skill for executing a defined change |
| SKILL-058 | `improve-codebase-architecture` | Skills/Commands | .claude/skills/ | Identify and implement codebase architecture improvements |
| SKILL-059 | `loop-me` | Skills/Commands | .claude/skills/ | Iterative loop skill for repeated execution of a task |
| SKILL-060 | `tdd` | Skills/Commands | .claude/skills/ | Test-driven development: red-green-refactor cycle with integration tests |
| SKILL-061 | `to-spec` | Skills/Commands | .claude/skills/ | Convert intent or description into a formal specification |
| SKILL-062 | `to-tickets` | Skills/Commands | .claude/skills/ | Convert spec or requirements into actionable tickets |
| SKILL-063 | `triage` | Skills/Commands | .claude/skills/ | Triage issues, findings, or bugs by severity and priority |
| SKILL-064 | `wayfinder` | Skills/Commands | .claude/skills/ | Navigation aid to find the right skill or workflow for a given need |
| SKILL-065 | `writing-beats` | Skills/Commands | .claude/skills/ | Writing skill focused on narrative beats and story structure |
| SKILL-066 | `writing-for-agents` | Skills/Commands | .claude/skills/ | Writing documents for agents: skills, AGENTS.md, CLAUDE.md |
| SKILL-067 | `writing-fragments` | Skills/Commands | .claude/skills/ | Writing skill for composing document fragments and sections |
| SKILL-068 | `writing-shape` | Skills/Commands | .claude/skills/ | Writing skill for shaping and restructuring document content |
| AGENT-001 | Mary  -  Business Analyst | Agent-Roles | _bmad/config.toml; reference/agents.md | Channels Porter's strategic rigor and Minto's Pyramid Principle; menu triggers: BP, MR, DR, TR, CB, WB, PC |
| AGENT-002 | John  -  Product Manager | Agent-Roles | _bmad/config.toml; reference/agents.md | Drives Jobs-to-be-Done; menu triggers: PRD, CE, IR, CC |
| AGENT-003 | Sally  -  UX Designer | Agent-Roles | _bmad/config.toml; reference/agents.md | Balances empathy with edge-case rigor; menu trigger: CU |
| AGENT-004 | Winston  -  System Architect | Agent-Roles | _bmad/config.toml; reference/agents.md | Favors boring technology for stability; menu triggers: CA, IR |
| AGENT-005 | Amelia  -  Senior Software Engineer | Agent-Roles | _bmad/config.toml; reference/agents.md | Test-first discipline; menu triggers: BD, QA, CR, SP, ER |
| AGENT-006 | Paige  -  Technical Writer (on hiatus) | Agent-Roles | reference/agents.md; explanation/named-agents.md | Technical writer on hiatus; project context still covered via PC trigger on Analyst |
| AGENT-007 | Agent activation 8-step flow | Agent-Roles | explanation/named-agents.md (Activation Flow) | Resolve block -> prepend steps -> adopt persona -> load facts -> load config -> greet -> append steps -> dispatch/menu |
| AGENT-008 | Fictional / custom agent in roster | Agent-Roles | how-to/customize-bmad.md; how-to/expand-bmad-for-your-org.md | Add any persona descriptor to central config for use in party-mode without a skill folder |
| AGENT-009 | TEA module  -  Murat agent | Agent-Roles | reference/modules.md; reference/testing.md | Master Test Architect and Quality Advisor; ships with nine TEA workflows |
| AGENT-010 | CIS module agents | Agent-Roles | reference/modules.md | Innovation Strategist, Design Thinking Coach, Brainstorming Coach, Problem Solver agents |
| WF-001 | Phase 1 Analysis  -  Brainstorming | Workflows | reference/workflow-map.md; explanation/brainstorming.md | Guided creative session; produces brainstorm.html keepsake and optional brainstorm-intent.md |
| WF-002 | Phase 1 Analysis  -  Deep Recon (draft mode) | Workflows | explanation/deep-recon.md | Compose a research prompt for the user's own deep-research tool (ChatGPT, Gemini, Grok, Perplexity) |
| WF-003 | Phase 1 Analysis  -  Deep Recon (process mode) | Workflows | explanation/deep-recon.md | Process a finished report into cited summary with metadata for downstream skill consumption |
| WF-004 | Phase 1 Analysis  -  Deep Recon (run mode) | Workflows | explanation/deep-recon.md | Run research in-session: plan gate, parallel web fan-out, claim verification, cited synthesis |
| WF-005 | Phase 1 Analysis  -  Product Brief | Workflows | reference/workflow-map.md | Capture strategic vision; produces brief.md + addendum.md |
| WF-006 | Phase 1 Analysis  -  PRFAQ | Workflows | reference/workflow-map.md | Working Backwards press-release-first methodology to stress-test product concept customer-first |
| WF-007 | Phase 1 Analysis  -  Forge Idea | Workflows | explanation/forge-idea.md | Adversarial interrogation of an idea producing forge-report.html and optional forged-idea.md |
| WF-008 | Phase 2 Planning  -  PRD create intent | Workflows | reference/workflow-map.md | Create new PRD via coached discovery; produces prd.md, addendum.md, .memlog.md |
| WF-009 | Phase 2 Planning  -  PRD update intent | Workflows | reference/workflow-map.md | Reconcile existing PRD with a change signal; surfaces conflicts before applying changes |
| WF-010 | Phase 2 Planning  -  PRD validate intent | Workflows | reference/workflow-map.md | Critique PRD against configurable checklist; produces validation-report.html + .md |
| WF-011 | Phase 2 Planning  -  UX design | Workflows | reference/workflow-map.md | Design UX patterns and behavioral specs; produces DESIGN.md + EXPERIENCE.md spine pair |
| WF-012 | Phase 2 Planning  -  Spec | Workflows | reference/workflow-map.md | Distill intent into SPEC.md five-field kernel + companions; only official writer of SPEC.md |
| WF-013 | Phase 3 Solutioning  -  Architecture | Workflows | reference/workflow-map.md | Make technical decisions explicit via ARCHITECTURE-SPINE.md; prevents agent conflicts |
| WF-014 | Phase 3 Solutioning  -  Create Epics and Stories | Workflows | reference/workflow-map.md | Break requirements into epics and user stories; produces epic files with stories |
| WF-015 | Phase 3 Solutioning  -  Sprint Planning (readiness gate) | Workflows | explanation/sprint-planning.md | Gate: PASS/CONCERNS/FAIL verdict on whether plan is implementable without invented decisions |
| WF-016 | Phase 3 Solutioning  -  Sprint Planning (generate tracking) | Workflows | explanation/sprint-planning.md | Generate sprint-status.yaml from epic files using deterministic sprint_plan.py script |
| WF-017 | Phase 3 Solutioning  -  Sprint Planning (status view) | Workflows | explanation/sprint-planning.md | Render counts, risk flags, open action items, and one recommended next action |
| WF-018 | Phase 3 Solutioning  -  Sprint Planning (validate/repair) | Workflows | explanation/sprint-planning.md | Validate structure of sprint-status.yaml; repair broken file via inference + confirmation + script |
| WF-019 | Phase 4 Implementation  -  Build | Workflows | explanation/build.md | Canonical implementation: compress intent, route to path, implement autonomously, review and triage |
| WF-020 | Phase 4 Implementation  -  Build Auto (unattended loop) | Workflows | reference/build-auto.md | Unattended iteration: clarify, create spec, implement, review, write terminal status |
| WF-021 | Phase 4 Implementation  -  Code Review | Workflows | reference/workflow-map.md | Adversarial code review using parallel review layers and structured triage |
| WF-022 | Phase 4 Implementation  -  Correct Course | Workflows | reference/workflow-map.md | Handle significant mid-sprint changes; update plan or re-route stories |
| WF-023 | Phase 4 Implementation  -  Retrospective | Workflows | explanation/retrospective.md | Evidence-based epic review; produces retro document, action items, acceptance verdict |
| WF-024 | Project Context  -  Setup intent | Workflows | how-to/project-context.md | For repo with no instructions worth preserving; discover, verify, write AGENTS.md block |
| WF-025 | Project Context  -  Adopt intent | Workflows | how-to/project-context.md | Absorb existing hand-written instructions with full review before any deletion |
| WF-026 | Project Context  -  Refresh intent | Workflows | how-to/project-context.md | Re-run commands, diff deletions/renames since recorded commit, update moved items |
| WF-027 | Project Context  -  Record intent | Workflows | how-to/project-context.md | Capture one observed agent mistake as a pitfall line at the moment it happens |
| WF-028 | Project Context  -  Audit intent | Workflows | how-to/project-context.md | Re-verify and prune; block ends smaller or equal, never larger |
| WF-029 | Checkpoint Preview | Workflows | explanation/checkpoint-preview.md | Five-step guided review after bmad-build: orientation, walkthrough, detail pass, testing, wrap-up |
| WF-030 | Advanced Elicitation | Workflows | explanation/advanced-elicitation.md | Structured second pass using named method (pre-mortem, first principles, inversion, red team, etc.) |
| WF-031 | Brownfield on-ramp (established projects) | Workflows | how-to/established-projects.md | Clean up planning artifacts, create project context, choose planning depth for existing codebases |
| WF-032 | Quick Fixes workflow | Workflows | how-to/quick-fixes.md | Enter bmad-build directly for bug fixes, refactors, minor tweaks, dependency updates |
| WF-033 | Web bundles session workflow | Workflows | explanation/web-bundles.md; how-to/use-web-bundles.md | Gemini Gem or ChatGPT GPT session: greet, discover scope, draft in Canvas, hand off to IDE |
| WF-034 | Deep Recon  -  Refresh existing report | Workflows | explanation/deep-recon.md | Re-verify only stale claims and append a delta report without re-running full research |
| WF-035 | Deep Recon  -  Deepen one dimension | Workflows | explanation/deep-recon.md | Drill deeper into one research dimension without re-running remaining dimensions |
| WF-036 | Spec  -  Break into stories.yaml | Workflows | reference/workflow-map.md (bmad-spec note) | Break a spec into ordered stories.yaml for autonomous dispatch via build-auto |
| WF-037 | Build Auto  -  Folder+ID dispatch | Workflows | reference/build-auto.md | Dispatch a specific story by spec folder + story ID without passing the full spec file path |
| WF-038 | Build Auto  -  spec resume from status | Workflows | reference/build-auto.md | Resume a spec from known frontmatter status: draft->plan, ready-for-dev->implement, in-review->review |
| WF-039 | bmad-help auto-run at workflow end | Workflows | how-to/established-projects.md | bmad-help automatically runs at the end of every workflow to provide clear next-step guidance |
| WF-040 | Retrospective headless mode | Workflows | explanation/retrospective.md | `-H <epic>` flag for unattended retrospective run producing verdict on evidence alone |
| WF-041 | TEA  -  Test Design workflow | Workflows | reference/testing.md | Create comprehensive test strategy tied to requirements (TEA module) |
| WF-042 | TEA  -  ATDD workflow | Workflows | reference/testing.md | Acceptance-test-driven development with stakeholder criteria (TEA module) |
| WF-043 | TEA  -  Test Review workflow | Workflows | reference/testing.md | Validate test quality and coverage against strategy (TEA module) |
| WF-044 | TEA  -  Traceability workflow | Workflows | reference/testing.md | Map tests back to requirements for audit and compliance (TEA module) |
| WF-045 | TEA  -  Release Gate workflow | Workflows | reference/testing.md | Make data-driven go/no-go release decisions (TEA module) |
| CONF-001 | `_bmad/config.toml` | Configuration | how-to/install-bmad.md; how-to/customize-bmad.md (Central Configuration) | Installer-managed team-scoped install answers and agent roster; regenerated every install |
| CONF-002 | `_bmad/config.user.toml` | Configuration | how-to/customize-bmad.md (Central Configuration) | Installer-managed user-scoped install answers (user_name, language, skill level); regenerated every install |
| CONF-003 | `_bmad/custom/config.toml` | Configuration | how-to/customize-bmad.md (Central Configuration) | Human-authored team overrides; never touched by installer; committed to git |
| CONF-004 | `_bmad/custom/config.user.toml` | Configuration | how-to/customize-bmad.md (Central Configuration) | Human-authored personal overrides; never touched by installer; gitignored |
| CONF-005 | `_bmad/<module>/config.yaml` | Configuration | how-to/install-bmad.md (Module config overrides) | Per-module configuration; holds declared key values that survive subsequent installs |
| CONF-006 | `_bmad/_config/manifest.yaml` | Configuration | how-to/install-bmad.md (What got installed) | Records every installed module: version, channel, sha, source, repoUrl; written after every install |
| CONF-007 | `_bmad/_config/skill-manifest.csv` | Configuration | _bmad/_config/ (observed in repo) | CSV tracking all installed skills and their metadata |
| CONF-008 | `_bmad/_config/files-manifest.csv` | Configuration | _bmad/_config/ (observed in repo) | CSV tracking all installed files for update/cleanup operations |
| CONF-009 | `_bmad/_config/bmad-help.csv` | Configuration | _bmad/_config/ (observed in repo) | CSV used by bmad-help to enumerate available skills and their descriptions |
| CONF-010 | `_bmad/scripts/resolve_customization.py` | Configuration | how-to/customize-bmad.md (How Resolution Works) | Python stdlib-only script that merges three-layer customize.toml overrides; invoked with `uv run` |
| CONF-011 | `_bmad/scripts/resolve_config.py` | Configuration | _bmad/scripts/ (observed in repo) | Python script for resolving central configuration across four-layer merge |
| CONF-012 | `_bmad/scripts/config_utils.py` | Configuration | _bmad/scripts/ (observed in repo) | Shared configuration utility functions used by resolver scripts |
| CONF-013 | `_bmad/scripts/memlog.py` | Configuration | _bmad/scripts/ (observed in repo) | Script managing .memlog.md session records for workflows |
| CONF-014 | `_bmad/scripts/render_skill.py` | Configuration | _bmad/scripts/ (observed in repo) | Script for rendering skill files from templates during install |
| CONF-015 | `_bmad/core/config.yaml` | Configuration | _bmad/core/ (observed in repo) | Core module configuration with project_name, user_name, languages, output_folder |
| CONF-016 | `_bmad/bmm/config.yaml` | Configuration | _bmad/bmm/config.yaml (read in task) | BMM module config with user_skill_level, artifact paths, project_knowledge path |
| CONF-017 | `_bmad/core/module-help.csv` | Configuration | _bmad/core/ (observed in repo) | CSV of core module help text consumed by bmad-help |
| CONF-018 | `_bmad/bmm/module-help.csv` | Configuration | _bmad/bmm/ (observed in repo) | CSV of BMM module help text consumed by bmad-help |
| CONF-019 | `uv` requirement for resolver scripts | Configuration | how-to/customize-bmad.md (Prerequisites) | `uv` must be on PATH; provisions Python >=3.11 automatically; no pip install needed |
| CONF-020 | `core.project_name` setting | Configuration | _bmad/config.toml | Project name used by agents and workflows for personalized output |
| CONF-021 | `core.document_output_language` setting | Configuration | _bmad/config.toml | Language for document output (e.g., English); set via installer or `--set` flag |
| CONF-022 | `core.output_folder` setting | Configuration | _bmad/config.toml | Root folder for all BMad output artifacts; defaults to `_bmad-output` |
| CONF-023 | `core.user_name` setting | Configuration | _bmad/config.user.toml | Personal user name used by agents for greeting; user-scoped |
| CONF-024 | `core.communication_language` setting | Configuration | _bmad/config.user.toml | Language for agent communication; user-scoped; set via installer or `--set` flag |
| CONF-025 | `modules.bmm.user_skill_level` setting | Configuration | _bmad/bmm/config.yaml | User skill level (beginner/intermediate/expert); affects workflow verbosity |
| CONF-026 | `modules.bmm.planning_artifacts` path | Configuration | _bmad/config.toml; _bmad/bmm/config.yaml | Directory for planning artifacts (briefs, PRDs, architecture); supports `{project-root}` token |
| CONF-027 | `modules.bmm.implementation_artifacts` path | Configuration | _bmad/config.toml; _bmad/bmm/config.yaml | Directory for implementation artifacts (specs, sprint tracking); supports `{project-root}` token |
| CONF-028 | `modules.bmm.project_knowledge` path | Configuration | _bmad/config.toml; _bmad/bmm/config.yaml | Directory for project knowledge docs read by agents; defaults to `{project-root}/docs` |
| CONF-029 | `sprint_plan.py` deterministic script | Configuration | explanation/sprint-planning.md | Script inside bmad-sprint-planning that deterministically parses epics and manages sprint-status.yaml |
| CUST-001 | Three-layer per-skill override model | Customization | how-to/customize-bmad.md (Three-Layer Override Model) | Priority: `{skill}.user.toml` > `{skill}.toml` > `customize.toml`; sparse overrides only |
| CUST-002 | `_bmad/custom/{skill-name}.toml` team override | Customization | how-to/customize-bmad.md | Team/org override file; committed to git; applies to all developers |
| CUST-003 | `_bmad/custom/{skill-name}.user.toml` personal override | Customization | how-to/customize-bmad.md | Personal override file; gitignored; personal preferences layered on top of team override |
| CUST-004 | `customize.toml` defaults file per skill | Customization | how-to/customize-bmad.md | Skill's canonical customization surface; read-only defaults; never edit directly |
| CUST-005 | Four-layer central config merge | Customization | how-to/customize-bmad.md (Four-Layer Merge) | Priority: `custom/config.user.toml` > `custom/config.toml` > `config.user.toml` > `config.toml` |
| CUST-006 | Scalar override merge rule | Customization | how-to/customize-bmad.md (Merge Rules) | Scalar (string/int/bool/float) values: override wins; replaces base value entirely |
| CUST-007 | Table deep-merge rule | Customization | how-to/customize-bmad.md (Merge Rules) | Tables deep-merge recursively applying all four structural rules |
| CUST-008 | Keyed array-of-tables merge rule | Customization | how-to/customize-bmad.md (Merge Rules) | Arrays of tables with uniform `code` or `id` key: merge by key; matching keys replace in place, new keys append |
| CUST-009 | Append-only array merge rule | Customization | how-to/customize-bmad.md (Merge Rules) | Other arrays (scalar arrays, no-identifier tables): base items first then team then user |
| CUST-010 | No removal mechanism in overrides | Customization | how-to/customize-bmad.md (Merge Rules) | Overrides cannot delete base items; suppress by overriding with no-op or fork the skill |
| CUST-011 | `agent.persistent_facts` customization field | Customization | how-to/customize-bmad.md (Customize What You Need) | Static facts kept in agent context the whole session; append array; supports `file:` references |
| CUST-012 | `agent.principles` customization field | Customization | how-to/customize-bmad.md | Agent value system additions; append array; team items after defaults, user items last |
| CUST-013 | `agent.activation_steps_prepend` field | Customization | how-to/customize-bmad.md | Steps running BEFORE standard activation (before persona, facts, config, greet) |
| CUST-014 | `agent.activation_steps_append` field | Customization | how-to/customize-bmad.md | Steps running AFTER greet and BEFORE menu; for heavy setup that runs after user is acknowledged |
| CUST-015 | `agent.menu` customization (merge by `code`) | Customization | how-to/customize-bmad.md (Menu customization) | Override menu items by `code` key; each item has `skill` or `prompt`; new codes append |
| CUST-016 | `agent.name` and `agent.title` read-only fields | Customization | how-to/customize-bmad.md (Read-only fields) | Hardcoded identity; overrides have no effect; fork the skill to create a differently named agent |
| CUST-017 | `agent.icon` customization field | Customization | how-to/customize-bmad.md | Emoji icon for agent; scalar override wins |
| CUST-018 | `agent.role` customization field | Customization | how-to/customize-bmad.md | Agent's domain role description; scalar override wins |
| CUST-019 | `agent.communication_style` customization field | Customization | how-to/customize-bmad.md | Agent communication style; scalar override wins |
| CUST-020 | `workflow.persistent_facts` customization field | Customization | how-to/customize-bmad.md (Workflow Customization) | Foundational context loaded for duration of workflow run; append array; supports `file:` refs |
| CUST-021 | `workflow.on_complete` customization field | Customization | how-to/customize-bmad.md (Workflow Customization) | Terminal hook running once after workflow main output is written; scalar override wins |
| CUST-022 | `workflow.activation_steps_prepend` field | Customization | how-to/customize-bmad.md (Workflow Customization) | Workflow steps running before activation (before greeting); append array |
| CUST-023 | `workflow.activation_steps_append` field | Customization | how-to/customize-bmad.md (Workflow Customization) | Workflow steps running after greeting; for heavy setup visible after user acknowledged |
| CUST-024 | `workflow.external_sources` field | Customization | how-to/expand-bmad-for-your-org.md (Recipe 6) | On-demand knowledge sources consulted when conversation surfaces matching need; append array |
| CUST-025 | `workflow.external_handoffs` field | Customization | how-to/expand-bmad-for-your-org.md (Recipe 6) | Route completed artifacts to external systems after finalize; append array with graceful degradation |
| CUST-026 | `workflow.doc_standards` field | Customization | how-to/expand-bmad-for-your-org.md (Recipe 6) | Apply org writing standards at finalize; skill/file/plain-text directives; runs as parallel subagents |
| CUST-027 | Template/checklist path overrides | Customization | how-to/expand-bmad-for-your-org.md (Recipe 4) | Scalar overrides pointing workflow at org-owned templates under `{project-root}` |
| CUST-028 | `file:` reference in persistent_facts | Customization | how-to/customize-bmad.md | Load file contents as facts via `file:{project-root}/path/to/file.md` in facts arrays |
| CUST-029 | `{project-root}` token in override files | Customization | how-to/customize-bmad.md | Runtime-resolved token for project root path; use in all file references inside override TOML |
| CUST-030 | Rebrand agent in central config (Recipe 5a) | Customization | how-to/expand-bmad-for-your-org.md | Override `[agents.<code>]` descriptor in `_bmad/custom/config.toml` to shift voice org-wide |
| CUST-031 | Add fictional/custom agent to roster (Recipe 5b) | Customization | how-to/expand-bmad-for-your-org.md | Add `[agents.<code>]` with name/title/icon/description/team; no skill folder needed |
| CUST-032 | Pin team install settings via central config (Recipe 5c) | Customization | how-to/expand-bmad-for-your-org.md | Override `[modules.<code>]` or `[core]` in team config to enforce shared paths org-wide |
| CUST-033 | Workflow activation order (6-step sequence) | Customization | how-to/customize-bmad.md (Activation Order) | Fixed sequence: resolve block -> prepend -> load facts -> load config -> greet -> append |
| CUST-034 | `bmad-customize` skill as guided authoring helper | Customization | reference/core-tools.md; how-to/customize-bmad.md | Scans customizable skills, picks right surface, writes override file, verifies merge |
| CUST-035 | IDE session file reinforcement pattern | Customization | how-to/expand-bmad-for-your-org.md (Reinforce Global Rules) | Restate critical BMad rules in CLAUDE.md/AGENTS.md so they apply outside BMad skill sessions |
| CUST-036 | `resolve_customization.py` CLI invocation | Customization | how-to/customize-bmad.md (How Resolution Works) | `uv run _bmad/scripts/resolve_customization.py --skill <path> --key agent` returns JSON |
| VER-001 | Stable channel | Verification/Quality | how-to/install-bmad.md (Axis 1) | Highest released semver tag; prereleases excluded; default for most users |
| VER-002 | Next channel | Verification/Quality | how-to/install-bmad.md (Axis 1) | Main branch HEAD at install time; for contributors and early adopters |
| VER-003 | Pinned channel | Verification/Quality | how-to/install-bmad.md (Axis 1) | Specific tag named by user; for enterprise installs and CI reproducibility |
| VER-004 | Sprint Planning readiness gate verdicts | Verification/Quality | explanation/sprint-planning.md | PASS / CONCERNS / FAIL verdict on implementation readiness; FAIL stops workflow with ordered findings |
| VER-005 | bmad-review adversarial lens | Verification/Quality | reference/core-tools.md | Forced-finding review (>=10 issues); looks for what's missing, not only what's wrong |
| VER-006 | bmad-review edge-case lens | Verification/Quality | reference/core-tools.md | Walks every branching path and boundary condition in behavior-defining content |
| VER-007 | bmad-review verification-gap lens | Verification/Quality | reference/core-tools.md | Finds changed behavior that could regress without reliable verification catching it |
| VER-008 | bmad-review structure lens | Verification/Quality | reference/core-tools.md | Proposes cuts, merges, moves for documents; does shape serve purpose? |
| VER-009 | bmad-review prose lens | Verification/Quality | reference/core-tools.md | Copy-edits for communication issues that impede comprehension |
| VER-010 | Build intent compression and spec approval | Verification/Quality | explanation/build.md | Human-in-loop at intent clarification, spec approval, and final review; other steps autonomous |
| VER-011 | Build deferred-work.md | Verification/Quality | how-to/quick-fixes.md | Pre-existing issues unrelated to current change deferred to file rather than handled inline |
| VER-012 | Retrospective acceptance verdict | Verification/Quality | explanation/retrospective.md | accepted / accepted-with-open-items / rejected; unfinished stories force machine verdict to rejected |
| VER-013 | Spec preservation validation | Verification/Quality | reference/workflow-map.md (bmad-spec note) | bmad-spec validates that every load-bearing source claim is preserved in the machine contract |
| VER-014 | Build Auto spec status machine | Verification/Quality | reference/build-auto.md | Spec frontmatter status drives orchestration: draft/ready-for-dev/in-progress/in-review/done/blocked |
| VER-015 | Build Auto blocking conditions | Verification/Quality | reference/build-auto.md | 13 named blocking conditions including unclear intent, no subagents, non-convergence after 5 iterations |
| VER-016 | PRD validation report | Verification/Quality | reference/workflow-map.md | bmad-prd validate intent produces validation-report.html + .md against configurable checklist |
| VER-017 | sprint-status.yaml `--dry-run` drift report | Verification/Quality | explanation/sprint-planning.md | Reports in_sync, new entries, orphans with old statuses, illegal values without writing |
| VER-018 | `bmad-checkpoint-preview` detail pass risk tags | Verification/Quality | explanation/checkpoint-preview.md | 2-5 highest blast-radius spots tagged [auth], [schema], [billing], [public API], [security] |
| VER-019 | Deep Recon claim verification levels | Verification/Quality | explanation/deep-recon.md | normal (spot-check load-bearing claims) / high (cross-check critical classes + red-team) / max (check all) |
| VER-020 | Deep Recon research firewall | Verification/Quality | explanation/deep-recon.md | Research assistants receive only their assignment; project files shape questions, never findings |
| VER-021 | AGENTS.md bmad:context markers | Verification/Quality | explanation/project-context.md | BMad owns only region between `<!-- bmad:context -->` markers; everything outside preserved byte-for-byte |
| ARCH-001 | `_bmad-output/` directory structure | Architecture/Artifacts | how-to/install-bmad.md; _bmad/config.toml | Root output folder for all generated artifacts; configurable via `output_folder` setting |
| ARCH-002 | `_bmad-output/planning-artifacts/` | Architecture/Artifacts | _bmad/config.toml; how-to/established-projects.md | Directory for briefs, PRDs, architecture, epic files, and research reports |
| ARCH-003 | `_bmad-output/implementation-artifacts/` | Architecture/Artifacts | _bmad/config.toml | Directory for spec files, sprint-status.yaml, epic context files, test summaries |
| ARCH-004 | `manifest.yaml` artifact | Architecture/Artifacts | how-to/install-bmad.md (What got installed) | Records all installed modules with version, channel, sha, source, repoUrl |
| ARCH-005 | `sprint-status.yaml` artifact | Architecture/Artifacts | explanation/sprint-planning.md | Single tracking file for dev cycle; holds story statuses, action items, project key |
| ARCH-006 | `spec-<slug>.md` artifact | Architecture/Artifacts | reference/build-auto.md | Build's execution contract: intent, code map, tasks/AC, spec change log, review triage log |
| ARCH-007 | `SPEC.md` artifact | Architecture/Artifacts | reference/workflow-map.md | Five-field kernel (Why/Capabilities/Constraints/Non-goals/Success signal) + companions |
| ARCH-008 | `stories.yaml` artifact | Architecture/Artifacts | reference/workflow-map.md; reference/build-auto.md | Ordered story list for autonomous dispatch by bmad-build-auto |
| ARCH-009 | `prd.md` + `addendum.md` artifacts | Architecture/Artifacts | reference/workflow-map.md | PRD output files; addendum captures supplemental decisions and clarifications |
| ARCH-010 | `DESIGN.md` + `EXPERIENCE.md` artifacts | Architecture/Artifacts | reference/workflow-map.md | UX spine pair: visual design doc and behavioral experience doc |
| ARCH-011 | `ARCHITECTURE-SPINE.md` artifact | Architecture/Artifacts | reference/workflow-map.md | Architecture spine of invariants; default output of bmad-architecture workflow |
| ARCH-012 | `brief.md` artifact | Architecture/Artifacts | reference/workflow-map.md | Product brief 1-2 page executive summary |
| ARCH-013 | `prfaq-{project}.md` artifact | Architecture/Artifacts | reference/workflow-map.md | Working Backwards PRFAQ document |
| ARCH-014 | `forge-report.html` artifact | Architecture/Artifacts | explanation/forge-idea.md; how-to/pressure-test-an-idea.md | Self-contained HTML session report from bmad-forge-idea; produced every run |
| ARCH-015 | `forged-idea.md` artifact | Architecture/Artifacts | explanation/forge-idea.md | Locked decisions and killed branches when idea survives forge; feeds spec/prd/prfaq |
| ARCH-016 | `brainstorm.html` artifact | Architecture/Artifacts | reference/core-tools.md; reference/workflow-map.md | Self-contained HTML keepsake of brainstorming session |
| ARCH-017 | `brainstorm-intent.md` artifact | Architecture/Artifacts | reference/core-tools.md | Optional downstream-consumable intent file from brainstorming session |
| ARCH-018 | `research.md` artifact | Architecture/Artifacts | explanation/deep-recon.md | Cited research report with metadata frontmatter; consumed directly by downstream skills |
| ARCH-019 | `validation-report.html` + `.md` artifact | Architecture/Artifacts | reference/workflow-map.md | PRD validation findings report with structured HTML output |
| ARCH-020 | `deferred-work.md` artifact | Architecture/Artifacts | how-to/quick-fixes.md | Backlog of pre-existing issues deferred by bmad-build; one item per deferred finding |
| ARCH-021 | `epic-<N>-context.md` artifact | Architecture/Artifacts | reference/build-auto.md | Cached epic context file produced by bmad-build-auto for epic-based work |
| ARCH-022 | `bmad-build-auto-result-<slug>.md` fallback artifact | Architecture/Artifacts | reference/build-auto.md | Fallback result file when build-auto halts before creating a valid spec file |
| ARCH-023 | `.memlog.md` artifact | Architecture/Artifacts | reference/workflow-map.md; _bmad/scripts/memlog.py | Session memory log written by workflows; managed by memlog.py script |
| ARCH-024 | Skill directory structure (`SKILL.md`) | Architecture/Artifacts | reference/commands.md | Each skill is a directory with SKILL.md; directory name determines invocation name in IDE |
| ARCH-025 | `module-help.csv` per module | Architecture/Artifacts | _bmad/core/, _bmad/bmm/ (observed) | Per-module CSV consumed by bmad-help to enumerate capabilities |
| ARCH-026 | `v6-shims/README.md` | Architecture/Artifacts | _bmad/core/v6-shims/, _bmad/bmm/v6-shims/ (observed) | Shim documentation explaining what each deprecated skill forwards to |
| ARCH-027 | IDE skill directory locations | Architecture/Artifacts | reference/commands.md (Where Skill Files Live) | Claude Code: `.claude/skills/`; Cursor/Windsurf: `.agents/skills/` |
| ARCH-028 | Party Mode session keepsake HTML | Architecture/Artifacts | explanation/party-mode.md | Self-contained HTML document of party session laid out by persona |
| ARCH-029 | Build Auto `deferred` frontmatter entries | Architecture/Artifacts | reference/build-auto.md | Machine-readable review findings triaged as defer; each has summary/evidence/location/severity |
| ARCH-030 | Build Auto `baseline_revision` frontmatter | Architecture/Artifacts | reference/build-auto.md | Full canonical revision before implementation; `NO_VCS` when no version control present |
| ARCH-031 | Web bundle ZIP structure | Architecture/Artifacts | explanation/web-bundles.md | Bundle contains SKILL.md (knowledge file), INSTRUCTIONS.md (paste block), and data files |
| ARCH-032 | `_bmad/render/` directory | Architecture/Artifacts | _bmad/render/ (observed in repo) | Render cache/output directory used by render_skill.py during install |
| TRBL-001 | "Could not resolve stable tag" / API rate limit | Troubleshooting | how-to/install-bmad.md (Troubleshooting) | Set GITHUB_TOKEN env var and retry; 60/hr anonymous limit exhausted |
| TRBL-002 | "Tag 'vX.Y.Z' not found" error | Troubleshooting | how-to/install-bmad.md (Troubleshooting) | Tag passed to `--pin` doesn't exist; check repo's releases page for valid tags |
| TRBL-003 | Pinned install keeps upgrading | Troubleshooting | how-to/install-bmad.md (Troubleshooting) | Check manifest.yaml; pinned channel plus fixed version and sha should hold across runs |
| TRBL-004 | `--pin bmm=X` silently ignored | Troubleshooting | how-to/install-bmad.md (Troubleshooting) | bmm is bundled; use `npx bmad-method@next` for prerelease or local checkout |
| TRBL-005 | Customization not appearing | Troubleshooting | how-to/customize-bmad.md (Troubleshooting) | Verify file in `_bmad/custom/` with correct skill name; check TOML syntax; confirm section header |
| TRBL-006 | Updates broke customization | Troubleshooting | how-to/customize-bmad.md (Troubleshooting) | Full `customize.toml` copy in override file locks in old defaults; trim to deltas only |
| TRBL-007 | Skills not appearing after install | Troubleshooting | reference/commands.md (Troubleshooting) | Some platforms require explicit skill enabling in settings; restart IDE or reload window |
| TRBL-008 | Expected skills are missing | Troubleshooting | reference/commands.md (Troubleshooting) | Installer only generates skills for selected modules; re-run installer and verify module selection |
| TRBL-009 | Stale skills from removed module | Troubleshooting | reference/commands.md (Troubleshooting) | Installer doesn't auto-delete old skills; manually remove stale directories or delete and reinstall |
| TRBL-010 | Build Auto `blocked` on `no subagents` | Troubleshooting | reference/build-auto.md (Blocking conditions) | Platform must support subagents; workflow halts with `blocked` if unavailable |
| TRBL-011 | Build Auto `intent gap` mid-review | Troubleshooting | reference/build-auto.md (On `blocked`) | Working tree reverted; attempted change saved as patch in implementation_artifacts for diagnosis |
| TRBL-012 | Sprint status script failure fallback | Troubleshooting | explanation/sprint-planning.md | If hand-edited file defeats script, skill reads directly and gives best-judgment summary |
| TRBL-013 | MCP tool name unknown in override | Troubleshooting | how-to/expand-bmad-for-your-org.md (Troubleshooting) | Use exact name MCP server exposes; ask Claude Code to list available MCP tools |
| TRBL-014 | Web bundle persona drift | Troubleshooting | how-to/use-web-bundles.md | Web LLMs may drop persona in long sessions; remind it of persona or start fresh session |
| TRBL-015 | `agent.name`/`agent.title` override has no effect | Troubleshooting | how-to/customize-bmad.md (Read-only fields) | These fields are hardcoded identity; fork the skill to create a differently named agent |
| TRBL-016 | v4 legacy `.bmad-method` folder detected | Troubleshooting | how-to/upgrade-to-v6.md | Installer offers backup/removal; non-standard folder names must be removed manually |
| TRBL-017 | Sprint status `blocked spec supplied` vs `story already blocked` | Troubleshooting | reference/build-auto.md | Distinction: direct blocked spec vs folder+id dispatch finding blocked story file |

---

## Coverage Summary

| Category | Count |
|---|---|
| Installation | 32 |
| Modules | 7 |
| Skills/Commands | 68 |
| Agent-Roles | 10 |
| Workflows | 45 |
| Configuration | 29 |
| Customization | 36 |
| Verification/Quality | 21 |
| Architecture/Artifacts | 32 |
| Troubleshooting | 17 |
| **Total** | **297** |

### Notes on Coverage

- All 68 skills enumerated from `/home/vercel-sandbox/Daily-Motivation-Brain-Helper/.claude/skills/` directory listing are represented in Skills/Commands rows SKILL-001 through SKILL-068.
- All CLI flags documented in `how-to/install-bmad.md` Flag reference table are covered in INST-001 through INST-021 plus INST-022–INST-032.
- All five named agent roles (Mary/analyst, John/pm, Sally/ux-designer, Winston/architect, Amelia/dev) appear in AGENT-001 through AGENT-005.
- All four workflow phases (Analysis, Planning, Solutioning, Implementation) are covered in WF-001 through WF-045.
- All customization surfaces documented in `how-to/customize-bmad.md` and `how-to/expand-bmad-for-your-org.md` are covered in CUST-001 through CUST-036.
- All configuration files observed in the repo plus documented in llms-full.txt are covered in CONF-001 through CONF-029.
- Installed version: BMAD 6.11.0; installed modules: core, bmm; IDE: claude-code.
