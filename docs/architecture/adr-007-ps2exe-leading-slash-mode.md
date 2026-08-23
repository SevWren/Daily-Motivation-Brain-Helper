# ADR-007: Mode Switch Cases Use Leading-Slash Argument Values

ps2exe passes command-line arguments to the compiled exe with their leading
slashes intact. When Windows Task Scheduler invokes `DailyMotivation.exe /popup`,
ps2exe binds `$Mode = "/popup"` (not `"popup"`). All `$Mode` comparisons
throughout the codebase use the slash-prefixed form to match this behavior.

## Decision

Standardize on slash-prefixed mode names everywhere:

- Parameter `ValidateSet`: `"main"`, `"/popup"`, `"/setfolder"`
- Switch cases: match `"/popup"` and `"/setfolder"`; bare `"main"` is the default fallthrough
- OS Task action argument: `/popup`
- Context Menu Verb command: `/setfolder "%1"`

Any new code path that branches on `$Mode` must use the slash-prefixed string.
The bare `"main"` string is only reached via the default case (no CLI argument
passed) or in tests via `-NoRun`.

## Consequences

New contributors may expect `$Mode -eq "popup"` to work. The slash requirement is
non-obvious from PowerShell alone but is a constraint of how ps2exe binds
positional parameters - not a design choice that can be removed without
replacing the compiler.

## Evidence

`DailyMotivation.ps1` lines 21 (ValidateSet), 746 (OS Task action), 1294
(Context Menu Verb), 3093–3097 (switch cases). Example dialogue in `CONTEXT.md`
documents this quirk for developers.
