# BMAD Method v6.11.0 -- Developer Reference Guide
## Repository: Daily-Motivation-Brain-Helper | Branch: SevAI_installing_bmad

> **Ledger SSOT:** `manual/guides/bmad/_ledger/bmad-feature-ledger.md` (297 rows)
> All configuration paths are relative to the repo root unless noted otherwise.

---

## 1. Installation and Prerequisites

### 1.1 Prerequisites

| Requirement | Minimum | Notes |
|---|---|---|
| Node.js | 20.12+ | Installer is an npm package; v24.14.1 confirmed in this repo |
| Git | Any recent | Required for external module cloning |
| uv | 0.12.5+ | Runs Python resolver scripts (`uv run`); required for agent activation and `bmad-build`/`bmad-build-auto` |
| AI tool | Claude Code (installed here) | Other supported tools: Cursor, Windsurf -- see `--list-tools` |
| Python | 3.11+ via uv | uv provisions its own interpreter; system Python irrelevant |

Install uv if absent:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# or: brew install uv
```

Verify: `uv --version`

### 1.2 Install Command

```bash
npx bmad-method install --yes --directory . --modules bmm --tools claude-code
```

This repository was installed with `bmad-method@6.11.0`, `bmm` module, targeting `claude-code`. Confirmed in `_bmad/_config/manifest.yaml`.

### 1.3 Installer CLI -- Complete Flag Reference

| Flag | Type | Default | Description |
|---|---|---|---|
| `--yes`, `-y` | bool | false | Skip all prompts; accept flag values + defaults |
| `--directory <path>` | string | cwd | Target installation directory |
| `--modules <a,b,c>` | csv | interactive | Exact module set. Core always auto-added. Not a delta -- list all desired modules. |
| `--tools <a,b>` | csv | interactive | IDE/tool IDs. Run `--list-tools` for valid IDs. |
| `--list-tools` | bool | -- | Print all supported tool IDs with target directories, then exit |
| `--action <type>` | enum | auto-detect | `install`, `update`, `quick-update` |
| `--custom-source <urls>` | csv | -- | Git URLs or local paths for custom/community modules |
| `--shims` | bool | -- | Install deprecated v6 compatibility shim skills |
| `--no-shims` | bool | -- | Explicitly omit shim skills; removes them on update |
| `--channel <stable\|next>` | enum | stable | Apply channel to all external modules |
| `--all-stable` | bool | -- | Alias for `--channel=stable` |
| `--all-next` | bool | -- | Alias for `--channel=next` |
| `--next=<code>` | string | -- | Put one external module on `next` channel. Repeatable. |
| `--pin <code>=<tag>` | string | -- | Pin one external module to a specific Git tag. Repeatable. |
| `--set <module>.<key>=<value>` | string | -- | Set any module config option non-interactively. Repeatable. Post-install patch. |
| `--list-options [module]` | string | -- | Print all `--set` keys for built-in and cached modules |
| `--user-name` | string | -- | Legacy shortcut for `--set core.user_name=<value>` |
| `--communication-language` | string | -- | Legacy shortcut for `--set core.communication_language=<value>` |
| `--document-output-language` | string | -- | Legacy shortcut for `--set core.document_output_language=<value>` |
| `--output-folder` | string | -- | Legacy shortcut for `--set core.output_folder=<value>` |

Flag precedence for channel conflicts: `--pin` beats `--next=` beats `--channel`/`--all-*` beats registry default (`stable`).

### 1.4 Update Operations

When `_bmad/` already exists, `npx bmad-method install` presents:

| Action | Behavior |
|---|---|
| Quick Update | Re-runs install with existing settings. Applies patch/minor stable upgrades; refuses major upgrades. Fast, non-interactive. |
| Modify Install | Full interactive flow. Add/remove modules, reconfigure, switch channels. |

Major version upgrades default to `N`; pass `--pin <code>=<new-tag>` to accept non-interactively.

### 1.5 Version Channels

External modules (bmb, cis, gds, tea) use independent channels:

| Channel | Installed version | Use case |
|---|---|---|
| `stable` (default) | Highest released semver tag at install time | Production |
| `next` | Main branch HEAD at install time | Early adopters, contributors |
| `pinned` | Specific named tag | Enterprise reproducibility, CI |

`core` and `bmm` are **bundled inside the installer binary** -- `--pin bmm=<tag>` and `--next=bmm` are silently no-ops. Use `npx bmad-method@next install` for prerelease core/bmm.

### 1.6 GitHub Token (Rate Limiting)

The installer resolves stable tags via GitHub API (60 req/hr anonymous). Set `GITHUB_TOKEN=<PAT>` to raise to 5000/hr. Any public-repo-read PAT works; no additional scopes required.

---

## 2. Repository Layout (Post-Install)

```
Daily-Motivation-Brain-Helper/
├── _bmad/                          # BMAD framework root
│   ├── _config/
│   │   ├── manifest.yaml           # What is installed (versions, channels, SHAs)
│   │   ├── files-manifest.csv
│   │   ├── skill-manifest.csv
│   │   └── bmad-help.csv
│   ├── core/                       # Bundled core module
│   │   ├── config.yaml
│   │   ├── module-help.csv
│   │   └── v6-shims/README.md
│   ├── bmm/                        # BMad Method module (bundled)
│   │   ├── config.yaml             # Module config (version, settings)
│   │   ├── module-help.csv
│   │   └── v6-shims/README.md
│   ├── config.toml                 # Installer-managed; team scope
│   ├── config.user.toml            # Installer-managed; user scope
│   ├── custom/                     # Human-authored overrides (never touched by installer)
│   │   ├── .gitignore              # gitignores *.user.toml
│   │   ├── config.toml             # Team central-config overrides (committed)
│   │   └── config.user.toml        # Personal central-config overrides (gitignored)
│   ├── render/
│   │   └── .gitignore
│   └── scripts/
│       ├── config_utils.py
│       ├── memlog.py
│       ├── render_skill.py
│       ├── resolve_config.py
│       └── resolve_customization.py  # Three-layer TOML merger (stdlib tomllib)
├── _bmad-output/                   # All generated artifacts (gitignored by default)
│   ├── planning-artifacts/         # PRDs, specs, epics, briefs, UX, architecture
│   └── implementation-artifacts/  # Spec files, story files, build outputs
├── .claude/
│   ├── agents/                     # Custom agent definitions for this repo
│   ├── rules/                      # Auto-loading rule files
│   └── skills/                     # 68 installed BMAD skills (one dir per skill)
│       ├── bmad-help/SKILL.md
│       ├── bmad-agent-dev/
│       │   ├── SKILL.md
│       │   └── customize.toml
│       └── ...
└── docs/                           # project_knowledge source (read by bmad-help)
```

Key config values from `_bmad/config.toml`:

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

---

## 3. Module System

### 3.1 Bundled Modules (core, bmm)

Installed at: `_bmad/core/` and `_bmad/bmm/`

- **core**: Universal framework. Ships eight kernel skills: `bmad-help`, `bmad-advanced-elicitation`, `bmad-review`, `bmad-customize`, `bmad-brainstorming`, `bmad-deep-recon`, `bmad-forge-idea`, `bmad-party-mode`. Present in every BMAD installation.
- **bmm** (BMad Method): Agile-suite module. Ships the five named agents (Analyst, PM, UX, Architect, Dev), all planning/implementation workflows, sprint tracking, and test generation. Version tied to installer binary.

### 3.2 External Modules

Not installed in this repo. Available via `npx bmad-method install --action update --modules bmm,<code>`:

| Module | Code | Description |
|---|---|---|
| BMad Builder | `bmb` | Meta-module: creates custom agents, workflows, modules |
| Creative Intelligence Suite | `cis` | Innovation strategist, design thinking coach, SCAMPER, etc. |
| Game Dev Studio | `gds` | Unity/Unreal/Godot workflows, GDD generation, narrative design |
| Test Architect (TEA) | `tea` | Enterprise test strategy: Murat agent, 9 workflows, P0-P3 risk |

### 3.3 Community and Custom Modules

Install via `--custom-source <git-url-or-local-path>`. The installer uses two discovery modes:

- **Discovery mode**: Source contains `.claude-plugin/marketplace.json` -- lists all plugins for selection.
- **Direct mode**: No marketplace.json -- scans for SKILL.md subdirs, treats as single module.

### 3.4 Manifest

`_bmad/_config/manifest.yaml` records the installed state:

```yaml
modules:
  - name: core
    version: v6.11.0
    channel: stable
    source: built-in
  - name: bmm
    version: v6.11.0
    channel: stable
    source: built-in
