# Leg C -- Audience Register Verification Report
## Repository: Daily-Motivation-Brain-Helper | BMAD v6.11.0
## Verifier: bmad-register-verifier subagent
## Date: 2026-08-24

---

## Part 1: Developer Guide Register Check

**File:** `manual/guides/bmad/dev-guide.md`

The developer guide is evaluated section by section for register failures: over-explanation, hedging, encouragement padding, concept re-definition, and soft analogical language.

---

### Section 1: Installation and Prerequisites

**Assessment: PASS**

Prerequisite table is dense and precise. Install command is stated without scaffolding. CLI flag reference (Section 1.3) is a clean tabular reference with type/default/description columns -- no explanatory padding. Version channel table (Section 1.5) is correct register. GitHub token note (Section 1.6) is terse and accurate.

No failures.

---

### Section 2: Repository Layout (Post-Install)

**Assessment: PASS**

Directory tree with inline comments is standard reference format. Key TOML values shown as a code block with no surrounding explanation beyond necessity.

No failures.

---

### Section 3: Module System

**Assessment: PASS**

Module catalog and manifest structure are stated factually. Community module discovery modes are documented without padding. No soft language.

No failures.

---

### Section 4: Skills Catalog

**Assessment: PASS**

Skill invocation described precisely. Skill file structure shown as a directory tree. 68-skill table is a pure catalog. Footer note about stale dirs is direct.

No failures.

---

### Section 5: Agent Roster

**Assessment: FAIL -- one failure**

**5.2 Agent Activation Sequence**

> "3. **Adopt persona** -- hardcoded identity (name, title) + customized role, communication_style, principles"

This section is correctly technical. No failure here.

**5.3 Agent Customization Surface**

The table of customizable fields and merge rules is correct register throughout, with one exception:

> "`agent.name` and `agent.title` are **read-only** -- hardcoded in SKILL.md identity. Override files with these fields have no effect."

This sentence is fine. However, reviewing the full section again: no failure is present. Retracting tentative flag.

**Revised Assessment for Section 5: PASS**

No failures.

---

### Section 6: Configuration Architecture

**Assessment: FAIL -- one failure**

**Section 6.3 Three-Layer Per-Skill Override Model** and **Section 6.4 Four-Layer Central Config Merge**

These are pure priority-stack diagrams with no padding. PASS on those.

**Section 6.5 Merge Rules**

> "| Any other array (scalars; tables with no identifier; tables mixing `code` and `id`) | Append: base items first, then team, then user |"
> "No removal mechanism: overrides cannot delete base items. To suppress a default menu item, override it by `code` with a no-op prompt/skill."

Correct register. No failure.

**Section 6.6 Configuration Resolution -- uv run Resolver**

> "Output is always JSON. Script uses only `tomllib` (stdlib, Python 3.11+). `uv run` provisions the interpreter from the `requires-python >= 3.11` header; system Python version is irrelevant."

This repeats a fact already stated in Section 1.1 (Prerequisites table note: "uv provisions its own interpreter; system Python irrelevant") and reinforced in the troubleshooting row: "Irrelevant -- `uv run` provisions its own Python 3.11+ from the script header". The restatement here is borderline but serves a local purpose (confirming it applies to this specific script invocation context). Marginal; not a hard failure.

**Revised Assessment for Section 6: PASS**

No failures.

---

### Section 7: Workflows -- Build System

**Assessment: FAIL -- one failure**

**Section 7.1 bmad-build (Interactive)**

The phase sequence and invocation example are correct register throughout.

**Section 7.2 bmad-build-auto (Unattended)**

> "Machine-facing surface of the same Build model. Requires subagent support on the platform."

Correct register.

> "**Orchestrator responsibilities:**
> - Monitor spec `status` field, not chat output
> - Read `deferred:` frontmatter for out-of-scope findings (not a backlog -- orchestrator decides routing)
> - Use `baseline_revision` for commit range identification
> - Handle `blocked` as a routing signal, not terminal failure"

Correct register. Technical, precise, no padding.

**Section 7.4 Quick Fixes Path**

> "Small, zero-blast-radius changes route directly to implementation (no upstream planning). Deferred findings written to `deferred-work.md` in implementation artifacts."

Correct register. No failure.

**Revised Assessment for Section 7: PASS**

No failures.

---

### Section 8: Planning Workflows

**Assessment: PASS**

All subsections (8.1-8.7) use tabular or enumeration format with precise descriptions. `bmad-spec` ownership note ("bmad-spec is the only writer of SPEC.md") is correct register. No soft language, no padding.

No failures.

---

### Section 9: Sprint and Project Management

**Assessment: PASS**

