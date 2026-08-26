---
description: Commit message rules - always loaded, no path restriction
---

# Commit Message Rules

## WRONG - Issue closure keyword without explicit user confirmation

Using `Closes #N`, `Fixes #N`, or `Resolves #N` in a commit message when the
current conversation contains no explicit user-provided confirmation that the
issue is resolved.

```
# WRONG - no gate evidence, no user confirmation in conversation
Closes #194
```

**Why this is wrong:** GitHub closure keywords auto-close the issue when the
commit merges. A fix that compiles, passes CI, or passes mocked/Linux tests does
not mean the underlying bug is gone - especially for Windows-specific behavior
(see CLAUDE.md: *Tests passing in Linux do not validate Windows behavior*).
Writing `Closes #N` without confirmation creates a false record that the problem
is solved and triggers premature issue closure.

**What counts as user confirmation** (at least one required before using a closure keyword):

| Evidence | Counts? |
|---|---|
| User posts passing `.\Invoke-Tests.ps1` output from a real Windows 10/11 machine | Yes |
| User explicitly states "confirmed fixed", "verified", "this resolves it", or equivalent | Yes |
| User links a passing Windows CI run for the affected tests | Yes |
| CI green on Linux | **No** |
| Mocked-only tests passing | **No** |
| Code review / agent self-assessment | **No** |
| Conversation silence / no objection | **No** |

**Rule:** Do not write `Closes #N`, `Fixes #N`, or `Resolves #N` in any commit
message unless the user has provided explicit confirmation in the current
conversation that the fix resolves the issue. When in doubt, omit the closure
keyword - the issue can always be closed manually.

---

## CORRECT - Reference without closure when confirmation is absent

When the fix is plausible but the user has not yet confirmed resolution, use a
non-closing reference:

```
Related to #194
```

---

## CORRECT - Closure keyword only after confirmed resolution

Only after the user has provided one of the qualifying confirmations above:

```
Closes #194

User confirmed: Windows PS7 test run posted showing 0 failures for
Issue #194 regression tests.
```

The confirmation evidence must be traceable to a specific user message in the
current conversation. Never infer confirmation from a passing test run that you
(the agent) executed - only the user can attest that the fix resolves their
reported problem.