```

For reproducible cross-machine installs of external modules, extract tags from `manifest.yaml` into `--pin` flags.

---

## 4. Skills Catalog

### 4.1 Skill Invocation

In Claude Code, type the skill name (or `/skill-name`) in any conversation. Skills are directory-based -- the directory name under `.claude/skills/` is the invocable name.

### 4.2 Skill File Structure

Each skill directory contains:

```
.claude/skills/bmad-build/
├── SKILL.md                   # Instruction file loaded at invocation
├── customize.toml             # Customization surface (defaults)
├── scripts/                   # Python scripts (run via uv run)
├── references/                # Sub-instruction files loaded on demand
├── assets/                    # Templates, CSVs, schemas
└── step-*.md / workflow.md    # Multi-step workflow fragments
```

### 4.3 All 68 Installed Skills

| # | Skill | Category | Purpose |
|---|---|---|---|
| 1 | `bmad-advanced-elicitation` | Core/Thinking | Structured second-pass refinement using named reasoning methods (pre-mortem, first principles, red team, Socratic, etc.) |
| 2 | `bmad-agent-analyst` | Agent | Activates Mary (Business Analyst) -- brainstorming, research, briefs, PRFAQs |
| 3 | `bmad-agent-architect` | Agent | Activates Winston (System Architect) -- architecture design, readiness gate |
| 4 | `bmad-agent-dev` | Agent | Activates Amelia (Senior Engineer) -- build, code review, sprint planning, retrospective |
| 5 | `bmad-agent-pm` | Agent | Activates John (Product Manager) -- PRD, epics, stories, implementation readiness |
| 6 | `bmad-agent-ux-designer` | Agent | Activates Sally (UX Designer) -- UX design specifications |
| 7 | `bmad-architecture` | Workflow | Create or update system architecture (ARCHITECTURE-SPINE.md) |
| 8 | `bmad-brainstorming` | Core/Thinking | Guided ideation with technique library; produces brainstorm.html + brainstorm-intent.md |
| 9 | `bmad-build` | Workflow | Core implementation loop: clarify, plan, implement, review. Accepts direct intent or planned story. |
| 10 | `bmad-build-auto` | Workflow | Unattended single-iteration of the Build model; exposes machine-readable terminal statuses |
| 11 | `bmad-checkpoint-preview` | Workflow | Five-step interactive code review: orientation, walkthrough, detail pass, testing, wrap-up |
| 12 | `bmad-code-review` | Workflow | Ad hoc code review; runs adversarial, edge-case-hunter, verification-gap lenses |
| 13 | `bmad-correct-course` | Workflow | Handle significant mid-sprint changes; updates plan or re-routes |
| 14 | `bmad-create-architecture` | Workflow | Architecture creation sub-workflow (invoked by bmad-architecture) |
| 15 | `bmad-create-epics-and-stories` | Workflow | Break PRD/spec into epic files with ordered stories |
| 16 | `bmad-create-prd` | Workflow | PRD creation sub-workflow |
| 17 | `bmad-create-story` | Workflow | Write a single story with checklist and template |
| 18 | `bmad-customize` | Core/Tool | Guided TOML override authoring; writes `_bmad/custom/` files and verifies merge |
| 19 | `bmad-deep-recon` | Core/Thinking | Decision-grade research: draft, process, or run mode; six typed packs (market, domain, technical, competitive, user-voice, academic-lit) |
| 20 | `bmad-dev-auto` | Workflow | Developer autonomous implementation shortcut |
| 21 | `bmad-dev-story` | Workflow | Developer story implementation with checklist |
| 22 | `bmad-document-project` | Workflow | DEPRECATED -- forwards to bmad-project-context |
| 23 | `bmad-domain-research` | Workflow | DEPRECATED -- forwards to bmad-deep-recon (domain type) |
| 24 | `bmad-edit-prd` | Workflow | PRD update/reconciliation sub-workflow |
| 25 | `bmad-editorial-review` | Workflow | DEPRECATED -- forwards to bmad-review (editorial lenses) |
| 26 | `bmad-editorial-review-prose` | Workflow | DEPRECATED -- forwards to bmad-review (prose lens) |
| 27 | `bmad-editorial-review-structure` | Workflow | DEPRECATED -- forwards to bmad-review (structure lens) |
| 28 | `bmad-forge-idea` | Core/Thinking | Adversarial idea pressure-test; produces forge-report.html + optional forged-idea.md |
| 29 | `bmad-generate-project-context` | Workflow | DEPRECATED -- forwards to bmad-project-context |
| 30 | `bmad-help` | Core/Tool | Context-aware guidance: inspects project state, recommends next step, answers natural language queries |
| 31 | `bmad-market-research` | Workflow | DEPRECATED -- forwards to bmad-deep-recon (market type) |
| 32 | `bmad-party-mode` | Core/Thinking | Multi-agent roundtable (session/auto/subagent/agent-team modes); custom parties; cross-session memory |
| 33 | `bmad-prd` | Workflow | PRD lifecycle: create, update, or validate; produces prd.md + addendum.md + validation-report |
| 34 | `bmad-prfaq` | Workflow | Working Backwards PRFAQ challenge; produces prfaq-{project}.md |
| 35 | `bmad-product-brief` | Workflow | Strategic product brief; produces brief.md + addendum.md |
| 36 | `bmad-project-context` | Workflow | Maintains AGENTS.md verified block; setup, adopt, refresh, record, audit intents |
| 37 | `bmad-qa-generate-e2e-tests` | Workflow | Generate API + E2E tests; framework auto-detection; produces test files + summary |
| 38 | `bmad-quick-dev` | Workflow | Fast direct code change without full build loop |
| 39 | `bmad-retrospective` | Workflow | Evidence-based epic retrospective; verdict (accepted/accepted-with-open-items/rejected) |
| 40 | `bmad-review` | Core/Tool | Multi-lens review: adversarial, edge-case, verification-gap (code); structure, prose (docs) |
| 41 | `bmad-review-adversarial-general` | Workflow | DEPRECATED -- forwards to bmad-review (adversarial lens) |
| 42 | `bmad-review-edge-case-hunter` | Workflow | DEPRECATED -- forwards to bmad-review (edge-case lens) |
| 43 | `bmad-review-verification-gap` | Workflow | DEPRECATED -- forwards to bmad-review (verification-gap lens) |
| 44 | `bmad-spec` | Workflow | Distill any intent into SPEC.md + companions; optionally generates stories.yaml for bmad-build-auto dispatch |
| 45 | `bmad-sprint-planning` | Workflow | Consolidates: readiness gate (PASS/CONCERNS/FAIL), sprint-status.yaml generation, status view, validate, repair |
| 46 | `bmad-sprint-status` | Workflow | DEPRECATED shim -- forwards to bmad-sprint-planning (status-view intent) |
| 47 | `bmad-technical-research` | Workflow | DEPRECATED -- forwards to bmad-deep-recon (technical type) |
| 48 | `bmad-ux` | Workflow | UX design: produces DESIGN.md + EXPERIENCE.md spine pair |
| 49 | `bmad-validate-prd` | Workflow | PRD validation sub-workflow; produces validation-report.html |
| 50 | `code-review` | Repo-specific | Review changes since a fixed point (commit, branch, tag) along Standards and Spec axes using parallel sub-agents |
| 51 | `codebase-design` | Repo-specific | Shared vocabulary for designing deep modules; interface improvement and seam decisions |
| 52 | `diagnosing-bugs` | Repo-specific | Diagnosis loop for hard bugs and performance regressions |
| 53 | `domain-modeling` | Repo-specific | Build and sharpen project domain model; ubiquitous language and ADR recording |
| 54 | `grill-me` | Repo-specific | Stress-test the user's plan or idea via adversarial questioning |
| 55 | `grilling` | Repo-specific | Relentlessly grill a plan or idea using adversarial questioning |
| 56 | `handoff` | Repo-specific | Transfer context between sessions or agents |
| 57 | `implement` | Repo-specific | Execute a defined change |
| 58 | `improve-codebase-architecture` | Repo-specific | Identify and implement codebase architecture improvements |
| 59 | `loop-me` | Repo-specific | Iterative loop skill for repeated execution of a task |
| 60 | `tdd` | Repo-specific | Test-driven development: red-green-refactor cycle with integration tests |
| 61 | `to-spec` | Repo-specific | Convert intent or description into a formal specification |
| 62 | `to-tickets` | Repo-specific | Convert spec or requirements into actionable tickets |
| 63 | `triage` | Repo-specific | Triage issues, findings, or bugs by severity and priority |
| 64 | `wayfinder` | Repo-specific | Navigation aid: find the right skill or workflow for a given need |
| 65 | `writing-beats` | Repo-specific | Writing skill focused on narrative beats and story structure |
| 66 | `writing-for-agents` | Repo-specific | Writing documents for agents: skills, AGENTS.md, CLAUDE.md |
| 67 | `writing-fragments` | Repo-specific | Composing document fragments and sections |
| 68 | `writing-shape` | Repo-specific | Shaping and restructuring document content |

> Note: Skills 1-49 (`bmad-*`) are BMAD framework skills installed by `npx bmad-method install`. Skills 50-68 are repo-specific custom skills pre-existing in `.claude/skills/` -- not installed by BMAD but discovered and enumerated here. Run `ls .claude/skills/` for the canonical listing. The installer regenerates `bmad-*` skill files on every install run; stale `bmad-*` dirs from removed modules must be deleted manually. Non-`bmad-*` skills are unaffected by re-installs.

---

## 5. Agent Roster

### 5.1 Configured Agents (from `_bmad/config.toml`)

| Agent Skill ID | Name | Title | Icon | Module | Team | Primary Triggers |
|---|---|---|---|---|---|---|
| `bmad-agent-analyst` | Mary | Business Analyst | 📊 | bmm | software-development | `BP`, `MR`, `DR`, `TR`, `CB`, `WB`, `PC` |
| `bmad-agent-pm` | John | Product Manager | 📋 | bmm | software-development | `PRD`, `CE`, `IR`, `CC` |
| `bmad-agent-ux-designer` | Sally | UX Designer | 🎨 | bmm | software-development | `CU` |
| `bmad-agent-architect` | Winston | System Architect | 🏗️ | bmm | software-development | `CA`, `IR` |
| `bmad-agent-dev` | Amelia | Senior Software Engineer | 💻 | bmm | software-development | `BD`, `QA`, `CR`, `SP`, `ER` |

Trigger meanings: `BP`=Brainstorm, `MR`=Market Research, `DR`=Domain Research, `TR`=Technical Research, `CB`=Create Brief, `WB`=Working Backwards/PRFAQ, `PC`=Project Context, `PRD`=Product Requirements Document, `CE`=Create Epics, `IR`=Implementation Readiness, `CC`=Correct Course, `CU`=Create UX, `CA`=Create Architecture, `BD`=Build, `QA`=QA Test Generation, `CR`=Code Review, `SP`=Sprint Planning, `ER`=Epic Retrospective.

Note: Paige (Technical Writer) is on hiatus; `PC` trigger is accessible via Mary (`bmad-agent-analyst`).

### 5.2 Agent Activation Sequence

When an agent skill is invoked, these eight steps run in order:

1. **Resolve agent block** -- merge `customize.toml` (Priority 3) with `_bmad/custom/{skill}.toml` (Priority 2) and `_bmad/custom/{skill}.user.toml` (Priority 1) via `uv run _bmad/scripts/resolve_customization.py --skill <skill-root> --key agent`
2. **Execute `activation_steps_prepend`** -- pre-flight steps (file loads, compliance checks) before greeting
3. **Adopt persona** -- hardcoded identity (name, title) + customized role, communication_style, principles
4. **Load `persistent_facts`** -- literal sentences or `file:` references resolved at runtime
5. **Load config** -- user_name, communication_language, document_output_language, artifact paths from merged config
6. **Greet** -- personalized greeting in configured language with agent icon prefix
7. **Execute `activation_steps_append`** -- post-greet setup steps
8. **Dispatch or present menu** -- if opening message matches a menu trigger, dispatch directly; otherwise render menu

### 5.3 Agent Customization Surface

Per-skill customizable fields under `[agent]` in `customize.toml`:

| Field | Shape | Merge Rule | Effect |
|---|---|---|---|
| `icon` | scalar | override wins | Agent emoji prefix |
| `role` | scalar | override wins | Narrative role description |
| `communication_style` | scalar | override wins | How the agent speaks |
| `persistent_facts` | array (no identifier) | append | Facts loaded on every activation; supports `file:{project-root}/...` refs |
| `principles` | array (no identifier) | append | Agent value system additions |
| `activation_steps_prepend` | array (no identifier) | append | Steps run before greeting |
| `activation_steps_append` | array (no identifier) | append | Steps run after greeting |
| `menu` | array of tables (key: `code`) | merge by `code` | Add/replace menu items; each item has exactly one of `skill` or `prompt` |

`agent.name` and `agent.title` are **read-only** -- hardcoded in SKILL.md identity. Override files with these fields have no effect.

---

## 6. Configuration Architecture

### 6.1 Installer-Managed Files

These files are **regenerated on every `npx bmad-method install` run**. Treat as read-only outputs; direct edits are overwritten.

| File | Scope | Content |
|---|---|---|
| `_bmad/config.toml` | team | `[core]` settings + `[modules.<code>]` settings + `[agents.<code>]` descriptors. Sourced from prompt answers with `scope: team`. |
| `_bmad/config.user.toml` | user | `[core]` user settings (user_name, communication_language, user_skill_level). Sourced from prompt answers with `scope: user`. |
| `_bmad/bmm/config.yaml` | module | Module-level config (version, user_skill_level, artifact paths, project_knowledge). Re-read by installer as prompt defaults. |
| `_bmad/core/config.yaml` | module | Core module config |
| `_bmad/_config/manifest.yaml` | system | Installed module inventory with versions, channels, SHAs |
| `_bmad/_config/files-manifest.csv` | system | Per-file installation tracking |
| `_bmad/_config/skill-manifest.csv` | system | Skill metadata |
| `_bmad/_config/bmad-help.csv` | system | Help catalog for bmad-help inspection |

### 6.2 Human-Authored Override Files

These files are **never touched by the installer**. The correct surface for durable overrides.

| File | Scope | Content |
|---|---|---|
| `_bmad/custom/config.toml` | team (committed) | `[agents.<code>]` descriptor overrides, `[modules.<code>]` setting pins, `[core]` overrides |
| `_bmad/custom/config.user.toml` | personal (gitignored) | Personal agent/module setting overrides |
| `_bmad/custom/{skill-name}.toml` | team (committed) | Per-skill agent/workflow override (sparse TOML) |
| `_bmad/custom/{skill-name}.user.toml` | personal (gitignored) | Personal per-skill overrides |

### 6.3 Three-Layer Per-Skill Override Model

```
Priority 1 (wins): _bmad/custom/{skill-name}.user.toml   [personal, gitignored]
Priority 2:        _bmad/custom/{skill-name}.toml         [team, committed]
Priority 3 (base): .claude/skills/{skill-name}/customize.toml  [shipped defaults]
```

### 6.4 Four-Layer Central Config Merge

```
Priority 1 (wins): _bmad/custom/config.user.toml
Priority 2:        _bmad/custom/config.toml
Priority 3:        _bmad/config.user.toml
Priority 4 (base): _bmad/config.toml
```

### 6.5 Merge Rules (structural, not field-name-based)

| Value shape | Merge behavior |
|---|---|
| Scalar (string, int, bool, float) | Override wins |
| Table | Deep merge (recursively apply rules) |
| Array of tables where ALL items share the same `code` field OR all share the same `id` field | Merge by that key: matching keys replace in place, new keys append |
| Any other array (scalars; tables with no identifier; tables mixing `code` and `id`) | Append: base items first, then team, then user |

No removal mechanism: overrides cannot delete base items. To suppress a default menu item, override it by `code` with a no-op prompt/skill.

### 6.6 Configuration Resolution -- uv run Resolver

```bash
# Resolve full agent block for bmad-agent-dev
uv run _bmad/scripts/resolve_customization.py \
  --skill .claude/skills/bmad-agent-dev \
  --key agent