`sprint_plan.py` behavior is described with specificity (deterministic behaviors listed, normalization rules, `--dry-run` behavior). Retrospective verdict outcomes and gate conditions are stated precisely. No hedging or encouragement.

No failures.

---

### Section 10: Research and Ideation

**Assessment: PASS**

`bmad-deep-recon` modes table is precise. Effort presets are tabular with specific numbers. `bmad-forge-idea` session outcomes (Hardened/Killed/Clearer) are stated as defined terms without soft explanation. `bmad-brainstorming` anti-bias protocol described factually.

No failures.

---

### Section 11: Review and Quality

**Assessment: PASS**

Five-lens table is a clean reference. Constraint that editorial lenses "never challenge ideas -- only organization and expression" is stated correctly. QA workflow steps are enumerated precisely. `bmad-advanced-elicitation` catalog reference and `pick_methods.py` note are correct register.

No failures.

---

### Section 12: Customization -- Extending BMAD

**Assessment: FAIL -- one failure**

**Section 12.1 Per-Skill Agent Overrides**

The TOML examples are technically sound and correctly placed. No failure.

**Section 12.3 Central Config Overrides**

> "To rebrand an agent org-wide (affects party-mode, retrospective, advanced-elicitation roster):"

Correct register.

> "To add a fictional agent (personal):"

The heading "fictional agent" is slightly informal but is a legitimate use-case label, not register drift. No failure.

**Section 12.6 Enterprise Recipes Summary**

The recipes table is a clean tabular reference. However, examining Section 12.5:

> "Guided TOML override authoring. Scans installed customizable skills, selects correct surface (agent vs workflow), writes override file, verifies merge. Run: `/bmad-customize` or `/bmad-customize bmad-agent-dev`."

This is consistent with how the skill is described elsewhere (Section 4.3 catalog entry). No failure.

**Identified failure in Section 12.4:**

> "### 12.4 Module-Level Config Pins
>
> ```toml
> # _bmad/custom/config.toml
>
> [modules.bmm]
> planning_artifacts = "{project-root}/_bmad-output/planning-artifacts"
> user_skill_level = "expert"
> ```"

This section has no prose beyond the heading and code block. The absence of explanatory prose here is not a register failure -- it is appropriately terse for a developer reference. No failure.

**Revised Assessment for Section 12: PASS**

No failures found on close reading.

---

### Section 13: Multi-Agent Orchestration

**Assessment: PASS**

Party mode table is a clean four-row reference. Custom parties and memory behavior are described factually. Subagent dispatch architecture (Section 13.2) uses precise technical framing with no softening.

No failures.

---

### Section 14: Project Context and Brownfield Onboarding

**Assessment: PASS**

Five-intent table is precise. "What earns a line" / "What never enters" lists are correctly prescriptive, not padded. Deprecation note is factual.

No failures.

---

### Section 15: Web Bundles (Not Installed)

**Assessment: PASS**

Single paragraph, factual, correct register.

No failures.

---

### Section 16: Maintenance and Updates

**Assessment: PASS**

All subsections use command-block + brief description format. Migration steps (16.5) are an ordered list with no padding. Troubleshooting table (Section 17) is Symptom/Cause/Fix with no hedging or reassurance.

No failures.

---

### Appendices

**Assessment: PASS**

Appendix A (cross-reference), B (file inventory table), C (agent roster table), D (workflow map table), E (skills by category list) are all pure reference format with no register issues.

No failures.

---

### Developer Guide Overall

