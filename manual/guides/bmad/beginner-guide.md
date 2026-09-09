# BMAD Method -- Beginner's Guide
## Daily-Motivation-Brain-Helper Project

> Welcome! This guide explains everything about BMAD in plain English.
> No prior knowledge of BMAD, AI agents, or automation frameworks is required.
> Every example in this guide uses the **real files in this project**.

---

## Part 1: What Is BMAD?

### 1.1 The Big Picture

Think of BMAD as a **team of AI assistants** that live inside your project and help you build software the right way -- from the first idea all the way to working, tested code.

Without BMAD, you talk to an AI assistant and it does its best, but it has to guess a lot:
- What exactly do you want built?
- How should it be designed?
- What rules does your project follow?
- What has already been done?

BMAD solves this by having **specialized AI teammates** who each know their job, follow a process, and hand work off to each other in the right order.

Here is a simple analogy: BMAD is like hiring a small software company. You have a business analyst who understands what you need, a product manager who writes the requirements, a UX designer who designs the look and feel, an architect who designs the technical structure, and a developer who writes the code. They work together and build on each other's work.

### 1.2 How BMAD Is Already Set Up in This Project

Good news -- BMAD is **already installed** in this project. You don't need to install anything to start using it.

Here is what was installed and where it lives:

```
Daily-Motivation-Brain-Helper/
├── _bmad/               <-- BMAD settings and configuration
│   ├── config.toml      <-- Project settings (project name, output folder, etc.)
│   └── ...
├── _bmad-output/        <-- Where BMAD saves its work (plans, specs, code notes)
│   ├── planning-artifacts/   <-- Plans, requirements, designs
│   └── implementation-artifacts/  <-- Build notes, test results
└── .claude/
    └── skills/          <-- 68 BMAD tools you can use (one folder per tool)
        ├── bmad-help/
        ├── bmad-build/
        ├── bmad-agent-dev/
        └── ... (65 more)
```

**About this project:** The Daily-Motivation-Brain-Helper is a Windows app (written in PowerShell) that pops up a motivational reminder at a scheduled time. It opens a folder in Windows Explorer so you can start your focused work session. The main code is in `DailyMotivation.ps1`, and tests are in the `Tests/` folder.

### 1.3 What You Can Do With BMAD Right Now

Here are some things you can do immediately:

- **Ask for help:** Type `/bmad-help` and ask any question
- **Make a code change:** Type `/bmad-build` and describe what you want
- **Plan a new feature:** Type `/bmad-prd` to write requirements
- **Talk to your AI team:** Type `/bmad-agent-dev` to talk to Amelia (the developer AI)
- **Review code changes:** Type `/bmad-code-review`
- **Brainstorm ideas:** Type `/bmad-brainstorming`

---

## Part 2: Your AI Team

### 2.1 Meet Your Five AI Teammates

BMAD gives you five AI assistants, each with a different job. They are configured specifically for this project in `_bmad/config.toml`.

---

**📊 Mary -- Business Analyst**

Mary is your research and analysis expert. She helps you understand problems before you start building solutions.

> When to call Mary: "I'm not sure if this is a good idea" or "I need to understand what users want" or "I want to brainstorm ideas."

---

**📋 John -- Product Manager**

John turns your ideas into formal requirements documents. He asks the right questions to make sure you know exactly what you're building and why.

> When to call John: "I know what I want to build, now I need to write it up properly" or "I need to define the features for a new release."

---

**🎨 Sally -- UX Designer**

Sally designs how the app looks and how users interact with it. She creates detailed specifications for screens, buttons, flows, and user interactions.

> When to call Sally: "I want to add or redesign something the user sees or clicks."

---

**🏗️ Winston -- System Architect**

Winston designs the technical structure of the code. He makes sure technical decisions are written down so all parts of the code stay consistent.

> When to call Winston: "I want to add a big new feature and need to plan how the code should be organized."

---

**💻 Amelia -- Senior Software Engineer**

Amelia writes and reviews code. She is test-first (meaning she makes sure tests pass before calling anything done) and extremely precise about file paths and acceptance criteria.

> When to call Amelia: "I want to write code, fix a bug, review code changes, or work on tests."

---

### 2.2 When to Talk to Each One

Here is a simple decision guide:

| What you want to do | Who to talk to |
|---|---|
| Explore an idea, do research | Mary (📊) |
| Write requirements for a feature | John (📋) |
| Design a screen or user flow | Sally (🎨) |
| Plan the technical structure | Winston (🏗️) |
| Write or review code | Amelia (💻) or `/bmad-build` directly |
| Not sure where to start | `/bmad-help` |

### 2.3 Two Terms You Will See Often

Before looking at the menu, two terms will keep coming up:

- **Story** -- a single, well-defined unit of work. For example: "Add a 90-minute snooze option to the popup window." One story = one focused task that a developer can complete independently.
- **Epic** -- a collection of related stories that together deliver a larger feature. For example: "Snooze improvements" might be an epic containing three stories: add 90-minute option, add custom duration input, and add snooze history log.

### 2.4 How to Start a Conversation with an Agent

In Claude Code (your AI tool), type the agent's skill name and press Enter. BMAD will activate the agent and they will introduce themselves, then show you a menu of things they can help with.

**Example -- starting a conversation with Amelia:**

```text
/bmad-agent-dev
```

Amelia will greet you and show her menu. You might see options like:
- `BD` -- Build (implement a story or change)
- `QA` -- Generate tests
- `CR` -- Code review
- `SP` -- Sprint planning
- `ER` -- Epic retrospective

You can type the short code (like `BD`) or just describe what you want in plain language. For example:

```text
BD -- I want to add a 90-minute snooze option to the snooze menu in DailyMotivation.ps1
```

Amelia will take it from there.

> **Note:** You can also skip the agent and use skills directly. For example, `/bmad-build` goes straight to building without activating Amelia's persona. Both work -- agents give you a consistent personality and a menu; direct skills are faster when you know exactly what you want.

---

## Part 3: Getting Things Done -- The Build Skill

### 3.1 What /bmad-build Does (Plain English)

`/bmad-build` is BMAD's main way of making code changes. Here is what it does, step by step:

1. **It asks what you want** (or you tell it right away)
2. **It writes a plan** -- a short document saying exactly what it will change and why
3. **You approve the plan** -- you read it and say "yes, do it" or "change this part"
4. **It writes the code** -- it does the actual programming
5. **It checks its own work** -- it reviews what it built, looking for bugs and problems
6. **It shows you what changed** -- you can look at the changes before accepting them

The whole point of this process is that you stay in control. The AI does the heavy lifting but never makes final decisions without your approval.

### 3.2 Step-by-Step: Running /bmad-build on a Real Change in This Project

**Goal:** Add a 90-minute snooze option to the Snooze button in `DailyMotivation.ps1`.

**Step 1:** Open Claude Code in the project folder (you should already be in `/home/vercel-sandbox/Daily-Motivation-Brain-Helper` or the equivalent on your machine).

**Step 2:** Type this:

```text
/bmad-build Add a 90-minute snooze option to the snooze menu. Currently DailyMotivation.ps1 offers 5, 15, 30, and 60 minute snooze options. Add 90 minutes as a fifth option.
```

**Step 3:** BMAD may ask clarifying questions. For example:

```
bmad-build: Should the 90-minute option appear before or after the 60-minute option?
```

Answer naturally:

```
After 60 minutes -- so the order is: 5, 15, 30, 60, 90.
```

**Step 4:** BMAD writes a plan. BMAD calls this plan a **"spec"** (short for "specification" -- a precise description of exactly what will be built and how). It will look something like this:

```
SPEC: Add 90-minute snooze option
Goal: Add 90 as a snooze duration after 60 in the snooze menu
Files to change: DailyMotivation.ps1 (snooze duration array, ~line 400)
Tests to update: Tests/Snooze.Tests.ps1 (if it exists)
```

You will see a message like: **"Does this look right? Type 'approve' to continue or describe what to change."**

**Step 5:** If it looks good, type:

```
approve
```

**Step 6:** BMAD writes the code, reviews it, and shows you:

```
Changes made:
- DailyMotivation.ps1: added 90 to snooze options array
- Tests updated (if applicable)

Review findings: None critical.
```

### 3.3 Answering BMAD's Questions

BMAD will sometimes ask you questions before writing code. This is normal and good -- it is making sure it understands exactly what you want before doing work.

Tips for answering:
- Be specific: "After the 60-minute option" is better than "somewhere near the end"
- Reference file names if you know them: "In `DailyMotivation.ps1`"
- If you don't know the answer, say "I'm not sure, use your best judgment"

### 3.4 Approving the Plan

After BMAD writes a plan (called a "spec"), you need to approve it. Read it carefully and make sure:
- The goal is stated correctly
- The files it will change make sense
- Nothing unexpected is included

If something is wrong, tell BMAD what to change:

```
Change the goal -- I want the 90-minute option to only appear on weekdays, not weekends.
```

BMAD will update the plan and show it to you again.

### 3.5 What Happens Next -- Reviewing the Result

After BMAD finishes building:
- It will show you a summary of what changed
- It will note if it found any problems (and whether it fixed them)
- It will save a record of its work in `_bmad-output/implementation-artifacts/`

You can then look at the actual code changes and decide whether to keep them.

---

## Part 4: Planning Your Work

### 4.1 Do You Need to Plan First?

Not always. Here is a simple guide:

| Change type | Do you need to plan? |
|---|---|
| Small bug fix | No -- just use `/bmad-build` directly |
| Adding a small feature | Maybe -- try `/bmad-build` first; add planning if it gets complicated |
| Big new feature (multiple parts) | Yes -- start with John (📋) for requirements |
| Redesigning the user interface | Yes -- involve Sally (🎨) for UX design |
| Changing how the code is organized | Yes -- involve Winston (🏗️) for architecture |

When in doubt, type `/bmad-help` and describe your situation. BMAD will recommend what to do.

### 4.2 /bmad-prd -- Writing Requirements for a New Feature

A PRD (Product Requirements Document) is a clear, structured description of what you want to build and why. John (the PM) helps you write it.

**Example -- writing a PRD for adding a context menu shortcut to the Windows right-click menu:**

```text
/bmad-prd
```

John will ask you questions like:
- "What problem does this solve?"
- "Who will use this feature?"
- "What should happen when the user right-clicks a folder and chooses 'Set as tomorrow's folder'?"

After the conversation, John saves the requirements to:
```
_bmad-output/planning-artifacts/prd.md
```

That file becomes the guide for everything else -- UX design, architecture decisions, and the actual code.

> **Note:** You can also tell John what you want right away:
> ```text
> /bmad-prd Create a PRD for adding a "Set as tomorrow's folder" option to the Windows
> right-click context menu for folder icons.
> ```

### 4.3 /bmad-spec -- Writing a Technical Spec Across Multiple Stories

A spec is a precise technical contract that says exactly what needs to be built. It is more detailed than a PRD.

Use `/bmad-spec` when you have a bigger feature that will be built in multiple steps (called "stories").

**Example -- creating a spec for adding a notification sound feature:**

```text
/bmad-spec Create a spec for adding a customizable notification sound when the popup appears.
The user should be able to pick from 3 built-in sounds or use a custom .wav file.
```

BMAD will produce a file at:
```
_bmad-output/specs/spec-notification-sound/SPEC.md
```

This spec can then be used to automatically build each part in order using `/bmad-build-auto`.

### 4.4 /bmad-create-epics-and-stories -- Breaking Work Into Chunks

"Epics" are big features. "Stories" are the smaller pieces that make up an epic.

For example, "Add a customizable notification sound" (epic) might break into:
- Story 1: Add sound playback when popup appears
- Story 2: Add sound selection UI to settings
- Story 3: Support custom .wav file paths

To break your requirements into stories:

```text
/bmad-create-epics-and-stories
```

BMAD reads your PRD and creates epic files in:
```
_bmad-output/planning-artifacts/
```

### 4.5 /bmad-create-story -- Writing One Story

If you want to write just one story (a single unit of work), use:

```text
/bmad-create-story Write a story for adding the 90-minute snooze option to DailyMotivation.ps1
```

### 4.6 /bmad-product-brief -- High-Level Project Brief

A product brief is a 1-2 page summary of what you want to build. It is shorter and less detailed than a PRD.

Use it when you have a clear idea but just need to document it quickly before diving into details.