# Resolve single field
uv run _bmad/scripts/resolve_customization.py \
  --skill .claude/skills/bmad-agent-dev \
  --key agent.icon

# Full dump (no --key)
uv run _bmad/scripts/resolve_customization.py \
  --skill .claude/skills/bmad-agent-dev
```

Output is always JSON. Script uses only `tomllib` (stdlib, Python 3.11+). `uv run` provisions the interpreter from the `requires-python >= 3.11` header; system Python version is irrelevant.

### 6.7 `_bmad/scripts/` Utilities

| Script | Purpose |
|---|---|
| `resolve_customization.py` | Three-layer TOML merge resolver |
| `resolve_config.py` | Central config resolution |
| `config_utils.py` | Shared TOML utilities |
| `render_skill.py` | Skill rendering helper |
| `memlog.py` | Memory log (session state persistence for skills) |

---

## 7. Workflows -- Build System

### 7.1 bmad-build (Interactive)

The canonical implementation workflow. Accepts: free-form intent, issue/bug URL, file path to intent, existing spec file path, or planned story from epics.

**Phase sequence:**
1. **Clarify** -- compress request into one coherent, contradiction-free goal. Human-in-the-loop.
2. **Route** -- one-shot vs. full path decision based on blast radius.
3. **Plan/Spec** -- produce spec file at `_bmad-output/implementation-artifacts/spec-<slug>.md`. Human approves.
4. **Implement** -- autonomous execution against frozen spec.
5. **Review** -- subagent-based triage (adversarial, edge-case, verification-gap). Findings categorized: local patch, spec defect, intent gap.
6. **Present** -- commit (no push), show review trail, offer `bmad-checkpoint-preview`.

**Example invocation for this repo:**

```text
/bmad-build Fix the catch block in New-MotivationTask (~line 801 of DailyMotivation.ps1)
to handle all five Windows Task Scheduler error conditions documented in CLAUDE.md.
```

### 7.2 bmad-build-auto (Unattended)

Machine-facing surface of the same Build model. Requires subagent support on the platform.

**Input forms:**
- Free-form change request
- Ticket/issue/story identifier
- Path to intent file
- Path to existing spec file (resumes from spec `status`)
- Spec folder + story ID (folder+id dispatch -- reads `stories.yaml`, routes to `stories/<id>-*.md`)

**Spec status state machine:**

```
draft -> ready-for-dev -> in-progress -> in-review -> done
                                                    -> blocked