After section-by-section evaluation, **no register failures were found** in the developer guide. The guide is consistently technical throughout: tabular references, code blocks, precise behavioral descriptions, no beginner scaffolding, no hedging, no encouragement padding. The one marginal item (re-statement of `uv`'s Python provisioning behavior in Section 6.6) serves a local disambiguation purpose and does not constitute a register failure.

**Developer Guide Register Result: PASS**

---

---

## Part 2: Beginner Guide Register Check

**File:** `manual/guides/bmad/beginner-guide.md`

The beginner guide is evaluated section by section for register failures: unexplained technical terms, assumed BMAD prior knowledge, technical shorthand, and instruction gaps.

---

### Part 1: What Is BMAD?

**Section 1.1 The Big Picture**

> "Think of BMAD as a **team of AI assistants** that live inside your project and help you build software the right way -- from the first idea all the way to working, tested code."

Plain English. No unexplained terms.

> "BMAD is like hiring a small software company. You have a business analyst who understands what you need, a product manager who writes the requirements, a UX designer who designs the look and feel, an architect who designs the technical structure, and a developer who writes the code."

Analogy is plain and correct for audience. All role titles are explained inline.

**Assessment: PASS**

---

**Section 1.2 How BMAD Is Already Set Up in This Project**

> "├── _bmad/               <-- BMAD settings and configuration"

The directory tree has plain-English inline comments. All folders are labeled.

**Assessment: PASS**

---

**Section 1.3 What You Can Do With BMAD Right Now**

Six bullet points use plain-English descriptions alongside skill names. No unexplained terms.

**Assessment: PASS**

---

### Part 2: Your AI Team

**Section 2.1 Meet Your Five AI Teammates**

Agent descriptions are plain English with "when to call" guidance. No BMAD jargon without explanation.

**Assessment: PASS**

---

**Section 2.2 When to Talk to Each One**

Decision table is plain language throughout.

**Assessment: PASS**

---

**Section 2.3 How to Start a Conversation with an Agent**

**FAIL -- one failure**

> "Amelia will greet you and show her menu. You might see options like:
> - `BD` -- Build (implement a story or change)
> - `QA` -- Generate tests
> - `CR` -- Code review
> - `SP` -- Sprint planning
> - `ER` -- Epic retrospective"

The term "story" appears here as an option label ("implement a story or change") without prior explanation. The term "epic" appears in "Epic retrospective" without prior explanation. A non-developer beginner reading this section does not yet know what a "story" or an "epic" is in the BMAD/agile sense -- these are introduced much later in Part 4 (Section 4.4 explains epics and stories for the first time).

**Failure type: BMAD/agile-specific terms used before first explanation.**
**Quoted passage:** "`BD` -- Build (implement a story or change)" and "`ER` -- Epic retrospective"

Note: The note at the bottom of this section correctly says "agents give you a consistent personality and a menu; direct skills are faster when you know exactly what you want" -- this is fine plain English. The failure is limited to the menu option labels.

---

### Part 3: Getting Things Done -- The Build Skill

**Section 3.1 What /bmad-build Does (Plain English)**

Six-step plain-English description. "The AI does the heavy lifting but never makes final decisions without your approval." Correct register throughout.

**Assessment: PASS**

---

**Section 3.2 Step-by-Step: Running /bmad-build on a Real Change**

> **Step 4:** BMAD writes a plan. It will look something like this:
>
> ```
> SPEC: Add 90-minute snooze option
> Goal: Add 90 as a snooze duration after 60 in the snooze menu
> Files to change: DailyMotivation.ps1 (snooze duration array, ~line 400)
> Tests to update: Tests/Snooze.Tests.ps1 (if it exists)
> ```

The label "SPEC" appears here in a code block example without explanation. At this point in the guide, "spec" has not been introduced to the reader. A beginner sees "SPEC:" in the output and does not know what it means.

**Failure type: Technical/BMAD term ("spec") used without prior plain-English explanation.**
**Section:** 3.2 Step-by-Step
**Quoted passage:** `"SPEC: Add 90-minute snooze option"` (inside the plan preview block, Step 4)

However, examining the prose immediately following in Section 3.4:

> "After BMAD writes a plan (called a 'spec'), you need to approve it."

Section 3.4 is titled "Approving the Plan" and introduces "spec" with a parenthetical definition. The problem is that "SPEC:" appears in the Step 4 code block in Section 3.2, two sections before it is defined in Section 3.4. A reader following steps linearly would encounter "SPEC:" without knowing what it means until they reach 3.4.

**Failure type: Term used in a prior section before its plain-English definition is given.**
**Quoted passage (Section 3.2, Step 4):** `"SPEC: Add 90-minute snooze option"` -- followed two sections later by the first definition in Section 3.4: "After BMAD writes a plan (called a 'spec')..."

This is a sequencing failure. The fix is to introduce "spec" at the point of first use (Step 4), not two sections later.

---

**Section 3.3 Answering BMAD's Questions**

Plain English. No failures.

---

**Section 3.4 Approving the Plan**

Defines "spec" in parentheses ("called a 'spec'"). As noted above, this definition arrives after the term already appeared in 3.2.

**Assessment: Failure already logged above. No additional failures here.**

---

**Section 3.5 What Happens Next -- Reviewing the Result**

Plain English. No failures.

---

### Part 4: Planning Your Work

**Section 4.1 Do You Need to Plan First?**

"Multiple parts" and feature types are explained inline. No failures.

---

**Section 4.2 /bmad-prd -- Writing Requirements for a New Feature**

> "A PRD (Product Requirements Document) is a clear, structured description of what you want to build and why."

PRD is expanded and explained. Plain English. No failures.

---

**Section 4.3 /bmad-spec -- Writing a Technical Spec Across Multiple Stories**

> "A spec is a precise technical contract that says exactly what needs to be built. It is more detailed than a PRD."
>
> "Use `/bmad-spec` when you have a bigger feature that will be built in multiple steps (called 'stories')."

"Spec" is defined here. "Stories" is defined parenthetically here ("multiple steps (called 'stories')"). This is a valid introduction of both terms.

However, as flagged above, "spec" was already used without definition in Section 3.2 (Step 4) and "story" was used without definition in Section 2.3 ("implement a story or change"). Section 4.3 is the first place both terms receive plain-English definitions. This confirms the sequencing failures already logged.

No additional failures in this section itself.

---

**Section 4.4 /bmad-create-epics-and-stories -- Breaking Work Into Chunks**

> "'Epics' are big features. 'Stories' are the smaller pieces that make up an epic."

"Epic" is defined here for the first time. As flagged, "epic" appeared without definition in Section 2.3 ("Epic retrospective") before this definition.

No additional failures in this section itself; sequencing failure already logged.

---

**Section 4.5 /bmad-create-story -- Writing One Story**

Plain English. No failures.

---

**Section 4.6 /bmad-product-brief -- High-Level Project Brief**

Plain English. No failures.

---

**Section 4.7 /bmad-prfaq -- Press-Release-Style Product Validation**

> "Before investing a lot of work, you can use the PRFAQ method (from Amazon's 'Working Backwards' process). You write the press release for your finished feature as if it already exists, then answer the hardest questions customers would ask."

PRFAQ is explained in plain English inline. No failures.

---

### Part 5: UX and Design

**Section 5.1 /bmad-ux**

Plain English throughout. DESIGN.md and EXPERIENCE.md outputs are labeled with plain descriptions in parentheses. No failures.

---

**Section 5.2 Working With Sally (UX Designer)**

**FAIL**

> "Sally will greet you and show her menu. Select `CU` (Create UX) to start designing."

The code `CU` is expanded inline as "(Create UX)" -- this is acceptable. However, this section directs the reader to activate Sally directly and then select `CU`, but provides no guidance on what "her menu" will look like or how to enter `CU` (type it, press Enter, etc.). This is a minor instruction gap: the reader saw how Amelia's menu works in Section 2.3, so this may be considered sufficient prior context. The gap is marginal rather than blocking.

**Revised assessment:** The instruction gap here is mild and the prior walkthrough in Section 2.3 provides sufficient model. This is not a hard failure.

**Assessment: PASS**

---

### Part 6: Architecture

**Section 6.1 /bmad-architecture**

> "'Architecture' means the technical decisions about how the code is structured -- which functions call which, how data flows, what patterns are used."

"Architecture" defined in plain English. No failures.

---

**Section 6.2 Working With Winston (System Architect)**

> "Use the `CA` trigger (Create Architecture) from his menu."

`CA` is expanded inline. No failures, but the instruction "Use the `CA` trigger ... from his menu" assumes the reader knows how to select a menu item (they do, from Section 2.3). No gap.

**Assessment: PASS**

---

### Part 7: Managing Sprints and Progress

**Section 7.1 /bmad-sprint-planning**

> "A 'sprint' is a block of time (usually 1-2 weeks) where you focus on a specific set of stories."

"Sprint" is defined on first use. "Stories" is already defined from Part 4. No failures.

The status values (`ready-for-dev`, `in-progress`, `in-review`, `done`) are listed in a plain bullet list with no need for further expansion. No failures.

**Assessment: PASS**

---

**Section 7.2 /bmad-sprint-status -- Checking How You're Doing**

Plain English. No failures.

---

**Section 7.3 /bmad-retrospective**

> "After finishing a set of features (an 'epic'), run a retrospective..."

"Epic" defined again in parentheses (correctly consistent). No failures.

> "Use Amelia's `ER` trigger for this:"

`ER` was listed in Section 2.3 as "Epic retrospective" -- consistent. No failures.

**Assessment: PASS**

---

**Section 7.4 /bmad-checkpoint-preview**

Plain English walkthrough with numbered steps. No unexplained terms. No failures.

---

### Part 8: Research and Ideas

**Section 8.1 /bmad-forge-idea**

Plain English description of the adversarial idea test. Outcomes (Hardened/Killed/Clearer) are explained in plain English. No failures.

---

**Section 8.2 /bmad-brainstorming**

> "BMAD acts as a brainstorming coach. It uses proven techniques (like SCAMPER, reverse brainstorming, and random association) to help you generate 50-100+ ideas before organizing them."

"SCAMPER" is a named technique used without explanation. A non-developer reader would likely not know what SCAMPER is. However, it is presented as one of three examples in a list, alongside "reverse brainstorming" and "random association" which are self-explanatory. The parenthetical "like SCAMPER..." is illustrative, not instructional -- the reader does not need to know what SCAMPER is to use the skill. Marginal; not a blocking failure.

**Assessment: PASS** (marginal item noted, not blocking)

---

**Section 8.3 /bmad-deep-recon**

> "BMAD can do research three ways:
> 1. **Draft mode** -- writes a research prompt for you to run in ChatGPT, Gemini, or Perplexity
> 2. **Process mode** -- takes a research report you already have and turns it into a structured summary
> 3. **Run mode** -- does the research right here in the conversation"

All three modes are explained in plain English. No failures.

---

**Section 8.4 /bmad-domain-research, etc.**

Plain English redirect notice. No failures.

---

### Part 9: Code Review and Quality

**Section 9.1 /bmad-code-review**

Three review angles (Adversarial, Edge cases, Verification gaps) are explained in plain English. No failures.

---

**Section 9.2 /bmad-review and Its Variants**

Five lenses listed with plain-English parenthetical descriptions. No failures.

---

**Section 9.3 /bmad-editorial-review**

Plain English. No failures.

---

**Section 9.4 /bmad-qa-generate-e2e-tests**

**FAIL**

> "> **Important for this project:** This project uses **Pester v5** (not v4). The tests in `Tests/` follow Pester v5 patterns with `BeforeAll`/`AfterAll` blocks, `-ForEach` parameters, and specific mock rules from `CLAUDE.md`. BMAD knows these rules because they are in the project's CLAUDE.md file."

The terms `BeforeAll`/`AfterAll`, `-ForEach parameters`, and "mock rules" are Pester-specific syntax and testing terminology. A non-developer beginner reading this note would not understand what `BeforeAll`/`AfterAll` blocks are, what `-ForEach parameters` means, or what "mock rules" are. These are used here without any plain-English explanation.

The note is labeled "Important for this project" and appears to be informational (it tells the reader that BMAD already knows these rules), so the reader is not being asked to act on this technical content. The practical instruction is just "BMAD knows these rules." The technical details are included as reassurance/transparency, not as steps the reader must perform.

However, the terms are genuinely opaque to a non-developer reader and a beginner guide should either omit them or offer a brief plain-English gloss ("mock rules" = "rules about which parts of the code BMAD is allowed to simulate during tests").

**Failure type: Technical shorthand (`BeforeAll`/`AfterAll`, `-ForEach parameters`, "mock rules") used without plain-English explanation in a note directed at the reader.**
**Quoted passage:** "The tests in `Tests/` follow Pester v5 patterns with `BeforeAll`/`AfterAll` blocks, `-ForEach` parameters, and specific mock rules from `CLAUDE.md`."

---

**Section 9.5 /bmad-advanced-elicitation**

> "- **Pre-mortem Analysis** -- 'Assume this plan failed; what went wrong?'
> - **First Principles Thinking** -- 'Strip away all assumptions; what is actually true here?'
> - **Red Team vs. Blue Team** -- 'Attack this plan, then defend it'"

Each named method is immediately explained in plain English in quotes. No failures.

---

**Section 9.6 /bmad-correct-course**

Plain English. No failures.

---

### Part 10: Getting Help

**Section 10.1 /bmad-help**

Plain English. No failures.

---

**Section 10.2 /bmad-quick-dev**

Plain English. No failures.

---

**Section 10.3 /bmad-dev-story and /bmad-dev-auto**

> "- `/bmad-dev-story` -- Amelia implements a specific story from your sprint with checklist validation"

"Story" and "sprint" are both defined by this point in the guide (Part 4 and Part 7). "Checklist validation" is not explained but is self-evident from context. No hard failure.

**Assessment: PASS**

---

### Part 11: The Party -- Getting Multiple Agents' Views

**Section 11.1 What Party Mode Is (Plain English)**

Plain English analogy. No failures.

---

**Section 11.2 How to Invite Your Team to a Discussion**

Plain English example. No failures.

---

**Section 11.3 Four Modes for Different Situations**

Four-mode table with plain-English descriptions and "when to use it" column. No failures.

> "To start in a specific mode:
> ```text
> /bmad-party-mode --mode subagent
> ```"

**FAIL -- instruction gap**

The reader is shown a command with a `--mode` flag but has not previously been told that BMAD skills accept flags in this form. Earlier skill invocations in the guide use the plain `/skill-name` form or `/skill-name <description>` form. The `--mode subagent` syntax introduces CLI flag syntax without explaining it. A non-developer beginner may not know how to type a flag, whether there is a space, or whether `--mode subagent` and `--mode=subagent` are both valid.

**Failure type: Instruction gap -- CLI flag syntax introduced without explanation for a non-developer audience.**
**Quoted passage:** "`/bmad-party-mode --mode subagent`" (presented without any explanation that `--mode` is a flag or how flag syntax works in this context)

---

**Section 11.4 Using Fictional Agents for Fun Perspectives**

> "Edit `_bmad/custom/config.user.toml` (your personal file -- it won't be shared):"
>
> ```toml
> [agents.security-hawk]
> team = "custom"
> name = "Security Hawk"
> ...
> ```

The reader is directed to edit a TOML file. The guide says the file is the reader's "personal file." However, the guide does not explain how to create the file if it does not yet exist, or how to open it for editing. Earlier in Part 12, Section 12.2 gives detailed step-by-step instructions for creating a custom file. But here in Section 11.4, the reader is told "edit `_bmad/custom/config.user.toml`" with no guidance on how to open, find, or create the file if it doesn't exist.

**Failure type: Instruction gap -- reader is told to edit a file with no guidance on opening/creating it; this step comes before Part 12 where the process is explained.**
**Quoted passage:** "Edit `_bmad/custom/config.user.toml` (your personal file -- it won't be shared):" -- no prior instruction establishes how to edit files in this guide; Part 12 (which does explain this) comes after.

Note: The gap is real but mild. A reader who reaches this section having already read Parts 1-11 would be expected to know how to open a text file. The guide's target audience ("non-technical or semi-technical") may still find this ambiguous. This is flagged as a moderate instruction gap.

---

### Part 12: Customizing Your AI Team

**Section 12.1 What Customization Means (Plain English)**

Plain English explanation. No failures.

---

**Section 12.2 Giving an Agent Extra Facts to Remember**

> "Create a new file: `_bmad/custom/bmad-agent-dev.toml`"

The instruction is to "create a new file" but does not say how. A non-developer beginner may not know how to create a file in a specific directory (do they use a file manager? a text editor? a command?). The guide does not provide this step.

**Failure type: Instruction gap -- "create a new file" at a specific path is stated without any guidance on how to create a file.**
**Quoted passage:** "Create a new file: `_bmad/custom/bmad-agent-dev.toml`" -- no instruction on how to create the file.

This is a clear instruction gap for the target audience (non-technical users). A developer would know how to create a file; a non-developer beginner would need at least one concrete method ("use a text editor like Notepad, create a new file, and save it as...").

---

**Section 12.3 Adding a Menu Item to an Agent**

> "Create or edit `_bmad/custom/bmad-agent-architect.toml`:"

Same issue as 12.2 -- "create or edit" without guidance. Since the failure is the same type, it is subsumed under the one logged in 12.2 rather than counted separately.

---

**Section 12.4 Team Settings vs Personal Settings**

Plain-English table. No failures.

---

**Section 12.5 Running /bmad-customize to Make Changes**

> "Instead of editing TOML files by hand, you can use the customize skill:"

This note essentially acknowledges the difficulty of the TOML editing instructions in 12.2-12.3 and offers an alternative. Plain English. No failures.

---

### Part 13: Checking What Was Built (/bmad-project-context)

**Section 13.1 What /bmad-project-context Does**

> "This skill creates and maintains a special section in the `AGENTS.md` file at the root of the project. This section tells AI agents important facts about the project that they should always know -- like which commands to run for tests, known pitfalls, and special rules."

Plain English. No failures.

---

**Section 13.2 Running It for the First Time**

> "5. Only write to the `<!-- bmad:context -->...<!-- /bmad:context -->` section (everything else is preserved exactly)"

`<!-- bmad:context -->` is an HTML comment marker. A non-developer beginner would not know what this syntax is. The section says the markers define the "section" -- the concept is understandable in context, but the syntax itself is opaque. The reader does not need to type these markers (BMAD manages them), so this is informational rather than instructional. The practical implication ("everything else is preserved exactly") is stated in plain English.

This is a borderline case. The marker is shown to reassure the reader that BMAD won't overwrite their file, not to instruct them to do something. The plain-English consequence is stated alongside it. This is not a hard failure.

**Assessment: PASS** (borderline noted, not blocking)

---

**Section 13.3 Keeping It Up to Date**

Plain English. No failures.

---

### Part 14: BMAD Files Explained

**Section 14.1 What Is `_bmad/`?**

Plain-English table with a note about `_bmad/scripts/`:

> "| `_bmad/scripts/` | Python helper scripts that BMAD uses internally. Mainly `resolve_customization.py` which merges your customizations. |"

`resolve_customization.py` is mentioned by name. A beginner does not need to interact with this file; it is presented as "BMAD uses internally." No instruction gap; purely informational. No failure.

**Assessment: PASS**

---

**Section 14.2 What Is `_bmad-output/`?**

Plain English with directory tree. No failures.

---

**Section 14.3 What Are the `.claude/skills/` Files?**

Plain English. "SKILL.md" and "customize.toml" are labeled but not jargon-heavy for this context. No failures.

---

**Section 14.4 What Is `config.toml` and Why Shouldn't You Edit It Directly?**

**FAIL**

> "TOML is a specific format. Strings must be in quotes. Tables use `[section]`. Array-of-tables use `[[section]]`. Test your TOML at a validator (search 'TOML validator' online)."

Wait -- this passage is in Section 16.3 (Troubleshooting), not Section 14.4.

Section 14.4 reads:

> "`_bmad/config.toml` is automatically regenerated every time you run `npx bmad-method install`. If you edit it directly, your changes will be overwritten the next time the installer runs.
>
> Instead, put your changes in `_bmad/custom/config.toml` (for team changes) or `_bmad/custom/config.user.toml` (for personal changes). Those files are never touched by the installer."

Plain English throughout. No failures.

---

**Section 14.5 What Is `manifest.yaml`?**

Plain English with YAML block for illustration. No failures.

---

### Part 15: Installing and Updating BMAD

**Section 15.1 How BMAD Was Installed in This Project**

> "Breaking this down:
> - `npx bmad-method install` -- downloads and runs the BMAD installer
> - `--yes` -- skips interactive questions and uses defaults
> - `--directory .` -- installs in the current folder (the project root)
> - `--modules bmm` -- installs the BMad Method module (the main agile suite)
> - `--tools claude-code` -- sets up the 68 skills in `.claude/skills/`"

Each flag is explained in plain English. No failures.

> "Before running this command, `uv` (a Python package manager) was also installed:
> ```bash
> curl -LsSf https://astral.sh/uv/install.sh | sh
> ```
> `uv` is required because some BMAD features run Python scripts in the background."

`uv` is introduced as "a Python package manager" -- sufficient plain-English label. No failures.

**Assessment: PASS**

---

**Section 15.2 Updating BMAD (Quick Update vs Full Re-Install)**

Plain English description of the two update choices. No failures.

---

**Section 15.3 Adding More BMAD Modules**

Module table with plain-English descriptions. No failures.

---

**Section 15.4 Installing Community Modules**

Plain English. No failures.

---

**Section 15.5 Pinning to a Specific Version**

> "'Pinning' means locking BMAD to a specific version so it never changes unexpectedly."

"Pinning" is defined on first use. No failures.

---

### Part 16: Troubleshooting

**Section 16.1 "I See a GitHub API Rate Limit Error"**

Plain English explanation with a step-by-step fix. "Personal Access Token" is used but labeled inline as a token ("Create a Personal Access Token (no special permissions needed)"). No failures.

---

**Section 16.2 "A Tag Wasn't Found"**

Plain English. `--pin bmb=v1.7.0` syntax is shown and self-explanatory in context. No failures.

---

**Section 16.3 "My Customization Isn't Taking Effect"**

> "2. **TOML syntax error:** TOML is a specific format. Strings must be in quotes. Tables use `[section]`. Array-of-tables use `[[section]]`. Test your TOML at a validator (search 'TOML validator' online)."

TOML syntax rules are introduced here. This is the troubleshooting section; it is appropriate to explain the format here when the reader has encountered a problem with it. The guidance is plain English and actionable. No failure.

---

**Section 16.4 "uv is not found"**

Plain English with fix steps. No failures.

---

**Section 16.5 Skills Not Appearing in Claude Code**

Plain English. No failures.

---

**Section 16.6 "bmad-sprint-status Not Found"**

Plain English redirect. No failures.

---

**Section 16.7 Review Stopped After Saying "Non-Convergence"**

> "If `/bmad-build` produced a 'review repair loop exceeded 5 iterations' message, it means the AI was having trouble getting the code to a passing state in an automated loop."

"Automated loop" is self-explanatory in context. No failures.

---

**Section 16.8 I Want to Undo What BMAD Just Did**

> ```bash
> git status          # see what changed
> git diff            # see the actual changes
> git restore .       # undo all uncommitted changes
> ```

Three git commands are shown with plain-English comments explaining what each does. "Version control" is used in the closing sentence:

> "Always review BMAD's changes before committing them to version control."

"Committing" and "version control" are used without explanation. A non-developer beginner would not know what "committing to version control" means. They know from the guide that `git restore .` undoes changes, but "committing" as a concept is introduced here without definition.

**Failure type: Technical term used without plain-English explanation for the first time late in the guide.**
**Quoted passage:** "Always review BMAD's changes before committing them to version control."

The term "committing" and "version control" are never explained elsewhere in the guide. A non-developer beginner following the instruction `git restore .` may understand the mechanical action from the comment, but the final sentence ("committing them to version control") is opaque jargon.

---

### Appendix: Quick Reference Card

**Assessment: PASS**

Pure catalog of skill names with one-line plain-English descriptions. Consistent with the rest of the guide. No failures.

---

### Beginner Guide -- Summary of Failures

| # | Section | Quoted Passage | Failure Type |
|---|---|---|---|
| BG-1 | Section 2.3 -- How to Start a Conversation with an Agent | "`BD` -- Build (implement a story or change)" and "`ER` -- Epic retrospective" | BMAD-specific terms "story" and "epic" used before their first plain-English definitions (given in Sections 4.3 and 4.4) |
| BG-2 | Section 3.2 -- Step-by-Step: Running /bmad-build (Step 4) | `"SPEC: Add 90-minute snooze option"` | Term "spec" appears in a code-block example before its first plain-English definition (given in Section 3.4) |
| BG-3 | Section 9.4 -- /bmad-qa-generate-e2e-tests (Important note) | "The tests in `Tests/` follow Pester v5 patterns with `BeforeAll`/`AfterAll` blocks, `-ForEach` parameters, and specific mock rules from `CLAUDE.md`." | Technical shorthand (`BeforeAll`/`AfterAll`, `-ForEach parameters`, "mock rules") used without plain-English explanation |
| BG-4 | Section 11.3 -- Four Modes for Different Situations | "`/bmad-party-mode --mode subagent`" | Instruction gap -- CLI flag syntax (`--mode`) introduced without explanation for a non-developer audience |
| BG-5 | Section 11.4 -- Using Fictional Agents for Fun Perspectives | "Edit `_bmad/custom/config.user.toml` (your personal file -- it won't be shared):" | Instruction gap -- reader directed to edit a file with no guidance on how to open or create it (this guidance appears later in Part 12) |
| BG-6 | Section 12.2 -- Giving an Agent Extra Facts to Remember | "Create a new file: `_bmad/custom/bmad-agent-dev.toml`" | Instruction gap -- "create a new file" at a specific path stated without any guidance on how to create the file (critical for non-developer audience) |
| BG-7 | Section 16.8 -- I Want to Undo What BMAD Just Did | "Always review BMAD's changes before committing them to version control." | Technical terms "committing" and "version control" used without explanation; never defined elsewhere in the guide |

---

---

## Overall Leg C Verdict

### Developer Guide

After exhaustive section-by-section review, the developer guide is correctly and consistently registered for a technical audience throughout. No section contains over-explanation of basics, beginner hedging, encouragement padding, concept re-definition, or soft analogical language. The guide is a clean technical reference.

**Developer Guide: PASS**

### Beginner Guide

Seven discrete register failures were found across the beginner guide. Five sections contain terms used before their plain-English definitions are given (BG-1, BG-2), unexplained technical shorthand (BG-3, BG-7), and instruction gaps that would leave a non-developer reader unable to proceed without inferring missing steps (BG-4, BG-5, BG-6).

**Beginner Guide: FAIL**

---

`LEG_C_VERDICT: FAIL`

**Itemized failures:**

1. **Section 2.3** -- Terms "story" (in `BD` menu label) and "epic" (in `ER` menu label) used before first plain-English definitions, which appear in Sections 4.3 and 4.4 respectively. Failure type: BMAD-specific terms assumed before introduction.

2. **Section 3.2, Step 4** -- Term "spec" appears inside a code-block example (`SPEC: Add 90-minute snooze option`) before its first plain-English definition, which is given two sections later in Section 3.4. Failure type: term used before definition (sequencing error).

3. **Section 9.4 (Important note)** -- `BeforeAll`/`AfterAll` blocks, `-ForEach parameters`, and "mock rules" are Pester testing terms used in a note directed at the reader without any plain-English glossing. Failure type: technical shorthand without explanation.

4. **Section 11.3** -- The command `/bmad-party-mode --mode subagent` introduces CLI flag syntax (`--mode`) without explanation to a non-developer audience that has only seen plain skill invocations (`/skill-name`) and plain-text follow-ups throughout the guide. Failure type: instruction gap (CLI flag syntax unexplained).

5. **Section 11.4** -- Reader is told "Edit `_bmad/custom/config.user.toml`" before Part 12 explains how to create or edit customization files. No guidance on how to open, find, or create the file. Failure type: instruction gap (file editing step without how-to).

6. **Section 12.2** -- "Create a new file: `_bmad/custom/bmad-agent-dev.toml`" is stated without any guidance on how to create a file at a specific path. For the stated target audience (non-technical or semi-technical), this is a blocking instruction gap. Failure type: instruction gap (file creation step without how-to).

7. **Section 16.8** -- "Always review BMAD's changes before committing them to version control." Uses "committing" and "version control" as assumed-known concepts. Neither term is defined or explained anywhere in the guide. Failure type: technical term without plain-English explanation.

---

*Leg C verification complete. This report covers register only. Completeness and factual grounding are assessed in Legs A and B.*