```text
/bmad-product-brief I want to add a "Focus Mode" that blocks all new MotivationTasks during
a user-defined work window (like 9am-5pm on weekdays).
```

The brief is saved to `_bmad-output/planning-artifacts/brief.md`.

### 4.7 /bmad-prfaq -- Press-Release-Style Product Validation

Before investing a lot of work, you can use the PRFAQ method (from Amazon's "Working Backwards" process). You write the press release for your finished feature as if it already exists, then answer the hardest questions customers would ask.

This is great for catching weak ideas before you build them.

```text
/bmad-prfaq I want to validate the idea of adding a "Shared team schedule" feature where
multiple users on the same Windows network can see each other's scheduled motivation tasks.
```

---

## Part 5: UX and Design

### 5.1 /bmad-ux -- Designing the User Interface

Use this when you want to change how something looks or how a user interacts with it.

**Example -- redesigning the main scheduling window:**

```text
/bmad-ux Design an updated main window for DailyMotivation.ps1. Currently it shows a folder
picker, a Today/Tomorrow selector, and a task list. I want to add a "Upcoming" panel on the
right side showing the next 3 scheduled tasks.
```

Sally will ask questions about the visual design and user flow, then produce two files:
- `_bmad-output/planning-artifacts/DESIGN.md` -- what it looks like (screens, colors, layout)
- `_bmad-output/planning-artifacts/EXPERIENCE.md` -- how it behaves (user flows, button actions, error states)

### 5.2 Working With Sally (UX Designer)

To activate Sally directly:

```text
/bmad-agent-ux-designer
```

Sally will greet you and show her menu. Select `CU` (Create UX) to start designing.

---

## Part 6: Architecture

### 6.1 /bmad-architecture -- Documenting How the Code Is Organized

"Architecture" means the technical decisions about how the code is structured -- which functions call which, how data flows, what patterns are used.

In `DailyMotivation.ps1`, there are already important architecture decisions documented in `docs/architecture/adr-005-mandate-history.md`. For example: the rule that `New-ScheduledTaskPrincipal` must use `LogonType Interactive` (not S4U).

Use `/bmad-architecture` when:
- You are adding a big new feature and need to decide how the code should be organized
- You want to document an important technical decision
- You want to prevent future developers (or AI agents) from making inconsistent choices

**Example -- documenting the popup-to-main mode communication design:**

```text
/bmad-architecture Document the architecture of how popup mode and main mode communicate
through the PopupConfig file (popup_config.json). Include why a file-based approach was chosen
over other options like named pipes or registry.
```

Winston will produce an architecture document at:
```
_bmad-output/planning-artifacts/ARCHITECTURE-SPINE.md
```

### 6.2 Working With Winston (System Architect)

To talk to Winston directly:

```text
/bmad-agent-architect
```

Use the `CA` trigger (Create Architecture) from his menu.

---

## Part 7: Managing Sprints and Progress

### 7.1 /bmad-sprint-planning -- What Work to Do This Sprint

A "sprint" is a block of time (usually 1-2 weeks) where you focus on a specific set of stories.

Before starting implementation, BMAD can check if your plan is ready:

```text
/bmad-sprint-planning check implementation readiness
```

BMAD will look at your planning documents (`_bmad-output/planning-artifacts/`) and answer: is everything clear enough to start building? It returns:
- **PASS** -- everything looks ready
- **CONCERNS** -- some things might be unclear (you decide whether to proceed)
- **FAIL** -- something important is missing (BMAD tells you what to fix first)

To generate a tracking file:

```text
/bmad-sprint-planning run sprint planning
```

This creates `sprint-status.yaml` in `_bmad-output/implementation-artifacts/`.

> **Tip -- dry run:** If you want to see what sprint-status.yaml *would* look like without actually writing it, ask BMAD: "show me a dry run of sprint planning." BMAD will report what entries are new, which are in sync, and which are orphaned (stories in the file but no longer in any epic), without making any changes. It tracks each story's status:
- `ready-for-dev` -- story is written and ready to be built
- `in-progress` -- being built right now
- `in-review` -- built, waiting for code review
- `done` -- complete

### 7.2 /bmad-sprint-status -- Checking How You're Doing

```text
/bmad-sprint-planning show sprint status
```

This shows you a summary: how many stories are done, what's in progress, what's blocked, and what the recommended next step is.

### 7.3 /bmad-retrospective -- What Went Well, What to Improve

After finishing a set of features (an "epic"), run a retrospective to review what was built:

```text
/bmad-retrospective
```

BMAD reads the actual code changes and test results (not just your memory), then:
- Lists what was built vs. what was planned
- Finds patterns in the code (like a function that grew too large)
- Gives an **accepted** / **accepted-with-open-items** / **rejected** verdict

Use Amelia's `ER` trigger for this:

```text
/bmad-agent-dev
ER
```

For fully automated use (for example, if you want to run it in a script with no human interaction), add `-H <epic-name>`:

```text
/bmad-retrospective -H epic-1
```

This "headless" mode produces a verdict based on evidence alone, with no interactive discussion.

### 7.4 /bmad-checkpoint-preview -- Reviewing Before Finishing

After `bmad-build` finishes, you can do a structured review of all the changes:

```text
checkpoint
```

(Type this in the same conversation after bmad-build finishes.)

BMAD walks you through:
1. What changed and why (one-sentence summary)
2. The changes organized by topic (not just file-by-file)
3. The 2-5 highest-risk spots to check carefully
4. How to manually verify the change works
5. Approve / rework decision

---

## Part 8: Research and Ideas

### 8.1 /bmad-forge-idea -- Testing If Your Idea Is Good

Before investing time in building something, you can test whether the idea is worth it.

**Example -- testing the idea of adding a dark mode:**

```text
/bmad-forge-idea I want to add a dark mode to the DailyMotivation.ps1 popup window.
```

BMAD will play the role of a tough but fair critic. It will:
- Ask you one challenging question at a time
- Put forward its own answer (that you can disagree with)
- Bring in different perspectives to challenge your thinking

The session ends with one of three outcomes:
- **Hardened** -- the idea survived the questions; BMAD saves it as `forged-idea.md` for use in planning
- **Killed** -- the idea has a fatal flaw; better to find out now
- **Clearer** -- the idea is still good but now you understand it better

Every session also produces a `forge-report.html` you can save or share.

### 8.2 /bmad-brainstorming -- Generating New Ideas Together

```text
/bmad-brainstorming
```

BMAD acts as a brainstorming coach. It uses proven techniques (like SCAMPER, reverse brainstorming, and random association) to help you generate 50-100+ ideas before organizing them.

**Example:**

```text
/bmad-brainstorming I want to brainstorm ways to make the Daily-Motivation-Brain-Helper app
more useful for users who work from home.
```

BMAD guides you through different techniques, asking questions and building on your answers. The session is saved as a `brainstorm.html` file.

### 8.3 /bmad-deep-recon -- Deep Research on a Topic

Use this when you need real, verified information before making a decision.

**Example:**

```text
/bmad-deep-recon Research Windows Task Scheduler limitations for non-admin users running
interactive tasks. What are the actual error conditions and workarounds?
```

BMAD can do research three ways:
1. **Draft mode** -- writes a research prompt for you to run in ChatGPT, Gemini, or Perplexity
2. **Process mode** -- takes a research report you already have and turns it into a structured summary
3. **Run mode** -- does the research right here in the conversation

In run mode you can also control how thoroughly BMAD checks its sources: normal (spot-checks the most important claims), high (checks all critical claims and tests the main conclusions), or max (checks everything). Just say "use high verification" or "thorough checking" when running research.

The result is saved as `research.md` with citations.

### 8.4 /bmad-domain-research, /bmad-technical-research, /bmad-market-research

These are old names that still work. They all now go to `/bmad-deep-recon` automatically. Just use `/bmad-deep-recon` directly.

---

## Part 9: Code Review and Quality

### 9.1 /bmad-code-review -- Reviewing Code Changes

Use this to get a structured review of changes you (or someone else) made.

**Example -- reviewing recent changes to DailyMotivation.ps1:**

```text
/bmad-code-review Review the recent changes to DailyMotivation.ps1 focusing on the
catch block in New-MotivationTask (around line 801).
```

BMAD reviews the code from three angles:
1. **Adversarial** -- forces itself to find at least 10 potential problems
2. **Edge cases** -- checks every branching condition and boundary
3. **Verification gaps** -- identifies behavior that could break silently with no test catching it

It produces a structured list of findings.

### 9.2 /bmad-review and Its Variants

`/bmad-review` is the full review tool with five "lenses":
- **Adversarial** -- finds problems aggressively
- **Edge case** -- checks boundaries and special cases
- **Verification gap** -- finds behavior that tests might miss
- **Structure** (for documents) -- is the document organized well?
- **Prose** (for documents) -- is it written clearly?

The old skills `/bmad-review-adversarial-general`, `/bmad-review-edge-case-hunter`, and `/bmad-review-verification-gap` still work but redirect to `/bmad-review`.

### 9.3 /bmad-editorial-review -- Reviewing Written Documents

If you have written a PRD, architecture document, or any other document and want feedback on how it reads:

```text
/bmad-editorial-review Review the PRD I just wrote for clarity and structure.
```

The old skills `/bmad-editorial-review-prose` and `/bmad-editorial-review-structure` also redirect here.

### 9.4 /bmad-qa-generate-e2e-tests -- Creating Automated Tests

BMAD can look at the code and generate tests for you.

**Example -- creating tests for the Snooze feature:**

```text
/bmad-qa-generate-e2e-tests Generate tests for the snooze functionality in DailyMotivation.ps1.
```

BMAD will:
1. Detect the test framework (Pester v5 for this project)
2. Identify the features to test
3. Write the test code
4. Run the tests and fix any failures

Tests are saved in the `Tests/` folder following the existing patterns.

> **Important for this project:** This project uses **Pester v5** -- a specific version of the PowerShell testing tool. Tests in `Tests/` follow particular rules documented in `CLAUDE.md`: for example, only certain functions (like `Register-ScheduledTask`) can be faked ("mocked") during tests, while others must be left real. BMAD knows these rules because they are in `CLAUDE.md`, which BMAD reads automatically.

### 9.5 /bmad-advanced-elicitation -- Improving Your Drafts

After you (or BMAD) produces any document or output, you can use advanced elicitation to make it better:

```text
/bmad-advanced-elicitation
```

BMAD suggests several thinking methods suited to your content. For example:
- **Pre-mortem Analysis** -- "Assume this plan failed; what went wrong?"
- **First Principles Thinking** -- "Strip away all assumptions; what is actually true here?"
- **Red Team vs. Blue Team** -- "Attack this plan, then defend it"

You pick a method, BMAD applies it, and you get a better version.

### 9.6 /bmad-correct-course -- Getting Back on Track

If you are in the middle of building something and a significant change comes up (a new requirement, a discovery that changes the plan), use:

```text
/bmad-correct-course
```

BMAD helps you update the plan and decide whether to continue, adjust, or start over.

---

## Part 10: Getting Help

### 10.1 /bmad-help -- Your First Stop for Any Question

Whenever you are unsure what to do next, type:

```text
/bmad-help
```

Or ask a specific question:

```text
/bmad-help I want to add a test for the snooze feature in DailyMotivation.ps1. Where do I start?
```

```text
/bmad-help We just finished Epic 1. What should we do now?
```

```text
/bmad-help Show me what workflows are available.
```

`bmad-help` looks at your project (reads `_bmad-output/`, `_bmad/`, and `docs/`) and gives you context-aware advice. It also runs automatically at the end of many BMAD workflows to tell you what to do next.

### 10.2 /bmad-quick-dev -- Fast, Direct Code Changes

For very small changes where you don't want to go through the full build process:

```text
/bmad-quick-dev Fix the typo in the "Already Scheduled" dialog message in DailyMotivation.ps1.
```

This is faster than `/bmad-build` but skips some of the planning and review steps.

### 10.2b /bmad-build-auto -- What the Statuses Mean

`/bmad-build-auto` is the "hands-free" version of build. It runs automatically and saves its progress to a "spec file" (see Section 3.2). You can check the status of a build-auto run by looking at that spec file's status field:

| Status | Plain English meaning |
|---|---|
| `draft` | Plan written, not yet ready to build |
| `ready-for-dev` | Plan approved, waiting to build |
| `in-progress` | Building right now |
| `in-review` | Build done, checking the result |
| `done` | Finished successfully |
| `blocked` | Stopped -- needs human attention before it can continue |

If a run shows `blocked`, look at the spec file for the reason. Common reasons: the request was unclear, the AI ran into an unexpected situation, or the review found a problem it could not fix automatically.

### 10.3 /bmad-dev-story and /bmad-dev-auto

- `/bmad-dev-story` -- Amelia implements a specific story from your sprint with checklist validation
- `/bmad-dev-auto` -- A faster, more autonomous version of dev-story for straightforward tasks

Use Amelia's `BD` trigger for most implementation work:

```text
/bmad-agent-dev
BD -- Implement Story 2.1 from the planning artifacts
```

---

## Part 11: The Party -- Getting Multiple Agents' Views

### 11.1 What Party Mode Is (Plain English)

"Party mode" means getting all your AI teammates into one conversation at the same time. Instead of talking to Mary, then John, then Winston one at a time, you put them all in the same room and they talk to you -- and each other.

This is useful when you have a question that different people would answer differently. The PM might think about user needs. The Architect might think about technical constraints. The Developer might think about how long it will take. Party mode surfaces all those perspectives at once.

### 11.2 How to Invite Your Team to a Discussion

```text
/bmad-party-mode
```

**Example -- asking the whole team about adding a snooze limit:**

```text
/bmad-party-mode
```

Then type your question:

```text
Should we add a maximum snooze count limit to DailyMotivation.ps1? Currently a user can
snooze indefinitely. I'm thinking of capping it at 5 snoozes per task.
```

Mary might focus on user experience. John might ask about user research. Winston might consider the technical implementation. Amelia might bring up what tests would be needed. They will agree, disagree, and build on each other's ideas.

The conversation stays open until you end it. You can ask follow-up questions, pull one voice forward ("Winston, what do you think about the technical side?"), or change the topic.

### 11.3 Four Modes for Different Situations

Party mode can run four different ways:

| Mode | What it does | When to use it |
|---|---|---|
| `session` (default) | One AI voice speaks as each character | Quick conversations, brainstorming |
| `auto` | Like session most of the time, but uses real separate AI agents when independence matters | Best of both worlds |
| `subagent` | Separate AI for each character every time | When you need truly independent opinions (like a review panel) |
| `agent-team` | Characters talk to each other directly (Claude Code only) | Hands-off team discussion |

To start in a specific mode, add `--mode` followed by the mode name. (The `--` prefix is how you pass options to a command; `mode` is the option name; `subagent` is the value you are setting it to.)

```text
/bmad-party-mode --mode subagent
```

### 11.4 Using Fictional Agents for Fun Perspectives

You can add custom or fictional characters to your team. For example, to add a persona who always thinks about security.

> **How to edit a file:** Open the file in any text editor (Notepad on Windows, TextEdit on Mac, VS Code, etc.). The file is at `_bmad/custom/config.user.toml` inside the project folder. If the file does not exist yet, create it -- see the note in Part 12.

Edit (or create) `_bmad/custom/config.user.toml` (your personal file -- it won't be shared with others):

```toml
[agents.security-hawk]
team = "custom"
name = "Security Hawk"
title = "Security Reviewer"
icon = "🦅"
description = "Paranoid security reviewer. Assumes every input is malicious. Asks 'what if an attacker sends this?' for every feature."
```

Then in party mode, you can ask "bring in Security Hawk" and that character will join.

---

## Part 12: Customizing Your AI Team

### 12.1 What Customization Means (Plain English)

"Customizing" BMAD means telling your AI teammates specific things about this project that they should always remember -- rules they should follow, facts about the codebase, or ways they should work that are different from the defaults.

For example, you might want to tell Amelia: "In this project, tests always use Pester v5. Never mock `New-ScheduledTaskAction` or `New-ScheduledTaskTrigger`. Always check CLAUDE.md before writing tests."

Once you customize Amelia, she will remember those rules in every conversation, forever, without you having to remind her each time.

### 12.2 Giving an Agent Extra Facts to Remember

**Example -- telling Amelia about this project's Pester v5 testing rules:**

> **How to create a new file:** In VS Code (or any file explorer), navigate to the `_bmad/custom/` folder inside the project. Right-click and choose "New File". Name it `bmad-agent-dev.toml`. Then open it and paste the content below. On the command line, you can use `touch _bmad/custom/bmad-agent-dev.toml` to create an empty file, then open it in an editor.

Create a new file: `_bmad/custom/bmad-agent-dev.toml`

Add this content:

```toml
[agent]
persistent_facts = [
  "This project uses Pester v5. Do NOT mock New-ScheduledTaskAction, New-ScheduledTaskTrigger, New-ScheduledTaskSettings, or New-ScheduledTaskPrincipal. Only mock Register-ScheduledTask, Get-ScheduledTask, and Unregister-ScheduledTask.",
  "Never declare a bug fix complete based on Linux CI results alone. Windows 10/11 live testing is required for any fix involving Register-ScheduledTask.",
  "file:{project-root}/CLAUDE.md",
]
```

After saving this file, every time you activate Amelia (`/bmad-agent-dev`), she will automatically know these rules without you having to tell her.

> **Note:** `{project-root}` is a special placeholder that BMAD replaces with the actual path to this project folder. The `file:` prefix means "load the contents of this file as facts."

### 12.3 Adding a Menu Item to an Agent

You can add custom shortcuts to any agent's menu. For example, add a shortcut to Winston's menu that checks the Task Scheduler architecture:

Create or edit `_bmad/custom/bmad-agent-architect.toml`:

```toml
[[agent.menu]]
code = "TS"
description = "Check Task Scheduler integration against ADR-005 rules"
prompt = """
Read docs/architecture/adr-005-mandate-history.md.
Then check DailyMotivation.ps1 around line 801 (New-MotivationTask function).
Verify that New-ScheduledTaskPrincipal uses -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited.
Report any deviations.
"""
```

Now when you activate Winston and type `TS`, he will run that check automatically.

### 12.4 Team Settings vs Personal Settings

BMAD has two types of override files:

| File name | Who it applies to | Saved to git? | Example use |
|---|---|---|---|
| `bmad-agent-dev.toml` | Everyone on the team | Yes (committed) | Project rules, coding standards |
| `bmad-agent-dev.user.toml` | Just you | No (hidden from git) | Personal preferences, private reminders |

Put rules that everyone should follow in the team file. Put personal preferences in the user file.

### 12.5 Reinforcing Rules in CLAUDE.md (for Extra Safety)

BMAD loads your customizations when you activate a skill. But this project also has a `CLAUDE.md` file at the root that Claude Code reads automatically at the start of every session -- even when no BMAD skill is active.

If there is a rule so important that you want it followed even in ordinary conversations (not just during BMAD workflows), add it to `CLAUDE.md`. This project already has critical rules there: for example, "never change the Task Scheduler principal settings without a live Windows test."

**Summary:** `_bmad/custom/bmad-agent-dev.toml` affects Amelia's behavior when you run the Amelia skill. `CLAUDE.md` affects Claude Code's behavior all the time.

### 12.6 Running /bmad-customize to Make Changes

Instead of editing TOML files by hand, you can use the customize skill:

```text
/bmad-customize
```

BMAD will ask you which agent or workflow you want to customize, what you want to change, and then write the override file for you. It also verifies that the change took effect.

---

## Part 13: Checking What Was Built (/bmad-project-context)

### 13.1 What /bmad-project-context Does

This skill creates and maintains a special section in the `AGENTS.md` file at the root of the project. This section tells AI agents important facts about the project that they should always know -- like which commands to run for tests, known pitfalls, and special rules.

This project already has an `AGENTS.md` file with rules from `CLAUDE.md`. `bmad-project-context` helps keep those rules up to date and verified.

### 13.2 Running It for the First Time

If the project does not have a BMAD-managed context section yet:

```text
/bmad-project-context
```

BMAD will:
1. Read what is already in `AGENTS.md` and `CLAUDE.md`
2. Ask you what additional rules you want followed
3. Verify that every command it mentions actually works
4. Show you the final block before writing it
5. Only write to the `<!-- bmad:context -->...<!-- /bmad:context -->` section (everything else is preserved exactly)

### 13.3 Keeping It Up to Date

After making significant changes to the codebase:

```text
/bmad-project-context refresh the context
```

Or when an AI agent made the same mistake twice:

```text
/bmad-project-context the agent keeps trying to run tests without dot-sourcing DailyMotivation.ps1 -NoRun first
```

BMAD adds that observation as a known pitfall in the context block.

---

## Part 14: BMAD Files Explained

### 14.1 What Is `_bmad/`?

The `_bmad/` folder is where BMAD stores its settings, configuration, and module files. Here is a plain-English tour:

| File | What it does |
|---|---|
| `_bmad/config.toml` | Main settings file. Has the project name ("Daily-Motivation-Brain-Helper"), output folder, and info about your five AI agents. **Don't edit this directly** -- the installer overwrites it. |
| `_bmad/config.user.toml` | Personal settings (your name, preferred language). Also overwritten by installer. |
| `_bmad/bmm/config.yaml` | Settings for the BMad Method module (where to save artifacts, skill level, etc.) |
| `_bmad/_config/manifest.yaml` | Records exactly what version of BMAD is installed. Used for reproducibility. |
| `_bmad/custom/config.toml` | **This is where you put team-wide setting overrides.** The installer never touches this file. |
| `_bmad/custom/config.user.toml` | **Your personal setting overrides.** Git-ignored (not shared). |
| `_bmad/scripts/` | Python helper scripts that BMAD uses internally. Mainly `resolve_customization.py` which merges your customizations. |

### 14.2 What Is `_bmad-output/`?

This is where BMAD saves everything it produces:

```
_bmad-output/
├── planning-artifacts/       <-- Plans, requirements, designs
│   ├── prd.md                <-- Product Requirements Document
│   ├── ARCHITECTURE-SPINE.md <-- Architecture decisions
│   └── epic-1.md, etc.       <-- Epic and story files
└── implementation-artifacts/ <-- Build notes and tracking
    ├── spec-snooze-90min.md   <-- Build spec for a change
    └── sprint-status.yaml     <-- Tracks story progress (created by /bmad-sprint-planning)
```

You generally do not need to edit these files -- BMAD manages them. But you can read them to understand what BMAD is planning.

### 14.3 What Are the `.claude/skills/` Files?

The `.claude/skills/` folder contains 68 sub-folders, one for each BMAD skill. Each sub-folder has:
- `SKILL.md` -- the instructions that tell BMAD what to do when you run this skill
- `customize.toml` (optional) -- what you can customize about this skill
- Other supporting files

You do not need to edit these files. They are managed by the BMAD installer.

### 14.4 What Is `config.toml` and Why Shouldn't You Edit It Directly?

`_bmad/config.toml` is automatically regenerated every time you run `npx bmad-method install`. If you edit it directly, your changes will be overwritten the next time the installer runs.

Instead, put your changes in `_bmad/custom/config.toml` (for team changes) or `_bmad/custom/config.user.toml` (for personal changes). Those files are never touched by the installer.

### 14.5 What Is `manifest.yaml`?

`_bmad/_config/manifest.yaml` is a record of exactly what is installed:

```yaml
modules:
  - name: bmm
    version: v6.11.0
    channel: stable
    source: built-in
```

This is useful for making sure everyone on the team has the same version of BMAD. If you need to set up BMAD on another machine with exactly the same version, you can use the version numbers from this file.

---

## Part 15: Installing and Updating BMAD

### 15.0 Starting With an Existing Project (Brownfield)

If you are adding BMAD to a project that already exists (with code already written, like this one), the recommended sequence is:

1. **Clean up old planning files** -- if you have PRD documents or epic files from a previous process, move them to an archive or `_bmad-output/planning-artifacts/` with clear names. Don't leave stale documents in `docs/`.
2. **Run bmad-project-context** (see Part 13) -- this sets up your `AGENTS.md` for AI agents to follow the project's rules.
3. **Keep `docs/` accurate** -- BMAD's `bmad-help` reads the `docs/` folder to give you relevant advice. The more current it is, the better BMAD's suggestions will be.
4. **Choose how much planning to do** -- for a small change, go straight to `/bmad-build`. For a large feature, work through planning first (Part 4). When unsure, ask `/bmad-help`.

### 15.1 How BMAD Was Installed in This Project

BMAD was installed using this command:

```bash
npx bmad-method install --yes --directory . --modules bmm --tools claude-code
```

Breaking this down:
- `npx bmad-method install` -- downloads and runs the BMAD installer
- `--yes` -- skips interactive questions and uses defaults
- `--directory .` -- installs in the current folder (the project root)
- `--modules bmm` -- installs the BMad Method module (the main agile suite)
- `--tools claude-code` -- sets up the 68 skills in `.claude/skills/`

Version installed: BMAD Method v6.11.0 (as recorded in `_bmad/_config/manifest.yaml`).

Before running this command, `uv` (a Python package manager) was also installed:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

`uv` is required because some BMAD features run Python scripts in the background.

### 15.2 Updating BMAD (Quick Update vs Full Re-Install)

To check for and apply updates:

```bash
npx bmad-method install
```

(Run this in the project folder.)

BMAD will ask you to choose:

**Quick Update** -- Fast. Applies small fixes and improvements automatically. Use this for routine maintenance.

**Modify Install** -- Full re-setup. Use this if you want to add new modules, change settings, or make bigger changes.

### 15.3 Adding More BMAD Modules (bmb, cis, gds, tea)

Currently this project has only the `bmm` (BMad Method) module. You can add more:

| Module code | Module name | What it adds |
|---|---|---|
| `bmb` | BMad Builder | Tools for creating your own custom BMAD skills and agents |
| `cis` | Creative Intelligence Suite | More brainstorming and creativity tools |
| `gds` | Game Dev Studio | Game-specific workflows (not relevant for this project) |
| `tea` | Test Architect | Advanced testing strategy and enterprise test workflows |

To add the Test Architect module:

```bash
npx bmad-method install --yes --action update --modules bmm,tea
```

> **Note:** List ALL modules you want, including the ones already installed. `--modules bmm,tea` means "have bmm and tea installed." If you only write `--modules tea`, bmm will be removed.

### 15.4 Installing Community Modules

Community members have created custom BMAD modules. To browse and install them:

```bash
npx bmad-method install
```

Then when asked "Would you like to browse community modules?" select Yes.

You can also install directly from a GitHub repository:

```bash
npx bmad-method install --yes --modules bmm --custom-source https://github.com/example/my-bmad-module
```

### 15.5 Pinning to a Specific Version (Why and How)

"Pinning" means locking BMAD to a specific version so it never changes unexpectedly. This is useful for team environments where everyone needs the exact same version.

```bash
npx bmad-method install --yes --modules bmm,tea --pin tea=v2.1.0 --tools claude-code
```

After pinning, the version is recorded in `manifest.yaml` and won't be upgraded automatically. To change a pinned version, re-run the installer with a new `--pin` value.

> **Note:** The `bmm` module cannot be pinned (it is bundled with the installer). Only external modules like `bmb`, `cis`, `gds`, and `tea` can be pinned.

---

## Part 16: Troubleshooting

### 16.1 "I See a GitHub API Rate Limit Error"

**What it means:** BMAD downloads module versions from GitHub. GitHub allows 60 free downloads per hour per IP address. If you (or others on your network) have hit that limit, you see this error.

**Fix:**

1. Create a free GitHub account (if you do not have one) at github.com
2. Go to github.com/settings/tokens and create a Personal Access Token (no special permissions needed)
3. Set it as an environment variable:

```bash
export GITHUB_TOKEN=your_token_here
```

4. Re-run the install command

### 16.2 "A Tag Wasn't Found"

**What it means:** You used `--pin bmb=v1.7.0` but that exact version does not exist in the BMAD repository.

**Fix:** Go to the module's GitHub releases page and check what versions are available. Use an existing version number.

### 16.3 "My Customization Isn't Taking Effect"

**What it means:** You edited a file in `_bmad/custom/` but the agent is not following the new rules.

**Common causes and fixes:**

1. **Wrong file name:** The file must be named exactly like the skill folder. For example, to customize `bmad-agent-dev`, the file must be `_bmad/custom/bmad-agent-dev.toml` (not `bmad-dev.toml`).

2. **TOML syntax error:** TOML is a specific format. Strings must be in quotes. Tables use `[section]`. Array-of-tables use `[[section]]`. Test your TOML at a validator (search "TOML validator" online).

3. **You copied the whole `customize.toml`:** Override files should only contain the fields you are changing. Do not copy the entire `customize.toml` into your override -- this causes problems when BMAD updates.

4. **Trying to change `agent.name` or `agent.title`:** These cannot be changed through override files. The agents' names and titles are hard-coded.

### 16.4 "uv is not found"

**What it means:** The `uv` program is not installed or not found in your terminal's PATH.

**Fix:**

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Then restart your terminal (or run `source ~/.bashrc` or `source ~/.zshrc`).

Verify it works:

```bash
uv --version
```

### 16.5 Skills Not Appearing in Claude Code

**What it means:** You ran the BMAD installer but the `/bmad-help`, `/bmad-build`, etc. skills are not available in Claude Code.

**Fix:**
1. Make sure Claude Code is opened in the project folder (not a parent folder)
2. Restart Claude Code
3. Check that the `.claude/skills/` folder exists and contains skill sub-folders
4. If skills are still missing, re-run: `npx bmad-method install --yes --directory . --modules bmm --tools claude-code`

### 16.6 "bmad-sprint-status Not Found"

`bmad-sprint-status` was replaced by `bmad-sprint-planning`. Use:

```text
/bmad-sprint-planning show sprint status
```

### 16.7 Review Stopped After Saying "Non-Convergence"

If `/bmad-build` produced a "review repair loop exceeded 5 iterations" message, it means the AI was having trouble getting the code to a passing state in an automated loop.

**Fix:** Start a fresh conversation and use `/bmad-build` again with a more specific description of what you want. The more precise your request, the fewer loops are needed.

### 16.8 I Want to Undo What BMAD Just Did

BMAD makes changes to your local files but does not push them to GitHub. To undo BMAD's last changes:

```bash
git status          # see what changed
git diff            # see the actual changes
git restore .       # undo all uncommitted changes
```

Always review BMAD's changes before saving them permanently. "Version control" means the Git system that tracks every change to the project's files over time (it is what lets you undo changes and see the history). "Committing" means saving a snapshot of your current changes into that history. BMAD makes file changes locally but never commits or saves them to the history on your behalf -- that is always your decision.

---

## Appendix: Quick Reference Card

Here is a one-line description of every skill, organized by what you are trying to do.

### Getting Oriented
| Skill | What it does |
|---|---|
| `/bmad-help` | Get context-aware advice on what to do next |

### Talking to Your AI Team
| Skill | Agent | Best for |
|---|---|---|
| `/bmad-agent-analyst` | Mary (📊) | Research, brainstorming, briefs, PRFAQ |
| `/bmad-agent-pm` | John (📋) | Requirements documents (PRDs), epics, stories |
| `/bmad-agent-ux-designer` | Sally (🎨) | Screen designs, user flows |
| `/bmad-agent-architect` | Winston (🏗️) | Technical decisions, architecture docs |
| `/bmad-agent-dev` | Amelia (💻) | Code, tests, reviews, sprint tracking |

### Building Code
| Skill | What it does |
|---|---|
| `/bmad-build` | Full build process: clarify, plan, code, review |
| `/bmad-build-auto` | Same as build but runs automatically (no questions) |
| `/bmad-dev-story` | Implement a specific planned story |
| `/bmad-dev-auto` | Fast autonomous implementation |
| `/bmad-quick-dev` | Quick code change, minimal process |

### Planning
| Skill | What it does |
|---|---|
| `/bmad-product-brief` | Write a quick product brief |
| `/bmad-prfaq` | Working Backwards product validation |
| `/bmad-prd` | Full requirements document (create/update/validate) |
| `/bmad-ux` | Design screens and user interactions |
| `/bmad-spec` | Technical spec (for automated build dispatch) |
| `/bmad-architecture` | Document technical decisions |
| `/bmad-create-epics-and-stories` | Break requirements into epics and stories |
| `/bmad-create-story` | Write one story |

### Sprint Tracking
| Skill | What it does |
|---|---|
| `/bmad-sprint-planning` | Readiness check, generate tracking file, show status, validate/fix |
| `/bmad-retrospective` | Review a completed epic, get acceptance verdict |
| `/bmad-checkpoint-preview` | Walk through code changes step by step |
| `/bmad-correct-course` | Handle mid-sprint changes |

### Research and Ideas
| Skill | What it does |
|---|---|
| `/bmad-brainstorming` | Guided idea generation (100+ ideas) |
| `/bmad-forge-idea` | Test if your idea is worth building |
| `/bmad-deep-recon` | Research any topic (market, technical, competitive, etc.) |

### Review and Quality
| Skill | What it does |
|---|---|
| `/bmad-code-review` | Review code changes |
| `/bmad-review` | Multi-lens review (code or documents) |
| `/bmad-qa-generate-e2e-tests` | Generate automated tests |
| `/bmad-advanced-elicitation` | Improve any output using reasoning methods |

### Project Setup and Customization
| Skill | What it does |
|---|---|
| `/bmad-project-context` | Set up / maintain AGENTS.md rules block |
| `/bmad-customize` | Add custom rules to any agent or workflow |
| `/bmad-party-mode` | Multi-agent group discussion |

### Repo-Specific Custom Skills (not BMAD-installed)

These 19 skills were already in this project's `.claude/skills/` folder before BMAD was installed. They are specific to this repository, not part of the BMAD framework. Use them just like any other skill -- type the name in Claude Code.

| Skill | What it does |
|---|---|
| `/code-review` | Review code changes against repo standards and the original spec |
| `/codebase-design` | Help design and improve module boundaries and interfaces |
| `/diagnosing-bugs` | Step-by-step diagnosis of hard bugs and performance problems |
| `/domain-modeling` | Build and refine the project's vocabulary and domain model |
| `/grill-me` | Test your plan by having the AI challenge you with hard questions |
| `/grilling` | Aggressive adversarial questioning of a plan or idea |
| `/handoff` | Transfer context when switching between sessions or agents |
| `/implement` | Execute a well-defined change |
| `/improve-codebase-architecture` | Find and implement architecture improvements |
| `/loop-me` | Run a task repeatedly in a loop |
| `/tdd` | Write code test-first (red-green-refactor style) |
| `/to-spec` | Turn a description or idea into a formal specification |
| `/to-tickets` | Convert requirements into individual work tickets |
| `/triage` | Sort issues or findings by severity and priority |
| `/wayfinder` | Get help choosing the right skill for your situation |
| `/writing-beats` | Writing with narrative structure |
| `/writing-for-agents` | Write documents that AI agents understand well (AGENTS.md, CLAUDE.md, skills) |
| `/writing-fragments` | Write sections or fragments of a document |
| `/writing-shape` | Restructure and reshape a document |

### Key BMAD Installer Options (for Part 15 reference)

When running `npx bmad-method install`, the most useful options beyond the defaults:

| Option | What it does | Example |
|---|---|---|
| `--yes` | Skip all questions, use defaults | `npx bmad-method install --yes --modules bmm --tools claude-code` |
| `--modules` | Which modules to include | `--modules bmm,tea` |
| `--tools` | Which AI tool to set up for | `--tools claude-code` |
| `--action update` | Add/remove modules without full re-install | `--action update --modules bmm,tea` |
| `--pin <code>=<tag>` | Lock a module to a specific version | `--pin tea=v2.1.0` |
| `--next=<code>` | Use the latest development version of a module | `--next=bmb` |
| `--set <module>.<key>=<value>` | Set a configuration value during install | `--set bmm.user_skill_level=expert` |
| `--list-options bmm` | See all available `--set` options for bmm | `--list-options bmm` |
| `--channel stable` | Use the latest stable version for all modules | `--channel stable` |
| `--all-next` | Use latest development versions for all modules (may be unstable) | `--all-next` |
| `--shims` | Install old-style compatibility shortcuts (only if upgrading from v4) | `--shims` |
| `--no-shims` | Remove old-style compatibility shortcuts | `--no-shims` |

**The three things /bmad-prd can do** (for reference from Part 4.2):
- **Create** -- write a brand-new requirements document
- **Update** -- change an existing requirements document when plans change
- **Validate** -- check that an existing requirements document is complete and correct

---

*Generated: 2026-08-24 | BMAD v6.11.0 | Repository: Daily-Motivation-Brain-Helper | Branch: SevAI_installing_bmad*