```

`blocked` conditions include: `unclear intent`, `intent gap`, `no subagents`, `missing spec_file before implementation`, `implementation verification failed`, `review repair loop exceeded 5 iterations (non-convergence)`, `no stories.yaml found`, `story id not found in stories.yaml`, `no epic spec found`, `ambiguous story file match`, `story already blocked`.

**Orchestrator responsibilities:**
- Monitor spec `status` field, not chat output
- Read `deferred:` frontmatter for out-of-scope findings (not a backlog -- orchestrator decides routing)
- Use `baseline_revision` for commit range identification
- Handle `blocked` as a routing signal, not terminal failure

**Output artifacts:**
- `_bmad-output/implementation-artifacts/spec-<slug>.md` (primary)
- `_bmad-output/implementation-artifacts/bmad-build-auto-result-<slug>.md` (fallback, pre-spec halts)
- `{spec-folder}/stories/<story-id>-<slug>.md` (folder+id dispatch mode)
- `_bmad-output/implementation-artifacts/epic-<N>-context.md` (epic context cache)

### 7.3 bmad-dev-story and bmad-dev-auto

- `bmad-dev-story`: Story implementation with explicit checklist validation
- `bmad-dev-auto`: Developer autonomous implementation shortcut (same model, reduced friction)

### 7.4 Quick Fixes Path

```text
/bmad-build Fix the login validation bug -- or --
/bmad-quick-dev <short description>
```

Small, zero-blast-radius changes route directly to implementation (no upstream planning). Deferred findings written to `deferred-work.md` in implementation artifacts.

---

## 8. Planning Workflows

### 8.1 Phase 1 -- Analysis (Optional)

| Skill | Output | When |
|---|---|---|
| `bmad-brainstorming` | `brainstorm.html`, optional `brainstorm-intent.md` | Problem space exploration before requirements |
| `bmad-forge-idea` | `forge-report.html`, optional `forged-idea.md` | Pressure-test a specific idea |
| `bmad-deep-recon` | `research.md` + optional HTML briefing | Market, domain, technical, competitive, user-voice, or lit research |
| `bmad-product-brief` | `brief.md`, `addendum.md` | Strategic vision capture when concept is clear |
| `bmad-prfaq` | `prfaq-{project}.md` | Working Backwards stress-test (customer-first validation) |

### 8.2 bmad-prd (Three Intents in One Skill)

```text
/bmad-prd            # skill detects intent from invocation message
```

| Intent | Behavior | Output |
|---|---|---|
| Create | Coached discovery session | `prd.md`, `addendum.md`, `.memlog.md` |
| Update | Reconcile existing PRD with change signal, surface conflicts | Updated `prd.md` |
| Validate | Critique against configurable checklist | `validation-report.html` + `.md` |

Sub-skills: `bmad-create-prd`, `bmad-edit-prd`, `bmad-validate-prd` (invoked headless).

### 8.3 bmad-spec

Distills any intent (brief, PRD, transcript, design folder, brain dump) into:

```
_bmad-output/specs/spec-{slug}/
├── SPEC.md          # Five-field kernel: Why, Capabilities, Constraints, Non-goals, Success signal
├── stories.yaml     # Optional; used for bmad-build-auto folder+id dispatch
└── stories/         # Per-story spec files (populated by bmad-build-auto)
```

`bmad-spec` is the **only writer of SPEC.md**. Other skills invoke it headless when they need to express intent.

### 8.4 bmad-ux

Produces the UX spine pair:
- `DESIGN.md` -- visual: screens, components, layout, color, typography
- `EXPERIENCE.md` -- behavioral: flows, interactions, states, error conditions

Invoked directly or via Sally (`CU` trigger).

### 8.5 bmad-architecture / bmad-create-architecture

Produces `ARCHITECTURE-SPINE.md`. Covers ADRs, FR/NFR mapping, tech decisions, naming conventions, testing patterns, directory structure. Winston's `CA` trigger routes here.

Phase 3 (Solutioning) -- translate what to build (PRD) into how (technical design). Prevents multi-agent implementation conflicts by establishing shared standards before epic implementation.

### 8.6 bmad-create-epics-and-stories

Inputs: PRD and/or architecture. Outputs: epic files in `_bmad-output/planning-artifacts/` with `## Epic N:` and `### Story N.M: Title` headings parseable by `sprint_plan.py`.

