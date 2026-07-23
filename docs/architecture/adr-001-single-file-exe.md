# ADR-001: Single-file script compiled to one exe

## Status

Accepted

## Context

The product is a small Windows desktop utility. Earlier iterations accumulated multi-file layout and historical artifacts that made distribution and agent navigation harder.

## Decision

Ship **one PowerShell source file** (`DailyMotivation.ps1`) compiled with **ps2exe** to a single self-contained `DailyMotivation.exe` (`-STA -noConsole`). No runtime companion scripts or `src/` tree.

## Consequences

### Positive

- Trivial distribution: one exe
- Clear mental model for contributors and agents
- Tests can dot-source with `-NoRun` without building

### Negative

- Large single file; navigation relies on section comments and docs
- Must avoid PS7-only syntax that breaks under .NET Framework 4.x host
- Harder to share modules with other projects without extraction

## Alternatives considered

- Multi-module PowerShell project with installer — rejected for complexity vs product size
- Pure C# / WPF project — rejected to keep scripting velocity and existing Pester suite