### 8.7 bmad-create-story

Write a single story with template and checklist. Invoked by PM agent (`CE` trigger paths) or directly.

---

## 9. Sprint and Project Management

### 9.1 bmad-sprint-planning (Consolidated)

Single skill that replaced three earlier skills (`bmad-check-implementation-readiness`, old `bmad-sprint-planning`, `bmad-sprint-status`).

**Four intents detected from invocation phrase:**

| Phrase trigger | Behavior |
|---|---|
| "check implementation readiness" / `IR` | Readiness gate: inventories planning artifacts, asks "could a developer implement without inventing decisions?" Returns PASS/CONCERNS/FAIL with severity-ordered findings. |
| "run sprint planning" / "generate sprint status" | Runs `sprint_plan.py generate` to parse epics -> `sprint-status.yaml` |
| "show sprint status" | Runs `sprint_plan.py status` -- counts, risks, next recommended action |
| "validate sprint status" / "fix sprint status" | Runs `sprint_plan.py validate` or repair flow |

`sprint_plan.py` is deterministic for: parsing `## Epic N:` / `### Story N.M:` headings (kebab-case keys), ordering, merging against existing file (advanced statuses preserved, never downgraded), normalizing legacy values (`drafted`->`ready-for-dev`, `contexted`->`ready-for-dev`), preserving retrospective `action_items`, custom keys, and comments. `--dry-run` produces a **drift report** (in_sync, new entries, orphans with old statuses, illegal values) without writing. `--fresh` rebuilds from scratch ignoring existing statuses; `--set key=status` applies explicit statuses (the only path that can downgrade).

`sprint-status.yaml` is written to `{implementation_artifacts}/sprint-status.yaml` (i.e., `_bmad-output/implementation-artifacts/sprint-status.yaml` in this repo). It is the single source of truth for the entire dev cycle -- read and written by `bmad-build` (story status sync), `bmad-code-review` (advances stories through review), and `bmad-retrospective` (appends action items).

### 9.2 bmad-retrospective

Runs after epic completion. Inputs: spec files, full diff, per-story commits, sprint status. Produces:
- **Retrospective document** in `_bmad-output/implementation-artifacts/`
- **Updated sprint-status.yaml** (epic retrospective marked done, action items appended)
- **Verdict**: `accepted`, `accepted-with-open-items`, or `rejected`

A `rejected` verdict (or unfinished stories) is the hard gate before starting the next epic. Optional: convenes `bmad-party-mode` over findings for team discussion.

**Headless mode (automation):** `-H <epic>` runs unattended; verdict is determined from evidence alone with no interactive discussion. Use when integrating retrospective into a CI or orchestration pipeline.

### 9.3 bmad-checkpoint-preview

Five-step interactive human-in-the-loop review after `bmad-build`:

1. **Orientation** -- one-line intent + surface area stats (files, modules, boundary crossings)
2. **Walkthrough** -- change organized by concern (not file), sequenced top-down, `path:line` stops
3. **Detail pass** -- 2-5 highest blast-radius spots tagged `[auth]`, `[schema]`, `[security]`, etc.
4. **Testing** -- 2-5 manual observation suggestions (not automated test commands)
5. **Wrap-up** -- approve / rework / keep discussing

Invoke mid-session: "checkpoint" or "walk me through this change."

---

## 10. Research and Ideation

### 10.1 bmad-deep-recon -- Three Modes

| Mode | What happens | Input |
|---|---|---|
| Draft | Composes type-specific research prompt; you run in your deep-research tool | Natural language request |
| Process | Takes finished report from any source, extracts claims, checks against type pack, writes standard summary | Path to report file |
| Run | Full in-session research: plan gate, parallel firewalled assistants, claim verification, cited `research.md` | Natural language request |

**Six research types:** `market`, `domain`, `technical`, `competitive`, `user-voice`, `academic-lit`. Auto-inferred from request or named explicitly.

**Run mode effort presets:**

| Preset | Assistants | Sources/round | Rounds |
|---|---|---|---|
| `quick` | 2 | 5 | 1 |
| `standard` (default) | 3 | 8 | 2 |
| `deep` | 6 | 12 | 3 |

**Refresh**: re-verifies stale claims only, appends delta report. **Deepen**: drills one dimension without re-running rest.

**Claim verification levels (run mode):**

| Level | Behavior |
|---|---|
| `normal` (default) | Spot-checks claims the recommendation rests on |
| `high` | Cross-checks the type pack's critical claim classes; red-teams major conclusions |
| `max` | Verifies everything in the report |

**Research firewall:** project files and briefs shape what questions get asked, never what gets found. Research assistants receive only their assignment.

Old skills `bmad-market-research`, `bmad-domain-research`, `bmad-technical-research` are deprecated forwarders to `bmad-deep-recon`.

### 10.2 bmad-forge-idea

Adversarial interrogator. Works one question at a time in dependency order, puts a recommended answer on the table for pushback. Brings two voices per branch (one from installed roster, one topic-conjured). Sessions end as: **Hardened** (-> `forged-idea.md` + `forge-report.html`) | **Killed** (-> `forge-report.html`) | **Clearer** (-> `forge-report.html`).

### 10.3 bmad-brainstorming

Loads technique library from `assets/brain-methods.csv`. Targets 100+ ideas before organization. Anti-bias protocol shifts creative domain every 10 ideas. Output: `brainstorm.html` keepsake + optional `brainstorm-intent.md` for downstream skills.

---

## 11. Review and Quality

### 11.1 bmad-review (Consolidated)

Replaced: `bmad-editorial-review`, `bmad-editorial-review-prose`, `bmad-editorial-review-structure`, `bmad-review-adversarial-general`, `bmad-review-edge-case-hunter`, `bmad-review-verification-gap` (all are now deprecated forwarders).

**Five shipped lenses:**

| Lens | Applies to | Method |
|---|---|---|
| `adversarial` | Anything | Forced-finding (>=10 issues); looks for missing items, not only errors. Empty lists disallowed. |
| `edge-case` | Anything | Walks every branch and boundary condition in behavior-defining content |
| `verification-gap` | Code | Changed behavior that could regress without verification catching it |
| `structure` | Documents | Proposes cuts, merges, moves -- does the shape serve the purpose? |
| `prose` | Documents | Copy-edits for comprehension issues. Runs on top of structure findings when both selected. |

Editorial lenses (structure, prose) never challenge ideas -- only organization and expression. They propose, not execute.

Lenses are extensible via `customize.toml` overrides. Parallel subagent execution when platform supports it.

### 11.2 bmad-code-review

Ad hoc code review. Runs code lenses (adversarial, edge-case, verification-gap) automatically.

### 11.3 bmad-qa-generate-e2e-tests

Five steps: detect test framework (from `package.json` + existing test files), identify features, generate API tests (status codes, response structure, error cases), generate E2E tests (semantic locators, visible-outcome assertions), run and fix. Framework-agnostic (Jest, Vitest, Playwright, Cypress, or custom). Test output: `_bmad-output/implementation-artifacts/test-summary.md`.

For `Daily-Motivation-Brain-Helper`, this project uses Pester v5 (PowerShell). The QA workflow will detect the framework from `Tests/` structure and existing `.ps1` test files.

### 11.4 bmad-advanced-elicitation

Structured second pass on recent LLM output. Selects 2-5 best-fit methods from `assets/methods.csv` catalog. Methods include: Pre-mortem Analysis, First Principles Thinking, Inversion, Red Team vs Blue Team, Socratic Questioning, Constraint Removal, Stakeholder Mapping, Analogical Reasoning, and dozens more. `scripts/pick_methods.py` serves the catalog to avoid loading it whole into context (except when all methods requested).

### 11.5 bmad-correct-course

Handles significant mid-sprint changes. Updates plan or re-routes with checklist validation.

### 11.6 Test Architect (TEA) -- Not Installed

If installed (`--modules bmm,tea`), provides Murat agent + 9 workflows: Test Design, ATDD, Automate (enhanced), Test Review, Traceability, NFR Assessment, CI Setup, Framework Scaffolding, Release Gate. P0-P3 risk-based prioritization.

---

## 12. Customization -- Extending BMAD

### 12.1 Per-Skill Agent Overrides

Example -- add persistent facts to Amelia so she always considers Pester v5 constraints in this repo:

```toml
# _bmad/custom/bmad-agent-dev.toml  (team, committed to git)

[agent]
persistent_facts = [
  "This repo uses Pester v5 (not v4) for all tests in Tests/**/*.ps1. Key constraints from CLAUDE.md: never mock New-ScheduledTaskAction/Trigger/Settings/Principal (use only Register/Get/Unregister-ScheduledTask mocks), never put common params in splatted hashtables, no module-qualified calls (causes infinite recursion), no <token> in test names unless using -ForEach data key.",
  "file:{project-root}/CLAUDE.md",
]
```

Example -- add menu item to Winston for architecture review of the Task Scheduler integration:

```toml
# _bmad/custom/bmad-agent-architect.toml

[[agent.menu]]
code = "TS"
description = "Review Task Scheduler integration against ADR-005"
prompt = """
Read docs/architecture/adr-005-mandate-history.md and DailyMotivation.ps1 lines 780-850.
Check that New-ScheduledTaskPrincipal parameters match: -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited.
Report any deviations from the validated principal configuration.
"""
```

### 12.2 Per-Skill Workflow Overrides

```toml
# _bmad/custom/bmad-prd.toml

[workflow]
persistent_facts = [
  "This is a Windows-only WPF app (ps2exe compiled). Any PRD feature requiring UI changes must account for STA threading requirements and the absence of a web frontend.",
]
on_complete = "Offer to create a GitHub issue linking the PRD for team tracking."
```

### 12.3 Central Config Overrides

To rebrand an agent org-wide (affects party-mode, retrospective, advanced-elicitation roster):

```toml
# _bmad/custom/config.toml

[agents.bmad-agent-dev]
description = "Amelia -- PowerShell-first engineer. Treats Pester v5 coverage as a hard gate. Never skips hooks or uses --no-verify."
```

To add a fictional agent (personal):

```toml
# _bmad/custom/config.user.toml

[agents.powershell-sage]
team = "custom"
name = "PowerShell Sage"
title = "Senior Windows Automation Architect"
icon = "🖥️"
description = "20 years of PowerShell. Thinks in pipeline stages. Corrects any script that would fail on PowerShell 5.1 or miss COM threading requirements."
```

### 12.4 Module-Level Config Pins

```toml
# _bmad/custom/config.toml

[modules.bmm]
planning_artifacts = "{project-root}/_bmad-output/planning-artifacts"
user_skill_level = "expert"
```

### 12.5 IDE Session File Reinforcement (CUST-035)

BMAD customizations load at skill activation. IDE global instruction files (`CLAUDE.md`, `AGENTS.md`) load at session start, before any skill. For rules that must hold even outside skill activation:

```markdown
<!-- _bmad-custom convention: also place critical rules here for always-loaded context -->
<!-- Any file-read of library docs goes through Context7 MCP before training-data knowledge. -->
```

**When to double up:** rule is important outside BMAD skill activation; training-data defaults might override it; rule is concise enough not to bloat the session file. Each layer owns its scope -- IDE session file (always-loaded), BMAD agent customize.toml (skill-activation), workflow customize.toml (one workflow run), central config (roster + paths).

This repo's `CLAUDE.md` already contains hard mandates (Task Scheduler principal config, Pester mock rules). These function as IDE-level guards independent of BMAD skill activation.

### 12.6 bmad-customize Skill

Guided TOML override authoring. Scans installed customizable skills, selects correct surface (agent vs workflow), writes override file, verifies merge. Run: `/bmad-customize` or `/bmad-customize bmad-agent-dev`.

### 12.7 Enterprise Recipes Summary

| Recipe | Surface | Use case |
|---|---|---|
| Shape agent across every workflow | `_bmad/custom/bmad-agent-{role}.toml` `persistent_facts` | MCP tool rules, org conventions |
| Enforce org conventions in one workflow | `_bmad/custom/{workflow}.toml` `persistent_facts` | Compliance fields, output formats |
| Auto-publish completed artifacts | `_bmad/custom/{workflow}.toml` `on_complete` | Confluence, Notion, Jira integration |
| Swap output template | `_bmad/custom/{workflow}.toml` scalar path override | Org-specific templates |
| Rebrand agent roster descriptor | `_bmad/custom/config.toml` `[agents.<code>]` | Party-mode / retrospective / elicitation |
| On-demand knowledge sources | `_bmad/custom/{workflow}.toml` `external_sources` | Competitive DB, compliance refs |
| Automatic artifact publishing | `_bmad/custom/{workflow}.toml` `external_handoffs` | Multi-system publishing with graceful degradation |
| Finalize-time doc standards | `_bmad/custom/{workflow}.toml` `doc_standards` | Voice/tone, ISO date enforcement |

---

## 13. Multi-Agent Orchestration

### 13.1 bmad-party-mode

Four run modes:

| Mode | Mechanism | Use case |
|---|---|---|
| `session` (default) | One model voices all personas inline | Brainstorming, quick back-and-forth |
| `auto` | Inline for light rounds, spawns real agents for hard rounds | Speed + independence when needed |
| `subagent` | Separate agent per persona per substantive round | Review panels, focus groups requiring independence |
| `agent-team` | Persistent team, agents address each other (Claude Code only) | Hands-off roundtable |

Mode fallback chain: `agent-team` -> `subagent` -> `session` when platform lacks capability.

**Shipped custom parties:** Code Review Crew (5 lenses: Vex/security, Grumbal/adversarial, Boundary/edge-cases, Yui/craftsmanship, Dana/pragmatist) and Anti-Consensus Club (Wildcard, Level, Killjoy, Splinter).

**Party memory:** each party keeps cross-session memory of dynamics, open threads, and prior landing points. Set per party; default installed-agent room remembers.

**Team filtering:** `[agents.<code>] team = "<team-name>"` in config. `bmad-party-mode --party <name>` or "invite the <team>" phrases filter by team field.

**Session keepsake:** HTML document offered at wrap-up.

### 13.2 Subagent Dispatch Architecture

`bmad-build` and `bmad-build-auto` internally dispatch review subagents (context-free, independent reasoning). `bmad-review` runs lenses in parallel via subagents when platform supports it. `bmad-deep-recon` fans out firewalled research assistants with the research firewall (project files shape questions, not findings).

---

## 14. Project Context and Brownfield Onboarding

### 14.0 Brownfield On-Ramp

For existing codebases, the recommended sequence before starting implementation:

1. **Clean up completed planning artifacts** -- archive or delete PRDs/epics/stories already shipped. Do not keep stale planning docs in `docs/`, `_bmad-output/planning-artifacts/`, or `_bmad-output/implementation-artifacts/`.
2. **Run `bmad-project-context`** -- builds the verified AGENTS.md context block from the existing codebase.
3. **Maintain `docs/`** -- `project_knowledge = "{project-root}/docs"` in this repo's config. `bmad-help` reads `docs/` to give context-aware advice. Keep it accurate; `bmad-project-context` audits and prunes on demand.
4. **Choose planning depth** (see `bmad-help`): direct entry to `bmad-build` for clear bounded changes; full planning sequence (PRD -> architecture -> epics -> sprint-planning) for multi-epic initiatives.

### 14.1 bmad-project-context

Maintains a verified block inside `AGENTS.md` between `<!-- bmad:context -->` and `<!-- /bmad:context -->` markers. Everything outside markers is preserved byte-for-byte.

**Five intents:**

| Intent | Phrase | Behavior |
|---|---|---|
| Setup | "set up AGENTS.md" | Fresh setup; asks what rules you bring, discovers/verifies rest |
| Adopt | "adopt the AGENTS.md we have" | Imports existing instructions; shows disposition of each before writing |
| Refresh | "refresh the context" | Re-runs commands, diffs deletions/renames since recorded commit |
| Record | "the agent keeps doing X wrong" | Captures one observed mistake as a pitfall entry |
| Audit | "audit our context" | Re-verifies and prunes; block ends smaller or equal, never larger |

**What earns a line:** policy org requires, catches config files cannot express, ecosystem convention deviations, observed-failure-only pitfalls, cross-component rules and required versions.

**What never enters:** repo structure, tech-stack overviews, ecosystem defaults (agent already knows these), derivable code facts, aspirational state, history narration.

`bmad-document-project` and `bmad-generate-project-context` are deprecated forwarders.

---

## 15. Web Bundles (Not Installed)

Web bundles repackage BMAD planning skills as Google Gemini Gems or ChatGPT Custom GPTs. Available at `bmadcode.com/web-bundles/`. Current shelf: Brainstorming Coach, Product Brief Coach, PRFAQ Coach, PRD Coach, UX Coach, Market and Industry Research. Custom bundles built via `bmad-os-skill-to-bundle` utility skill.

---

## 16. Maintenance and Updates

### 16.1 Quick Update

```bash
npx bmad-method install   # in project root; select Quick Update
# or non-interactively:
npx bmad-method install --yes --action quick-update
```

Refreshes files, applies patch/minor stable upgrades, refuses major upgrades.

### 16.2 Add a Module

```bash
npx bmad-method install --yes --action update --modules bmm,tea
# --tools is omitted on update; reuses tools from first install
```

### 16.3 Switch Channel

Interactive: Modify Install -> Yes to "Review channel assignments?"

Non-interactive:
```bash
# Put bmb on next:
npx bmad-method install --yes --action update --modules bmm,bmb --next=bmb
# Pin to specific tag:
npx bmad-method install --yes --action update --modules bmm,bmb --pin bmb=v1.7.0
```

### 16.4 Remove Stale Skill Files

The installer does not delete old skill dirs automatically. After removing a module:

```bash
rm -rf .claude/skills/bmad-{skill-from-removed-module}/
```

Or delete the entire `.claude/skills/` directory and re-run the installer for a clean set.

### 16.5 v4 to v6 Migration

1. Run `npx bmad-method install` -- installer detects `.bmad-method/` and offers backup/removal.
2. Manually remove `.claude/commands/` (v4 skill location).
3. Move planning docs to `_bmad-output/planning-artifacts/` (use PRD/brief/architecture in filenames).
4. For in-progress stories: run `bmad-sprint-planning` and report which epics/stories are complete.

---

## 17. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| "Could not resolve stable tag" | GitHub API rate limit (60/hr anonymous) | `export GITHUB_TOKEN=<PAT>` and retry |
| "Tag 'vX.Y.Z' not found" | `--pin` tag does not exist in module repo | Check repo releases page; use an existing tag |
| Pinned install upgrading itself | Not a pinned install -- `channel: stable` in manifest | Verify manifest.yaml shows `channel: pinned` |
| `--pin bmm=X` had no effect | bmm is bundled; `--pin` does not apply | Use `npx bmad-method@next install` for prerelease |
| Customization not appearing | Wrong file location or TOML syntax error | Verify file is in `_bmad/custom/` with exact skill dir name; validate TOML syntax |
| Skills not appearing in IDE | IDE requires explicit skill enablement | Enable skills in IDE settings; restart IDE or reload window |
| Expected skills missing | Module not selected during install | Re-run installer; verify module selection |
| Stale skills from removed module | Installer does not delete old skill dirs | Remove stale dirs from `.claude/skills/` manually |
| `uv` not found | uv not installed or not on PATH | Install via `curl -LsSf https://astral.sh/uv/install.sh | sh`; add `~/.local/bin` to PATH |
| Agent activation fails with Python error | Python < 3.11 on system PATH | Irrelevant -- `uv run` provisions its own Python 3.11+ from the script header |
| `resolve_customization.py` unavailable | uv not on PATH | Either install uv, or read the three TOML files directly and apply merge rules manually |
| bmad-build-auto blocked: `no subagents` | Platform does not support subagent spawning | Use interactive `bmad-build` instead |
| `review repair loop exceeded 5 iterations` | Non-convergent review cycle | Review the spec for intent ambiguities; re-run with cleaner intent |
| Updates broke customization | Copied full `customize.toml` into override | Override files must be sparse (only changed fields). Trim to deltas. |
| Sprint status file drifted | Manual edits or story renames without updating file | Run "fix sprint status" intent; confirm proposed state table before write |
| `bmad-sprint-status` not found | Deprecated; forwarded | Use `bmad-sprint-planning` with status-view intent |

---

## Appendix A -- Complete CLI Flag Reference

See Section 1.3.

## Appendix B -- Configuration File Inventory

| File | Owner | Scope | Overwritten by installer? |
|---|---|---|---|
| `_bmad/config.toml` | Installer | team | Yes, every install |
| `_bmad/config.user.toml` | Installer | user | Yes, every install |
| `_bmad/bmm/config.yaml` | Installer | module | Yes, every install |
| `_bmad/core/config.yaml` | Installer | module | Yes, every install |
| `_bmad/_config/manifest.yaml` | Installer | system | Yes, every install |
| `_bmad/_config/files-manifest.csv` | Installer | system | Yes, every install |
| `_bmad/_config/skill-manifest.csv` | Installer | system | Yes, every install |
| `_bmad/_config/bmad-help.csv` | Installer | system | Yes, every install |
| `_bmad/custom/config.toml` | Human | team | Never |
| `_bmad/custom/config.user.toml` | Human | user | Never |
| `_bmad/custom/{skill}.toml` | Human | team | Never |
| `_bmad/custom/{skill}.user.toml` | Human | user | Never |
| `.claude/skills/{skill}/customize.toml` | Installer | skill defaults | Yes, every install |
| `.claude/skills/{skill}/SKILL.md` | Installer | skill instructions | Yes, every install |

## Appendix C -- Agent Roster (from `_bmad/config.toml`)

| Skill ID | Name | Title | Icon | Module | Team |
|---|---|---|---|---|---|
| `bmad-agent-analyst` | Mary | Business Analyst | 📊 | bmm | software-development |
| `bmad-agent-pm` | John | Product Manager | 📋 | bmm | software-development |
| `bmad-agent-ux-designer` | Sally | UX Designer | 🎨 | bmm | software-development |
| `bmad-agent-architect` | Winston | System Architect | 🏗️ | bmm | software-development |
| `bmad-agent-dev` | Amelia | Senior Software Engineer | 💻 | bmm | software-development |

## Appendix D -- Four-Phase BMad Method Workflow Map

| Phase | Workflows | Produces |
|---|---|---|
| **1 -- Analysis** (optional) | bmad-brainstorming, bmad-forge-idea, bmad-deep-recon, bmad-product-brief, bmad-prfaq | brainstorm.html, forge-report.html/forged-idea.md, research.md, brief.md, prfaq.md |
| **2 -- Planning** | bmad-prd, bmad-ux, bmad-spec | prd.md+addendum.md, DESIGN.md+EXPERIENCE.md, SPEC.md+stories.yaml |
| **3 -- Solutioning** | bmad-architecture, bmad-create-epics-and-stories, bmad-sprint-planning (readiness gate) | ARCHITECTURE-SPINE.md, epic files, sprint-status.yaml |
| **4 -- Implementation** | bmad-build, bmad-build-auto, bmad-code-review, bmad-correct-course, bmad-retrospective | spec-*.md + code, retro document, acceptance verdict |

Context management: each phase document becomes context for the next. PRD -> Architecture -> Epics -> Build ensures consistent implementation decisions across stories.

## Appendix E -- Skills by Category (Quick Reference)

**Core (always installed):** bmad-help, bmad-advanced-elicitation, bmad-review, bmad-customize, bmad-brainstorming, bmad-deep-recon, bmad-forge-idea, bmad-party-mode

**Agents:** bmad-agent-analyst (Mary), bmad-agent-pm (John), bmad-agent-ux-designer (Sally), bmad-agent-architect (Winston), bmad-agent-dev (Amelia)

**Build/Implementation:** bmad-build, bmad-build-auto, bmad-dev-story, bmad-dev-auto, bmad-quick-dev, bmad-code-review, bmad-correct-course, bmad-checkpoint-preview, bmad-qa-generate-e2e-tests

**Planning:** bmad-prd, bmad-create-prd, bmad-edit-prd, bmad-validate-prd, bmad-spec, bmad-ux, bmad-architecture, bmad-create-architecture, bmad-create-epics-and-stories, bmad-create-story, bmad-product-brief, bmad-prfaq

**Sprint/Project:** bmad-sprint-planning, bmad-retrospective, bmad-project-context, bmad-document-project (deprecated), bmad-generate-project-context (deprecated)

**Research (merged into bmad-deep-recon):** bmad-domain-research (deprecated), bmad-market-research (deprecated), bmad-technical-research (deprecated)

**Review (merged into bmad-review):** bmad-editorial-review (deprecated), bmad-editorial-review-prose (deprecated), bmad-editorial-review-structure (deprecated), bmad-review-adversarial-general (deprecated), bmad-review-edge-case-hunter (deprecated), bmad-review-verification-gap (deprecated)

**Deprecated shim:** bmad-sprint-status (-> bmad-sprint-planning)

---

*Generated: 2026-08-24 | BMAD v6.11.0 | Repository: Daily-Motivation-Brain-Helper | Branch: SevAI_installing_bmad*
